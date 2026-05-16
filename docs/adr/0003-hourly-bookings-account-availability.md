---
status: accepted; pricing portion superseded by ADR 0004
date: 2026-05-08
decision-makers: [aiden]
---

# Hourly-only bookings with account-level availability (v1)

> **Status note (2026-05-15).** This ADR originally bundled two decisions: (a) account-level availability with a `slot_occupancy` table and cross-profile blocking, and (b) hourly-only pricing (`hourly_rate` as the only price column; no `rate_type` enum). Decision (a) remains in force. Decision (b) is **superseded by [ADR 0004](0004-session-and-hourly-pricing.md)**, which reintroduces a `pricing_type` enum (`SESSION` | `HOURLY`) following the product's repositioning around creative services. The text below is preserved verbatim; read alongside ADR 0004 for the current pricing model.

## Context and Problem Statement

Two coupled questions about the v1 booking model needed answers that the original PRD did not give cleanly:

1. **Pricing surface.** The PRD listed three rate types — hourly, flat rate, and custom. Carrying all three through v1 multiplies UI surface (a rate-type selector in onboarding, profile editing, search filters, checkout) and data-model surface (a `rate_type` enum, polymorphic price fields), without a validated demand signal that any of the non-hourly modes are needed for the MVP category.
2. **Whose calendar?** The PRD said "Buyers book against a specific profile; a seller's separate profiles have independent booking calendars." But the seller is one human — independent calendars make it possible, by construction, to double-book the same person across two of their profiles. ADR 0001 / 0002 establish the profile as the *commercial* unit (pricing, discovery, conversations), which is right; but **physical time** can't belong to a profile, because the human can only be in one place at one moment.

The two decisions interact: the cleanest cross-profile blocking model assumes a single unit of inventory (the hour), so collapsing pricing and unifying availability are best decided together.

## Decision Drivers

- Avoid designing in a real-world impossibility (one human in two places at once).
- Reduce v1 surface area: no rate-type selector across onboarding, profile edit, search filters, or checkout; no polymorphic price fields in the data model.
- Stay consistent with ADR 0001's "profile is the commercial unit" stance — pricing and discovery remain per-profile — while acknowledging that physical time can only belong to the human (the account).
- Enable a clean first-come-first-served slot-claim model with no cross-profile race condition.
- Keep the booking *flow* friendly to a marketplace where sellers are not always online: a request → accept/decline lifecycle, not a fully automatic transaction.

## Considered Options

**Calendar ownership (the cross-profile question):**

- **A — Independent per-profile calendars (current PRD).** Each profile owns its own availability and bookings. Rejected: structurally allows the same human to be booked twice in the same hour through two different profiles.
- **B — Per-profile calendars + a cross-profile blocking layer.** Each profile publishes its own windows; a coordination layer auto-closes overlapping slots when any one is claimed. Rejected: complex to model (overlapping windows on different profiles must auto-resolve), no clear ownership of "the truth" calendar, and a buyer browsing profile A may see a different availability picture than the same buyer would compute by looking at all of the seller's profiles together.
- **C — Account-level calendar, profile-level pricing (chosen).** One calendar lives on the seller account. Buyers book against a specific profile (and pay that profile's hourly rate), but the slot inventory is account-wide. A slot held or booked through any profile is unavailable on every other profile of the same seller.
- **D — Defer the booking model entirely.** Rejected: bookings are an explicit Phase 1 MVP requirement.

**Pricing surface:**

- **P1 — Keep `rate_type` enum, restrict to `HOURLY` in v1.** Rejected: adds a field that does nothing in v1. Carrying a single-valued enum just to gesture at future flexibility creates UI dead weight (a selector with one option) and a migration path that can be reintroduced later anyway.
- **P2 — Remove the rate-type concept from spec and data model entirely; hourly is implicit (chosen).** Reintroduce post-validation if a category needs it.

## Decision Outcome

Chosen: **C + P2.** Account-level availability with hourly-only pricing.

Schema-level summary (full migration to land in `fl-api/prisma/migrations/…_account_availability/` when the API is implemented):

- `seller_profiles.rate_type` and `seller_profiles.flat_rate` are not introduced (or removed if they exist). `hourly_rate` is the only price column on `seller_profiles`.
- Availability moves from `seller_profiles.availability_*` to a new table keyed on `seller_id` (e.g. `seller_account_availability_windows`). Sellers publish windows once per account; all of their profiles draw from the same windows.
- A `slot_occupancy` (or equivalent) table holds one row per `(seller_id, slot_start)` that is either **HELD** (request pending) or **BOOKED** (request accepted). The unique constraint on `(seller_id, slot_start)` is the no-overbooking guarantee at the DB layer — derived through the profile→account join when the request comes in via a profile.
- **Hold creation** is a transactional `INSERT` into `slot_occupancy` with `state = HELD` and a `held_until` timestamp at `request_created_at + 12h`. Concurrent inserts for the same `(seller_id, slot_start)` fail with a unique-violation, surfaced to the second buyer as "slot just taken".
- **Accept** transitions HELD → BOOKED and captures payment.
- **Decline** or **`held_until` expiry** deletes the hold row, returning the slot to availability. Expiry is reaped by a scheduled job (or computed at read-time).
- **Originator withdrawal** of a still-pending request also deletes the hold row. The withdraw endpoint accepts the operation only while the request is in REQUESTED state (i.e., before the counterparty has responded); a 409-style error otherwise. Symmetric: applies to buyer-withdrawal of a booking request and to seller-withdrawal of a modification proposal.
- **Modifications** can be proposed on any open booking (INCOMING, CONFIRMED, or ACTIVE). The proposal reuses the same `slot_occupancy` HELD state for any *net-new* slots. Original slots stay in their current state (HELD on INCOMING bookings, BOOKED on CONFIRMED/ACTIVE) during proposal review. On counterparty approval, original-but-not-in-proposal slots are released; proposed-but-not-in-original slots transition to the booking's current state — HELD if the booking is still INCOMING (the seller's accept step is unchanged and still flips HELD→BOOKED), BOOKED if already accepted. Approving a modification is a terms change, not an accept. Price delta is captured (extension) or refunded (shortening) at the booking's originally captured `hourly_rate` (not the seller's current rate). Proposals carry their own 12h `decided_by` deadline, an originator (buyer or seller), and may be withdrawn by the originator before resolution. Pre-accept modifications let buyer and seller settle on terms inside the 12h accept window without forcing a decline+rebook.

### Consequences

- Good, because it is structurally impossible to double-book the same human across profiles.
- Good, because the rate-type selector disappears across all surfaces (onboarding, profile edit, search filters, checkout) and no v1 ceremony exists for a feature that is not yet needed.
- Good, because the seller has one editing surface for availability — they don't manage N calendars when they have N profiles.
- Good, because pricing differentiation across profiles remains clean (per-profile `hourly_rate` column).
- Neutral, because cross-profile views of availability for the *same* seller are now trivially derivable (one calendar) rather than synthesized.
- Bad, because a buyer browsing profile A can be told "this slot is unavailable" without obvious cause when the slot is actually held or booked via the seller's profile B. UI must explain ("seller is unavailable at this time") without leaking which other profile holds it.
- Bad, because holds tie up inventory for up to 12h while the seller decides. A slow-to-respond seller loses bookings as buyers' attention moves on. Mitigated by push notifications on every request and automatic expiry.
- Bad, because bilateral modifications widen the booking lifecycle (more states, more notifications, more refund/capture paths). Acceptable: the alternative — cancel-then-rebook — fragments reviews and messaging and risks the new slot being claimed by someone else mid-rebook.
- Bad, because per-day and per-session sellers (e.g., a personal driver doing a full-day hire) cannot model their offering naturally in v1. Acceptable given MVP scope; reintroduce post-validation if a category demonstrably needs it.

### Confirmation

This ADR is in effect when:

- PRD has no remaining mention of "flat rate", "per-session", or "rate type" outside the *Out of Scope for MVP* list.
- PRD lists the availability calendar under the seller account, and the *Profile* glossary entry no longer claims availability.
- PRD's *Booking & Scheduling* section describes (a) account-level windows and 1-hour slots, (b) request → accept/decline with a 12h hold, (c) bilateral modification proposals, (d) originator withdrawal.
- The schema (when implemented) shows availability tables FK'd on `seller_id`, not `seller_profile_id`, with a `slot_occupancy` table enforcing account-scoped uniqueness.

## Pros and Cons of the Options

### Option A — Independent per-profile calendars (current PRD)

Each profile owns its own availability rows and can be booked independently of the seller's other profiles.

- Good, because it requires no schema rework — it's the status quo before this ADR.
- Good, because it's the most "profile-as-commercial-unit" pure interpretation of ADR 0001.
- Bad, because it allows the same human to be booked twice for the same hour through two different profiles — a real-world impossibility.
- Bad, because there is no clean place for a "seller is unavailable" signal that crosses profiles, so the UX has to either fudge it (silently overbook) or implement Option B's coordination layer on top.

### Option B — Per-profile calendars + cross-profile blocking layer

Each profile publishes its own windows; a coordination layer auto-closes overlapping slots when one is claimed.

- Good, because it preserves "calendar belongs to the profile" framing for sellers who think of their offerings as separate businesses.
- Bad, because two profiles can publish conflicting windows (e.g., 14:00–16:00 on profile A and 15:00–17:00 on profile B); reconciliation rules become a separate design problem.
- Bad, because no single authority owns "is this slot free" — every read becomes a cross-profile join with explanation logic.
- Bad, because slot claims still need account-level coordination at write time, so the per-profile calendar is partly cosmetic.

### Option C — Account-level calendar, profile-level pricing (chosen)

A single availability calendar belongs to the seller account. Slots are inventory; profiles are how that inventory is priced and presented.

- Good, because it matches reality: the human owns their time, the profiles are how they sell it.
- Good, because the data model is honest about cross-profile inventory and the no-overbooking guarantee lives on a single unique constraint.
- Good, because the seller manages one calendar regardless of how many profiles they run.
- Bad, because the buyer-facing explanation for "unavailable" can't mention the other profile (privacy/leakage), so the message stays generic.
- Bad, because some categories (full-day services) don't naturally fit hourly slots and have to be deferred.

### Option D — Defer the booking model entirely

Push the whole booking question past v1.

- Bad, because the PRD already commits to a Phase 1 MVP booking flow. Deferring would invalidate the MVP scope.

### Option P1 — Keep `rate_type` enum, restrict to `HOURLY`

Carry the enum as a placeholder for future flat-rate / custom support.

- Good, because reintroduction of other rate types is one enum value away.
- Bad, because every consumer of pricing has to handle a single-valued enum that the UI hides — dead weight in the API, the buyer apps, and the seller apps.
- Bad, because a UI selector with one option is worse than no selector — it suggests choice without offering it.

### Option P2 — Remove the rate-type concept entirely (chosen)

`hourly_rate` is the only price column. Reintroduce a rate-type concept later if a category needs it.

- Good, because every surface is simpler in v1.
- Good, because reintroduction post-validation can be done with full knowledge of which alternative shape (flat / custom / both) actually matters.
- Bad, because reintroduction is a schema migration rather than an enum-value addition.

## More Information

- ADR 0001 — `fl/docs/adr/0001-seller-account-profile-separation.md` — establishes account vs. profile separation. This ADR resolves which level owns *physical time*.
- ADR 0002 — `fl/docs/adr/0002-profile-scoped-conversations.md` — established that conversations are profile-scoped. Conversations remain profile-scoped under this ADR; only availability moves up to the account.
- PRD — see *Glossary → Account*, *Glossary → Profile*, *Glossary → Window*, *Glossary → Slot*, *Core Features → Seller Profiles*, *Core Features → Booking & Scheduling*, *Out of Scope for MVP*.

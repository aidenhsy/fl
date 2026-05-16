---
status: accepted; exclusivity portion superseded by ADR 0005
date: 2026-05-15
decision-makers: [aiden]
supersedes: 0003 (pricing portion only — see *More Information*)
---

# Session/package pricing as primary, hourly retained (v1)

> **Status note (2026-05-16).** The original ADR positioned `pricing_type` as an **exclusive** per-profile discriminator (a profile is SESSION or HOURLY, never both). [ADR 0005](0005-non-exclusive-pricing-capabilities.md) relaxes that — profiles can now offer packages + hourly + extension hours simultaneously, with `pricing_type` retained as a *primary-mode* hint rather than an exclusivity gate. The Package + Variant model, proposal-time price capture, denormalised at-booking fields, and the booking-side `pricing_mode` discriminator all remain in force. Read alongside ADR 0005 for current behaviour.

## Context and Problem Statement

ADR 0003 collapsed v1 pricing to hourly-only. That decision was made under the original product positioning — a generalist services marketplace (くらしのマーケット-style) whose presumed launch verticals (personal training, driving, tutoring, cleaning) sold metered time. Hourly pricing was the natural unit for those categories, and the simplification (no `rate_type` enum, no polymorphic price fields, no UI selector) bought a smaller v1 surface.

The product has since been repositioned around **creative services** — photographers, videographers, designers — with travel/portrait photography as the launch wedge. Creative work is not sold by the hour:

- A wedding photographer sells "a wedding package — full day coverage, 200 edited photos, online gallery, delivered in 4 weeks", not "8 hours of photography".
- A portrait photographer sells "a 2-hour portrait session, 30 edited photos delivered in 7 days, ¥18,000 flat", not "2 × ¥9,000/hour".
- A videographer sells a project (event highlights reel, brand promo) with a flat package price and a defined deliverable.

Hourly-only also forces creative sellers to do uncomfortable backwards math at listing time — "what's my session worth divided by hours?" — and exposes that calculation to buyers, who then compare on hourly rate rather than on portfolio. The framing is wrong for the new category.

The earlier verticals (training, driving, etc.) have not been excised from the model and may return as the platform broadens — and hourly pricing is genuinely the right unit for those. So the v1 model has to support both, not pivot from one to the other.

This ADR addresses only **pricing**. ADR 0003's other decision — account-level availability with cross-profile slot blocking — is independent of pricing surface and remains in force.

## Decision Drivers

- Match how creative sellers actually price and sell their work.
- Don't lock out the original verticals where hourly genuinely fits.
- Preserve the account-level availability and slot-occupancy model from ADR 0003 — pricing type is orthogonal to slot ownership.
- Keep the modification-proposal flow economically symmetric and bilateral under both pricing types.
- Accept the v1 cost of reintroducing a pricing-type surface (the surface ADR 0003 deliberately removed) — that cost was justified under the prior positioning and is no longer.

## Considered Options

- **A — Keep hourly only.** Rejected: structurally incompatible with how creatives price.
- **B — Switch to session-only.** Rejected: closes off verticals where hourly is the natural unit, and creates retrofit pain if hourly returns post-launch.
- **C — Support both, with a `pricing_type` per profile (chosen).** Default and primary type is `SESSION`. `HOURLY` is retained for verticals that genuinely meter time.

## Decision Outcome

Chosen: **C.** Each profile carries a `pricing_type` enum (`SESSION` | `HOURLY`) and the corresponding rate fields. `SESSION` is the default at profile creation since the launch category is creative.

Schema-level summary (full migration to land in `fl-api/prisma/migrations/…_pricing_type/` when the API is implemented):

**Two enums, one mapping:**

- `seller_profiles.pricing_type` ∈ `{ SESSION, HOURLY }` — describes the seller's **offering shape**. `SESSION` is the default at profile creation.
- `bookings.pricing_mode` ∈ `{ PACKAGE, HOURLY }` — explicit per-booking discriminator describing the **captured pricing basis** of that booking. Bookings against `SESSION` profiles produce `pricing_mode = PACKAGE`; bookings against `HOURLY` profiles produce `pricing_mode = HOURLY`. The discriminator lets booking-reading code branch on a single column instead of inferring from null patterns across `package_id` / `hourly_rate_at_booking`.

**`HOURLY` profiles:** `seller_profiles.hourly_rate` (existing column from ADR 0003) applies. Booking total = `hourly_rate × number_of_slots`, unchanged.

**`SESSION` profiles — Package + Variant split:** the profile carries **one or more packages**, and each package carries **one or more priced variants**. This separation is driven by real launch sellers (e.g., a photographer offering solo/duo × digital/film — four priced permutations that share duration, deliverables, and the 注意事項 terms list, differing only in price/format/group-size).

- `seller_packages` — the **offer identity**. Columns: `id`, `profile_id` (FK `seller_profiles`, `ON DELETE CASCADE`), `sub_category_id` (FK `job_subcategories`, **NOT NULL** — every package belongs to a sub-category), `title`, `description`, `duration_slots` (int — the slot span shared across all variants of this package), `terms` (text — the 注意事項 list), `sort_order`, timestamps.
- `seller_package_variants` — the **priced permutation**. Columns: `id`, `package_id` (FK `seller_packages`, `ON DELETE CASCADE`), `label` (e.g., "Solo digital, 9 photos", "Duo film, 30 photos"), `price` (JPY), `format` (enum `{ DIGITAL, FILM, VIDEO, OTHER }`, nullable for non-photography), `included_items` (text — variant-specific deliverables, e.g., "9 retouched photos; film roll & scanning included"), `sort_order`, timestamps. Group size and deliverable counts (photo count, hours-of-class, etc.) ride on `label` + `included_items` rather than as structured columns — these axes vary by vertical, and a buyer-side feature with structured demand hasn't materialised yet.
- A `SESSION` profile must have ≥ 1 package; every package must have ≥ 1 variant; an `HOURLY` profile has neither.

**Slot inventory unchanged from ADR 0003:** under both pricing modes, bookings hold and book 1+ contiguous slots inside an availability window; the `(seller_id, slot_start)` unique constraint enforces no-overbooking identically. A package's `duration_slots` determines how many slots are held when that package is booked (duration lives on the *package*, not the *variant*, since the launch case has duration-shared-across-variants).

**Booking-time UX:**
- `HOURLY`: buyer picks start time *and* number of slots.
- `SESSION`: buyer picks a package, then a variant within that package, then a start time; the slot span is derived from `package.duration_slots`. Total is the flat `variant.price`.

**Booking denormalisation** (mirrors the existing `hourly_rate_at_booking` pattern, so editing or deleting a package/variant never retroactively reprices a confirmed booking):
- All bookings carry `pricing_mode` (the discriminator).
- HOURLY bookings (`pricing_mode = HOURLY`) carry `hourly_rate_at_booking` (existing).
- PACKAGE bookings (`pricing_mode = PACKAGE`) carry `package_id`, `package_variant_id`, `package_title_at_booking`, `package_duration_slots_at_booking`, `variant_label_at_booking`, `variant_price_at_booking`. Both FKs are `ON DELETE SET NULL` so a seller can retire a package or a variant without breaking the history of bookings against them.

**Modification proposals:** every modification captures its pricing snapshot at **proposal time**, not approval time. The rule is uniform across all four axes:

| Axis | What snapshot is captured at proposal time | Where |
|---|---|---|
| HOURLY start-time only | Degenerate — no new pricing data; the booking's frozen `hourly_rate_at_booking` is the snapshot | `bookings.hourly_rate_at_booking` (already frozen) |
| HOURLY slot-count change | Degenerate — same frozen `hourly_rate_at_booking`; the proposal carries `proposed_slot_count` and delta is computed as `hourly_rate_at_booking × (proposed_slot_count − booking.slot_count)` | `booking_modifications.proposed_slot_count` (existing) |
| PACKAGE start-time only | The booking's current package + variant snapshot (degenerate — same as current) | `booking_modifications.proposed_package_*_at_proposal`, `proposed_variant_*_at_proposal` |
| PACKAGE variant-within-package change | The new variant's current price + label, plus the unchanged package's title + duration_slots | same |
| PACKAGE cross-package change | The new package's title + duration_slots + the new variant's price + label | same |

The rule is uniform — every modification row carries the proposed pricing snapshot, even when degenerate — because uniformity is cleaner in code and removes the temptation to introduce special cases later. For HOURLY, the snapshot lives implicitly in the booking's frozen `hourly_rate_at_booking`, so no new HOURLY-specific columns are needed.

**Why proposal-time, not approval-time.** If the seller edits a variant's price between proposing a modification and the buyer approving it, the buyer must be charged what they saw in the proposal, not the new edited price. Approval-time capture would let a seller (intentionally or not) bait-and-switch — buyer sees "¥1,100" in the proposal, accepts, gets charged "¥1,300" because the variant was re-priced in between. Proposal-time capture makes the modification row a complete, self-contained statement of "here is the new deal" and approval becomes a pure yes/no on that exact deal.

**On approval:**
- The `_at_proposal` snapshot fields on the modification row are copied onto the booking as the new `_at_booking` values (e.g., `proposed_variant_price_at_proposal` → `variant_price_at_booking`); `package_id` and `package_variant_id` are updated to match the proposed values.
- Price delta = `new_variant.price_at_proposal − variant_price_at_booking` (for PACKAGE) or `hourly_rate_at_booking × (proposed_slot_count − booking.slot_count)` (for HOURLY). For PACKAGE, the delta is zero when the proposed variant is the same as the booking's current variant (i.e., a start-time-only PACKAGE modification).

**On rejection or expiry:** the modification row's `_at_proposal` snapshot is preserved for audit but never copied onto the booking. The booking's `_at_booking` values are untouched.

This preserves ADR 0003's no-retroactive-reprice guarantee for the unchanged leg of any modification — the seller's *current* prices are never used at approval; only the proposal's frozen snapshot is.

**New `booking_modifications` columns** (all nullable; populated only when the parent booking has `pricing_mode = PACKAGE`):
- `proposed_package_id` (FK `seller_packages`, `ON DELETE SET NULL`)
- `proposed_package_variant_id` (FK `seller_package_variants`, `ON DELETE SET NULL`)
- `proposed_package_title_at_proposal`
- `proposed_package_duration_slots_at_proposal`
- `proposed_variant_label_at_proposal`
- `proposed_variant_price_at_proposal`

The existing `proposed_slot_count` column stays. For PACKAGE proposals it is set equal to `proposed_package_duration_slots_at_proposal` (redundant but uniform); for HOURLY proposals it is the buyer/seller-chosen count.

Search and filter surface:

- The profile card shows a single representative price for the profile — the **minimum `variant.price` across all variants of all packages on the profile** (with a "from ¥X" prefix) for SESSION profiles, the `hourly_rate` for HOURLY profiles — with a unit label.
- A buyer-facing price-range filter accepts a budget in JPY and matches the min-variant-price for SESSION profiles and the `hourly_rate` for HOURLY profiles. Cross-type comparison is approximate — pending product-owner review on whether the filter exposes pricing-type as a separate facet.
- Sub-category is a first-class filter dimension for SESSION profiles: a buyer searching "Travel/portrait photography (旅拍)" matches profiles that have ≥ 1 package in that sub-category. Sub-category also feeds search ranking — profiles with more packages and more portfolio media tagged with the queried sub-category rank higher.

### Consequences

- Good, because the data model matches how the launch buyers and sellers actually transact.
- Good, because ADR 0003's account-level inventory model carries over without change.
- Good, because the modification flow remains bilateral and economically symmetric under both pricing types.
- Good, because the original verticals (training, driving) are not locked out — they get the right pricing surface (`HOURLY`) when they return.
- Bad, because v1 UI now carries a pricing-type concept that ADR 0003 had removed: a selector at profile creation, different price displays on the profile card, different math at booking total, slightly different modification semantics. This is the explicit reason to revisit ADR 0003's pricing decision.
- Bad, because search filters are more complex (price-range filter normalises across types). Acceptable for v1; can be refined post-launch with real buyer behaviour data.
- Bad, because reintroducing a `pricing_type` enum is a schema migration. Acceptable: ADR 0003 anticipated this exact migration ("reintroduce post-validation if a category needs it") — the validation is the repositioning.

### Confirmation

This ADR is in effect when:

- PRD's *Glossary → Profile* lists pricing as session/package or hourly (not "hourly rate").
- PRD's *Core Features → Seller Profiles* documents `pricing_type` and the Package + Variant model.
- PRD's *Core Features → Booking & Scheduling* shows total-price math for both modes and the booking-time package→variant→time picker.
- PRD's *Core Features → Payments* notes which payment events fire for PACKAGE vs. HOURLY bookings (mostly identical; PACKAGE simply uses `variant_price_at_booking` as the captured amount).
- PRD's *Out of Scope for MVP* no longer lists "Per-session / per-day rate types". Multi-package per profile and multi-variant per package are **in scope** for v1 at the **schema** level. The **seller UI** ships in v1 with single-variant package creation only; a multi-variant editor is a fast-follow PR — see PRD *Out of Scope for MVP*. Deposit handling is intentionally out of this ADR and will be addressed separately.
- ADR 0003's status reflects that its pricing portion is superseded by this ADR; its calendar/availability portion remains in force.
- The schema (when implemented) has: `seller_profiles.pricing_type` (SESSION | HOURLY), `bookings.pricing_mode` (PACKAGE | HOURLY) discriminator, `seller_packages` child table (with NOT NULL `sub_category_id`), `seller_package_variants` child table. SESSION profiles have ≥ 1 package and each package has ≥ 1 variant; HOURLY profiles have neither.

## Pros and Cons of the Options

### Option A — Keep hourly only

- Good, because v1 surface is minimal (the ADR 0003 status quo).
- Bad, because the launch category does not price by the hour. Listing a photographer at "¥9,000/hour" misrepresents the product and forces awkward backwards math.
- Bad, because hourly-only invites buyer comparison on a metric that is not how creative work is sold or chosen.

### Option B — Switch to session-only

- Good, because it matches the launch category cleanly.
- Bad, because it closes off the verticals where hourly is genuinely the right unit (training, driving) — those would need a retrofit if they return post-launch.
- Bad, because some creative sellers do also offer hourly add-ons (e.g., "additional hours billed at ¥6,000/hour"); session-only forces them to model overflow as a separate package.

### Option C — Support both, with `pricing_type` per profile (chosen)

- Good, because it covers both the new launch category and the original verticals without forcing one shape onto the other.
- Good, because pricing type is orthogonal to slot inventory — the cross-profile no-overbooking guarantee from ADR 0003 carries over without modification.
- Good, because reintroducing `pricing_type` now (with a clear use case) is the future-proofing path ADR 0003 explicitly anticipated.
- Bad, because v1 UI carries a selector and conditional layouts that ADR 0003 had eliminated. Justified by the new positioning.

## More Information

- ADR 0001 — `fl/docs/adr/0001-seller-account-profile-separation.md` — establishes profile as the *commercial* unit (pricing, discovery), 1:N from the account with `@@unique(seller_id, category_id)`. This ADR adds `pricing_type` and the Package + Variant child tables to that unit; the 1:N cardinality and per-category profile uniqueness are unchanged.
- ADR 0003 — `fl/docs/adr/0003-hourly-bookings-account-availability.md` — bundled two decisions: (a) account-level availability, and (b) hourly-only pricing. This ADR supersedes **only (b)**. ADR 0003's status frontmatter is updated to reflect the partial supersession; the calendar / slot-occupancy / cross-profile blocking decisions remain in force unchanged.
- PRD — see *Glossary → Profile*, *Core Features → Seller Profiles*, *Core Features → Booking & Scheduling*, *Core Features → Payments*, *Out of Scope for MVP*.

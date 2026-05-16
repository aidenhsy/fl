---
status: accepted
date: 2026-05-16
decision-makers: [aiden]
supersedes: 0004 (exclusivity portion only — see *More Information*)
---

# Non-exclusive pricing capabilities + package-extension hourly rate (v1)

## Context and Problem Statement

ADR 0004 introduced `seller_profiles.pricing_type ∈ { SESSION, HOURLY }` as an **exclusive** discriminator: a profile is one or the other. That was the right shape for the launch cases I had in mind — travel/portrait photographers selling packages, drivers selling hours — and the corresponding seller UI shipped as a segmented "Packages | Hourly" picker.

Two real-world patterns push past that exclusivity:

1. **Package + ad-hoc hourly on the same profile.** A photographer mostly sells 2h portrait packages but also takes "I just need someone for one hour" ad-hoc bookings. Under ADR 0004 they have to either model these as more packages (a "1h Quick Shoot" package — workable but loses the "ad-hoc" framing) or split into two profiles per category (blocked by `@@unique(seller_id, category_id)`, which ADR 0001 made a v1 invariant). Neither is clean.
2. **Package + overtime extension hours.** A wedding photographer sells "4h coverage ¥80,000" but charges ¥5,000/hour for overtime when the day runs long. The overtime amount is an *open-ended* hourly rate, not a fixed extra-hours package. ADR 0004 has no mechanism for this — a modification proposal can change the *variant* (swapping one fixed package for another) but cannot add hours billed at a unit rate.

The fix can't be "make the seller create two profiles" — `@@unique(seller_id, category_id)` blocks that, and ADR 0001's reasoning for that uniqueness still holds. The fix has to live inside the single-profile model.

## Decision Drivers

- Match how real sellers price (the two patterns above are common in the photography market).
- Keep the per-booking `pricing_mode` discriminator from ADR 0004 — the booking itself is still unambiguously priced as one mode or the other.
- Avoid invalidating ADR 0001's per-category uniqueness — the new model lives inside a single profile.
- Keep migration cost small (add fields, not restructure tables).
- Keep the seller UI explicit about capabilities — buyers should see exactly the options a seller offers, no more.

## Considered Options

- **A — Keep ADR 0004's exclusivity.** Sellers with mixed offerings work around via extra package rows (model "1h quick shoot" as a variant). Rejected: the workaround is awkward for ad-hoc framing and structurally impossible for open-ended overtime hours.
- **B — Replace `pricing_type` with `(acceptsPackages, acceptsHourly)` booleans.** Drops the discriminator entirely; capabilities are independent flags. Rejected: invalidates the booking-side `pricing_mode` discriminator's coupling to a profile-level intent, makes the "what does this profile primarily sell" hint disappear (relevant for card display and ranking).
- **C — Keep `pricing_type` as the *primary mode* hint; make capabilities independent.** Profile can have packages, hourly rate, both, plus a new `hourly_extension_rate` for overtime. `pricing_type` becomes "what the seller positions themselves as" rather than "the one mode they offer." (Chosen.)

## Decision Outcome

Chosen: **C.**

### Profile fields, after this ADR

- `seller_profiles.pricing_type ∈ { SESSION, HOURLY }` — **primary mode** (display/positioning hint). No longer exclusive — does not gate what other fields can be set. Default at create remains `SESSION` for new profiles in the launch category.
- `seller_profiles.hourly_rate` (nullable Decimal) — "ad-hoc by-the-hour" rate. Set when the seller accepts standalone hourly bookings (independent of whether they also have packages).
- `seller_packages[]` (existing) — package + variant matrix. Their presence means "this profile accepts package bookings."
- **NEW:** `seller_packages.hourly_extension_rate` (nullable Decimal, **per-package**) — overtime rate applied when extending *this specific* package's booking past its included duration. Per-package, not per-profile, because the natural rate varies by offering: a wedding package on the same profile as a travel-portrait package will have very different overtime economics (¥10,000/hr vs ¥4,000/hr). A package without an extension rate doesn't accept overtime; the buyer must split into a separate booking.

### Capability matrix (derived from data, exposed on read DTOs)

| Capability | Level | True when |
|---|---|---|
| `acceptsPackages` | profile | profile has ≥ 1 active package |
| `acceptsHourly` | profile | `seller_profiles.hourly_rate IS NOT NULL` |
| `acceptsExtension` | package | `seller_packages.hourly_extension_rate IS NOT NULL` on that specific package |

At least one of `acceptsPackages` / `acceptsHourly` must be true for a profile to be bookable — enforced in the application layer (the use case rejects a profile that ends up with neither). DB-level CHECK is deferred since `acceptsPackages` requires a join.

### Booking-side semantics (unchanged from ADR 0004)

The per-booking `pricing_mode ∈ { PACKAGE, HOURLY }` discriminator from ADR 0004 stays. It records *how this specific booking was priced* and is independent of what other modes the profile also offered. A mixed-capability profile produces both PACKAGE bookings and HOURLY bookings; each booking row carries one and only one mode.

### Extension hours via modification

When a buyer wants to extend a PACKAGE booking past the package's `duration_slots`:

- The seller (or buyer) proposes a modification adding `Δslots` of extension time.
- Modification proposal stores `proposed_extension_slots` and the snapshot rate (`hourly_extension_rate_at_proposal`) at proposal time, sourced from **the booked package's** `hourly_extension_rate` at the moment of proposal (per ADR 0004's proposal-time capture rule). Different packages on the same profile resolve to their own rates.
- On approval, those slots are billed at `proposed_extension_slots × hourly_extension_rate_at_proposal` and added to the booking total.
- The booking's `pricing_mode` stays `PACKAGE` — the extension is an add-on, not a mode flip. New booking columns: `extension_slots`, `extension_hourly_rate_at_booking` (denormalised, NULL when no extension).
- A PACKAGE modification cannot add extension hours unless the booked package has `hourly_extension_rate` set (otherwise the proposal is rejected with `EXTENSION_NOT_OFFERED`).

**Schema additions for extension on bookings:**

- `bookings.extension_slots` (Int, nullable)
- `bookings.extension_hourly_rate_at_booking` (Decimal, nullable)
- `booking_modifications.proposed_extension_slots` (Int, nullable)
- `booking_modifications.proposed_extension_hourly_rate_at_proposal` (Decimal, nullable)

These are nullable since most bookings won't have extensions. The booking total = `variant_price_at_booking + (extension_slots * extension_hourly_rate_at_booking)` for PACKAGE bookings with extensions.

### Validation rules

**On profile create/update:**
- `pricing_type` is required as a "primary mode" hint (existing).
- If `pricing_type = HOURLY` → `hourly_rate` must be set and > 0 (the seller positions hourly as primary, so they must offer it).
- If `pricing_type = SESSION` → `hourly_rate` is optional. The seller can also set it for mixed mode.
- `hourly_extension_rate` is per-package. Setting/clearing it lives in the package editor, not the profile editor.
- At least one capability must end up true (i.e., a profile with `pricing_type=SESSION`, no packages, and no `hourly_rate` is invalid — but only the final state matters, not intermediate during onboarding).

**On booking creation:**
- PACKAGE mode requires `acceptsPackages = true` on the profile (i.e. ≥ 1 active package).
- HOURLY mode requires `acceptsHourly = true` on the profile (i.e. `hourly_rate IS NOT NULL`).

**On modification proposal:**
- An extension-hours modification requires the booked package to have `hourly_extension_rate IS NOT NULL`. Otherwise: 400 with code `EXTENSION_NOT_OFFERED`.

### Pricing on the profile card (search/discovery)

The back-compat `price` field on profile DTOs (ADR 0004) continues to render as:

- Profile has packages: `min(variant.price across all variants)` — the "from ¥X" floor.
- Profile has hourly only: `hourly_rate`.
- Profile has both: `pricing_type` decides which is primary. SESSION primary → min variant price; HOURLY primary → hourly_rate.

The new raw fields (`hourlyRate`, `minVariantPrice`, `hourlyExtensionRate`) let the iOS UI render the secondary offering ("also ¥6,000/hour" or "overtime ¥5,000/hour") when present.

### Consequences

- Good, the photographer use cases land cleanly: package-only, package + ad-hoc hourly, package + overtime, hourly-only, hourly + ad-hoc add-ons. All in one profile.
- Good, the booking-side `pricing_mode` discriminator from ADR 0004 stays untouched. Booking-reading code branches on a single column as before.
- Good, ADR 0001's per-category uniqueness invariant is preserved.
- Bad, the seller UI is now multi-toggle instead of a single segmented picker. More UI surface, but each toggle is binary and the layout is small.
- Bad, the booking modification flow gets a new axis (extension hours). Additional columns on `booking_modifications` + `bookings`, new validation. Acceptable: it's the only way to model open-ended overtime.
- Bad, the discrimination on "what does this profile primarily sell" lives in `pricing_type` semantics rather than the data — it's a positioning field, not an exclusivity gate. Documentation must be clear on this so reviewers don't read it as a constraint.

### Confirmation

This ADR is in effect when:

- PRD's *Glossary → Profile* describes profiles as having a *primary* pricing type with optional additional capabilities (packages, hourly, extension).
- PRD's *Core Features → Seller Profiles* documents the capability matrix.
- PRD's *Core Features → Booking & Scheduling* documents how PACKAGE modifications can add extension hours.
- PRD's *Core Features → Payments* notes the extension component of the captured total.
- ADR 0004's status frontmatter reflects that the exclusivity portion is superseded by this ADR.
- The schema (when implemented) has `hourly_extension_rate` on `seller_packages` (not on `seller_profiles`), plus `extension_slots` / `extension_hourly_rate_at_booking` on `bookings` and the proposal-side counterparts on `booking_modifications`.

## Pros and Cons of the Options

### Option A — Keep ADR 0004's exclusivity

- Good, smaller v1 surface: one segmented picker, one DB column, no extension semantics.
- Bad, photographers with mixed offerings can't model their work without awkward workarounds.
- Bad, overtime extension is structurally impossible (can only swap variants).

### Option B — Replace `pricing_type` with capability booleans

- Good, the cleanest data model: capabilities are independent atoms.
- Bad, loses the "primary mode" hint that's useful for card display and discovery ranking.
- Bad, larger migration: dropping the enum column requires backfilling and changing the booking-side discriminator's relationship to the profile.

### Option C — Keep `pricing_type` as primary-mode hint; add capabilities (chosen)

- Good, smallest delta from ADR 0004 — adds one column, relaxes one constraint, adds extension-on-booking columns.
- Good, preserves ADR 0004's per-booking discriminator semantics.
- Good, lets the seller declare their positioning ("I'm a SESSION seller") while still offering hourly fallback.
- Bad, `pricing_type` now means "primary mode" in this ADR but meant "exclusive type" in ADR 0004. The semantic shift is a documentation burden, and reviewers reading old comments may be misled. Mitigated by status frontmatter on ADR 0004 + this ADR's prominent placement of the shift.

## More Information

- ADR 0001 — establishes `@@unique(seller_id, category_id)`. Preserved by this ADR — mixed pricing modes live inside the single profile rather than across multiple profiles per category.
- ADR 0003 — establishes account-level availability + `pricing_mode` on bookings. The booking discriminator from ADR 0003/0004 is unchanged.
- ADR 0004 — established `pricing_type` as the *exclusive* per-profile gate and proposal-time price capture for modifications. This ADR supersedes **only the exclusivity portion**. The Package + Variant model, proposal-time capture, denormalised at-booking fields, and the booking `pricing_mode` discriminator all remain in force.
- PRD — see *Glossary → Profile*, *Core Features → Seller Profiles*, *Core Features → Booking & Scheduling*, *Core Features → Payments*.

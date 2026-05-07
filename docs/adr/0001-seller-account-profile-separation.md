---
status: accepted
date: 2026-05-07
decision-makers: [aiden]
---

# Seller account / profile separation

## Context and Problem Statement

The original seller model conflated two distinct concepts: account-level data (identity, KYC, Stripe Connect, payout, contact) and profile-level data (bio, headline, portfolio media, category, rate). A seller declared categories via `seller_job_categories` (M:N junction) and set rates via `seller_services` (one row per `(seller_id, category_id)` with price, unit, description). Bio, headline, and portfolio media lived on the seller account itself, shared across every category that seller offered.

This created three concrete problems:

1. **Portfolio mismatch.** A driver's portfolio (vehicle photos, license class, insurance) and a photographer's portfolio (sample shots, style, gear) cannot share one bio or one media set. The single-account model forced them to.
2. **Discovery dilution.** Buyers searching for photographers saw cards advertising "photographer + driver," diluting credibility on both sides.
3. **Orphan-row footgun.** The two-step "declare category → set rate" flow allowed a category to exist without a service, or a service to be orphaned when its category was deselected (`selectJobCategories` replaced the full set without confirmed cleanup of dependent `seller_services` rows).

The product decision (recorded in the PRD) is to separate account from profile: one account holds 1..N profiles, each scoped to exactly one category, owning its own bio, portfolio, rate, slug, and reviews.

## Decision Drivers

- Each category needs its own portfolio and positioning to be credible to buyers.
- Discovery surfaces should be profile-scoped, not account-scoped, so buyers see only what's relevant to their search.
- Atomic profile creation eliminates the orphan-row footgun by collapsing "declare category" and "set rate" into a single transaction.
- Identity, KYC, and payout should remain consolidated at the account level — duplicating them per profile would be a UX and compliance burden.
- Pre-launch status: low data volume makes the migration cost low, so the right time to do this is now.

## Considered Options

- **Option 1.** Account/profile split with one profile per category in v1.
- **Option 2.** Keep the current model, fix UX with category-specific portfolio sections.
- **Option 3.** Allow N profiles per category from day one (drop the unique constraint).
- **Option 4.** Fully separate accounts per category — a "driver Aiden" account and a "photographer Aiden" account with distinct KYC and payout.

## Decision Outcome

Chosen: **Option 1 — Account/profile split with one profile per category in v1**, because it is the only option that solves both the portfolio mismatch and the discovery dilution at the data layer while keeping identity, KYC, and payout consolidated. The pre-launch timing also makes the migration cost low enough that paying it now is cheaper than paying it later.

Schema-level summary (full schema lives in the implementation prompt, not here):

- New `seller_profiles` table with a `(seller_id, category_id)` unique constraint, owning headline, bio, price, unit, description, slug, status, plus FK relations for portfolio media, reviews, and bookings.
- `seller_job_categories` and `seller_services` are deprecated and dropped after migration.
- `sellers` retains account-level fields only (auth, KYC, Stripe Connect `account_id`, payout, contact).
- The v1 unique constraint locks one profile per category per seller. Multiple profiles in the same category is explicitly deferred (see Option 3).

### Consequences

- Good, because discovery URLs become `/p/{profile_slug}`, making each profile its own indexable surface.
- Good, because reviews and reputation are profile-scoped, matching how buyers actually evaluate sellers.
- Good, because profile creation is atomic; the orphan-row class of bug disappears.
- Good, because onboarding collapses from four steps (declare categories → custom-job-request → rate setup → profile setup) into two (account creation → first profile funnel).
- Good, because Stripe Connect remains account-level — no payout architecture change is needed.
- Bad, because it requires breaking API changes: `POST /sellers/me/job-categories`, `POST /sellers/me/services`, and `PUT /sellers/me/services/:id` are removed and replaced with profile CRUD endpoints.
- Bad, because the iOS onboarding rewrite is non-trivial: `OnboardingJobSelectionView`, `OnboardingViewModel`, and `ServicesRatesSection` all change.
- Bad, because a migration script is needed to fan out existing `seller_services` rows into `seller_profiles` rows and to re-FK portfolio media, reviews, and bookings.
- Bad, because the bio and headline currently shared across categories must be carried to the first profile only; sellers will need to edit per-profile bios manually post-migration.
- Neutral, because aggregate seller-level metrics (e.g., "total bookings by this seller") now require a join across the seller's profiles rather than reading a single column. Acceptable cost for the cleaner model.
- Neutral, because account-level trust signals ("verified seller since X, N total bookings across all profiles") are deferred to v2 pending product owner review (see PRD → Ratings & Reviews).
- Neutral, because the "Seller activation rate" KPI is proposed to split into "active accounts" vs "active profiles" (see PRD → Success Metrics) — pending product owner review.

### Confirmation

This ADR is confirmed in effect when:

- The Prisma schema contains a `seller_profiles` table with the documented unique constraint, and `seller_job_categories` / `seller_services` are removed.
- The OpenAPI surface no longer exposes the deprecated category/service endpoints; profile CRUD endpoints replace them.
- The iOS onboarding flow lands on the profile list rather than the rate-setup screen as a terminal step.
- The merged migration removes profile-level columns (bio, headline, portfolio, rate) from the `sellers` table.

## Pros and Cons of the Options

### Option 1 — Account/profile split with one profile per category in v1

The chosen option. A new `seller_profiles` table with `@@unique(seller_id, category_id)` replaces both `seller_job_categories` and `seller_services`. Identity and payout stay on the seller account.

- Good, because each profile owns its own portfolio, headline, and bio — no more conflation across categories.
- Good, because profile-scoped discovery means buyers see only relevant cards.
- Good, because profile creation is a single transaction — no orphan rows possible.
- Good, because identity, KYC, and Stripe Connect stay consolidated at the account level.
- Bad, because it requires breaking API changes and an iOS onboarding rewrite.
- Bad, because a one-time data migration is needed to split existing `seller_services` rows into profiles.
- Neutral, because the unique constraint is easy to drop later if multi-profile-per-category demand emerges.

### Option 2 — Keep the current model, fix UX with category-specific portfolio sections

Add per-category portfolio fields to the existing model and surface them in the seller profile UI. No schema separation between account and profile.

- Good, because no migration is needed.
- Good, because no API breaking changes.
- Bad, because it does not solve discovery dilution — a buyer searching for photographers would still see "photographer + driver" cards.
- Bad, because it bolts category-specific data onto a model that was not designed for it; data shape grows messier over time.
- Bad, because the orphan-row footgun in the two-step flow remains.

### Option 3 — Allow N profiles per category from day one

Same as Option 1, but without the `@@unique(seller_id, category_id)` constraint. A seller could publish "wedding photography" and "corporate photography" as separate profiles immediately.

- Good, because maximum flexibility for sellers from day one.
- Bad, because there is no validated demand for sub-category profiles — speculative complexity.
- Bad, because it introduces real product complexity: positioning conflicts, naming collisions, buyer confusion when the same seller surfaces twice in one search.
- Neutral, because the constraint is cheap to drop later if demand emerges; introducing it after sellers have built habits would be harder.

### Option 4 — Fully separate accounts per category

A seller offering driving and photography would maintain two completely independent accounts: separate logins, separate KYC, separate Stripe Connect, separate payout.

- Good, because it gives the cleanest isolation between categories.
- Bad, because of KYC duplication — every additional category triggers another identity verification pass.
- Bad, because of payout duplication — sellers would manage multiple Stripe Connect accounts for what is effectively one income stream.
- Bad, because of login confusion — sellers with two services would need to remember which account is which.
- Bad, because it negates the core purpose of an account: identity is set up once, not per category.

## More Information

- PRD: `fl/docs/PRD.md` — see *Glossary*, *Core Features → Seller Profiles*, *Search & Discovery (Buyer)*, *Booking & Scheduling*, *Payments*, *Ratings & Reviews*, *MVP Scope*, *Out of Scope for MVP*.
- Implementation prompt: `seller-profiles-refactor-prompt.md` — handoff for the engineering work after this ADR is approved.

### Open questions flagged for product owner review

These are intentionally not resolved in this ADR:

- Account-level trust badge in v2 (see PRD → Ratings & Reviews).
- KPI split: active accounts vs active profiles (see PRD → Success Metrics).

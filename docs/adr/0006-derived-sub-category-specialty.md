---
status: accepted
date: 2026-05-16
decision-makers: [aiden]
---

# Derived sub-category specialty (no separate seller-side toggle)

## Context and Problem Statement

A buyer browsing **Photography** wants to filter to one specific shoot type — Wedding, Travel Portrait, Family, Graduation, etc. The sub-category taxonomy already exists (`job_subcategories`, seeded by the pricing-taxonomy migration) and shows up on two existing data points that sellers populate:

- **Packages** (`seller_packages.sub_category_id`) — when a seller publishes a package, they pick the sub-category it sits under. This is what they actively sell.
- **Portfolio items** (`portfolio_items.sub_category_id`, optional, per ADR-less feature from 2026-05-16) — when a seller uploads a photo, they tag the sub-category it represents.

The question is whether the marketplace also needs a **third** declaration: an explicit "specialties I do" multi-select on the profile, separate from the two above.

## Decision Drivers

- Buyer needs a sub-category filter on Browse, and a relevance order on the card's portfolio carousel when that filter is set.
- Sellers already declare sub-categories in two places (packages, portfolio tags). Adding a third declaration risks the three falling out of sync — a seller marked as "doing weddings" with no wedding package and no wedding photos surfaces in filtered results with nothing to show.
- Buyer trust on a creative marketplace comes from *seeing the work*, not from the seller's self-claim. A buyer searching for wedding photographers wants photographers who have *demonstrated* wedding work, not ones who claim they'd take a wedding job.
- Less surface for the seller to maintain is a feature — the seller UI already has packages + portfolio + service areas; adding a fourth toggle screen earns its own onboarding friction.

## Considered Options

- **A — Explicit toggle.** New `seller_profile_subcategories` join table or `subcategory_ids string[]` column on `seller_profiles`. Seller picks specialties on a dedicated screen. Independent of what they actually sell or show. Filter and ranking key off this column.
- **B — Derived from packages + portfolio.** A profile "does" a sub-category if (active package exists in it) OR (at least one portfolio item tagged with it). No new schema, no new seller UI. (Chosen.)
- **C — Derived from packages only.** A profile "does" a sub-category if it has an active package in it. Rejected — too restrictive in the early marketplace where a seller may have built one package but uploaded representative work across several shoot types they'd take. Also rules out hybrid HOURLY-only photographers (ADR 0005) who have no packages.

## Decision Outcome

**Chosen: Option B.** The marketplace derives "what this seller does" from data the seller is already producing.

A `seller_profiles` row is *eligible* for the filter `subCategoryId = X` if and only if either:

1. **Package match** — there exists `seller_packages WHERE profile_id = sp.id AND sub_category_id = X AND deleted_at IS NULL`, or
2. **Portfolio match** — there exists `portfolio_items WHERE seller_profile_id = sp.id AND sub_category_id = X`.

Implemented as a top-level `OR` clause in `GET /profiles`. The sort order is unchanged — within eligible profiles, the user's chosen `sort_by` (recommended / rating / hours / price) applies as before. Profiles with a *package* match are not ranked above portfolio-only matches in v1; that distinction can be revisited if buyer behavior suggests it matters.

When the filter is set, each card's `portfolioImages[]` is reshuffled so items tagged with the filter sub-category appear first (preserving `sort_order` within each group), capped at the existing 5-item card window. The repository fetches up to 20 items per profile to give the reshuffle headroom, then slices.

## Consequences

**Positive**
- Zero new schema, zero new seller-side UI, zero new validation surface.
- The seller's "specialty" stays automatically in sync with their actual offerings — adding a wedding package or uploading a wedding photo *is* the act of becoming a wedding photographer on the marketplace.
- Buyer-side trust signal is strong: filter results are guaranteed to contain at least one piece of demonstrable work or a publishable package in the filtered sub-category.

**Negative**
- **Cold-start gap.** A seller who has only just signed up and has neither built a package nor uploaded a tagged photo is invisible to any sub-category filter. This is acceptable — until they have something to show or sell, they have nothing to *be filtered for*. The default unfiltered Browse still surfaces them.
- **Untagged portfolio items don't count.** A photo uploaded before the sub-category tagging feature shipped, or one the seller left untagged, contributes nothing to specialty derivation. Mitigated by the optional retag flow already in the seller app — and untagged photos still appear in the card's portfolio carousel, just not in *filtered* relevance order.
- **No "I would take a wedding job but haven't yet" channel.** A seller who'd accept wedding work but hasn't built one cannot appear in the wedding filter. Treated as a forcing function rather than a problem — the marketplace prefers demonstrable claims to aspirational ones.

If buyer behavior later shows demand for aspirational specialty claims (e.g., very few sellers have built wedding packages but many would take wedding jobs), revisit by adding option A as an *additional* declaration alongside the derived signal — not as a replacement.

## More Information

- Sub-category eligibility check + portfolio reshuffle live in `prisma-seller-profile.repository.ts::searchProfiles`.
- The card's `portfolioImages[]` semantics (top 5, reshuffled when filter is set) are part of the `SearchProfileItemDto` contract — already documented in the OpenAPI description on the `portfolioImages` property.
- `PortfolioItemResponseDto.subCategoryId` was already optional pre-decision; this ADR cements that **untagged portfolio items contribute nothing to specialty** while remaining valid for display.

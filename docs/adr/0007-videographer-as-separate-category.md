---
status: accepted
date: 2026-05-16
decision-makers: [aiden]
---

# Videographer as a separate top-level category (not a sub-category of Photographer)

## Context and Problem Statement

The launch wedge is `photographer` (ADR 0004, renamed from the legacy slug `photography` by migration `20260516220000_rename_photography_category_to_photographer`). The natural next adjacency in the creative-services space is videography. The question is whether videography should be:

1. A **sub-category** under `photographer` (alongside Wedding, Travel Portrait, Family, etc.), or
2. A **separate top-level category** parallel to `photographer`.

This decision lands now, before either approach has shipped, while sub-category eligibility (ADR 0006) is also being wired up.

## Decision Drivers

- The buyer's mental model when searching ("I need a wedding photographer" vs "I need a wedding videographer") — are these one decision or two?
- Pricing structure parity. Wedding videographers typically charge 2-5× wedding photographers; pricing per day is more common than per hour; deliverables include a multi-week edit window.
- Deliverable parity. A photographer hands over edited stills; a videographer hands over a colour-graded film with sound design, often with revisions. Different timelines, different terms.
- Portfolio rendering. The search card swipes through still images. Video clips need a different play affordance — auto-playing muted, a play overlay, a duration badge. Mixing stills and video in the same carousel is awkward.
- Sub-category taxonomy coherence. The existing Photographer sub-categories (Wedding, Travel Portrait, Family…) describe **shoot occasions**, not **media**. Adding "Video" as a sibling of "Wedding" mixes a medium with a context — every other sub-cat would have to bifurcate (Wedding-Photo vs Wedding-Video).
- Onboarding cost for hybrid sellers (who do both photo and video). Per ADR 0001, one seller can have multiple profiles, one per category. Two profiles to maintain is the cost.

## Considered Options

- **A — Sub-category under Photographer.** Add a `video` sub-cat to the `photographer` taxonomy. Cheapest schema move — no new category row, no new browse routing. Rejected: collapses two genuinely different pricing/deliverable shapes into one filter; the card carousel can't represent stills and video clips with the same affordance; the sub-cat axis stops meaning "shoot occasion" and starts meaning a mix of occasion + medium, which makes the filter UI muddier the more sub-cats we add.
- **B — Separate top-level `videographer` category.** Parallel to `photographer`, with its own sub-category taxonomy (Wedding Film, Event Film, Brand & Commercial, Music Video, Travel Film, Portrait Film). Hybrid sellers maintain two profiles. (Chosen.)
- **C — Umbrella "Visual Media" category with `photographer` + `videographer` as sub-cats.** Cleaner ontology in the abstract, but introduces a third layer (category → medium → shoot type) and weakens the noun-as-category convention ("Photographer" is a stronger search target than "Visual Media"). Also requires retrofitting the existing `photographer` slug into a sub-cat, which breaks all existing profile URLs and search-card categorySlug consumers. Rejected: cost of restructuring outweighs the ontological tidiness.

## Decision Outcome

**Chosen: Option B.** `videographer` ships as an active top-level category alongside `photographer`. Sort order: photography = 1, videographer = 2; inactive legacy categories (driver, cleaner, tutor, etc.) shift behind both.

Sub-category taxonomy for `videographer` mirrors the *shoot-occasion* structure of `photographer` but in video-native terms:

| slug | English |
| --- | --- |
| `wedding-film` | Wedding Film |
| `event-film` | Event Film |
| `travel-film` | Travel Film |
| `portrait-film` | Portrait Film |
| `music-video` | Music Video |
| `brand-commercial` | Brand & Commercial |

Hybrid sellers (photo + video) maintain two profiles — one per category — with independent portfolios, packages, and ratings. ADR 0001's per-category uniqueness already makes this the canonical multi-offering shape; this ADR commits to using it rather than working around it.

The search card currently renders portfolio thumbnails as still images. Videographer profiles will populate `portfolioImages[]` with **thumbnail stills extracted from the source video** at upload time. A video-native carousel (autoplay-muted clips, duration badge, play overlay) is a follow-up; the current still-image carousel is acceptable for v1.

## Consequences

**Positive**
- Clean separation of two creative-services markets with genuinely different commercial shapes. Each can evolve its own pricing structure, modification flow, and review prompts without one constraining the other.
- Sub-category taxonomy stays semantically coherent — both `photographer` and `videographer` sub-cats describe shoot occasions in their respective medium.
- ADR 0001's profile-per-category shape gets a second concrete use case, validating the model beyond a single launch category.

**Negative**
- Hybrid sellers maintain two profiles. Mitigation: shared account-level availability (ADR 0003) means a slot booked through one profile is unavailable on the other automatically. Profile content (portfolio, packages, headline) is the only duplication.
- Card carousel renders video thumbnails as static stills in v1. Acceptable but not ideal — buyers can't preview motion before opening the profile. Tracked as follow-up.
- Inactive legacy category rows had to be re-sort-ordered. One-off cost.

## More Information

- Migration: `prisma/migrations/20260516230000_add_videographer_category/migration.sql` adds the category row + six sub-category rows.
- `seed.ts` mirrors the new `videographer` entry in its `defaultCategories` list (sort_order = 2, isActive = true).
- PRD updates: launch wedge expands from "single category — photography" to "two categories — photography + videography"; sub-category bullet in §4 already covers the same derived-specialty rules from ADR 0006 for both categories without needing further edits.

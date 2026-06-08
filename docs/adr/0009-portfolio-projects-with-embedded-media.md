---
status: accepted
date: 2026-05-16
decision-makers: [aiden]
supersedes: portfolio portion of PRD §3 (flat-photo model)
---

# Portfolio Data Model — Projects with Embedded Media Items

## Context and Problem Statement

PRD §3 currently models a portfolio as a flat collection of individual photos: each row in `portfolio_items` is one image with a caption, sort order, optional sub-category tag, and optional package link. That shape was correct for the original "casual seller drops in a handful of shots" assumption, but user research with a professional photographer surfaced a different shape: working photographers think and ship in **projects** — a wedding is one project of 80 images, a brand campaign is one project with a 10-image final-cut plus a PDF deliverable, a travel shoot is a project with a hero image and 20 supporting frames. The flat-photo model has nowhere to put the project-level identity (title, description, cover, ordering of media within the project, deliverable PDFs).

At the same time, plenty of sellers — casual creators, side-hustle photographers, sellers in adjacent categories (designers, etc.) — will continue to want the lightweight "add a photo" flow. Forcing them through a Behance-style project wizard for a single image is friction without payoff.

Two competitor reference points:
- **Behance** ships projects only. No standalone photos. Wrong for our casual end of the marketplace — too heavyweight for "post a few shots and start getting bookings."
- **Instagram** ships flat photos only. No project grouping. Wrong for our professional end — a wedding can't render as 80 sibling tiles with no parent identity.

Handii spans both ends of that spectrum on the same surface (a buyer browsing photographers will see casual one-shot sellers and professional project-based sellers side by side), so the model has to support both without forcing either user into the wrong UX.

This decision lands now while the app is pre-launch with no production users — schema can be rebuilt cleanly, existing seed/dev portfolio rows can be wiped.

## Decision Drivers

- Serve the photographer use case (multi-media projects with title/description/cover) and the casual-seller use case (single photo with caption) from one underlying model, not two parallel ones.
- PDF support for design / brand-campaign deliverables — not just images.
- Cover image, project ordering, and project-level metadata (title, description, multilingual) need to be first-class, not crammed into a "first photo wins" convention.
- Future features (case studies, multi-deliverable client jobs, before/after pairs) extend cleanly without another schema rewrite.
- Keep the "Add a photo" flow visually identical to the current single-step UX — sellers in that flow should never see the word "project."

## Considered Options

- **A — Keep flat photos.** Status quo. `portfolio_items` is the unit. Rejected: cannot represent a project-with-cover-and-description-and-PDF without overloading existing columns or adding a hidden "first item is special" rule, both of which collapse under the photographer's actual deliverables.
- **B — Projects only (Behance model).** Replace `portfolio_items` with `portfolio_projects` + child `media_items`. Single-photo sellers fill out a project shell with one media item, see the project title field, the cover-picker, the description box. Rejected: too heavyweight for the casual upload flow — the friction loses sellers at the threshold and undersells the marketplace's casual-creator surface.
- **C — Two separate models, polymorphic on the public surface.** `photos` table + `projects` table; the profile renders an interleaved feed. Rejected: every API endpoint, every query, every iOS view, every search-result card has to handle two shapes. The cost compounds — twice the DTOs, twice the seed paths, twice the indexes — without proportionally more product surface.
- **D — Everything is a Project; single photos are a Project with `isSingleItem: true` and exactly one MediaItem.** Single underlying model, two upload flows, two display layouts. (Chosen.)

## Decision Outcome

**Chosen: Option D — everything is a Project.**

A `Project` is the primary container on the portfolio. It owns:
- A multilingual title and description (JA, EN, ZH_CN, ZH_TW — seller authors manually in each language they want to support; no auto-translation in v1).
- An ordered list of 1..N `MediaItem`s (image, video, or PDF; see *MediaType* below).
- A cover MediaItem (one of the project's own media items; defaults to the first).
- A `publishedAt` nullable timestamp (a draft is `publishedAt IS NULL`; published projects have a value). No separate draft entity.
- An `isSingleItem` boolean — `true` when the project was created via the "Add a photo" flow, `false` otherwise. Drives UI behaviour (single-item projects skip the project-detail-view step on tap and open the lightbox directly; their title is hidden in some layouts).
- A `sortOrder` for the seller-controlled ordering within the portfolio.
- Optional `subCategoryId` and optional `packageId` tags (same semantics as the current portfolio-item tags — drive search relevance + drill-from-package), promoted up from the media item.

A `MediaItem` is the leaf. It carries:
- A `mediaType` enum: `IMAGE`, `VIDEO`, `PDF`.
- A `url` to the rendered media.
- An optional `thumbnailUrl` (mandatory for VIDEO and PDF; ignored for IMAGE since the asset itself is the thumbnail).
- An optional multilingual `caption` (JA / EN / ZH_CN / ZH_TW, same authoring and fallback rules as the project's title/description; no auto-translation in v1). Stored as a JSONB map keyed by BCP-47 language code, matching the chat-translations precedent already used in the codebase.
- A `sortOrder` within the parent project.
- File metadata (mime type, byte size, original filename) for PDF download UX and analytics.

The `Portfolio` itself (one per seller profile) carries:
- A `layout` enum: `PROJECTS | GRID`. Default `PROJECTS`. The seller switches from a profile settings toggle; the choice is persisted on the portfolio so it survives across sessions.
- The list of projects (ordered by `sortOrder`).

The two display layouts interpret the same data differently:
- **`PROJECTS` layout** — the public profile renders a grid of project cards (cover image + title). Tapping a card opens a project detail view with the full media gallery and description.
- **`GRID` layout** — the public profile renders a flat grid of every MediaItem across every project (Instagram-style). Tapping any tile still opens the parent project's detail view, so the project context is never lost — a buyer looking at one image can always see what shoot it came from. Lightbox swipe stays within the tapped project — a tile opens the parent project's detail view and swipe-next walks that project's media, not across project boundaries. The flat grid is a presentation choice; the project remains the navigation unit. (The Instagram-pure interpretation — swipe walks across the flat grid regardless of project boundary — was considered and rejected: a buyer swiping through what they understand as one shoot suddenly seeing media from a different project destroys the project context that justifies the data model in the first place.)

The two upload flows on the seller side:
- **Add a Project** — multi-step wizard: title → description → media upload (1..N items) → reorder → set cover → publish. Multilingual title/description fields in the editor.
- **Add a Photo** — single-step: photo file + optional caption. Behind the scenes the server creates a `Project` with `isSingleItem: true`, a single `MediaItem` of type `IMAGE`, the project's cover set to that media item, and an empty title/description. The seller never sees the word "project" in this flow. The seller can later convert the single-photo project into a full project via a **"Promote to project"** action on the single-photo card — this ships in v1. The action flips `isSingleItem` to `false` and opens the standard project editor pre-populated with the existing MediaItem (so the seller can add a title, description, more media, and re-select the cover). Rationale: the alternative — delete and re-upload — is a worse first-impression bug than the affordance being unused by some sellers. Cost is small (a boolean flip plus reusing the editor we already build for Add a Project).

**Clarifications on the promotion + Add a Photo flows.** Three details that fall out of the model and that the implementer should not have to re-derive:

- **Cover image on promotion.** The original MediaItem stays pinned as the project's cover by default. The cover-picker is available inside the project editor but is not a required step during the promotion flow — a seller who tap-promotes, adds a title, and saves should not be blocked on a cover decision.
- **Caption on promotion.** The existing MediaItem's caption stays on the MediaItem. It is not copied into the project description, and it is not replaced by it. Caption (per-image label) and description (per-project context) are conceptually distinct fields; promotion does not silently move content between them.
- **Add a Photo caption input UX.** The single-step Add a Photo flow exposes exactly **one** caption input — in the seller's primary language only. Additional languages for that caption are reachable only via the project editor (i.e. after Promote to project, or by using Add a Project from the start). This preserves the single-step casual UX — a seller dropping in one photo should not see a four-tab language editor for one optional caption.

## Consequences

**Positive**
- One data model, one set of API endpoints, one set of iOS view models. Adding a new MediaType, a new project-level field, or a new layout is one place to change.
- PDF support falls out for free — `mediaType = PDF` with a thumbnail URL and the file metadata for a download affordance. No new entity.
- Cover image, project metadata, and seller ordering are first-class — no more "first item wins by convention."
- Future features (case studies with rich text per project, client-deliverable bundles, before/after pairs, project-level analytics) extend by adding fields to `Project` or new media types; the shape doesn't need to change.
- Search-relevance signals from the current portfolio-tag flow (ADR 0006) keep working — the sub-category and package tags just move up from media to project, which matches reality (a project is about one shoot type; individual frames inherit that).

**Negative**
- Slightly more indirection than a flat photo model. Every photo is wrapped in a project even when the seller didn't ask for one. The "Add a photo" flow has to hide that abstraction perfectly — the moment the word "project" leaks into that path, casual sellers will feel like they're doing more work than the previous flow.
- Two display layouts means the profile-render code is two paths, not one. We need to be disciplined about not letting them drift (e.g. card sort order should mean the same thing in both).
- ADR 0006's "derived specialty" signal needs to count sub-category tags at the *project* level, not media-item level. Same idea, one level up — straightforward but worth flagging.

**Neutral**
- No migration needed: pre-launch, no production users. Existing dev/seed `portfolio_items` rows get wiped on the schema rebuild.
- ADR 0006 (derived sub-category specialty) stays valid — the eligibility check moves from `portfolio_items.sub_category_id` to `portfolio_projects.sub_category_id` (single source instead of one per media item), which actually simplifies it.

## More Information

- **Where this lives.** Detailed field-level schema, indexes, and API surface land in a follow-up implementation PR. This ADR is the model decision; the wire format (Prisma schema, DTOs, OpenAPI) is intentionally not specified here so reviewers focus on the shape and the tradeoff.
- **PRD §3 (Portfolio)** is being updated in the same change to reflect projects-with-media as the model, the two upload flows, the two display layouts, and the MediaType set.
- **PRD §3 fields that move:** `sub_category_id` and `package_id` were on the media item — they move to the project. The cover-image-by-convention rule is replaced by an explicit `coverMediaItemId` on the project. The per-item caption stays at the media item but becomes a multilingual JSONB map (JA / EN / ZH_CN / ZH_TW), consistent with the project-level title/description and with the existing chat-translations pattern in the codebase.
- **PRD §3 fields that are removed:** the "first portfolio item is the profile card's hero" convention is replaced by the project's cover image being the card's hero (or the seller's chosen cover project on a future "feature this work" affordance, deferred).
- **Out of scope for v1** (captured in PRD §3 update as well, listed here for reviewer convenience):
  - Auto-translation of project titles, project descriptions, and media-item captions across JA/EN/ZH_CN/ZH_TW. Sellers author each language they want manually; localisation rendering picks the best available per ADR 0008-precedent (use authored language → fallback to seller's primary).
  - Project drafts beyond a simple `publishedAt IS NULL` flag. No multi-stage approval, no admin moderation queue, no scheduled-publish.
  - Project analytics — view counts, likes, save-for-later.
  - Native in-app PDF rendering. v1 ships PDFs as downloadable attachments with a static thumbnail; the in-app reader is a v2 line item.

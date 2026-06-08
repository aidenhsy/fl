---
status: proposed (deferred)
date: 2026-05-17
decision-makers: [aiden]
supersedes: 0009 (MediaItem portion only — see *More Information*)
---

# Portfolio Block Model — Heterogeneous Photo + Text Blocks (Behance-shape)

> **Deferred 2026-05-17.** We're shipping the buyer-side rendering against the current MediaItem model first (per ADR 0009, minus the per-image caption — caption was dropped via migration `20260517110000_drop_portfolio_item_caption` on the same day this ADR was deferred). The block model is still the directionally-right end state; we'll revisit it after the buyer flow is validated end-to-end and we have real seller feedback on whether interleaved text blocks pull their weight. None of the rename + validation work below is committed yet — treat this as a design exploration, not a planned migration.

## Context and Problem Statement

ADR 0009 modelled a portfolio Project as a container of `MediaItem`s — photos, videos, and PDFs in an ordered list, each with an optional per-image multilingual caption. The editor surfaced media as a 3-column grid of square tiles, with project-level metadata (title, description) on a separate Settings form. This shape was correct for the photographer's stated need (multi-media projects with cover and metadata) but wrong on the **canvas layout**.

User research with the photographer surfaced a different mental model — and a strong reference design: Behance. A Behance project is a **single-column vertical canvas of stacked content blocks**, where photo blocks and text blocks are interleaved freely. Text blocks have rich formatting (bold / italic / underline / link / color / size / alignment). Project metadata (title, tags, cover image) lives entirely on a separate Publish screen.

The semantic difference between the ADR 0009 model and Behance:

| ADR 0009 | Behance |
| --- | --- |
| `Project → [MediaItem]` | `Project → [Block]` where Block is Photo or Text (or Video, PDF, Embed) |
| Per-image multilingual caption on every MediaItem | No per-image caption — text is a sibling Block, interleaved freely |
| Title / description on a Settings form alongside the media | Title + tags + cover on a separate Publish screen; description doesn't exist as a project-level field — it's a text block |

The data model has to change. ADR 0009's MediaItem is too narrow to express "a paragraph of context between two photos." Adding text content to MediaItem would be misleading — "media" + plain text don't share a coherent abstraction. The right move is to promote MediaItem to a polymorphic Block.

This decision lands before Phase 3a-ii (buyer-side rewrite), so the buyer renderer gets built once against the right model. Phase 2 server work just shipped; the rename cost is real but bounded.

## Decision Drivers

- Match the photographer's actual mental model (Behance, not Instagram-grid).
- Avoid building the buyer-side project detail view against a model that needs replacing weeks later.
- Keep the Add a Photo flow (ADR 0009) — single-photo projects stay a casual entry point, semantically a Project with one PHOTO block.
- Don't carry the "MediaItem" naming forward once text is first-class; the abstraction needs to read accurately to future contributors.
- Don't multiply the editor's surface — single-language text blocks match Behance and avoid a four-tab markdown editor per block (which would dominate the UI).

## Considered Options

- **A — Extend `MediaItem` with a TEXT mediaType + `text_content` column.** Smaller migration; same table. Rejected: the table name `portfolio_media_items` becomes a lie. Every future contributor reads "media items" and either misses that text rows exist or adds clutter to disambiguate. The naming debt outweighs the migration cost given we're pre-launch.
- **B — Rename `MediaItem` to `Block`; add `block_type` enum (`PHOTO | VIDEO | PDF | TEXT`); add nullable `text_content` + `text_language` columns; drop the unused `caption` column.** Cleaner model, accurate naming, drops the now-redundant caption surface. (Chosen.)
- **C — Keep MediaItem AND add a sibling `TextBlock` table; interleave via two-table query with a unified sort key.** Two tables for one ordered list. Rejected: every read path has to merge two row sets; ordering across tables is fragile; the editor would have two insert flows that share no code.

## Decision Outcome

**Chosen: Option B — rename to Block, drop captions, add TEXT type.**

### Schema (replaces ADR 0009's MediaItem section)

```
model portfolio_blocks {
  id              UUID PK
  project_id      UUID FK → portfolio_projects.id (cascade)
  block_type      BlockType  -- PHOTO | VIDEO | PDF | TEXT
  sort_order      Int

  -- Media-block fields (PHOTO / VIDEO / PDF — all NULL for TEXT)
  url               VARCHAR(500)?
  thumbnail_url     VARCHAR(500)?     -- required app-side for VIDEO + PDF
  mime_type         VARCHAR(100)?
  byte_size         Int?
  original_filename VARCHAR(255)?
  width             Int?
  height            Int?

  -- Text-block fields (TEXT — both NULL for media blocks)
  text_content   Text?         -- markdown, single-language, ≤ 5000 chars
  text_language  Language?     -- ja / en / zh_CN / zh_TW

  created_at, updated_at
}

enum BlockType { PHOTO, VIDEO, PDF, TEXT }
```

The `caption` column from `portfolio_media_items` is **dropped** entirely. Text blocks subsume the role of captions: a seller who wants text next to a photo inserts a TEXT block adjacent to the PHOTO block.

`portfolio_projects.cover_media_item_id` is renamed to **`cover_block_id`**, and the FK constraint stays nullable with the same cycle-break transactional pattern (insert blocks first with cover NULL, then UPDATE).

### Block-type validation (application layer)

| block_type | required | forbidden |
| --- | --- | --- |
| `PHOTO` | `url`, `mime_type`, `byte_size`, `original_filename` | `text_content`, `text_language` |
| `VIDEO` | + `thumbnail_url` | same |
| `PDF` | + `thumbnail_url` | same |
| `TEXT` | `text_content`, `text_language` | every media field |

Violations raise `INVALID_BLOCK_SHAPE` with the violating field listed.

### Cover constraint (application layer)

`cover_block_id` must reference a **PHOTO** block on the same project. Validation lives in the cover-setter use case; mismatches raise `COVER_BLOCK_MUST_BE_PHOTO`. The editor's cover picker only surfaces PHOTO blocks. Implications:

- Every project must have **≥ 1 PHOTO block** to be publishable (text-only projects can't have a cover, so they can't render on the buyer card). Server enforces on publish.
- A single-photo project (Add a Photo flow) is exactly one PHOTO block; cover is that block.
- The Add a Project Canvas must guard publish until at least one PHOTO block exists — text-only drafts are allowed but can't be published.

### Text blocks: single-language, markdown

- Storage: `text_content` is plain markdown (`**bold**`, `_italic_`, `[label](url)`). The buyer side renders via `Text(AttributedString(markdown:))`.
- `text_language` records which AppLanguage the seller wrote in. Buyer renders the text as-is — **no auto-translation in v1, no per-text-block translation UI in v1.** A seller serving a non-primary-language audience can insert a second text block in another language as a sibling. This matches Behance (single-language per text block) and avoids the much larger editor cost of stacked markdown editors per language.
- Length cap: 5000 chars per text block (≈ 800 words; a substantial paragraph cluster). Multiple blocks for longer captions.
- Format buttons in the editor: Bold, Italic, Link (insert / edit). No font / size / color / alignment in v1 — Behance shows them but they're polish; markdown doesn't natively express them and bolting on inline styles would make the storage format messy.

### Project-level title still multilingual

Project `title` stays multilingual JSONB (as in ADR 0009). The reasoning: titles are short, the most-rendered field on the buyer card, and worth translating. Description is **removed** — its role is taken by text blocks. A seller who wants a project-level intro paragraph adds a text block as the first block.

## Consequences

**Positive**
- Editor matches the photographer's reference mental model. Adding context paragraphs between photos becomes the natural Behance gesture (tap T, type) instead of cramming everything into a "description" textarea on a separate form.
- One data model accurately spans single-photo projects, photo-only multi-image projects, and narrative photo+text projects without special-casing.
- Drops the per-image caption surface (which was a Phase 2 ambiguity around multilingual merge UX) — that whole code path goes away cleanly.
- Future media types (audio block, embed block) extend by adding to the `block_type` enum + per-type validation, not by introducing parallel tables.

**Negative**
- Phase 2 server work needs renaming and validation expansion. Mechanical but touches every portfolio use case, repository method, DTO, and controller route name. iOS regen + call-site updates flow from this.
- `updateMediaCaption` endpoint disappears. Any client that was about to consume it (none in practice — only the now-removed editor sheet referenced it) stops being valid; no production consumers.
- The 3-column grid layout option from ADR 0009 (`PortfolioLayout.GRID`) loses some of its semantic clarity — text blocks don't grid well. The layout enum stays for now (the buyer-facing portfolio render still distinguishes "card grid of project covers" from a flattened all-blocks view), but the GRID variant on the buyer side will skip TEXT blocks (photos only). Documented as a v1 limitation; revisit in Phase 4 if sellers complain.

**Neutral**
- Pre-launch, no production data: the schema migration is destructive (drop + recreate) which is the cleanest path. Local DB seed re-runs cleanly.

## More Information

- The Add a Photo single-step flow from ADR 0009 stays unchanged in behavior: creates a Project with `is_single_item: true`, one PHOTO block, cover pinned. The seller never sees the word "project" or "block" in this flow.
- The Promote to Project action from ADR 0009 stays unchanged: flips `is_single_item: false`, opens the standard editor pre-populated with the existing PHOTO block. The seller can now add more PHOTO / VIDEO / PDF / TEXT blocks.
- The multilingual `MediaItem.caption` field, the `updateMediaCaption` use case, the `UpdateMediaCaptionBodyDto`, the merge-semantics helper, and the per-image multilingual editor sheet are all removed. The `mergeMultilingualPatch` helper stays — it's used by future per-language flows on project title.
- ADR 0009 stays valid for its Portfolio + Project + isSingleItem + cover-cycle + Add a Photo + Promote decisions. Only the MediaItem portion is superseded. The superseded text is the per-image caption field and the layout-as-square-tiles assumption baked into the editor screenshots in PRD §3.
- PRD §3 will be updated to describe the block model + Behance-shape editor + dropped caption surface in the same change as the implementation.

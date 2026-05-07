# Architecture Decision Records

This directory holds **cross-cutting** Architecture Decision Records (ADRs) for the `fl` project.

## Where each ADR lives

ADRs are layered by scope. An ADR lives in the most specific directory that fully contains its impact.

| Directory                       | Scope                       | Examples                                                              |
| ------------------------------- | --------------------------- | --------------------------------------------------------------------- |
| `fl/docs/adr/`                  | Cross-cutting               | Domain model, auth strategy, payment architecture, real-time transport — anything that constrains more than one app |
| `fl-api/docs/adr/`              | Backend only                | ORM choice, internal service boundaries, queue tech, caching          |
| `fl-seller-ios/docs/adr/`       | iOS seller app only         | Navigation pattern, state management, networking layer                |
| `fl-buyer-ios/docs/adr/`        | iOS buyer app only          | Same pattern as seller-ios                                            |
| `fl-web/docs/adr/`              | Web only                    | Same pattern (when introduced)                                        |

If a decision affects two or more of the above, it lives here at the repo root.

## Conventions

- **Template:** [MADR 4.0.0](https://adr.github.io/madr/), full form (not the short form). Use the standard headings: *Context and Problem Statement*, *Decision Drivers*, *Considered Options*, *Decision Outcome* (with *Consequences* and *Confirmation*), *Pros and Cons of the Options*, *More Information*.
- **Numbering:** Zero-padded four-digit prefix, monotonically increasing per directory. The first cross-cutting ADR is `0001-…`; the first backend-only ADR will be its own `0001-…` under `fl-api/docs/adr/`.
- **Filename:** `NNNN-kebab-case-slug.md`.
- **PRD references:** Reference PRD sections by **name**, not number. Section numbers shift; names are stable. Format: *"see PRD → Glossary → Profile"*.
- **Status lifecycle:** `proposed` → `accepted`, or `rejected`. An accepted ADR may later become `deprecated` or `superseded by NNNN`. Set `status` and `date` in the YAML frontmatter.
- **Immutability:** Once an ADR is accepted, do not edit its substance. To revise the decision, write a new ADR that supersedes it and update the old one's status to `superseded by NNNN`. Typo fixes, broken-link repairs, and clarifying language that was already ambiguous are fine to edit in place — only substantive revisions of the decision require a superseding ADR.

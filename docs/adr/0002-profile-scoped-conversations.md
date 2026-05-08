---
status: accepted
date: 2026-05-08
decision-makers: [aiden]
---

# Profile-scoped conversations

## Context and Problem Statement

Conversations were keyed at the **user pair** level — one thread per `(buyer_user, seller_user)` regardless of which seller profile (category) the chat was about. This created two problems for sellers who run multiple profiles under one account:

1. **Conflated context.** A buyer who messaged the same seller about photography and driving lived in one thread; the seller had to context-switch on every message to figure out which side of the business was being discussed.
2. **Inconsistency with ADR 0001.** ADR 0001 established the **profile** as the commercial unit — bookings, reviews, ratings, discovery URLs are all profile-scoped. Conversations being user-scoped meant a thread didn't map cleanly to anything else in the system, and the seller's mental model ("I run two profiles") didn't match the data layer.

A previous mitigation added a per-message `seller_profile_id` and a `CategoryContextChip` that rendered above each message when the profile context flipped. That solved labeling but left the cognitive work in place — the seller still scanned for chip transitions to figure out what they were reading.

## Decision Drivers

- Consistency with ADR 0001 — keep the profile as the commercial unit across the whole system.
- Eliminate ambiguity at the data layer rather than relabel it in the UI.
- Pre-launch status: no production data, so the migration cost is low and one-time.
- The buyer-side entry point (Profile page → "Message") already knows which profile is in scope, so re-keying naturally aligns with how buyers actually start threads.

## Considered Options

- **A — User-pair conversations + per-message profile chips (current state).** Solves labeling but leaves the seller doing context-switching cognitive work on every message in mixed-category threads.
- **B — Per-profile seller inbox.** Each seller profile gets its own inbox; the seller picks a profile (like switching accounts) before reading messages. Rejected: adds a switcher UI, fragments unread counts across inboxes, and makes the buyer's mental model ("I'm chatting Tanaka") drift from the seller's ("I'm Photographer-Me right now").
- **C — Hybrid: thread keyed on user pair in DB, profile-split visually in list and detail screens.** A single DB row, but every consumer (buyer web, buyer iOS, seller web, seller iOS, admin) is responsible for splitting it visually by profile. Rejected: pushes splitting logic to every consumer and the data model still lies — cross-profile views and per-thread metadata (last-read, booking link, unread) all become awkward to model.
- **D — Profile-scoped conversations.** Re-key on `(buyer_user_id, seller_profile_id)`. One thread per `(buyer, profile)` pair. (Chosen.)

## Decision Outcome

Chosen: **Option D — Profile-scoped conversations**, because it eliminates the ambiguity at the data layer rather than papering over it in the UI, and keeps the data model honest about what a thread *is*.

Schema-level summary (full migration lives in `fl-api/prisma/migrations/…_profile_scoped_conversations/`):

- `conversations` adds `buyer_user_id` and `seller_profile_id` columns (both NOT NULL, FK to `users` and `seller_profiles` respectively).
- Partial unique constraint `UNIQUE (buyer_user_id, seller_profile_id) WHERE booking_id IS NULL` — exactly one pre-booking thread per `(buyer, profile)`. Booking-tied threads (each unique by `booking_id`) are excluded from this constraint, so each booking still gets its own thread.
- `seller_profile_id` uses `ON DELETE NO ACTION` (RESTRICT). Soft delete (`seller_profiles.deleted_at`) is the operational reality — the row stays, the conversation stays readable, but sending is blocked.
- `conversation_messages.seller_profile_id` and the `MessageProfileContextDto` chip rendering are **dropped** — every message in a thread is now implicitly about the thread's anchored profile, so per-message stamping is redundant.
- The repository's `findConversationBetweenUsers(userIdA, userIdB)` is replaced with `findPrebookingConversation(buyerUserId, sellerProfileId)`. Booking-tied conversation creation (in `bookings`) populates the new columns from `bookings.seller_profile_id`.

Active-profile rule (enforced in `create-conversation.use-case.ts` and `send-message.use-case.ts`):

- New thread creation is **rejected** when the target profile is not ACTIVE *or* is soft-deleted.
- Existing threads remain readable when their profile becomes inactive — only sending is blocked. The UI shows a "this profile is no longer active" banner on the input.

### Consequences

- Good, because the thread structure now matches ADR 0001's profile-as-commercial-unit model.
- Good, because the buyer-side "Message" button on a profile page naturally targets the right thread — no inheritance heuristics needed.
- Good, because per-message chip rendering and the inheritance/stamping rules go away — net less code in the API, the buyer iOS app, and the seller iOS app.
- Good, because soft-deleted profile threads remain visible for historical context with a clear inactive affordance, instead of disappearing or muddling the active inbox.
- Neutral, because cross-profile views (e.g. "all conversations across this seller's profiles") now require a join through `seller_profiles.seller_id`. Acceptable — the join is one hop and the tradeoff is in the right direction.
- Neutral, because hard-deleting a `seller_profile` row while threads exist now fails loudly (FK RESTRICT). Soft delete is already the supported path; this just makes the constraint explicit.
- Bad, because it requires a one-time migration that drops existing chat data. Pre-launch with no production users, so the cost is zero in practice.
- Bad, because every consumer (API, both iOS apps) had to update DTOs, view models, and UI surfaces — the breaking surface is the entire chat module.

### Confirmation

This ADR is confirmed in effect when:

- The Prisma schema has `buyer_user_id` and `seller_profile_id` on `conversations`, with the partial unique index `uq_prebooking_thread`.
- `conversation_messages.seller_profile_id` is gone (column, FK, and index).
- Neither iOS app contains references to `MessageProfileContextDto` or `CategoryContextChip`.
- The buyer iOS app's `SellerProfileViewModel.startConversation()` opens the thread for the specific profile, and entering the same seller's other profile opens a distinct thread.
- The seller iOS inbox shows the profile (category line) on every row.

## Pros and Cons of the Options

### Option A — User-pair conversations + per-message profile chips

Status quo. Threads are keyed on `(buyer_user, seller_user)`; each message remembers which seller profile the sender was looking at; UI renders a "Photography" / "Driver" chip when the context flips.

- Good, because it requires no schema migration.
- Good, because chips already work for the labeling case.
- Bad, because it leaves the seller doing context-switching cognitive work on every message in mixed-category threads.
- Bad, because it conflicts with ADR 0001's profile-as-commercial-unit model.
- Bad, because the inheritance/stamping rule (server inherits the most recent inbound profile when the seller doesn't pick one) is fragile and surprising — silent mis-attribution if the buyer pivots and the seller's reply lands first.

### Option B — Per-profile seller inbox

Each seller profile has its own inbox. The seller chooses a profile before viewing messages.

- Good, because each inbox is unambiguous about which profile it concerns.
- Bad, because it adds a switcher UI to every messaging surface (list, push notifications, badges).
- Bad, because unread counts fragment across inboxes — sellers can miss messages because they're "on the wrong profile."
- Bad, because the buyer's mental model ("I'm chatting Tanaka") doesn't match the seller's switcher-driven model — the asymmetry is a confusing UX seam.

### Option C — Hybrid: user-pair keyed in DB, profile-split in views

Single DB row per user pair, but every list view and detail screen splits visually by profile.

- Good, because no schema migration.
- Bad, because every consumer (buyer web, buyer iOS, seller web, seller iOS, admin) carries the splitting logic.
- Bad, because per-thread state (last-read, unread, booking link) doesn't fit cleanly when "thread" is a synthetic UI concept that doesn't match a row.
- Bad, because cross-profile views and analytics still have to reckon with the lie at the data layer.

### Option D — Profile-scoped conversations (chosen)

Threads are keyed on `(buyer_user_id, seller_profile_id)`. One thread per `(buyer, profile)` pair.

- Good, because the data model is honest about what a thread is.
- Good, because every consumer (buyer iOS, seller iOS, future web/admin) gets the right answer for free with no splitting logic.
- Good, because per-message chip rendering and inheritance heuristics go away — fewer moving parts.
- Bad, because it requires a one-time migration. Mitigated by pre-launch timing.
- Bad, because the breaking surface is wide. Mitigated by the migration being a single coordinated change across api + both iOS apps.

## More Information

- ADR 0001 — `fl/docs/adr/0001-seller-account-profile-separation.md` — established the profile as the commercial unit. This ADR extends that decision to the messaging surface.
- PRD: `fl/docs/PRD.md` — see *Real-Time Features* (messaging bullet now reflects profile scoping).
- Migration: `fl-api/prisma/migrations/20260508004854_profile_scoped_conversations/migration.sql`.

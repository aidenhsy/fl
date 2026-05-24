# Feature Brief: FCM Push Notifications

> **Status:** Drafting — not yet started
> **Owner:** Aiden
> **Last updated:** 2026-05-23
> **Related:** [`personas.md`](../personas.md), translation feature (shipped 2026-04-30)

---

## Why now

Users are missing messages when the app is backgrounded. The translation feature shipped two weeks ago but its impact is invisible until Emma sees a translated preview on her lock screen — that's the moment "this app speaks my language" becomes real, not the moment she opens a chat thread.

This is the highest-leverage next feature: it unblocks retention (people stop checking the app and stop coming back) and makes the translation work tangible.

---

## Personas served

| Persona | What they need from push |
|---|---|
| **Emma** (tourist) | English previews of incoming JA messages on the lock screen; booking confirmations; deposit receipts |
| **Hiroshi** (local client) | Japanese previews; booking status changes; reminders the day before a shoot |
| **Kenji** (pro seller) | High-signal lead alerts with enough context to triage without opening the app; deposit-received confirmations |
| **Yuki** (side-hustle seller) | Same as Kenji, but respects iOS Focus modes so weekday work hours stay quiet |

See [`personas.md`](../personas.md) for full context.

---

## Goal

Deliver timely, language-correct, actionable push notifications on iOS (the merged `fl-client-ios` app covers both buyer and seller roles — see ADR 0011) so users respond to messages and bookings without needing the app foregrounded.

---

## Scope — v1

### In scope
- **iOS only** — single `fl-client-ios` app, routing pushes to whichever role (buyer or seller) the notification targets. Android and web come later
- **Dual-role token registration:** when a user holds both a client profile and a seller profile, the same install registers its device token twice (once with `app: .BUYER`, once with `app: .SELLER`) so role-specific pushes land on the right registration. This is the dual-registration model called out as out-of-scope in ADR 0011 §Out of scope, now in scope for this feature
- **Notification categories:**
  - New chat message
  - Booking request received (seller)
  - Booking accepted / declined (client)
  - Deposit received (seller)
  - Payment confirmation (client)
- **Language routing:** notification body in the *recipient's* app language, not the sender's
- **Translated previews** for chat messages, sourced from the existing `translations` JSONB column
- **Deep links** that open the relevant chat thread or booking detail screen
- **iOS Focus mode respect** — out of the box via standard APNS, no custom DND

### Out of scope (explicit)
- Android FCM integration (separate feature)
- Web push (separate feature)
- In-app notification center / history view
- Per-category notification preferences (e.g., "mute booking alerts, keep chat") — assume all-on for v1
- Rich notifications with images (photo previews, profile pics)
- Notification grouping / threading beyond iOS's default
- Email/SMS fallback when push fails or is disabled
- Scheduled reminders (e.g., "your shoot is tomorrow")
- Marketing/promotional pushes

---

## Happy paths

### HP1 — Cross-language chat message (Emma receives from Kenji)
1. Kenji sends "明日の10時で大丈夫です" from the seller side of the app (`activeRole == .seller`)
2. Backend `sendMessage` use case translates to all 4 languages, persists to `translations` JSONB (already shipped behavior)
3. Backend dispatches FCM notification to Emma's device token
4. **Notification payload includes the EN translation as the body**, not the original JA
5. Emma's lock screen shows: *"Kenji · Tomorrow at 10am works."*
6. Tap → app opens directly to the chat thread with Kenji, message already visible

### HP2 — Same-language chat message (Hiroshi receives from Yuki)
1. Yuki sends "週末空いてます" from the seller side of the app
2. Backend translates (JA → JA is a no-op / cache hit)
3. FCM payload body = JA original
4. Hiroshi sees: *"Yuki · 週末空いてます"*
5. Tap → chat thread

### HP3 — Booking request (Kenji receives)
1. Emma submits a booking request from the buyer side of the app (`activeRole == .buyer`)
2. Backend creates booking record, dispatches FCM to Kenji
3. Notification body in JA: *"新規予約リクエスト · Asakusa · 3月18日 10:00 · 2時間"*
4. Tap → booking detail screen with accept/decline actions

---

## Edge cases & error states

| Case | Expected behavior |
|---|---|
| Recipient has no device token registered | Skip push silently; message still delivered via Socket.IO if app is open; no retry |
| Device token is stale / FCM returns `UNREGISTERED` | Delete token from DB on that error; do not retry |
| FCM returns transient error (5xx, quota) | Retry with exponential backoff (3 attempts), then drop |
| Recipient is actively in the relevant chat thread (Socket.IO connection live) | **Suppress push** to avoid double-notification; rely on in-app indicator |
| Translation for recipient's language is missing in JSONB (shouldn't happen, but) | Fall back to original language; log warning |
| Message contains only an attachment, no text | Body = localized "📎 Sent an attachment" in recipient's language |
| Message is deleted before push is delivered | Best-effort: push may still arrive; tap should navigate to thread and show "message deleted" placeholder |
| Recipient has multiple devices | Push to all registered tokens for that user |
| Notification permission denied at OS level | App should detect on launch and prompt to re-enable; no server-side handling |
| User logged out on a device but token still registered | On logout, app calls backend to deregister token; backend deletes |
| Booking notification arrives but booking has already been cancelled | Tap → booking detail shows current (cancelled) state; no special handling |

---

## Technical sketch

> Not a spec — just enough to scope. The coding-agent prompt will go deeper.

### Backend (`fl-api`)
- New module: `notifications/` following Clean Architecture (port + adapter pattern, like `ITranslationService`)
- `INotificationService` port → `FcmNotificationService` adapter using Firebase Admin SDK
- New table: `device_tokens` (`user_id`, `token`, `platform`, `app_variant` (client/seller), `created_at`, `last_seen_at`)
- New use case: `RegisterDeviceTokenUseCase`, `UnregisterDeviceTokenUseCase`
- Hook into existing use cases:
  - `SendMessageUseCase` → dispatch chat notification
  - `CreateBookingUseCase` → dispatch booking-request notification
  - (etc. for other categories)
- Notification dispatch should be **fire-and-forget from the use case's perspective** — push to a queue or run async so chat send latency isn't bottlenecked on FCM
- Language selection logic: look up recipient's `preferred_language`, pull corresponding translation from message's `translations` JSONB
- Suppression check: query active Socket.IO sessions for the recipient + thread before dispatching chat pushes

### iOS (`fl-client-ios` — single app, both roles)
- APNS registration on launch (after permission grant)
- Token upload to backend via new endpoint; if the user holds both a client profile and a seller profile (per `RoleManager.hasClientProfile` / `hasSellerProfile`), upload **twice** with `app: .BUYER` and `app: .SELLER` so role-specific pushes route correctly
- Token refresh handling (`messaging:didReceiveRegistrationToken:`) — re-upload all role registrations on rotation
- Notification tap handler → deep link routing (chat thread vs. booking detail); if the payload targets a role other than `RoleManager.activeRole`, flip the active role before navigating
- Foreground notification handler dispatches by payload type + active role (silently suppress, badge-only, or surface a banner)
- Logout flow → call deregister endpoint for all role registrations on this device
- Localization keys for non-chat notification copy (booking request, deposit received, etc.) — 4 languages

> `fl-seller-ios` is deprecated (see ADR 0011) and is not a build target for this feature; its directory remains on disk as a porting baseline only.

### Localization keys needed
- `notification.booking.request.title`
- `notification.booking.request.body` (with placeholders for location, date, duration)
- `notification.booking.accepted.title` / `.body`
- `notification.booking.declined.title` / `.body`
- `notification.payment.depositReceived.title` / `.body`
- `notification.payment.confirmed.title` / `.body`
- `notification.message.attachmentOnly` (e.g., "📎 Sent an attachment")

---

## Open questions

1. **Queue vs. inline dispatch?** Adding a job queue (BullMQ, Cloud Tasks) is more robust but adds infra. For v1, async-but-inline (fire `setImmediate`, don't await) may be enough. Decide based on expected throughput.
2. **Socket.IO suppression — how strict?** "User is in the thread right now" is the obvious case, but what about "user has the app open but is on a different screen"? Lean toward sending the push and letting iOS handle foreground display.
3. **`device_tokens` schema for the merged iOS app.** Resolved: one table with an `app_variant` column (`'buyer' | 'seller'`). Post-merge there's only one install per device, but a dual-role user registers the same APNS token twice — once per role — so the dispatcher can pick the right `(user_id, app_variant)` row when sending a role-specific push. Uniqueness is `(token, app_variant)`, not `(token)` alone.
4. **FCM vs. APNS direct?** FCM wraps APNS and is already in the stack (memory says FCM is part of the GCP setup). Sticking with FCM for consistency unless there's a reason not to.
5. **Notification copy review** — who writes the JA, ZH_CN, ZH_TW translations for the non-chat categories? Translate via Cloud Translation API and review manually, or commission native-speaker copy from the start? Auto-translate is probably fine for v1 given chat translations use the same path.
6. **Re-engagement timing** — if Kenji doesn't tap a booking-request notification within 1 hour, do we re-push? Out of scope for v1, but worth flagging.

---

## Definition of done

- Emma can receive an English-translated push from a Japanese-speaking seller and tap into the chat thread
- Kenji can receive a Japanese booking-request push and tap into the booking detail screen
- Notification permission is requested on first launch (after a contextual primer screen)
- Device tokens are registered on login and deregistered on logout
- Stale tokens are cleaned up on FCM `UNREGISTERED` errors
- All 7 notification copy keys exist in 4 languages
- Pushes are suppressed when the recipient is active in the relevant Socket.IO session
- Logged in monitoring: push send count, failure rate, latency from event → dispatch

---

## What this unblocks next

- **Socket.IO translation wiring** (the existing stubbed PR) can ship before or after this — they're independent
- **Android FCM** — most backend work here is reusable
- **In-app notification center** — once we have the dispatch infrastructure, persisting a feed is straightforward
- **Per-category preferences** — adding a settings screen on top of an all-on baseline

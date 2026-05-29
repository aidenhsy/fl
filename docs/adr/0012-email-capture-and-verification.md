---
status: accepted
date: 2026-05-27
decision-makers: [aiden]
---

# Email capture on sign-up + verify-by-code via Resend

## Context and Problem Statement

Today `users.email` is set only when a social provider hands us a *verified, non-relay* address. That means:

- **Google** → always set (provider asserts `email_verified === true`)
- **Apple, real email** → set
- **Apple, "Hide My Email"** → dropped (we filter `is_private_email === true`)
- **LINE** → never set (we don't request the `email` scope and the `/v2/profile` endpoint doesn't return one)
- **WeChat** → never set (no email concept)

For the MVP categories (photographer, videographer) every account needs to be reachable by mail — booking confirmations, payment receipts, dispute notices, etc. Shipping order-confirmation emails to `null` is a silent failure mode that bites later. We need a guaranteed email on every account.

## Decision

1. **Blocking email-capture step.** After any successful social sign-in, if `users.email IS NULL`, the iOS app gates the whole experience on a verify-by-code screen. No skip button — the user cannot reach onboarding, browse, booking, or chat until an email is set.
2. **Verify by 6-digit numeric code, not magic link.** The user types an email → server emails a 6-digit code → user types the code back in-app → server writes `users.email`.
3. **Email transport = Resend.** Server-side via `RESEND_API_KEY` env var, sender `noreply@handii.io`. When the key is unset (local dev) the `ResendEmailSender` logs the message to stdout instead of calling the network — keeps the flow exerciseable without provisioning a key.
4. **Email-collision is resolved via the existing `/auth/link` flow.** If the user types an email that another live account already owns, `POST /auth/email/request-code` returns `LINK_REQUIRED` with a `pendingLinkToken` (purpose `auth.email-merge`) and the list of existing providers. The iOS client reuses `LinkAccountsView` — the user re-authenticates with one of those providers and `POST /auth/link` runs a transactional **merge**: every `auth_accounts` row moves to the older user, the ephemeral user's refresh tokens are revoked, the ephemeral user is soft-deleted.
5. **Change-email lives in account settings.** The same `EmailGateViewModel` powers a push from buyer `SettingsView` and seller `SettingsSection` (`profile.settings.email`). Same backend endpoints, same merge semantics.

### Rate-limit & lock policy

- Max **5** `request-code` calls per user per rolling hour → `TOO_MANY_CODE_REQUESTS`
- Code TTL = **10 minutes** (`expires_at = created_at + 10min`)
- Max **5** confirm attempts per code → `CODE_LOCKED`; user requests a fresh code to retry
- Codes are stored as `sha256(code)` — the plaintext is never persisted

### Endpoints

- `POST /auth/email/request-code` (auth'd) — `{ email }` → `{ status: CODE_SENT, expiresAt }` or `{ status: LINK_REQUIRED, existingProviders, pendingLinkToken }`
- `POST /auth/email/confirm-code` (auth'd) — `{ email, code }` → 204 (or `CODE_INCORRECT` / `CODE_LOCKED` / `CODE_NOT_FOUND_OR_EXPIRED`)
- `POST /auth/link` is extended: when `pending.purpose === 'auth.email-merge'`, runs `mergeUserAuthAccounts` in a Prisma `$transaction` instead of `createAuthAccountForExistingUser`

## Alternatives considered

**(A) Don't verify — save whatever the user types.** Simpler. Rejected because typos and fake addresses are common ("a@a", "test@test") and silent confirmation-email bounces are exactly the failure mode this whole change exists to prevent.

**(B) Verify by magic link.** Lower friction in theory but higher in practice on mobile — the link opens Mail, the user taps, iOS context-switches into Mail or Safari, the original app is backgrounded and may not handle the deep-link cleanly. 6-digit codes keep the user in-app.

**(C) Skip email capture; ask only at first booking.** Defers the gate to the moment a confirmation email becomes load-bearing. Rejected because it adds friction at a high-stakes moment (the user is mid-booking and the booking can't be confirmed unless they sit through the verify flow). Front-loading it once at signup is the gentler total UX.

**(D) Reject email collisions instead of merging.** Show "this email is already in use" and let the user pick a different one. Simpler but bad UX for the legitimate case where someone signed in with LINE last time and Google this time — they'd end up with two accounts they can never unify. The merge flow handles the right case and falls back cleanly when the user can't prove ownership of the other account.

**(E) Email transport alternatives.** AWS SES is cheaper at scale but requires SES sandbox-exit (24h approval) and more boilerplate; SendGrid is heavier and more expensive for low volume. Resend is the best fit for the launch volume (low) with a clear migration path to either alternative behind the `IEmailSender` port.

## Consequences

- Every new account ends up with an emailable `users.email` post-signup — booking confirmations, receipts, and any future transactional email can rely on the column being populated.
- New required infra: a `RESEND_API_KEY` env var in staging + prod. Local dev runs without one (stdout fallback).
- New table `email_verification_codes`. Indexed for the per-user rate-limit lookup and a future cleanup job (rows older than `expires_at + 24h`).
- The ephemeral-user merge path is the riskiest piece: a freshly signed-in user could theoretically create data (a message, a favorite) between signup and the email-gate finishing, which the merge wouldn't yet copy across. v1 accepts this — the gate is blocking, so the window is sub-second and only their `auth_accounts` row is realistically populated. If real-world data shows up in the ephemeral row, extend `mergeUserAuthAccounts` to copy bookings / messages / favorites / device_tokens before the soft-delete.
- iOS regen ([[reference_ios_openapi_regen]]) and a fresh fl-api → iOS spec sync are required to pick up the new operations.

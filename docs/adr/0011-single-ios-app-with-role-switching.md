---
status: accepted
date: 2026-05-20
decision-makers: [aiden]
---

# Single iOS App with In-App Role Switching (vs. Two Apps)

## Context and Problem Statement

The platform launched with two separate iOS targets — `fl-client-ios` for buyers (browse, book, message, leave reviews) and `fl-seller-ios` for sellers (availability, accept bookings, packages, payouts). Each app has its own bundle id, App Store listing, OpenAPI-generated client, and Firebase project. The backend (`fl-api`) already models a single `users` row as potentially holding both a `client_profiles` row **and** a `sellers` row (with N `seller_profiles`), so the data layer treats buyer/seller as facets of one identity — but the iOS surface forced users to install two apps to live in both worlds.

Two consequences hurt:

1. **Infrastructure drift.** `Core/Auth/AuthState.swift` was byte-identical between the two apps. `Core/Localization/LocalizationManager.swift` was identical. `Core/Network/AuthMiddleware.swift` had silently drifted by 16 lines; `Core/Network/openapi.yaml` differed by exactly one operation (`listMyReviews`). Each new shared concern was a coin-flip on whether the implementations stayed in sync.
2. **Onboarding friction for the dual-role case.** Most sellers also browse the platform as buyers (e.g. a photographer who occasionally books a driver). Forcing them to install + sign into two apps with the same Google account, just to access the other half of an account they already own, was a UX tax with no architectural justification.

Three options were on the table:

- **(A) Keep two apps.** Status quo.
- **(B) Extract a shared Swift package** for `Core/Auth`, `Core/Localization`, `Core/Network`, `Core/Notifications`. Keep two Xcode projects.
- **(C) Merge `fl-seller-ios` into `fl-client-ios`** as a single app with an Instagram-style role switcher.

## Decision

Adopt **(C)**: a single iOS app with in-app role switching. The merge lands as Phase 1 + Phase 2 of a phased plan; subsequent phases handle push routing, chat reconciliation, and seller-app retirement on the App Store.

### Mechanics

- **Survivor target.** `fl-client-ios` (bundle id `com.younger7jp.fl-client-ios`) absorbs `fl-seller-ios`. Buyer install base will dwarf seller install base post-launch (typical two-sided marketplace ratio ~10:1), so the buyer bundle id is the one worth preserving.
- **Active-role state.** A new `RoleManager` (`@Observable`) owns `activeRole: AppRole = .buyer | .seller`, persisted to `UserDefaults` under key `fl.active_role`. It also caches `hasClientProfile` / `hasSellerProfile` from `/me` so the UI can avoid switching to a side the user has no profile for.
- **Role-aware root.** A `RoleRootView` replaces the previous direct render of `MainTabView`. It branches on `RoleManager.activeRole` and renders either the buyer `MainTabView` (5 tabs: Browse / Favorites / Messages / Bookings / Profile) or the new `SellerMainTabView` (4 tabs: Home / Bookings / Messages / Profile). SwiftUI tears down + rebuilds the tab tree on role change — per-tab `NavigationStack` state resets, which matches Airbnb's behaviour.
- **Switcher trigger.** A long-press (`UILongPressGestureRecognizer`, 0.4s, `cancelsTouchesInView = true`) on the Profile tab bar button opens an Instagram-style `RoleSwitcherSheet`. Short taps still navigate to the Profile tab normally. The recognizer is attached to the live `UITabBar` via a SwiftUI `.task`-driven installer that locates the bar through `UIApplication.shared.connectedScenes` (the responder chain doesn't reach the `UITabBarController` because SwiftUI hosts it as a child of the scene). A medium-style `UIImpactFeedbackGenerator` fires on `.began` for the Instagram-style haptic confirmation.
- **Switcher content.** The sheet renders the user's client account row at top, then a "Your pro profiles" section listing each `seller_profile` (one row per category — a seller can hold many), then an "Add pro profile" row at the bottom. Tapping a row writes the active selection to `UserDefaults["profileTab.selectedProfileId"]` (the same key `ProfileContextStore` uses, so they stay in sync) and flips `RoleManager.activeRole`. Tapping "Add pro profile" dismisses the sheet and presents `SellerOnboardingContainerView`; on completion, `RoleManager.refresh()` re-pulls `/me` and `setRole(.seller)` flips the app.
- **Cross-role inbox isolation.** Both sides hit the same `GET /conversations` endpoint, which returns *every* thread the user participates in — including threads where they're the seller (a buyer messaging one of their pro profiles) and threads where they're the buyer (they messaged some other seller). To prevent leak across roles, `ConversationsViewModel.scope` is a new enum (`.all | .buyer(excludingOwnSellerProfileIds:) | .seller(profileId:)`). The buyer-side tab view sets `.buyer` with the user's own pro profile IDs (fetched from `listSellerProfiles`); the seller-side tab view sets `.seller(profileId: profileContext.selectedProfileId)`. A `visibleConversations` computed property applies the filter; `totalUnread` reads from the filtered list so badge counts match what's visible.
- **Onboarding gating.** Switching to seller mode while `hasSellerProfile == false` is impossible by construction: the sheet's "Your pro profiles" section renders only the "Add pro profile" row when the user has no seller account, and that row routes through onboarding rather than calling `RoleManager.setRole(.seller)`.
- **Push notifications (deferred).** FCM token registration still uses the single-role `app: .BUYER` discriminator inherited from the client app. Dual-registration (register the token twice with both `.BUYER` and `.SELLER` when the user holds both roles) is a separate phase — see *Out of scope*.
- **Chat reconciliation (deferred).** Seller-ios had a profile-scoped chat surface (identity-header + `totalUnread(forProfile:)`); the merged build uses the client's flatter `ConversationsListView`. The scope-based filter above is the minimum bar for correctness; the richer seller chat UI is a future phase.

### Why not (A) — keep two apps

Drift was already happening: 11 keys with conflicting English strings between the two apps' `Localization/en.json`, 17 keys in `zh-CN.json`. The longer two apps share an OpenAPI spec and an `AuthMiddleware` while evolving independently, the more those divergences accumulate. (A) is the path of "no change today, expensive change later."

### Why not (B) — shared Swift package only

(B) is strictly less work than (C) and was tempting. It captures ~80% of the duplication risk (`Core/Auth`, `Core/Localization`, `Core/Network`, `Core/Notifications`) with ~20% of the effort, *and* it's a prerequisite for any future merge anyway. The argument against:

1. The pre-launch window is the cheapest possible time to consolidate bundle ids — no installs to migrate, no App Store reviews to coordinate, no users to communicate the move to. Doing (B) now and then (C) post-launch means *two* disruptive packaging changes instead of one.
2. The Airbnb-style role switch is genuinely valuable as a discovery surface for dual-role users. (B) leaves them with two installed apps; (C) lets a buyer become a host without leaving the app they already trust.
3. The merge cost was bounded. ~60 seller feature files copied into `Features/Seller/` under a single namespace; 18 colliding top-level types renamed mechanically (e.g. `MainTabView` → `SellerMainTabView`); ~5 surgical reconciliations where seller code expected core types that differ on the client side. The whole port built green on the first xcodebuild after fixes.

(A) was rejected on drift grounds; (B) was rejected as an intermediate step that would have to be redone.

## Consequences

**Positive:**

- Single bundle id, single Firebase app, single App Store listing post-launch. Buyer-only releases stop blocking on seller QA and vice versa.
- One source of truth for `AuthState`, `LocalizationManager`, `AuthMiddleware`, the generated API client. Drift becomes a compile error rather than a silent runtime difference.
- Dual-role users (sellers who also book, buyers exploring becoming a host) have a one-tap path between sides. The "Add pro profile" affordance turns role conversion into a flow that lives on the user's existing identity rather than a new app install.
- Cross-side data isolation is enforceable in one place (`ConversationsViewModel.scope`) rather than diverging across two codebases.

**Negative:**

- One App Store binary now carries ~33k LOC of seller code that's dead weight for buyer-only users (most of `Features/Seller/*`, plus seller-specific SDKs). App Store binary size grows; cold-launch parsing cost is marginally higher. Acceptable for MVP scale, worth revisiting if download size becomes a metric.
- The long-press tab gesture relies on UIKit reach-around (`UILongPressGestureRecognizer` attached to the live `UITabBar`) because SwiftUI's `Tab` API doesn't surface a tab-button gesture hook. If iOS reshuffles `UITabBar`'s internal subview hierarchy or `Tab` adopts a non-UIKit rendering path in a future iOS release, the helper will need to adapt. Contained in `Core/UI/TabBarLongPressInjector.swift` (~110 LOC, one file).
- Push notification routing is now stale for dual-role users: an FCM message intended for the seller side of a dual-role account currently routes through the buyer-app registration. Tracked as a follow-up phase, not blocking MVP.
- The chat surface lost the seller-side identity-header + `forProfile`-scoped affordances from the standalone seller app. The scope-based filter is correct but the UX is the buyer's flatter list, not seller-ios's richer one. Acceptable for the merge; a richer seller chat surface is a future phase.

## Out of scope

- **Dual FCM-token registration.** When the user holds both roles, register the device token twice with `app: .BUYER` and `app: .SELLER`. Foreground notification handler dispatches by payload type and active role. Deferred to a follow-up phase.
- **Seller-ios App Store retirement.** Final in-app message on the existing seller listing pointing users at the merged app, then remove-from-sale. Coordinated with the merged app's first published release.
- **Per-platform consolidation.** The same merge eventually applies to Android (`fl-buyer-android` / `fl-seller-android`) and the seller web app. Out of scope for this ADR; precedent only.
- **Richer seller chat surface.** Profile-scoped identity header, `forProfile`-scoped unread counts, and the seller-flavoured `ConversationsViewModel` from the standalone seller app. Future phase.

## More Information

- The merge landed in two phases: Phase 1 (foundation — `RoleManager`, merged OpenAPI spec, lifted byte-identical core files) and Phase 2 (feature port — 60 seller files into `Features/Seller/` with namespaced renames, plus `RoleRootView`, `RoleSwitcherSheet`, long-press wiring). Each phase is a single commit on `main` so either can be reverted in isolation.
- The `BOOKING_BYPASS_STRIPE_GATE` env flag (set in prod via `/var/www/fl-api/.env`) coexists with this merge; it remains independent of the iOS role-switch logic.
- The two iOS repos remain on disk during the transition (`fl-seller-ios` is no longer the build artefact but its source is still referenced as the porting baseline for ADRs 0001–0010).

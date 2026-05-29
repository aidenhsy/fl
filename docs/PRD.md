# Freelance Services Marketplace — Product Requirement Document

## Overview

A two-sided marketplace platform connecting **buyers** (clients seeking creative work) and **sellers** (freelance creative professionals) across creative categories — photography, videography, design, and similar. Phase 1 launches with two adjacent categories — **photographer** and **videographer** — for foreign travelers visiting Japan and for couples / event hosts in Japan. The launch persona is the traveler buyer hiring a local photographer or videographer to document their trip or event; domestic-buyer growth and additional creative categories (design, etc.) follow once the traveler wedge is validated. Why two categories at launch (not one): videography is a different medium with different pricing, deliverables, and gear from photography — nesting it as a sub-category of photographer would muddle both the buyer's mental model and the sub-category taxonomy (which describes shoot *occasions*, not media). See ADR 0007. The platform operates similarly to Uber's model — separate experiences for each side, with request-based matching, scheduling, and payment.

The launch is **traveler-first** in product decisions (pricing surface, payment-method emphasis, language coverage, discovery surfaces, marketing) but **buyer-agnostic in the data model** — there is no "traveler" vs "domestic" flag on a buyer record. Domestic buyers are a later segment, not a separate schema.

## Platforms

| Platform | Buyer surface | Seller surface | Distribution |
|----------|---------------|----------------|--------------|
| iOS      | Yes           | Yes            | **Single combined app** (ADR 0011) — long-press the Profile tab to swap roles |
| Android  | Yes           | Yes            | Two apps (pre-merge baseline; same consolidation TBD) |
| Web      | Yes           | Yes            | Two surfaces |

**Backend:** NestJS monorepo serving all platforms via shared APIs.

The iOS app ships as a single binary (`com.younger7jp.fl-client-ios`) that hosts both the buyer and seller surfaces; an in-app role switcher gates which tab bar and feature set is visible. The same `users` row backs both sides — a single sign-in unlocks any combination of `client_profiles` + N `seller_profiles` the user holds. See ADR 0011 for the role-switching mechanics, cross-role inbox isolation, and the rationale for picking a merged binary over two apps.

---

## User Roles

### Buyer (Client)
A person looking to hire a freelance service provider for a specific task or ongoing engagement.

### Seller (Provider)
A freelance professional offering their services through the platform. A seller **account** holds one or more **profiles**, each scoped to a single category (see Glossary).

### Admin
Handi staff who manage users, disputes, categories, and platform settings. Admins act on other users' content (e.g. removing a portfolio photo that violates policy, suspending a profile, approving a custom-category request). Admin is an **additive capability**, not an exclusive role: a single `users` row can simultaneously be a buyer (has `client_profiles` row), a seller (has `sellers` row), **and** an admin (`users.is_admin = true`). This is deliberate so Handi staff can dogfood the buyer/seller apps with the same Google account they use for admin work — the three capabilities live on independent signals and never collide. Admins authenticate via Google OAuth gated by an `ADMIN_ALLOWED_EMAILS` allowlist (see §1); successful sign-in flips `is_admin = true` on the user record and issues a JWT whose `role` claim is `ADMIN`. Mobile sign-ins for buyer/seller use a different login flow that does not carry the admin claim, so a single user with both mobile and admin tokens has scoped privileges in each app.

---

## Glossary

### Account
A seller's identity on the platform. Holds authentication, KYC / identity verification, Stripe Connect / payout details, contact information, and the **availability calendar** (one calendar per account, shared across all of the seller's profiles — see ADR 0003). One person = one account.

The seller account row is created **implicitly** on the user's first seller-only action — creating their first profile, or submitting a custom job request. There is no separate "become a seller" step. From the user's perspective, signing up and finishing the first-profile funnel is one continuous flow; the account/profile distinction is a server-side concept that becomes visible only when they go to add a second profile.

### Profile
A sellable persona scoped to exactly one category. Owns its own headline, bio, **portfolio media** (see *Core Features → Portfolio*), **pricing capabilities** (any combination of packages, ad-hoc hourly, and package-extension hourly — see *Core Features → Seller Profiles*; primary-mode hint via `pricing_type` per ADR 0005), slug (used in discovery URLs), and reviews. A seller account holds 1..N profiles. Availability is **account-scoped, not profile-scoped** — see ADR 0003.

Profile slugs are globally unique across the platform.

In v1, a seller may have at most one profile per category. Multiple profiles in the same category (e.g., "wedding photography" vs "corporate photography") is deferred.

### Window

A continuous span on the seller's account-level calendar during which they are available, e.g. `Fri 2026-02-12 15:00–17:00`. Sellers publish windows; buyers claim slots inside them.

### Slot

A fixed 1-hour subdivision of a window, aligned to the window's start. A 15:00–17:00 window contains two slots (15:00–16:00, 16:00–17:00). A booking is 1+ contiguous slots within a single window.

---

## Core Features

### 1. Authentication & Onboarding
- Email/password and social login (Google, Apple)
- Phone number verification via OTP
- **Blocking email-capture step after social sign-in** (ADR 0012). Google always returns a verified email, but Apple's "Hide My Email" yields a relay address we drop, and LINE returns no email at all. To guarantee every account is reachable by booking-confirmation / receipt mail, any signed-in user with `users.email IS NULL` is funneled through a verify-by-code screen before they can use the app: enter an email → 6-digit code is emailed via Resend → enter code → `users.email` is set. A change-email row in account settings re-uses the same flow. If the typed email already belongs to another live account, the flow returns `LINK_REQUIRED` and routes through the existing account-linking screen — the user signs in with one of the other account's providers and the two accounts merge into the older one (the just-created ephemeral user is soft-deleted).
- **First-time onboarding lands the user on the buyer surface by default** (the larger install base). The user's `client_profiles` row is created up front; a `sellers` row is only created when they choose to add a pro profile. The role they're "wearing" is persisted in `UserDefaults` (`fl.active_role`) so the app reopens in the same surface.
- **Becoming a seller (pro) is in-app, not a separate install** (ADR 0011). From any tab, long-press the Profile tab in the bottom bar → role switcher sheet → "Add pro profile" → seller onboarding flow (category single-select, headline, bio, **portfolio** — see §3, **pricing** — session/package or hourly per ADR 0004) → first profile is created → land on the seller side. Each additional category is another `seller_profile` reachable via the same switcher.
- Seller onboarding: account creation (auth + identity verification) → first profile created in a single funnel (category single-select, headline, bio, **portfolio** — see §3, **pricing** — session/package or hourly per ADR 0004) → set up the **account-level availability calendar** (shared across all future profiles too) → land on a profile list with a "Create another profile" CTA for additional categories
- **Admin sign-in (web-only)** — admins authenticate via `POST /admin/auth/google` using the same Google ID-token verification used on mobile, gated by an `ADMIN_ALLOWED_EMAILS` env-var allowlist. Successful verification finds-or-creates the user, flips `users.is_admin = true` on that row (no-op if already true), and issues a JWT + refresh-token pair (reusing `AuthTokenResponseDto`). The flow rejects only when the verified email is **not** in the allowlist (HTTP 400, `ADMIN_EMAIL_NOT_ALLOWED`); it does **not** reject when the email already exists as a buyer or seller — admin is additive (see § Admin). The admin JWT carries a `role: 'ADMIN'` claim that mobile JWTs lack; the `AdminGuard` on every `/admin/*` route checks both that claim and the live `users.is_admin` value in the DB (so role demotion via env-var removal cuts off outstanding tokens on the next request). Adding or removing a Handi staff member is an env-var update; no admin-management UI ships in MVP.

### 2. Seller Profiles

A seller account holds one or more profiles. Each profile is scoped to a single category and is the unit buyers discover, book, and review.

- Each profile owns:
  - Category (e.g., photographer, videographer, designer) — exactly one per profile
  - Headline and bio
  - **Pricing** — `pricing_type` (`SESSION` | `HOURLY`) is a **primary-mode positioning hint** on the profile (not an exclusivity gate — see ADR 0005 superseding ADR 0004). A profile can simultaneously offer **any combination** of these capabilities:
    - **Packages** — 1..N package rows, each with 1..N priced variants. A **package** is the offer's identity — sub-category (`旅拍` / `写真` / `毕业` etc., NOT NULL), title, description, `duration_slots`, the 注意事項 terms list, and an optional **per-package `hourly_extension_rate`** for overtime billing on that specific package. Duration, terms, and extension rate are shared across all variants of a package. A **variant** is the priced permutation — label (e.g., "Solo digital, 9 photos"), price, format (`DIGITAL | FILM | VIDEO | OTHER`), and included-items text. Example: one Package "Travel/portrait photography in Tokyo, 1.5h, ¥4,000/hr overtime" with four variants — solo digital 9 photos ¥18k / duo digital 9 photos ¥22k / solo film 1 roll ¥20k / duo film 1 roll ¥24k. A *different* package on the same profile (e.g. "Wedding ceremony coverage") can carry a different extension rate (¥10,000/hr) — the rate scales with the offering, not the seller.
    - **Ad-hoc hourly** — `hourly_rate` (JPY/hour) on the profile. Set when the seller accepts standalone by-the-hour bookings. Independent of whether the profile also has packages.
  - At least one of *Packages* or *Ad-hoc hourly* must be true for the profile to be bookable. `pricing_type` declares which is the seller's *primary* offering (drives the headline price on cards, search-result ranking). See ADR 0004 for the per-booking `pricing_mode` discriminator and the at-booking denormalised fields; see ADR 0005 for the relaxed non-exclusive capability model.
  - Service area / location radius
  - **Portfolio** — promoted to its own first-class feature, see §3
  - Slug (used in discovery URLs)
  - Reviews and aggregate rating
- A seller may create additional profiles for additional categories (e.g., a photographer profile and a videographer profile under the same account).
- Account-level fields (auth, KYC, Stripe Connect / payout, contact, **availability calendar**) are shared across all of a seller's profiles. Availability lives on the account because the seller is one human — a slot claimed through any profile blocks the same hour on every other profile of the same seller (see ADR 0003).

### 3. Portfolio

For creative discovery the portfolio *is* the product — a buyer hires the work, not the rate card. Portfolio is therefore a first-class designed surface on every profile, not an "optional media field."

The portfolio data model is **project-based** (ADR 0009). The flat-photo model that this section previously described has been replaced. The summary:

- **Project = container.** Every piece of portfolio content is a `Project`. A project owns a multilingual title and description (JA, EN, ZH_CN, ZH_TW — authored manually by the seller, see *Out of scope* below), an ordered list of 1..N `MediaItem`s, a designated cover MediaItem, a `publishedAt` nullable timestamp (a draft is `publishedAt IS NULL`), seller-controlled `sortOrder` within the portfolio, and optional `subCategoryId` + `packageId` tags promoted up from the previous item-level model.
- **MediaItem = leaf.** A MediaItem has a `mediaType` (`IMAGE | VIDEO | PDF`), a URL, an optional multilingual caption (same language set and fallback rules as project title/description — JA / EN / ZH_CN / ZH_TW), an optional thumbnail (required for VIDEO/PDF), file metadata (mime type, byte size, original filename), and a `sortOrder` within its parent project.
- **Single photos are projects too.** A single-photo upload creates a Project with `isSingleItem: true`, one MediaItem of type IMAGE, and the cover set to that MediaItem. The seller never sees the word "project" in this flow — the abstraction is hidden behind the **Add a Photo** UX (see *Upload flows* below). One unified data model, two upload UXes.

**Upload flows.**
- **Add a Project** — multi-step wizard on the seller app: title → description → upload media (1..N) → reorder → set cover → publish. Multilingual title/description fields per supported language; sellers fill in whichever languages they want (see *Out of scope* — auto-translation is deferred).
- **Add a Photo** — single-step on the seller app: pick the photo, optionally add a caption, tap Save. Behind the scenes the server creates a Project with `isSingleItem: true`. No project title, no description, no cover-picker step. A single-photo project can later be converted into a full project via a **Promote to project** action on the seller app — tapping it opens the standard project editor pre-populated with the existing MediaItem, where the seller can add a title, description, more media, and re-select the cover (ADR 0009).
- **Cover image on promotion.** The original MediaItem stays pinned as the project's cover by default when a single-photo project is promoted. The cover-picker is available inside the project editor but is not a required step during the promotion flow.
- **Caption on promotion.** The existing MediaItem's caption stays on the MediaItem after promotion. It is not copied into the project description, and it is not replaced by it — caption (per-image label) and description (per-project context) are distinct fields and stay independent.
- **Caption input UX on Add a Photo.** The single-step flow exposes exactly **one** caption input — in the seller's primary language. Additional languages for that caption are reachable only via the project editor (after Promote to project, or by using Add a Project from the start). This keeps Add a Photo casual and single-step; multilingual caption authoring lives in the project editor where the seller is already in a multi-language context.

**Display modes.** Each `Portfolio` (one per seller profile) carries a `layout` setting that the seller toggles from profile settings — persisted, survives sessions, defaults to `PROJECTS`:
- **`PROJECTS` layout (default).** Public profile renders a grid of project cards (cover image + title). Tapping a card opens a project detail view with the full media gallery and the project description.
- **`GRID` layout.** Public profile renders a flat grid of every MediaItem across every project (Instagram-style). Tapping any tile still opens the parent project's detail view — the project context is never lost, a buyer can always see what shoot a given frame came from.

**MediaType.**
- `IMAGE` — JPEG / PNG / HEIC. The image itself is the thumbnail.
- `VIDEO` — short video clips. A poster thumbnail is required at upload time (server may generate one from the first frame as fallback).
- `PDF` — design / brand-campaign deliverables and similar artefacts. v1 displays a PDF as a **downloadable** attachment with a **static thumbnail preview** (uploaded with the file). Native in-app PDF rendering is v2.

**Other portfolio behaviour.**
- **Seller-controlled ordering.** Projects are reorderable; within each project, MediaItems are reorderable. Both orderings are the source of truth for the public-profile rendering in either layout mode.
- **Tagging at the project level.** Each project carries optional `subCategoryId` and optional `packageId`. Sub-category tags drive search relevance (a buyer filtering "Wedding & Couples" surfaces projects tagged with that sub-category — ADR 0006 eligibility check moves from media item to project). Package link lets a buyer drill from a package into the projects that represent its shoots. Both fields nullable because sellers will publish legacy work that predates the package or sub-category it belongs to. The corresponding field on `seller_packages.sub_category_id` is **NOT NULL** — asymmetry intentional, same reasoning as before.
- **Cover image.** Each project has an explicit `coverMediaItemId`. The profile card's hero in search results is the cover of the first project (by seller-controlled order). The "first item wins" convention from the flat-photo model is gone.
- **Lightbox.** In `GRID` mode, tapping a tile opens the lightbox at that item inside the parent project's detail view (so swipe-next/previous walks through *that project's* media, not across project boundaries). In `PROJECTS` mode, the project detail view's media gallery is the lightbox.
- **No sub-albums.** Projects ARE the album-equivalent. Nested sub-albums within a project (e.g. "ceremony" / "reception" inside a wedding project) are out of scope.
- **Project count cap.** A practical upper bound is enforced server-side — exact number pending product-owner review (working assumption: 50 projects per profile; no per-project media-item cap below the server's overall upload-size limits).

Portfolio is also a primary **discovery surface** — see §4.

**Out of scope for v1 (portfolio):**
- **Auto-translation** of project titles, project descriptions, and media-item captions across JA/EN/ZH_CN/ZH_TW. Sellers author each language they want manually. The rendering layer picks the best available for the reader's preferred language and falls back to the seller's primary language when the requested locale is missing.
- **Project drafts** beyond a simple `publishedAt IS NULL` flag. No multi-stage approval workflow, no admin moderation queue on the project itself (admin can still remove a project as a slice-2 portfolio moderation action), no scheduled-publish.
- **Project analytics** — view counts, likes, save-for-later. The card's hero count and the buyer-favorites surface from §9 are unchanged.
- **Native in-app PDF rendering**. v1 ships PDFs as downloadable attachments with a static thumbnail; the in-app reader is a v2 line item.

### 4. Search & Discovery (Buyer)

A creative-services buyer discovers along two complementary axes: **the work** (browsing portfolios) and **the place** (where the buyer is, where the seller works). For a foreign traveler in Japan the natural framings are *city / landmark* and *current location* — not 郵便番号 and not 政令指定都市 ward codes.

- Browse by category (two active categories in v1 — **photographer** and **videographer**; ADR 0007)
- **Portfolio-led grid.** The default discovery surface is a visual grid of seller cards led by portfolio cover imagery, with rate, rating, and area beneath. Tapping a card opens the full portfolio. For creative work the portfolio is itself a primary discovery surface, not a downstream profile detail.
- Area filter — see *Area filter* below
- Filter by price range, rating, availability
- **Sub-category (specialty) filter.** Within a parent category the buyer can narrow to a specific shoot type — Wedding, Travel Portrait, Family, Graduation, Commercial, etc. A profile is eligible for the filter if it has *either* an active package in that sub-category *or* at least one portfolio project tagged with it; there is no separate seller-side "specialty" toggle to keep in sync (see ADR 0006 and ADR 0009 — eligibility now derives from `Project.subCategoryId`, not media-item-level tags). When the filter is set, each card surfaces matching projects first — the cover image of the seller's first matching project becomes the card's hero, with the seller's broader portfolio behind it — so a buyer filtering by Wedding sees each photographer's wedding work first on the card before navigating into the rest of their portfolio.
- Recommended / featured profiles
- **Map view** is **secondary** for creative discovery. (For home-services the map is the primary surface — "a cleaner near me"; for creative work the buyer is choosing on portfolio strength first and proximity second, so the default surface is the visual grid with map available as a toggle.)
- A seller with profiles in multiple categories appears as one card per profile. A buyer searching for photographers does not see that seller's videographer profile, and vice versa — discovery is profile-scoped, not account-scoped.

**Area filter.** Buyers narrow results geographically using three discovery routes — area-name / landmark search, current location, or postal code — all of which collapse onto the same `areaId` parameter on `GET /seller-profiles`, where `areaId` is a prefecture UUID or a municipality UUID:

1. **Area-name / landmark search** (**primary** for the traveler buyer). The buyer types "Tokyo", "Shibuya", "Kyoto", or a landmark name like "Fushimi Inari" / "渋谷駅". A typeahead matches against prefecture and municipality names (JA + romanised via the kana columns already in the schema; EN/zh-CN/zh-TW name variants pending product-owner review on data source). Landmark resolution likely uses a curated landmark→areaId table seeded alongside KEN_ALL — pending product-owner review.
2. **Current location** (**primary** for the traveler buyer). Reverse-geocodes the device's GPS coordinates to a municipality. (Reverse-geocoding implementation remains out of MVP scope — placeholder button only.)
3. **Postal code lookup** (`郵便番号から探す`). The buyer types a 7-digit 郵便番号 (with or without hyphen, full-width or half-width). `GET /postal-codes/{code}` resolves it to a (prefecture, municipality, town) tuple, the UI auto-selects that municipality, and search re-runs. This route is **primarily a seller tool** (setting one's service area at municipality precision) and a fallback for domestic buyers; foreign travelers will not normally know a 郵便番号. The endpoint and the buyer-side affordance are retained but de-emphasised on the buyer app.

Region → prefecture → municipality browse (`都道府県から探す`) remains as an alternative entry. `GET /prefectures/grouped` returns the 47 prefectures pre-sectioned into the eight conventional 地方 (北海道, 東北, 関東, 中部, 近畿, 中国, 四国, 九州・沖縄). Tapping a prefecture row drills into `GET /prefectures/{id}/municipalities`. Tapping a municipality finalises the filter.

Reference data sources:
- **Prefectures** (47, JIS X 0401) — hardcoded in migration `20260514132714_add_region_kana_postal_codes`. Reference data lives in migrations, not seed scripts, so every environment lands with the same canonical rows.
- **Municipalities** (~1,892 including 政令指定都市 wards, JIS X 0402) and **postal codes** (~124k rows) — both seeded from Japan Post's KEN_ALL feed (`https://www.post.japanpost.jp/service/search/zipcode/download/utf/zip/utf_ken_all.zip`) by `scripts/import-postal-codes.ts`. Japan Post publishes KEN_ALL monthly; the importer is idempotent and intended to run on a monthly cron once the marketplace is live.

Service-area precision: sellers may set their service area as **Nationwide** (e.g. remote designers, online translators), **Prefecture-level** (e.g. "anywhere in 東京都"), or **Municipality-level** (e.g. "渋谷区 only"). Buyer area selection of any granularity matches every seller whose service area contains it — picking 渋谷区 surfaces both 渋谷区-specific sellers and 東京都-wide sellers and Nationwide sellers. See `ServiceAreaType` in `prisma/schema.prisma`.

### 5. Booking & Scheduling
- The seller publishes **availability windows** on a single account-level calendar (e.g., `Fri 2026-02-12 15:00–17:00`). Each window splits into fixed 1-hour **slots** aligned to the window's start.
- Buyers book against a specific profile, but slots are drawn from the seller's account-level calendar. A slot held or booked through any profile becomes unavailable on every other profile of the same seller (see ADR 0003).
- A booking request is one or more **contiguous** 1-hour slots within a single window. A 3-hour window can be sold as one 3-hour booking, three 1-hour bookings, or any contiguous combination. For `SESSION`-priced profiles the buyer **selects a package, then a variant within that package, then a start time**; the slot span is derived from the chosen package's `duration_slots`. Each booking carries an explicit `pricing_mode` discriminator (`PACKAGE` | `HOURLY`) so booking-reading code branches on a single column rather than inferring from null patterns (see ADR 0004).
- **Initial booking flow is request → accept/decline.** The buyer submits a request for the chosen slots and (optionally) a message. On submission the slots enter a **hold** state — they no longer show as available to other buyers, on any profile of the same seller.
- **Custom-time request path (ADR 0008).** When none of the seller's published windows match what the buyer needs ("my wedding is Saturday 2pm-7pm, can you do it?"), the buyer can switch the slot grid for a `DatePicker` and propose a specific hour-aligned time directly. The booking is created with `requested_outside_window = true`; the use case skips the "must fall in a window" check but still writes `slot_occupancy` rows so two buyers can't double-book the same hour. The seller's inbox card shows a "Custom request" chip on these bookings so they understand the time wasn't pulled from their published schedule. Accept/decline flow is unchanged.
- The seller has **12 hours** to accept or decline. On accept the slots become a confirmed booking and the buyer is notified. (Payment timing depends on pricing method — see §7 and the *Completion* subsection below.) On decline or timeout, the hold is released and the slots return to availability.
- **The buyer may withdraw their pending request at any time before the seller responds.** Withdrawal immediately releases the held slots back to availability. (Applies symmetrically across the system: the originator of any pending request/proposal can withdraw it while it is awaiting the counterparty's response.)
- Hold creation is **first-come-first-served and atomic** — if two buyers request the same slot simultaneously, exactly one acquires the hold; the other sees "slot just taken". This prevents overbooking at the request layer.
- **Total price** depends on the booking's `pricing_mode` (see ADR 0004) plus optional extension hours (ADR 0005):
  - `PACKAGE` bookings: total = `variant_price_at_booking + (extension_slots × extension_hourly_rate_at_booking)` (extension term = 0 when no overtime added).
  - `HOURLY` bookings: total = `hourly_rate × number_of_slots`.
  Price is shown at request time and captured at the appropriate point in the lifecycle (see §7 and the *Completion* subsection below).

**Bilateral modification proposals.** During the 12h accept window *and* after a booking is confirmed, the engagement may need to change — e.g., during a chat the seller realises a 1-hour portrait session won't capture what the buyer wants and proposes a longer slot span (or, for HOURLY, more hours), or counters a pending request with a different start time before accepting. Either party (buyer or seller) can propose a modification:
- A modification can change the **time** and/or **duration** of the booking, subject to the booking's `pricing_mode`. For **HOURLY** bookings both start and duration are modifiable. For **PACKAGE** bookings, the modifiable axes are **start time**, **variant within the same package** (the common case — "actually it's two of us, switch from solo to duo"), and **package on the same profile** (the rarer case — "let's upgrade from Travel 1.5h to Half-day"). Within-package variant changes do not change the slot span; package swaps may (because `duration_slots` lives on the package). The new slots must not already be booked or held by anyone else (the no-overbooking constraint is enforced on every proposal). **Buyer-initiated** proposals additionally must fall inside a published availability window — the buyer can't demand times the seller hasn't said they're free for. **Seller-initiated** proposals skip that window check: the seller proposing a new time is itself the availability signal, so they don't have to first publish a window and then propose against it.
- A `PACKAGE` modification can additionally **add extension hours** at the **booked package's** `hourly_extension_rate` (e.g., the wedding ran long, add 2h at ¥10,000/h; a travel-portrait shoot on the same profile would use that package's lower rate). The proposal carries `proposed_extension_slots` + the snapshot rate `proposed_extension_hourly_rate_at_proposal` (proposal-time capture per ADR 0004); on approval those land on the booking as `extension_slots` + `extension_hourly_rate_at_booking`. The booking's `pricing_mode` stays `PACKAGE` — the extension is an add-on, not a mode flip. An extension proposal is rejected (`EXTENSION_NOT_OFFERED`) if the booked package has no `hourly_extension_rate` set. See ADR 0005.
- On submission, any **net-new slots** in the proposal enter the same hold state as a fresh request, blocking the seller's calendar across all profiles. Original slots remain in their current state — HELD if the booking is still INCOMING, BOOKED if already confirmed — until the proposal resolves.
- The counterparty has **12 hours** to approve or reject. On approval, the booking's slot set is replaced with the proposed set (released slots return to availability, new slots take the booking's current state — HELD if still INCOMING, BOOKED if already confirmed), and any price delta is captured (extension) or refunded (shortening). Approving a modification is a terms change, not an accept; an INCOMING booking stays INCOMING after approval and the seller still has to accept or decline it. On rejection or timeout, the held delta is released and the booking reverts to its original slots — no charge.
- Pricing on a modification uses the booking's **originally captured pricing** for the unchanged leg — `hourly_rate_at_booking` for HOURLY bookings, `variant_price_at_booking` for PACKAGE bookings — so a seller raising their listed prices after the booking does not retroactively reprice. When a PACKAGE modification *swaps the variant or the package*, the new variant's current price is captured at modification-approval time (and stored as the booking's new `variant_price_at_booking`, with `package_id` / `package_variant_id` and denormalised title/label updated to match); the price delta = `new_variant.price − variant_price_at_booking`. When a PACKAGE modification *adds extension hours*, the captured rate is **the booked package's** current `hourly_extension_rate` at proposal time (not booking time) — the seller's overtime rate at the moment the buyer is offered the extension applies. A PACKAGE modification that only changes the start time has zero price delta.
- **The originator may withdraw the proposal at any time before the counterparty responds**, immediately releasing the delta hold and leaving the original booking intact. Either side can be the originator, so this withdrawal right applies bilaterally.

**Completion.** For creative work the booked slot is not the end of the engagement — edited deliverables (photos, video, designs) arrive days or weeks later. After the slot elapses the booking stays `CONFIRMED`; completion is a two-sided acknowledgement:

1. The booked slot(s) elapse. The booking remains `CONFIRMED`.
2. When the deliverables are ready, the seller hits **Mark work done** in the seller app. This records a `seller_marked_done_at` timestamp on the booking and push-notifies the buyer, but **does not change `BookingStatus`** — the booking is still `CONFIRMED`. (The "work-done, awaiting-buyer" sub-state lives on the timestamp, not on the status enum. The current `BookingStatus` set — `INCOMING`, `WITHDRAWN`, `DECLINED`, `EXPIRED`, `AWAITING_PAYMENT`, `CONFIRMED`, `ACTIVE`, `COMPLETED`, `CANCELLED` — is unchanged.) The seller may also attach delivery artefacts (e.g., a gallery link) into the booking conversation — exact delivery-artefact UX is pending product-owner review.
3. The buyer reviews and hits **Confirm completion**, transitioning the booking `CONFIRMED` → `COMPLETED`. Reviews unlock at `COMPLETED` (unchanged).
4. **Auto-complete after 7 days.** If the buyer takes no action within **7 days** of `seller_marked_done_at`, the booking auto-completes to `COMPLETED`. This prevents bookings from hanging post-shoot and unblocks seller payout. A scheduled job sweeps for `CONFIRMED` bookings whose `seller_marked_done_at + 7 days` has elapsed and transitions them.

Payment timing interacts with completion per pricing method — see §7. In short: **card** authorises at request and **captures at completion** (`CONFIRMED` → `COMPLETED`, manual buyer-confirm or 7-day auto-complete); **konbini** is already paid upfront, so the same transition is a confirmation / payout-release gate, not a payment event.

Calendar export (`.ics`, Google Calendar sync) is deferred post-MVP.

### 6. Real-Time Features
- In-app messaging between buyer and seller, scoped per (buyer, seller profile) — each thread is anchored to one profile/category, so a buyer who engages two profiles of the same seller has two distinct threads (see ADR 0002).
- Live status updates on active bookings (e.g., "session started", "work done", "completed")

**Push notifications.** Every booking lifecycle transition and modification event fires a Firebase Cloud Messaging push to the affected party in addition to inserting a `notifications` row for the in-app inbox. Each device registers its FCM token with `POST /me/device-tokens` (idempotent upsert) at app launch and after auth; the same human can hold both a `BUYER` and `SELLER` token on one device (separate bundle ids → separate tokens), and events fan out only to the relevant app:

| Event | Recipient | Recipient app |
|---|---|---|
| Booking requested | Seller | SELLER |
| Booking confirmed / declined | Buyer | BUYER |
| Seller marked work done (booking stays `CONFIRMED`) | Buyer | BUYER |
| Booking completed (buyer confirmed or 7-day auto-complete) | Seller | SELLER |
| Booking cancelled | Other party | swap |
| Booking withdrawn (buyer-side) | Seller | SELLER |
| Modification proposed | Counterparty | swap |
| Modification approved / rejected | Originator | swap |
| Modification withdrawn | Counterparty | swap |
| New chat message | Other participant | swap |

Push body + title are localised server-side to the recipient's `users.language`. The payload carries `type`, `bookingId`, and (where relevant) `conversationId` / `modificationId` so the iOS app can deep-link on tap. Each event also drops a `SYSTEM`-type message into the booking's conversation so the chat thread doubles as a permanent audit trail and the in-conversation view updates live via the existing chat WebSocket — push covers the "app closed" path; the SYSTEM message covers the "app open in another tab" path. FCM tokens reported as `UNREGISTERED` / `INVALID_ARGUMENT` are reaped automatically from `device_tokens` on the next failed send.

### 7. Payments
- In-app payment processing via Stripe.
- **Card is the primary payment method for the launch (traveler) buyer.** A foreign tourist visiting Japan will not pay a konbini voucher; the launch flows are designed and tested card-first. Konbini is retained in the system for domestic buyers and seller preference but is **not load-bearing for the launch segment** — it should keep working, but design decisions favour card.
- Two buyer payment methods are offered at checkout (chosen per booking):
  - **Card** — authorize-and-capture model. Funds are **authorised** on the buyer's card when the booking is created (status `INCOMING`); **captured at completion** (`CONFIRMED` → `COMPLETED`, manual buyer-confirm or 7-day auto-complete — see *Completion* in §5). Modifications between `CONFIRMED` and the capture event re-authorise off-session against the saved card without buyer interaction. The same off-session mechanism re-authorises if shoot-to-completion exceeds the card network's auth window (typically 7 days). For both `PACKAGE` and `HOURLY` bookings the captured amount is the booking's current total (`variant_price_at_booking` or `hourly_rate × slots`).
  - **Konbini (コンビニ払い)** — pay-after-acceptance model for buyers who prefer cash/convenience-store payment. The seller accepts (or both sides agree on a modification) **before** any payment is requested, so the buyer never has to make a second konbini payment for a price change. Lifecycle: `INCOMING` → seller accepts → `AWAITING_PAYMENT` (Stripe konbini voucher issued, valid 24h, buyer pushed) → buyer pays at 7-Eleven / Lawson / FamilyMart / etc. → webhook flips status to `CONFIRMED` → service runs → seller marks work done → buyer confirms (or 7-day auto-complete) → `COMPLETED`. There is **no capture step** because the funds are already in escrow — for konbini, `CONFIRMED` → `COMPLETED` is a **confirmation / payout-release gate** that releases the seller payout via Stripe Connect and unlocks reviews. (For card, the same transition is also the capture event.)
- Konbini constraints: JPY only, ¥120–¥300,000, voucher expires 24h after issue. If the voucher expires unpaid, the booking auto-cancels and the slot is freed; both sides are notified.
- Modifications are locked once a konbini voucher is issued (`AWAITING_PAYMENT`) until the voucher is paid or expires — this prevents the buyer from being asked to make a second konbini payment.
- Platform commission deducted from seller payout (same `application_fee_amount` model regardless of payment method or pricing type).
- Seller payout dashboard with earnings history.
- Refund and dispute handling.
- Stripe Connect and payout settings live on the seller account, not the profile. All of a seller's profiles share one payout destination.

### 8. Ratings & Reviews
- Buyer rates and reviews the profile after service completion (reviews attach to `profile_id`, not the seller account)
- Seller rates the buyer after service completion
- Aggregate rating is computed and displayed per profile
- Account-level trust signals (e.g., "verified seller since X, N total bookings across all profiles") are deferred to v2 — flagged for product owner review

### 9. Favorites (Buyer)
- A buyer can **favorite** a seller profile from the browse list or profile page (the heart icon on a profile card).
- Favorites are **profile-scoped**, not account-scoped — favoriting Tanaka's photographer profile does not favorite his videographer profile. This is consistent with ADR 0001 (profile is the commercial unit).
- The full list of favorited profiles is reachable from the buyer's "My Page" → "My favorites" screen.
- Soft-deleted or deactivated profiles remain in the underlying favorites table but are filtered out of the favorites list view (sellers can re-activate without losing existing favorites).
- v1 favorites are a binary heart only — no tags, notes, or folders.

### 10. Admin Panel (Web)
- User management (buyers, sellers, and profiles — e.g., suspending a profile without suspending the account)
- **Seller profile management — slice 1 (read + edit profile fields).** Admins can list every seller in the system (paginated, filterable by email / display name / status), drill into a seller to see all of that seller's profiles, and edit any profile's editable fields — `headline`, `bio`, `photoUrl`, `description`, `pricingType`, `hourlyRate`, `isNationwide`, and **`status`** (toggling `ACTIVE | INACTIVE` is how an admin suspends a single profile without touching the seller account or its other profiles). Reads reuse `SellerProfileResponseDto`; writes reuse `UpdateSellerProfileBodyDto`. Portfolio items, packages, and package variants are **read-only in slice 1** — admins see them on the profile detail page but cannot mutate them yet; portfolio moderation actions (delete a single item) ship as slice 2 once the endpoint contract is approved.
- Service category management
- Booking and transaction oversight
- Dispute resolution
- Platform analytics dashboard

---

## Non-Functional Requirements

- **Scalability:** Backend must support horizontal scaling for growing user base
- **Security:** End-to-end encryption for messages, PCI-compliant payment handling, secure authentication (JWT + refresh tokens)
- **Performance:** API response times under 200ms for standard operations; real-time features via WebSockets
- **Availability:** 99.9% uptime target
- **Localization (buyer app, MVP):** Buyer-facing apps ship in **all four supported languages on MVP** — Japanese, English, Simplified Chinese, Traditional Chinese — to serve the foreign-traveler launch segment. Device language auto-detection with Japanese fallback. Dates: `YYYY年MM月DD日`, 24-hour time, ¥ JPY currency. Chat auto-translation and server-side localised push are already in place and used end-to-end. Multi-currency stays deferred to a future phase (the launch buyer sees JPY only).
- **Localization (seller app, deferred):** Seller-facing surfaces remain **Japanese-first** in MVP since sellers are local. Multi-language seller surfaces are deferred to a future phase.

---

## Technical Architecture (High Level)

```
Monorepo
├── apps/
│   ├── api/                  # NestJS backend (REST + WebSocket)
│   ├── web-buyer/            # Web app — buyer side
│   ├── web-seller/           # Web app — seller side
│   ├── ios/                  # Single SwiftUI app, both buyer + seller surfaces (ADR 0011)
│   ├── mobile-buyer/         # Android — buyer (consolidation TBD)
│   └── mobile-seller/        # Android — seller (consolidation TBD)
├── libs/
│   ├── shared/               # Shared types, DTOs, utilities
│   ├── ui/                   # Shared UI components (web)
│   └── mobile-ui/            # Shared UI components (mobile)
└── infrastructure/           # Docker, CI/CD, deployment configs
```

The iOS app uses a `RoleManager` (`@Observable`) to track which surface — buyer or seller — is active for the signed-in user, persisted in `UserDefaults`. A `RoleRootView` branches on `RoleManager.activeRole` and swaps in either the buyer `MainTabView` (5 tabs) or the seller `SellerMainTabView` (4 tabs). The same `Client` (generated OpenAPI client), `AuthState`, `LocalizationManager`, and FCM token are shared across both surfaces; cross-role inbox isolation is enforced in `ConversationsViewModel.scope` so the seller Messages tab never shows buyer threads (and vice versa). See ADR 0011.

---

## MVP Scope (Phase 1)

Launch with two adjacent service categories — **photographer** and **videographer** — anchored on foreign travelers visiting Japan plus domestic couples / event hosts. See ADR 0007 for the rationale on launching with two categories rather than nesting videography under photography.

1. Buyer and seller registration/authentication
2. Seller profile creation (one profile per category; a seller may create additional profiles for additional categories) with `pricing_type` selection — `SESSION` (default) or `HOURLY` per ADR 0004. For `SESSION`, the seller creates one or more packages, each tagged to a **sub-category** (`旅拍`, `写真`, `毕业`, `家庭親子`, `活動`, `婚紗情侣`, `商業`, etc.) and carrying one or more priced variants
3. **Category taxonomy:** two-level (Category → Sub-category), seeded for **Photographer** (Travel Portrait, Portrait, Wedding & Couples, Graduation, Family, Event, Commercial) and **Videographer** (Wedding Film, Event Film, Travel Film, Portrait Film, Music Video, Brand & Commercial) on launch. `job_subcategories` is a child table of `job_categories`. Sub-category is a first-class search/filter dimension and is NOT NULL on every package
4. **Portfolio** — project-based model per ADR 0009. Each portfolio is 0..N Projects; each Project owns 1..N MediaItems (IMAGE / VIDEO / PDF). Two upload flows (Add a Project, Add a Photo) feed the same data shape. Two display layouts (Projects, Grid) on the public profile, seller-toggleable. Multilingual project title/description (JA, EN, ZH_CN, ZH_TW; manual authoring, no auto-translation in v1). Sub-category + package tags at the project level. See §3.
5. Buyer search and discovery (visual-first list + secondary map view), profile-scoped — primary discovery routes are portfolio-led browse, area-name / landmark search, and current location; postal-code lookup retained as a secondary affordance and primary seller-side service-area tool
6. Booking lifecycle: request → accept/decline → `CONFIRMED` → seller hits **Mark work done** (`seller_marked_done_at` timestamp; status stays `CONFIRMED`) → buyer confirms (or 7-day auto-complete) → `COMPLETED`. `BookingStatus` enum is unchanged; the "work-done, awaiting-buyer" sub-state lives on the timestamp. Supports both `PACKAGE` and `HOURLY` `pricing_mode`.
7. Bilateral modification proposals (pre- and post-accept); for PACKAGE bookings these can change start time, variant within the package, package on the same profile, and add **extension hours** at the profile's `hourly_extension_rate` for overtime (ADR 0004 / 0005)
8. In-app messaging (per booking; auto-translation already in place)
9. Payment processing (Stripe — **card primary** for the launch traveler buyer, konbini retained for domestic — see §7); card captures at completion (buyer-confirm or 7-day auto-complete)
10. Ratings and reviews (attached to `profile_id`)
11. Buyer favorites (profile-scoped heart + "My favorites" list)
12. Push notifications (incl. work-done and completion events, localised server-side per recipient's `users.language`)
13. **Buyer-app localisation** in JA, EN, ZH_CN, ZH_TW; seller-app Japanese-first
14. Basic admin panel
15. v1 constraint: one profile per category per seller (`@@unique(seller_id, category_id)`)

> **v1 implementation scope-cut.** The Package + Variant **schema** ships in v1 (the buyer app reads it, the API exposes it, the OpenAPI surface is final). The **seller UI** ships with a single-variant package editor — sellers create one package per offer with exactly one variant per package. A multi-variant editor (drag-to-reorder, format/group-size pickers) is a fast-follow PR. This lets schema and API stabilise without blocking on the editor work; multi-variant data is admin-creatable in the meantime.

### Out of Scope for MVP
- Recurring bookings
- **Multi-variant package editor in the seller UI** — schema and API support multi-variant from day one; the seller-side UI to create/edit multiple variants per package is a fast-follow PR after launch
- **Multi-currency** — buyer-side displays JPY only; multi-currency deferred to a future phase
- **Multi-language on the seller app** — seller surfaces are Japanese-first in MVP; multi-language seller UI deferred
- **In-app PDF rendering** — PDFs in the portfolio ship as downloadable attachments with a static thumbnail in v1; the native reader is a v2 line item (ADR 0009 / §3)
- **Auto-translation of project titles/descriptions** — sellers author each language they support manually in v1 (ADR 0009 / §3)
- **Portfolio nested sub-albums** — projects are the album equivalent; nested sub-albums within a project are not in v1 (ADR 0009 / §3)
- **Portfolio project analytics** — view counts, likes, save-for-later on projects are out of scope
- **Reverse-geocoding** for "current location" discovery — placeholder button in v1
- **Landmark search data source** — typeahead against curated landmark→areaId table is in scope only if a usable data source is settled in time; otherwise area-name (prefecture / municipality) search ships alone
- Advanced analytics
- Seller identity verification (manual review only)
- Promotional features (featured listings, ads)
- Multiple profiles in the same category for one seller (e.g., separate "wedding photography" and "corporate photography" profiles) — deferred to a future version
- Account-level trust badges aggregating across profiles — deferred to v2 pending product owner review

---

## Success Metrics

Phase 1 metrics are organised around the **traveler funnel** (buyer-side acquisition → booking → completion) and the **supply side** (seller activation), with platform-level financials underneath. Several specifics below are pending product-owner review.

**Traveler-buyer funnel (demand side):**
- **Traveler-buyer acquisition** — weekly traveler buyers (foreign-traveler-segment buyers landing on the app from inbound channels). The exact attribution model is pending product-owner review; minimally, app installs and first-session-by-locale are tracked.
- **Buyer-to-booking conversion** — share of traveler buyers who reach a `CONFIRMED` booking.
- **Booking completion rate** — share of `CONFIRMED` bookings that reach `COMPLETED`. Drops here are a post-shoot signal — sellers failing to mark work done, buyers disputing the result, or auto-complete leaning too heavy.
- **Average rating per booking** (unchanged).

**Supply side:**
- **Seller activation** — see note below. *Proposed (pending product owner review):* split into two metrics — *active accounts* (sellers with at least one published profile, supply-side acquisition signal) and *active profiles* (published profile count, listing density signal). Under the account/profile model these diverge: a single seller publishing three profiles boosts profile count but not account count. A single metric conflates the two.

**Platform:**
- Number of completed bookings per week.
- Platform revenue (commission collected).

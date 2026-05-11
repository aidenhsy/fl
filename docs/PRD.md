# Freelance Services Marketplace — Product Requirement Document

## Overview

A two-sided marketplace platform connecting **buyers** (clients seeking services) and **sellers** (freelance service providers) across categories like personal training, personal driving, tutoring, cleaning, and more. The platform operates similarly to Uber's model — separate experiences for each side, with real-time matching, booking, and payment.

## Platforms

| Platform | Buyer App | Seller App |
|----------|-----------|------------|
| iOS      | Yes       | Yes        |
| Android  | Yes       | Yes        |
| Web      | Yes       | Yes        |

**Backend:** NestJS monorepo serving all platforms via shared APIs.

---

## User Roles

### Buyer (Client)
A person looking to hire a freelance service provider for a specific task or ongoing engagement.

### Seller (Provider)
A freelance professional offering their services through the platform. A seller **account** holds one or more **profiles**, each scoped to a single category (see Glossary).

### Admin
Platform operators who manage users, disputes, categories, and platform settings.

---

## Glossary

### Account
A seller's identity on the platform. Holds authentication, KYC / identity verification, Stripe Connect / payout details, contact information, and the **availability calendar** (one calendar per account, shared across all of the seller's profiles — see ADR 0003). One person = one account.

The seller account row is created **implicitly** on the user's first seller-only action — creating their first profile, or submitting a custom job request. There is no separate "become a seller" step. From the user's perspective, signing up and finishing the first-profile funnel is one continuous flow; the account/profile distinction is a server-side concept that becomes visible only when they go to add a second profile.

### Profile
A sellable persona scoped to exactly one category. Owns its own headline, bio, portfolio media, **hourly rate**, slug (used in discovery URLs), and reviews. A seller account holds 1..N profiles. Availability is **account-scoped, not profile-scoped** — see ADR 0003.

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
- Role selection during onboarding (buyer or seller)
- Seller onboarding: account creation (auth + identity verification) → first profile created in a single funnel (category single-select, headline, bio, portfolio, **hourly rate**) → set up the **account-level availability calendar** (shared across all future profiles too) → land on a profile list with a "Create another profile" CTA for additional categories

### 2. Seller Profiles

A seller account holds one or more profiles. Each profile is scoped to a single category and is the unit buyers discover, book, and review.

- Each profile owns:
  - Category (e.g., personal trainer, driver, tutor) — exactly one per profile
  - Headline and bio
  - **Hourly rate** (the only pricing model in v1 — see ADR 0003)
  - Service area / location radius
  - Portfolio or certifications (optional, per-profile media)
  - Slug (used in discovery URLs)
  - Reviews and aggregate rating
- A seller may create additional profiles for additional categories (e.g., one driver profile and one photographer profile under the same account).
- Account-level fields (auth, KYC, Stripe Connect / payout, contact, **availability calendar**) are shared across all of a seller's profiles. Availability lives on the account because the seller is one human — a slot claimed through any profile blocks the same hour on every other profile of the same seller (see ADR 0003).

### 3. Search & Discovery (Buyer)
- Browse by service category
- Filter by location, price range, rating, availability
- Map view showing nearby available profiles
- Recommended / featured profiles
- A seller with profiles in multiple categories appears as one card per profile. A buyer searching for photographers does not see that seller's driver profile, and vice versa — discovery is profile-scoped, not account-scoped.

### 4. Booking & Scheduling
- The seller publishes **availability windows** on a single account-level calendar (e.g., `Fri 2026-02-12 15:00–17:00`). Each window splits into fixed 1-hour **slots** aligned to the window's start.
- Buyers book against a specific profile, but slots are drawn from the seller's account-level calendar. A slot held or booked through any profile becomes unavailable on every other profile of the same seller (see ADR 0003).
- A booking request is one or more **contiguous** 1-hour slots within a single window. A 3-hour window can be sold as one 3-hour booking, three 1-hour bookings, or any contiguous combination.
- **Initial booking flow is request → accept/decline.** The buyer submits a request for the chosen slots and (optionally) a message. On submission the slots enter a **hold** state — they no longer show as available to other buyers, on any profile of the same seller.
- The seller has **12 hours** to accept or decline. On accept, payment is captured and the slots become a confirmed booking. On decline or timeout, the hold is released and the slots return to availability.
- **The buyer may withdraw their pending request at any time before the seller responds.** Withdrawal immediately releases the held slots back to availability. (Applies symmetrically across the system: the originator of any pending request/proposal can withdraw it while it is awaiting the counterparty's response.)
- Hold creation is **first-come-first-served and atomic** — if two buyers request the same slot simultaneously, exactly one acquires the hold; the other sees "slot just taken". This prevents overbooking at the request layer.
- Total price = booked profile's hourly rate × number of slots. Price is shown at request time and captured on accept.

**Bilateral modification proposals.** During the 12h accept window *and* after a booking is confirmed, the engagement may need to change — e.g., during a chat the seller realises a 1-hour cleaning won't be enough and proposes 3 hours instead, or counters a pending request with a different start time before accepting. Either party (buyer or seller) can propose a modification:
- A modification can change the **time** and/or **duration** of the booking. The new slots must not already be booked or held by anyone else (the no-overbooking constraint is enforced on every proposal). **Buyer-initiated** proposals additionally must fall inside a published availability window — the buyer can't demand times the seller hasn't said they're free for. **Seller-initiated** proposals skip that window check: the seller proposing a new time is itself the availability signal, so they don't have to first publish a window and then propose against it.
- On submission, any **net-new slots** in the proposal enter the same hold state as a fresh request, blocking the seller's calendar across all profiles. Original slots remain in their current state — HELD if the booking is still INCOMING, BOOKED if already confirmed — until the proposal resolves.
- The counterparty has **12 hours** to approve or reject. On approval, the booking's slot set is replaced with the proposed set (released slots return to availability, new slots take the booking's current state — HELD if still INCOMING, BOOKED if already confirmed), and any price delta is captured (extension) or refunded (shortening). Approving a modification is a terms change, not an accept; an INCOMING booking stays INCOMING after approval and the seller still has to accept or decline it. On rejection or timeout, the held delta is released and the booking reverts to its original slots — no charge.
- Pricing on a modification uses the booking's **original captured hourly rate**, not the seller's current rate (so a seller raising their listed rate after the booking does not retroactively reprice).
- **The originator may withdraw the proposal at any time before the counterparty responds**, immediately releasing the delta hold and leaving the original booking intact. Either side can be the originator, so this withdrawal right applies bilaterally.

Calendar export (`.ics`, Google Calendar sync) is deferred post-MVP.

### 5. Real-Time Features
- In-app messaging between buyer and seller, scoped per (buyer, seller profile) — each thread is anchored to one profile/category, so a buyer who engages two profiles of the same seller has two distinct threads (see ADR 0002).
- Push notifications for booking requests, confirmations, reminders, and messages
- Live status updates on active bookings (e.g., "provider en route", "session started", "completed")

### 6. Payments
- In-app payment processing (Stripe or equivalent)
- Buyer pays upon booking confirmation or after service completion (configurable per category)
- Platform commission deducted from seller payout
- Seller payout dashboard with earnings history
- Refund and dispute handling
- Stripe Connect and payout settings live on the seller account, not the profile. All of a seller's profiles share one payout destination.

### 7. Ratings & Reviews
- Buyer rates and reviews the profile after service completion (reviews attach to `profile_id`, not the seller account)
- Seller rates the buyer after service completion
- Aggregate rating is computed and displayed per profile
- Account-level trust signals (e.g., "verified seller since X, N total bookings across all profiles") are deferred to v2 — flagged for product owner review

### 8. Favorites (Buyer)
- A buyer can **favorite** a seller profile from the browse list or profile page (the heart icon on a profile card).
- Favorites are **profile-scoped**, not account-scoped — favoriting Tanaka's photographer profile does not favorite his driver profile. This is consistent with ADR 0001 (profile is the commercial unit).
- The full list of favorited profiles is reachable from the buyer's "My Page" → "My favorites" screen.
- Soft-deleted or deactivated profiles remain in the underlying favorites table but are filtered out of the favorites list view (sellers can re-activate without losing existing favorites).
- v1 favorites are a binary heart only — no tags, notes, or folders.

### 9. Admin Panel (Web)
- User management (buyers, sellers, and profiles — e.g., suspending a profile without suspending the account)
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
- **Localization:** Support for multiple languages and currencies (future phase)

---

## Technical Architecture (High Level)

```
Monorepo
├── apps/
│   ├── api/                  # NestJS backend (REST + WebSocket)
│   ├── web-buyer/            # Web app — buyer side
│   ├── web-seller/           # Web app — seller side
│   ├── mobile-buyer/         # React Native or Flutter — buyer
│   └── mobile-seller/        # React Native or Flutter — seller
├── libs/
│   ├── shared/               # Shared types, DTOs, utilities
│   ├── ui/                   # Shared UI components (web)
│   └── mobile-ui/            # Shared UI components (mobile)
└── infrastructure/           # Docker, CI/CD, deployment configs
```

---

## MVP Scope (Phase 1)

Focus on launching with a single service category (e.g., personal training) to validate the model.

1. Buyer and seller registration/authentication
2. Seller profile creation (one profile per category; a seller may create additional profiles for additional categories)
3. Buyer search and discovery (list + map view), profile-scoped
4. Booking request and acceptance flow
5. In-app messaging (per booking)
6. Payment processing (Stripe)
7. Ratings and reviews (attached to `profile_id`)
8. Buyer favorites (profile-scoped heart + "My favorites" list)
9. Push notifications
10. Basic admin panel
11. v1 constraint: one profile per category per seller (`@@unique(seller_id, category_id)`)

### Out of Scope for MVP
- Recurring bookings
- **Per-day and per-session rate types** — v1 is hourly only (see ADR 0003)
- Multi-language / multi-currency
- Advanced analytics
- Seller identity verification (manual review only)
- Promotional features (featured listings, ads)
- Multiple profiles in the same category for one seller (e.g., separate "wedding photography" and "corporate photography" profiles) — deferred to a future version
- Account-level trust badges aggregating across profiles — deferred to v2 pending product owner review

---

## Success Metrics

- Number of completed bookings per week
- Buyer-to-booking conversion rate
- Seller activation rate (listed at least one service)
- Average rating per booking
- Platform revenue (commission collected)

> **Proposed (pending product owner review):** Split "seller activation rate" into two metrics — *active accounts* (sellers with at least one published profile, supply-side acquisition signal) and *active profiles* (published profile count, listing density signal). Under the account/profile model these diverge: a single seller publishing three profiles boosts profile count but not account count. The current single metric conflates the two.

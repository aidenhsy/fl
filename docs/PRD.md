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
A seller's identity on the platform. Holds authentication, KYC / identity verification, Stripe Connect / payout details, and contact information. One person = one account.

The seller account row is created **implicitly** on the user's first seller-only action — creating their first profile, or submitting a custom job request. There is no separate "become a seller" step. From the user's perspective, signing up and finishing the first-profile funnel is one continuous flow; the account/profile distinction is a server-side concept that becomes visible only when they go to add a second profile.

### Profile
A sellable persona scoped to exactly one category. Owns its own headline, bio, portfolio media, pricing, availability, slug (used in discovery URLs), and reviews. A seller account holds 1..N profiles.

Profile slugs are globally unique across the platform.

In v1, a seller may have at most one profile per category. Multiple profiles in the same category (e.g., "wedding photography" vs "corporate photography") is deferred.

---

## Core Features

### 1. Authentication & Onboarding
- Email/password and social login (Google, Apple)
- Phone number verification via OTP
- Role selection during onboarding (buyer or seller)
- Seller onboarding: account creation (auth + identity verification) → first profile created in a single funnel (category single-select, headline, bio, portfolio, rate, availability) → land on a profile list with a "Create another profile" CTA for additional categories

### 2. Seller Profiles

A seller account holds one or more profiles. Each profile is scoped to a single category and is the unit buyers discover, book, and review.

- Each profile owns:
  - Category (e.g., personal trainer, driver, tutor) — exactly one per profile
  - Headline and bio
  - Pricing (hourly, flat rate, or custom)
  - Availability schedule
  - Service area / location radius
  - Portfolio or certifications (optional, per-profile media)
  - Slug (used in discovery URLs)
  - Reviews and aggregate rating
- A seller may create additional profiles for additional categories (e.g., one driver profile and one photographer profile under the same account).
- Account-level fields (auth, KYC, Stripe Connect / payout, contact) are shared across all of a seller's profiles.

### 3. Search & Discovery (Buyer)
- Browse by service category
- Filter by location, price range, rating, availability
- Map view showing nearby available profiles
- Recommended / featured profiles
- A seller with profiles in multiple categories appears as one card per profile. A buyer searching for photographers does not see that seller's driver profile, and vice versa — discovery is profile-scoped, not account-scoped.

### 4. Booking & Scheduling
- Buyers book against a specific profile; a seller's separate profiles have independent booking calendars.
- Buyer requests a booking with preferred date/time
- Seller accepts or declines the request
- Instant booking option for sellers who opt in
- Calendar integration for scheduling

### 5. Real-Time Features
- In-app messaging between buyer and seller (per booking)
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

### 8. Admin Panel (Web)
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
8. Push notifications
9. Basic admin panel
10. v1 constraint: one profile per category per seller (`@@unique(seller_id, category_id)`)

### Out of Scope for MVP
- Recurring bookings
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

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
A freelance professional offering their services through the platform.

### Admin
Platform operators who manage users, disputes, categories, and platform settings.

---

## Core Features

### 1. Authentication & Onboarding
- Email/password and social login (Google, Apple)
- Phone number verification via OTP
- Role selection during onboarding (buyer or seller)
- Seller onboarding includes: profile setup, service category selection, availability, rate setting, and identity verification

### 2. Seller Profile & Service Listing
- Profile with photo, bio, ratings, and reviews
- One or more service listings per seller, each with:
  - Category (e.g., personal trainer, driver, tutor)
  - Description
  - Pricing (hourly, flat rate, or custom)
  - Availability schedule
  - Service area / location radius
- Portfolio or certifications upload (optional)

### 3. Search & Discovery (Buyer)
- Browse by service category
- Filter by location, price range, rating, availability
- Map view showing nearby available sellers
- Recommended / featured sellers

### 4. Booking & Scheduling
- Buyer requests a booking with preferred date/time
- Seller accepts or declines the request
- Instant booking option for sellers who opt in
- Calendar integration for scheduling
- Recurring booking support

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

### 7. Ratings & Reviews
- Buyer rates and reviews the seller after service completion
- Seller rates the buyer after service completion
- Aggregate rating displayed on profiles

### 8. Admin Panel (Web)
- User management (buyers, sellers)
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
2. Seller profile and service listing creation
3. Buyer search and discovery (list + map view)
4. Booking request and acceptance flow
5. In-app messaging (per booking)
6. Payment processing (Stripe)
7. Ratings and reviews
8. Push notifications
9. Basic admin panel

### Out of Scope for MVP
- Recurring bookings
- Multi-language / multi-currency
- Advanced analytics
- Seller identity verification (manual review only)
- Promotional features (featured listings, ads)

---

## Success Metrics

- Number of completed bookings per week
- Buyer-to-booking conversion rate
- Seller activation rate (listed at least one service)
- Average rating per booking
- Platform revenue (commission collected)

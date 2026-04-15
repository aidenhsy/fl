# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Two-sided freelance services marketplace (similar to Uber's model) connecting buyers (clients) with sellers (freelance providers) across categories like personal training, driving, tutoring, cleaning, etc. The platform targets the Japanese market primarily, with support for English and Chinese (Simplified/Traditional).

## Planned Architecture

Monorepo structure:

```
apps/
├── api/                  # NestJS backend (REST + WebSocket)
├── web-buyer/            # Web app — buyer side
├── web-seller/           # Web app — seller side
├── mobile-buyer/         # React Native or Flutter — buyer
└── mobile-seller/        # React Native or Flutter — seller
libs/
├── shared/               # Shared types, DTOs, utilities
├── ui/                   # Shared UI components (web)
└── mobile-ui/            # Shared UI components (mobile)
infrastructure/           # Docker, CI/CD, deployment configs
```

## Key Design Decisions

- **Backend**: NestJS monorepo serving all platforms via shared APIs
- **Real-time**: WebSockets for messaging and live booking status updates
- **Payments**: Stripe (buyer-side) / Bank transfer via Stripe Connect (seller payouts, standard in Japan)
- **Auth**: Social login (Google, Apple, LINE, WeChat) — no email/password on seller mobile. JWT + refresh tokens.
- **Localization**: Japanese (default), English, zh-CN, zh-TW. Device language auto-detection with Japanese fallback. Dates: `YYYY年MM月DD日`, 24-hour time, ¥ JPY currency.
- **Seller onboarding**: Sellers can request custom job categories not in the default list; these require admin approval before the seller can receive requests in that category.
- **Service areas**: Three granularity levels — Nationwide (remote work), Prefecture, Municipality (hyper-local).

## User Roles

- **Buyer (Client)**: Searches for services, books sellers, pays via in-app payment
- **Seller (Provider)**: Lists services, accepts/declines bookings, receives payouts
- **Admin**: Manages users, categories, disputes, platform settings (web-only panel, no public sign-up)

## MVP Scope (Phase 1)

Single service category to validate the model. Includes: auth, profiles, search/discovery (list + map), booking flow, in-app messaging, Stripe payments, ratings/reviews, push notifications, basic admin panel.

**Out of scope for MVP**: recurring bookings, multi-currency, advanced analytics, automated identity verification, promotional features.

## Documentation

- `docs/PRD.md` — Full product requirements document
- `docs/ui-flows/client/` — Buyer UI flows (web + mobile)
- `docs/ui-flows/seller/` — Seller UI flows (web + mobile)
- `docs/ui-flows/admin/` — Admin panel UI flows (web only)

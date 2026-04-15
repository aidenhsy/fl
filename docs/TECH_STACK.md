# Tech Stack

> Living document — last updated 2026-04-13

---

## Backend

| Layer | Choice | Notes |
|---|---|---|
| Runtime | Node.js (LTS) | |
| Framework | NestJS | Single monolithic service — MVP-first; decompose only when proven necessary |
| ORM | Prisma (schema-first) | Migrations via `prisma migrate` |
| Database | Cloud SQL for PostgreSQL 17 | GCP-managed; automated backups, HA optional |
| Auth | JWT (access + refresh) | OAuth via Google, Apple, LINE, WeChat |
| Validation | class-validator + class-transformer | NestJS pipes |
| API style | REST | Documented via Swagger (`@nestjs/swagger`); OpenAPI JSON spec generated for all endpoints |
| Real-time | WebSockets via `@nestjs/websockets` + Socket.IO | Chat; same NestJS process, shares auth/services — split to dedicated gateway later if needed |
| File storage | Google Cloud Storage (GCS) | Signed URLs for client uploads/downloads |
| Payments | Stripe Connect | Client pays → platform splits → seller payout to bank account |
| Transactional email | Resend | Job confirmations, payout receipts, account emails; triggered via RabbitMQ jobs |
| Queue | RabbitMQ | Background jobs, email, push notifications |
| Caching | Redis | Session, rate-limiting, ephemeral data |
| Testing | Jest + Supertest | Unit + e2e |

---

## Web — Client & Seller

| Layer | Choice | Notes |
|---|---|---|
| Framework | Next.js (App Router) | Primarily client-side rendering; server components only where beneficial |
| Language | TypeScript (strict) | |
| Styling / Component lib | Ant Design (antd) | Built-in design system, form controls, tables, layout |
| State | Zustand | Lightweight; React Query handles server state |
| Data fetching | TanStack Query (React Query) | Caching, optimistic updates, background refetch |
| Real-time | socket.io-client | Chat; connects to NestJS WebSocket gateway |
| Forms | Ant Design Form + Zod | Zod for validation schemas; shareable with backend |
| Testing | Vitest + Playwright | Unit + e2e |

---

## Web — Admin

| Layer | Choice | Notes |
|---|---|---|
| Framework | Next.js (App Router) | Same stack as client/seller for code sharing |
| Component lib | Ant Design (antd) | Consistent with other web apps |
| Tables / data grids | Ant Design Table + ProTable | Sorting, filtering, pagination built-in |

> Admin shares the same core stack as client/seller. Only notable additions are listed above.

---

## Android — Client & Seller

| Layer | Choice | Notes |
|---|---|---|
| UI | Jetpack Compose | |
| Design system | Material 3 (Compose Material 3) | Dynamic color support |
| Language | Kotlin | |
| Architecture | MVVM + Clean Architecture | ViewModel → UseCase → Repository |
| DI | Hilt | |
| Networking | Retrofit + OkHttp | |
| Real-time | socket.io-client-java | Chat |
| Serialization | Kotlinx Serialization | Preferred over Gson/Moshi for multiplatform alignment |
| Image loading | Coil (Compose) | |
| Maps | Google Maps SDK for Android (Compose) | Job location preview, service area picker |
| Navigation | Compose Navigation | Type-safe routes |
| Local storage | DataStore (Preferences) | Room if offline-first features are needed later |
| Testing | JUnit 5 + Compose UI testing | |

---

## iOS — Client & Seller

| Layer | Choice | Notes |
|---|---|---|
| UI | SwiftUI | iOS 16+ minimum target |
| Language | Swift 5.9+ | |
| Architecture | MVVM | ObservableObject / @Observable (iOS 17) |
| Networking | URLSession + async/await | Alamofire only if complex interceptors are needed |
| Real-time | Socket.IO-Client-Swift | Chat |
| Serialization | Codable | |
| Image loading | SwiftUI AsyncImage + Kingfisher for caching | |
| Maps | Google Maps SDK for iOS | Job location preview, service area picker |
| DI | Swift Package — manual / Factory | Keep lightweight |
| Local storage | Keychain + UserDefaults | Auth tokens in Keychain; small preferences in UserDefaults |
| Testing | XCTest + Swift Testing | |

---

## Shared / Cross-cutting

| Concern | Choice | Notes |
|---|---|---|
| Repo strategy | Separate repos per app | `fl-api`, `fl-seller-ios`, `fl-admin-web`, etc. |
| API contract | OpenAPI spec generated from NestJS (`@nestjs/swagger`) | All endpoints documented; each client generates types from the spec |
| Payments | Stripe Connect | Marketplace split payments, seller KYC, bank payouts |
| Transactional email | Resend | TypeScript SDK; React Email templates for web |
| Auth providers | Google, Apple, LINE, WeChat | LINE is priority for Japan market |
| Push notifications | Firebase Cloud Messaging (Android + iOS) | |
| Maps | Google Maps Platform | Geocoding, static maps, Places API |
| Analytics | PostHog | Self-hostable, privacy-friendly |
| Error tracking | Sentry | All platforms |
| CI/CD | GitHub Actions | Lint → test → build → deploy to server via SSH |
| Containerisation | Docker + Docker Compose | All services (API, RabbitMQ, Redis) composed together |
| Hosting | Single GCE instance (or bare-metal) | Docker Compose in production; scale to GKE when needed |
| Cloud platform | Google Cloud | Cloud SQL, GCS, GCE, Artifact Registry |

---

## Decisions Deferred

| Topic | Status |
|---|---|
| Service decomposition | Single NestJS service for MVP — revisit when clear bounded contexts or scaling bottlenecks emerge |
| KMP (Kotlin Multiplatform) | Evaluate if Android + iOS share significant business logic |
| Chat gateway extraction | If WS connections saturate the single process, extract chat into a dedicated NestJS gateway service |
| GKE migration | Move from single-server Docker Compose to GKE when traffic/reliability demands it |
| CDN | Cloud CDN in front of GCS / web apps when traffic justifies it |
| PayPay payments | Stripe supports PayPay — enable when client payment flow is built |
| Konbini payments | Convenience store payments via Stripe — add post-MVP for users without credit cards |

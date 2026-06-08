# Admin API — Slice 1 (read + edit seller profiles)

Endpoint contract for the first wave of admin-scoped endpoints in fl-api. Scope per PRD §10 "Seller profile management — slice 1":

- List every seller in the system + drill into one seller's profiles.
- Read any single seller profile (including its portfolio items, packages, and variants — read-only).
- Edit the editable fields of any seller profile, including `status` (suspend / un-suspend a single profile).

Portfolio / package / variant **writes** are explicitly out of slice 1 (they ship as slice 2 once this contract is approved and implemented).

This doc is the source of truth for fl-api implementation and for fl-admin client consumption. Update it in the same PR that implements an endpoint; openapi.yaml is regenerated from fl-api code, but DTO/behavior decisions live here.

---

## 1. Module layout (fl-api)

Two new modules, both under `src/modules/`:

```
src/modules/admin-auth/
├── domain/
│   └── ports/
│       └── admin-allowlist.port.ts         ← interface: isAllowed(email): boolean
├── application/
│   └── use-cases/
│       ├── admin-google-login.use-case.ts
│       ├── admin-refresh-token.use-case.ts
│       ├── admin-logout.use-case.ts
│       └── get-admin-me.use-case.ts
├── infrastructure/
│   └── env-admin-allowlist.adapter.ts      ← reads ADMIN_ALLOWED_EMAILS env var
└── presentation/
    ├── controllers/admin-auth.controller.ts
    ├── dtos/                                ← reuse existing DTOs where possible
    └── guards/admin.guard.ts                ← rejects non-ADMIN tokens
└── admin-auth.module.ts

src/modules/admin-profiles/
├── application/
│   └── use-cases/
│       ├── list-admin-sellers.use-case.ts
│       ├── get-admin-seller.use-case.ts
│       ├── get-admin-profile.use-case.ts
│       └── update-admin-profile.use-case.ts
├── presentation/
│   ├── controllers/
│   │   ├── admin-sellers.controller.ts
│   │   └── admin-profiles.controller.ts
│   ├── dtos/                                ← list-response DTOs + seller-detail DTO
│   └── presenters/                          ← maps repo rows → response DTOs
└── admin-profiles.module.ts
```

Both modules apply `AdminGuard` at the controller level. `admin-profiles` reuses the existing `seller_profiles` Prisma repository for reads/writes — there is no separate "admin repository" because the row-level access rule is the same (an admin can act on any profile; the constraint sits at the route guard, not the data layer). Use cases live in `admin-profiles` so the layer separation is clean; thin wrappers around existing seller-profile use cases are fine when behavior is identical.

---

## 2. Schema changes

```prisma
model users {
  // ... existing fields ...
  /// Admin capability flag. Independent of buyer (client_profiles) and seller
  /// (sellers) capabilities — a single user can be any combination of the
  /// three. Set true by the admin login flow on successful allowlist match;
  /// reset to false by removing the email from ADMIN_ALLOWED_EMAILS and
  /// letting the AdminGuard's live DB check cut off subsequent requests
  /// (operators can also flip this directly via SQL).
  is_admin Boolean @default(false)

  // Reverse relation for the audit log.
  admin_audit_log admin_audit_log[]
}

/// Append-only audit trail of admin-initiated writes. Every admin-scoped
/// mutation (slice 1: profile updates) writes one row here. No UI surfaces
/// it in MVP, but the data is retained because history cannot be backfilled.
model admin_audit_log {
  id            String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  admin_user_id String   @db.Uuid
  /// Canonical action name (e.g. `UPDATE_SELLER_PROFILE`). Kept as a string
  /// rather than an enum so adding actions doesn't require a migration.
  action        String   @db.VarChar(64)
  /// Target entity type, e.g. `seller_profile`.
  target_type   String   @db.VarChar(64)
  /// Target entity id (uuid as text — different target types use different id types).
  target_id     String   @db.VarChar(64)
  /// JSON payload: for updates, `{ before: {...}, after: {...} }` of the changed fields only.
  changes       Json
  created_at    DateTime @default(now()) @db.Timestamptz(6)

  admin users @relation(fields: [admin_user_id], references: [id], onDelete: Restrict, onUpdate: NoAction)

  @@index([admin_user_id])
  @@index([target_type, target_id])
  @@index([created_at])
}
```

Migration name: `replace_user_role_with_is_admin`. Existing rows default to `is_admin = false`. Bootstrapping the first admin is simplest done by signing in via `POST /admin/auth/google` with an allowlisted email — the flow flips the bit. Ops can also pre-promote a user with `UPDATE users SET is_admin = true WHERE email = ...`.

The earlier slice-1 draft modelled this with a `Role` enum (`BUYER | SELLER | ADMIN`) on `users.role` and treated admin as exclusive. That was overcautious — see the Decisions log at the bottom of this doc. The migration drops the old `role` column + `Role` enum.

### Audit-log write rules

- Every admin-scoped **write** endpoint must record one `admin_audit_log` row in the same transaction as the mutation. If the audit insert fails, the mutation fails.
- The `changes` payload stores only the **changed** fields (compute the diff against the pre-update row), in the shape `{ before: { fieldA: oldA, ... }, after: { fieldA: newA, ... } }`. No-op updates (the patch made no field change) skip the audit row.
- Action names for slice 1: `UPDATE_SELLER_PROFILE` (the only admin write that exists today). Reads do not write audit rows.

---

## 3. Admin auth endpoints

All paths are mounted under `/admin/auth`. Responses use the existing `{ code, msg, data }` envelope (`setupSaihuSwagger` wraps automatically — no changes needed in controllers).

### `POST /admin/auth/google` — `operationId: adminAuthWithGoogle`

Verifies a Google ID token, gates by allowlist, returns JWT tokens.

**Request body** — reuse `GoogleLoginDto` (already exists for `/auth/google`).

**Behavior:**
1. Verify the Google ID token using the same verifier the mobile flow uses.
2. Pull the verified email from the token claims (must be present + `email_verified === true`).
3. If `!ADMIN_ALLOWED_EMAILS.includes(email)` → throw `ApplicationError.withCode('ADMIN_EMAIL_NOT_ALLOWED', ...)`.
4. Look up `users` by email:
   - **Exists** → upsert the (`GOOGLE`, `sub`) auth_account row for that user, set `is_admin = true` (no-op if already true), proceed. The user's existing buyer/seller capabilities are preserved.
   - **Does not exist** → create `users` row with `is_admin = true` + `email` + `language` (best-effort from token's `locale`, fallback `JA`) + an auth_account link.
5. Issue access + refresh tokens via the same `JwtService` the mobile flow uses. JWT payload includes `sub: user.id`, `role: 'ADMIN'` (this claim is the *fast path* used by `AdminGuard`; the slow path re-checks `users.is_admin` in the DB).
6. Persist refresh token (reuse `refresh_tokens` table).

**Response** — `200 AuthTokenResponseDto` (existing).

### `POST /admin/auth/refresh` — `operationId: adminRefreshToken`

Refresh-token rotation. Behavior identical to the existing mobile `/auth/refresh`, except it additionally verifies that the user behind the refresh token still has `is_admin = true` (so revocation = setting `is_admin = false` or removing the email from the allowlist + waiting for the next refresh). Reuse `RefreshTokenDto` request + `RefreshTokenResponseDto` response.

### `POST /admin/auth/logout` — `operationId: adminLogout`

Revokes the refresh token. Same body shape as `/auth/logout` (a `RefreshTokenDto`). Returns `204` on success. No content envelope.

### `GET /admin/auth/me` — `operationId: getAdminMe`

Returns the authenticated admin's identity. Guarded by `AdminGuard`.

**Response DTO** (new) — `AdminMeResponseDto`:

```ts
{
  id: string;          // users.id (uuid)
  email: string;       // verified Google email
  avatarUrl: string | null;
  language: 'JA' | 'EN' | 'ZH_CN' | 'ZH_TW';
  createdAt: string;   // ISO
}
```

No mobile equivalent exists (`AuthSellerAccountDto` / `AuthClientProfileDto` are role-specific). Admins are simple — one row in `users`, no relations to project.

---

## 4. Admin profile endpoints

All paths are mounted under `/admin` and guarded by `AdminGuard`.

### `GET /admin/sellers` — `operationId: listAdminSellers`

Paginated list of all users where `role = SELLER` (or alternative: every user that has a row in the `sellers` table — both are equivalent today since the seller relation 1:1 mirrors `role = SELLER` once that column lands).

**Query params:**

| Name | Type | Default | Notes |
|------|------|---------|-------|
| `page` | int ≥ 1 | `1` | Reuse `PageMetaDto` envelope on response. |
| `pageSize` | int 1..100 | `20` | |
| `q` | string | — | Optional. Substring match on `users.email`, `sellers.display_name` (case-insensitive). |
| `status` | `ANY \| HAS_ACTIVE_PROFILE \| ALL_INACTIVE` | `ANY` | Filters by aggregated profile status across the seller's profiles. |

**Response DTO** (new) — `ListAdminSellersResponseDto`:

```ts
{
  data: AdminSellerListItemDto[];
  meta: PageMetaDto;  // existing
}
```

`AdminSellerListItemDto` (new):

```ts
{
  sellerId: string;          // sellers.id (uuid)
  userId: string;
  email: string | null;
  displayName: string;       // sellers.display_name
  avatarUrl: string | null;
  profileCount: number;      // total seller_profiles owned
  activeProfileCount: number;
  createdAt: string;
}
```

### `GET /admin/sellers/{sellerId}` — `operationId: getAdminSeller`

Single seller's identity + the full list of that seller's profiles.

**Response DTO** (new) — `AdminSellerDetailDto`:

```ts
{
  sellerId: string;
  userId: string;
  email: string | null;
  displayName: string;
  avatarUrl: string | null;
  createdAt: string;
  profiles: SellerProfileResponseDto[];  // reuse existing
}
```

### `GET /admin/profiles/{profileId}` — `operationId: getAdminProfile`

Read a single profile in full, including portfolio + packages + variants (all read-only in slice 1).

**Response DTO** — reuse `PublicProfileResponseDto` if it covers the admin's needs (it nests `portfolioItems`), or add a thin `AdminProfileDetailDto` that wraps `SellerProfileResponseDto` and includes `portfolioItems: PortfolioItemResponseDto[]` + `packages: SellerPackageResponseDto[]`. Prefer the latter — `PublicProfileResponseDto` drops admin-relevant fields like `status` and `categoryId`.

`AdminProfileDetailDto` (new):

```ts
{
  profile: SellerProfileResponseDto;       // reuse
  portfolioItems: PortfolioItemResponseDto[];  // reuse, ordered by sort_order asc
  packages: SellerPackageResponseDto[];    // reuse, each carrying its variants
}
```

### `PATCH /admin/profiles/{profileId}` — `operationId: updateAdminProfile`

Update editable fields on any profile. **This is how an admin suspends a profile** — by sending `{ status: 'INACTIVE' }`.

**Request DTO** — reuse `UpdateSellerProfileBodyDto` exactly. The existing DTO already covers all editable fields including `status`. No new DTO needed.

**Response** — `200 SellerProfileResponseDto` (existing).

**Behavior:**
- The use case is a near-identical wrapper around `UpdateSellerProfileUseCase`, except it resolves the profile by id alone (no `sellerId === currentUser.id` check).
- Writes an `admin_audit_log` row with `action = 'UPDATE_SELLER_PROFILE'`, `target_type = 'seller_profile'`, `target_id = profileId`, and `changes = { before, after }` over the changed fields only. Mutation + audit insert happen in the same transaction — if the audit insert fails the profile update is rolled back. See §2 for the write rules.

---

## 5. AdminGuard

`AdminGuard` (Nest `CanActivate`) runs after the existing `JwtAuthGuard` and:

1. Reads the JWT payload from `request.user` (already populated by `JwtAuthGuard`).
2. Re-checks `payload.role === 'ADMIN'` — defence-in-depth fast path (the token claim) **and** queries `users.is_admin` (defence against stale tokens after demotion).
3. On mismatch → `ApplicationError.withCode('ADMIN_ROLE_REQUIRED', ...)`.

`AdminGuard` is composed at the controller level (`@UseGuards(JwtAuthGuard, AdminGuard)`) so individual routes can opt out only by *not* applying the guard — there is no public route on these controllers.

---

## 6. Environment

New env var:

```
ADMIN_ALLOWED_EMAILS=aiden@handi.example,ops@handi.example
```

- Comma-separated, lowercased on read.
- Empty / missing → admin login is fully disabled (returns 403 to every request). This is the safe default — fl-api comes up without admin access until ops sets the var.
- Domain matching (`@handi.example`) is **not** in slice 1; we can add a glob/domain syntax later if managing per-email becomes tedious.

---

## 7. Out of slice 1 (deferred)

- Portfolio item delete (`DELETE /admin/profiles/{profileId}/portfolio/{itemId}`) — needed for the "remove a policy-violating photo" use case. Lands as slice 2.
- Portfolio item edit (caption, sort order).
- Package + variant CRUD by admins.
- Seller account suspension (separate from per-profile suspension).
- Bulk operations.
- Admin role lifecycle UI (admins are managed via env var in MVP).
- An admin UI that surfaces `admin_audit_log` rows (the data is captured in slice 1; viewer ships later).

---

## 8. Open questions (resolve before implementation)

1. **Should `PATCH /admin/profiles/{id}` setting `INACTIVE` cancel/refund any in-flight bookings on that profile?** Current seller-side flow doesn't address this. Defer to a follow-up RFC, but flag during code review.
2. **Pagination cursor vs offset.** The contract above uses offset (`page`, `pageSize`) to match the existing `PageMetaDto` shape. If we expect more than ~10k sellers, a cursor would be more durable. Slice 1 launches will be well under that.

---

## Decisions log

- **2026-05-16** — Initial: admin and buyer/seller identities are disjoint (the 409 rule in §3). **Reversed later same day** — see next entry.
- **2026-05-16** — Confirmed: `admin_audit_log` ships in slice 1. Capturing history from day one; viewer UI is deferred.
- **2026-05-16** — Reversal: admin is an **additive capability**, not an exclusive role. Replaced `users.role` (enum) with `users.is_admin` (boolean). Motivation: Handi staff need to dogfood the buyer/seller apps with the same Google account, and the only thing the disjoint rule bought was a marginal account-takeover-isolation benefit. The new model: a `users` row independently carries `is_admin` (boolean), a `client_profiles` relation (buyer capability), and a `sellers` relation (seller capability) — all three are orthogonal. Admin login flow no longer rejects existing buyer/seller emails; it just flips `is_admin = true`.

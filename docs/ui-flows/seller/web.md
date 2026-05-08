# Web — Seller (Provider) UI Flows

## 1. Onboarding & Authentication

### 1.1 Seller Landing Page
- Hero: "Earn money offering your services"
- "Become a Provider" CTA button
- Benefits section (flexibility, reach, payments)
- "Log In" in nav bar

### 1.2 Sign Up Page
- Email input
- Password input
- "Continue with Google" / "Continue with Apple"
- "Continue" button → OTP verification

### 1.3 OTP Verification
- Phone number input
- 6-digit code entry
- Resend link

### 1.4 Provider Onboarding (Multi-step wizard)
**Step 1 — Profile**
- Profile photo upload
- Full name
- Bio / about you
- "Next" button

**Step 2 — Profile Setup (per category)**
- Select service category (single-select; one profile per category in v1)
- Headline
- Description
- **Hourly rate** (¥/hour) — single input. v1 is hourly-only; per-day and per-session rate types are deferred (see ADR 0003).
- Service area: map with draggable radius (per profile)
- "Next" button

**Step 3 — Availability Calendar (account-level)**
- Banner: "This calendar is shared across all of your profiles. A slot booked through one profile blocks the same hour on every other profile (see ADR 0003)."
- Window editor: pick a date and a start/end time (e.g., `Fri 2026-02-12 15:00–17:00`). Each window splits into fixed 1-hour slots aligned to the window's start.
- Calendar view of existing windows; click a window to remove or shorten (only slots that are not held or booked can be removed)
- "Next" button

**Step 4 — Verification**
- ID upload (drag & drop or file picker)
- Certifications upload (optional)
- "Submit for Review" button → Pending approval page

### 1.5 Log In Page
- Email + password fields
- "Forgot Password?" link
- Social login buttons

---

## 2. Dashboard

### 2.1 Dashboard Page
- Welcome banner with online/offline toggle
- Stats cards: today's earnings, this week, this month
- Today's schedule (timeline view)
- Pending booking requests (count + preview cards)
- Recent reviews snippet

---

## 3. Booking Management

### 3.1 Booking Requests Page
- Table of incoming requests, each with a **12-hour response countdown** (red when < 1 hour remains; auto-declines on expiry)
- Columns: buyer, profile (which of your profiles the buyer booked through), requested slots (date + time range), location (if applicable), countdown, actions
- Actions: "Accept" / "Decline" buttons
- Buyer-withdrawn requests disappear from the list immediately
- Click row → full request detail

### 3.2 Calendar / Schedule Page
- Full **account-level** calendar (day / week / month toggle) — single view across all of your profiles
- Three slot states are visually distinct: **available** (your published windows), **held** (pending request, dashed border), **booked** (confirmed, solid block)
- Booked/held blocks label which profile the booking came through
- Click a slot → booking detail (if held/booked) or window editor (if available)

### 3.3 Booking Detail Page
- Buyer info (name, photo, rating)
- Profile (which of your profiles the buyer booked through) + booked slots (date + time range, e.g., `2026-02-12 15:00–17:00`, 2 hours)
- Location (if applicable), buyer's optional message
- Status: Requested → Confirmed → In Progress → Completed (or Declined / Expired / Withdrawn / Cancelled)
- Pricing: hourly rate × slot count = total. Captured at accept (or at modification approval for added slots)
- Action buttons (context-dependent):
  - **Requested** (12h countdown shown): "Accept" / "Decline"
  - **Confirmed (upcoming)**: "Propose Modification" / "Message Buyer" / "Cancel"
  - **In Progress**: "Start Session" / "Complete Session" / "Cancel"
  - **With a modification you proposed (pending buyer approval)**: "Withdraw Proposal"
  - **With a modification proposed by the buyer (pending your response, 12h countdown)**: "Approve" / "Reject"
- Session timer (when in progress)

---

## 4. Messaging

### 4.1 Messages Page
- Left panel: conversation list (one per booking)
- Right panel: active chat
- Each conversation: buyer photo, name, last message, time
- Unread indicators

### 4.2 Chat Panel
- Message thread
- Text input + send
- Booking context banner at top

---

## 5. Earnings & Payouts

### 5.1 Earnings Page
- Summary cards: today, this week, this month, all-time
- Earnings chart (bar chart, toggle daily/weekly/monthly)
- Transactions table: date, service, buyer, gross, platform fee, net
- Export to CSV button

### 5.2 Payout Settings Page
- Connected payout method (bank account via Stripe Connect)
- "Add / Change Payout Method" button → Stripe Connect flow
- Payout schedule info
- Payout history table

---

## 6. Profiles

### 6.1 My Profiles Page
- Table/grid of your profiles (one per category in v1)
- Columns: category, headline, **hourly rate** (¥/hour), status (active/paused)
- "Add New Profile" button
- Click row → Edit Profile

### 6.2 Add / Edit Profile Page
- Category dropdown (single-select; one profile per category in v1)
- Headline + bio
- Description (rich text)
- Portfolio media
- **Hourly rate** (¥/hour) — v1 is hourly-only (see ADR 0003)
- Service area
- Toggle: active / paused
- "Save" / "Delete" buttons
- (Availability is set on the account-level calendar — see 8.2)

---

## 7. Reviews

### 7.1 Reviews Page
- Average rating display (large stars + number)
- Review list with pagination
- Each review: buyer name, star rating, comment, date
- Filter by rating

---

## 8. Profile & Settings

### 8.1 Profile Page
- Profile preview (as buyers see it)
- "Edit Profile" button → inline edit

### 8.2 Availability Calendar (account-level)
- Calendar editor showing your account-wide availability — shared across all of your profiles (see ADR 0003)
- Add a window: pick a date, start time, end time. Stored as 1-hour slot subdivisions.
- Slots in HELD state (pending request) and BOOKED state are visible but locked from editing
- Vacation mode toggle (hides you from new requests; existing bookings unaffected)
- (Service area is per-profile — edit it on the profile under My Profiles)

### 8.3 Settings Page
- Account settings (email, password, phone)
- Payout Methods link
- Notification preferences:
  - Email toggles: new requests, booking updates, messages, payouts
  - Push toggles: same categories
- Help & Support link
- "Delete Account" option

### 8.4 Nav Sidebar (persistent)
- Logo
- Dashboard
- Bookings (with request count badge)
- Calendar
- Messages (with unread count)
- Profiles
- Earnings
- Reviews
- Profile & Settings

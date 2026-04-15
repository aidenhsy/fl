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

**Step 2 — Service Setup**
- Select service category
- Service title
- Description
- Pricing model selector: hourly / flat rate / custom
- Rate amount input
- "Next" button

**Step 3 — Availability**
- Weekly schedule grid (click to toggle time blocks)
- Service area: map with draggable radius
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
- Table of incoming requests
- Columns: buyer, service, requested date/time, location, actions
- Actions: "Accept" / "Decline" buttons
- Click row → full request detail

### 3.2 Calendar / Schedule Page
- Full calendar view (day / week / month toggle)
- Bookings displayed as color-coded blocks
- Click a booking → detail sidebar or modal

### 3.3 Booking Detail Page
- Buyer info (name, photo, rating)
- Service, date, time, location
- Status: Pending → Confirmed → In Progress → Completed
- Action buttons:
  - "Start Session"
  - "Complete Session"
  - "Cancel" (with reason dropdown)
- "Message Buyer" button
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

## 6. Service Listings

### 6.1 My Services Page
- Table/grid of service listings
- Columns: title, category, price, status (active/paused)
- "Add New Service" button
- Click row → Edit Service

### 6.2 Add / Edit Service Page
- Service title
- Category dropdown
- Description (rich text)
- Pricing model + rate
- Toggle: active / paused
- "Save" / "Delete" buttons

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

### 8.2 Availability Settings Page
- Weekly schedule grid editor
- Service area map with radius control
- Vacation mode toggle

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
- Services
- Earnings
- Reviews
- Profile & Settings

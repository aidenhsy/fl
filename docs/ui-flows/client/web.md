# Web — Client (Buyer) UI Flows

## 1. Onboarding & Authentication

### 1.1 Landing Page
- Hero section with value proposition
- "Sign Up" / "Log In" buttons in nav bar
- Service category showcase
- How it works (3-step explainer)
- Footer with links

### 1.2 Sign Up Page
- Email input
- Password input (with strength indicator)
- "Continue with Google" / "Continue with Apple"
- "Continue" button → OTP verification

### 1.3 OTP Verification
- Phone number input
- 6-digit code entry
- Resend code link

### 1.4 Profile Setup
- Profile photo upload
- Full name
- Location (auto-detect or search)
- "Get Started" button → Home

### 1.5 Log In Page
- Email + password fields
- "Forgot Password?" link
- Social login buttons

---

## 2. Home / Discovery

### 2.1 Home Page (Authenticated)
- Search bar (prominent, top center)
- Service category cards (grid layout)
- "Near You" — row of top-rated seller cards
- "Recommended for You" section

### 2.2 Search Results / Category Page
- Left sidebar: filters (distance, price range, rating, availability)
- Main content: seller cards in grid or list layout
- Sort dropdown: relevance, rating, price, distance
- Map toggle (splits view: list left, map right)

### 2.3 Map View
- Split layout: seller list on left, interactive map on right
- Map pins for sellers; clicking a pin highlights the list card
- "Search this area" on map drag

---

## 3. Seller Profile & Booking

### 3.1 Seller Profile Page
- Header: photo, name, category, rating, location
- About / bio section
- **Hourly rate** display (e.g., ¥5,000 / hour) — v1 is hourly-only (see ADR 0003)
- Other profiles by the same seller (if any) — separate cards with their own categories and rates; clicking switches profile context
- Reviews section with pagination
- "Book Now" sticky CTA button (disabled if the seller has no published availability or has paused new bookings)

### 3.2 Booking Modal / Page
- **Calendar date picker** — only dates with seller availability are selectable
- **Slot grid** for the selected date: 1-hour slots aligned to the seller's window starts (e.g., 15:00–16:00, 16:00–17:00, 17:00–18:00). Held or booked slots show as unavailable.
- Buyer selects 1+ **contiguous** slots within a single window; total time and price update live
- Location input (if applicable)
- Notes field (optional)
- Price summary sidebar: hourly rate × slot count + platform fee = total
- "Request Booking" button — sends a request to the seller (NOT an instant confirmation). Card is authorized for the total at this step.

### 3.3 Request Sent Page
- "Request submitted! The seller has 12 hours to accept or decline."
- Booking summary details (seller, profile, slots, total)
- Note: "Your slots are reserved while the seller decides. If they decline or don't respond within 12 hours, the hold is released and your card is not charged."
- "Withdraw Request" button (available until the seller responds)
- "Message Seller" link
- "View My Bookings" link

---

## 4. Bookings

### 4.1 My Bookings Page
- Tabs: Upcoming | Past | Cancelled
- Table/card layout: seller, profile/category, slots (date + time range), status badge (Requested / Confirmed / In Progress / Completed / Declined / Expired / Withdrawn / Cancelled)
- Click row → Booking Detail

### 4.2 Booking Detail Page
- Full booking info (seller, profile/category, slots, location, notes)
- Status tracker (timeline visualization): Requested → Confirmed → In Progress → Completed
- **Pending modification panel** (when active):
  - If you proposed a change: shows proposed slots, price delta, seller's 12h response window, "Withdraw Proposal" action
  - If the seller proposed a change: shows proposed slots, price delta, your 12h countdown to respond, "Approve" / "Reject" actions
- "Message Seller" button
- Action buttons (context-dependent):
  - **Requested** (12h countdown): "Withdraw Request"
  - **Confirmed**: "Propose Modification" / "Cancel Booking" (with policy info)
- After completion: "Leave a Review" section

> **Propose Modification**: opens a slot picker showing the seller's currently-available (unbooked, unheld) slots. Confirm the new slot set; net-new slots enter HELD state immediately. The seller has 12 hours to approve. On approval, the booking's slots are replaced and the price delta is captured (extension) or refunded (shortening) at the booking's originally captured hourly rate. On rejection or timeout, the held delta is released and the original booking is unchanged. You can withdraw your proposal any time before the seller responds.

### 4.3 Rate & Review
- Inline on booking detail page after completion
- Star rating (1–5)
- Text review (optional)
- "Submit Review" button

---

## 5. Messaging

### 5.1 Messages Page
- Left panel: conversation list (one per booking)
- Right panel: active chat
- Each conversation: seller photo, name, last message, time
- Unread indicators

### 5.2 Chat Panel
- Message thread
- Text input + send button
- Booking context banner at top of chat

---

## 6. Payments

### 6.1 Payment Methods Page
- List of saved cards
- "Add New Card" form (Stripe Elements)
- Set default card

### 6.2 Payment History Page
- Table: date, service, seller, amount, status
- Click row → receipt/detail view
- Download receipt option

---

## 7. Profile & Settings

### 7.1 Profile Page
- Profile photo, name, email, phone
- "Edit Profile" button → inline edit or modal

### 7.2 Settings Page
- Account settings (email, password, phone)
- Payment Methods link
- Notification preferences (email and push toggles)
- Help & Support link
- "Delete Account" option

### 7.3 Nav Bar (persistent)
- Logo (→ Home)
- Search bar
- "My Bookings" link
- Messages icon (with unread count)
- Profile avatar dropdown (Profile, Settings, Log Out)

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
- Header: photo, name, rating, location
- About / bio section
- Service listings table (name, price, duration)
- Reviews section with pagination
- "Book Now" sticky CTA button

### 3.2 Booking Modal / Page
- Select a service listing
- Calendar date picker
- Time slot grid (based on availability)
- Location input (if applicable)
- Notes field (optional)
- Price summary sidebar
- "Confirm Booking" button

### 3.3 Booking Confirmation Page
- Success message
- Booking summary details
- "Message Seller" link
- "View My Bookings" link

---

## 4. Bookings

### 4.1 My Bookings Page
- Tabs: Upcoming | Past | Cancelled
- Table/card layout: seller, service, date/time, status badge
- Click row → Booking Detail

### 4.2 Booking Detail Page
- Full booking info
- Status tracker (timeline visualization)
- "Message Seller" button
- "Cancel Booking" button (with policy info)
- After completion: "Leave a Review" section

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

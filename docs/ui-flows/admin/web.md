# Web — Admin Panel UI Flows

## 1. Authentication

### 1.1 Admin Log In
- Email + password fields
- Two-factor authentication (OTP via authenticator app)
- No public sign-up — admin accounts created by existing admins

---

## 2. Dashboard

### 2.1 Overview Dashboard
- Key metrics cards:
  - Total users (buyers + sellers)
  - Active bookings today
  - Revenue this month (total commission)
  - Pending seller verifications
- Charts:
  - Bookings over time (line chart)
  - Revenue over time (line chart)
  - New user sign-ups (bar chart)
- Recent activity feed (new bookings, disputes, flagged reviews)

---

## 3. User Management

### 3.1 Buyers List
- Table: name, email, phone, sign-up date, total bookings, status
- Search and filter (by status, date range)
- Click row → Buyer Detail

### 3.2 Buyer Detail
- Profile info
- Booking history
- Payment history
- Reviews given
- Actions: suspend, ban, delete account

### 3.3 Sellers List
- Table: name, email, category, rating, total bookings, verification status, account status
- Search and filter (by category, status, rating)
- Click row → Seller Detail

### 3.4 Seller Detail
- Profile info
- Service listings
- Booking history
- Earnings summary
- Reviews received
- Verification documents (ID, certifications)
- Actions: approve verification, suspend, ban, delete account

### 3.5 Pending Verifications
- Table of sellers awaiting verification
- Each row: name, submitted date, documents preview
- Actions: "Approve" / "Reject" (with reason)

---

## 4. Service Categories

### 4.1 Categories List
- Table: category name, icon, number of active sellers, status (active/hidden)
- "Add Category" button

### 4.2 Add / Edit Category
- Category name
- Icon upload
- Description
- Toggle: active / hidden
- "Save" / "Delete" buttons

---

## 5. Bookings

### 5.1 All Bookings
- Table: booking ID, buyer, seller, service, date, amount, status
- Search and filter (by status, date range, category)
- Click row → Booking Detail

### 5.2 Booking Detail
- Full booking info (buyer, seller, service, date, time, location)
- Status history timeline
- Payment info (amount, commission, payout status)
- Messages between buyer and seller (read-only)
- Actions: cancel booking, issue refund

---

## 6. Disputes & Reports

### 6.1 Disputes List
- Table: dispute ID, booking, reporter, reported user, reason, status (open/in review/resolved)
- Filter by status

### 6.2 Dispute Detail
- Booking info
- Reporter's complaint
- Reported user's profile
- Conversation history (read-only)
- Admin notes field
- Actions: resolve in favor of buyer, resolve in favor of seller, issue partial refund, suspend user

---

## 7. Transactions & Revenue

### 7.1 Transactions Page
- Table: transaction ID, booking, buyer, seller, amount, commission, date, status
- Filter by date range, status
- Export to CSV

### 7.2 Revenue Dashboard
- Total revenue (commission) over time
- Revenue by category (pie chart)
- Average booking value
- Payout summary (total paid out to sellers)

---

## 8. Platform Settings

### 8.1 General Settings
- Platform name and logo
- Commission rate (percentage)
- Supported service categories

### 8.2 Admin Users
- List of admin accounts
- "Invite Admin" (email invite)
- Role management (super admin, support, finance)
- Remove admin

### 8.3 Notification Templates
- Email templates for: booking confirmation, booking cancellation, payment receipt, seller approval, seller rejection
- Edit template content

---

## 9. Nav Sidebar (persistent)

- Logo
- Dashboard
- Users → Buyers, Sellers, Pending Verifications
- Categories
- Bookings
- Disputes
- Transactions
- Settings
- Log Out

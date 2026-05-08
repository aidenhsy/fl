# Seller Mobile UI Flow

## 0. Localization

- **Supported languages**:
  - `ja` — 日本語 / Japanese — primary, default fallback
  - `en` — English
  - `zh-CN` — 简体中文 / Chinese Simplified
  - `zh-TW` — 繁體中文 / Chinese Traditional
- **Language detection**: On first launch, the app reads the device's system language and sets it automatically. If the device language is not one of the four supported languages, the app defaults to Japanese.
- Language can be switched at any time from Settings (3.4) or on the Welcome Screen (1.1)
- All UI labels in this document are shown as: **日本語 / English** for brevity. Chinese translations follow the same label structure during implementation.
- **i18n file structure**:
  ```
  locales/
  ├── ja.json
  ├── en.json
  ├── zh-CN.json
  └── zh-TW.json
  ```
- Date format: `YYYY年MM月DD日`（e.g., 2026年4月11日）
- Time format: 24-hour（e.g., 14:30）
- Currency: ¥ JPY

---

## 1. Authentication

### 1.1 Welcome Screen（ようこそ画面）
- App logo and tagline
- 「Googleで続ける / Continue with Google」button
- 「Appleで続ける / Continue with Apple」button
- 「LINEで続ける / Continue with LINE」button
- 「WeChatで続ける / Continue with WeChat」button
- Language switcher（top-right corner）: 日本語 / English / 简体中文 / 繁體中文. Defaults to device system language on first launch.
- Link to 利用規約 / Terms of Service and プライバシーポリシー / Privacy Policy at the bottom

### 1.2 Auth Result
- **Success → first-time user**: Navigate to Onboarding (2.1)
- **Success → returning user**: Navigate to Home Dashboard (3.1)
- **Failure**: Inline error message with retry option

---

## 2. Onboarding (First-Time Only)

### 2.1 Job/Skill Selection（職種選択）
- Header: 「あなたの職種は？ / What do you do?」
- Grid or list of default job categories:
  - カメラマン / Photographer
  - ドライバー / Driver
  - 清掃スタッフ / Cleaner
- Each item is a selectable card with an icon and label
- Seller may select **one or more** categories
- 「該当する職種がない / I don't see my job」link at the bottom → navigates to 2.2
- 「次へ / Continue」button → navigates to 2.3

### 2.2 Custom Job Request（カスタム職種の申請）
- Text input: 「あなたの職種・スキルを入力 / Enter your job or skill」
- Optional: Brief description textarea
- 「審査を申請する / Submit for Review」button
- Confirmation message: 「申請を受け付けました。承認をお待ちの間、プロフィールの設定を進めることができます。」
- Navigate to 2.3
- **Note**: Seller enters the app immediately. A 「承認待ち / Pending」badge appears on their job tag. They can set up their profile but won't appear in client search for that category until approved.

### 2.3 Rate Setup（料金設定）

For each category selected in 2.1, the seller sets their **hourly rate**:

- Header: 「時給を設定してください / Set your hourly rate」
- For each selected category, a card showing:
  - Category name (e.g., カメラマン / Photographer)
  - 時給 / Hourly rate: Numeric input in ¥/時間
  - 自己紹介 / Short description of what you offer for this category (e.g., 「ポートレート・イベント撮影。機材持ち込み。」). Max 200 characters.
- Categories pending approval (from 2.2) show a 「承認待ち」badge — rate can still be set in advance
- 「次へ / Continue」→ navigates to 2.4

> **Note**: v1 is hourly-only. Per-day and per-session rate types are deferred (see ADR 0003). The rate + description per category is what clients see when browsing.

### 2.4 Basic Profile Setup（プロフィール設定）
- Profile photo upload (camera or gallery)
- 表示名 / Display name
- 自己紹介 / Short bio (about the person, not a specific service)
- Service area selection (see 2.5)
- 「次へ / Continue」→ Navigate to Availability Calendar Setup (2.6)

### 2.5 Service Area Selection（対応エリア設定）

| Level | Label | Example | Use case |
|---|---|---|---|
| Nationwide | 全国対応 / All of Japan | — | Remote services |
| Prefecture | 都道府県 / Prefecture | 東京都、大阪府 | General local services |
| Municipality | 市区町村 / City/Ward | 渋谷区、札幌市 | Hyper-local services |

- Seller can select **one or more** areas
- Searchable dropdown with prefecture → municipality drill-down
- 「全国対応 / Available nationwide」toggle at the top
- Selected areas displayed as removable tags/chips

### 2.6 Availability Calendar Setup（カレンダー設定）

The seller's **account-level** availability calendar — shared across all of their profiles (see ADR 0003). A slot booked through any profile blocks the same hour on every other profile of this account.

- Header:「予約可能な時間を設定 / Set your available hours」
- Banner: 「このカレンダーは全てのプロフィールで共有されます。1つのプロフィールで予約が入ると、同じ時間は他のプロフィールでも予約不可になります。」
- **Add window**: pick a date (calendar picker), then a start and end time (e.g., `2026年2月12日（金） 15:00〜17:00`). Each window splits into fixed 1-hour slots aligned to the window's start.
- **Window list**: existing windows shown as cards under each date. Each card shows time range and slot count. Tap to remove (only if no slots are held or booked) or to shorten.
- 「スキップ / Skip for now」link — seller can publish the calendar later from Profile (3.4 → 稼働カレンダー). They will not appear in client search results until at least one window is published.
- 「保存して始める / Save & Continue」→ Navigate to Home Dashboard (3.1)

---

### 2.7 Payout Setup Prompt（振込先の設定）

This screen is **not** shown during initial onboarding — it is triggered **the first time a seller accepts a booking**.

- Opens Stripe Connect onboarding (hosted page) for KYC and bank setup
- 「あとで / Skip for now」→ persistent banner on Home until configured. Seller **cannot mark a booking as completed** until payout method is set.

---

## 3. Main App (Footer Navigation)

Footer tabs: **ホーム** | **予約** | **メッセージ** | **プロフィール**

---

### 3.1 Home（ホーム / Tab 1）

The seller's at-a-glance dashboard.

- **Greeting**: 「おはようございます、{name}さん」（time-aware）
- **Earnings card**: 今日 / 今週 / 今月 toggle, amounts as ¥XX,XXX
- **Profile views**: 「今週のプロフィール閲覧数: XX回 / Profile views this week: XX」
- **Upcoming bookings**: Horizontal scrollable list of next 1–3 confirmed bookings (client name, date/time, category)
- **Recent activity feed**: List of recent events (new booking request, review received, booking completed, payment received, custom job approved)
- **新規予約の受付を一時停止 / Pause new bookings** toggle (vacation mode). When on: seller is hidden from client search and existing published windows can't be requested against — without deleting the windows. Existing confirmed bookings proceed normally; pending requests already received can still be accepted or declined. Distinct from the published availability calendar — the calendar describes *when* you can work; this toggle is a global "not now" override.

---

### 3.2 Bookings（予約 / Tab 2）

Segmented tabs at the top: **新着** | **確定済み** | **履歴**

#### 3.2.1 Incoming（新着）
- List of new booking requests from clients. Slots are in HELD state across all of your profiles for the duration of the response window.
- Each card shows: client name + photo, **profile booked through** (which of your categories), requested slots (date + time range, e.g. `2026年2月12日 15:00〜17:00 (2時間)`), hourly rate × slot count = total, **countdown timer showing time remaining to respond**
- Actions per card: 「受ける / Accept」/「辞退する / Decline」
- A request **withdrawn by the client** disappears from the list immediately
- Tapping opens Booking Detail (3.2.4)
- **Request expiry**: **12-hour** response window. Countdown on card. Auto-declined if no response (held slots released). Red countdown in last 1 hour.

#### 3.2.2 Confirmed & Active（確定済み）
- List of accepted bookings (upcoming + in-progress)
- Each card shows: client name, category, date/time, location, status indicator (確定済み / 進行中)
- Tapping opens Booking Detail (3.2.4) with active-state actions

#### 3.2.3 History（履歴）
- List of completed, cancelled, and expired bookings
- Each card shows: client name, category, date, amount earned in ¥, rating received
- Filter by: date range, category
- Tapping opens a read-only Booking Detail

#### 3.2.4 Booking Detail（予約詳細）
- **Client info**: Name, photo, rating
- **Booking info**: Profile booked through (category), slots booked (date + time range, e.g. `2026年2月12日 15:00〜17:00 (2時間)`), location (if applicable), client's message/notes
- **Pricing section**:
  - Hourly rate × slot count = total: e.g. ¥5,000 × 2時間 = ¥10,000
  - Platform fee breakdown: 「サービス料 / Service fee: ¥X,XXX」→「受取額 / You receive: ¥XX,XXX」
  - **Expiry countdown** (for incoming requests; 12h)
- **Pending modification panel** (when active):
  - If you proposed a change: shows proposed slots, price delta, buyer's response window (12h), 「提案を取り消す / Withdraw Proposal」action
  - If the buyer proposed a change: shows proposed slots, price delta, your 12h countdown to respond, 「承認する / Approve」/「却下する / Reject」actions
- Action buttons (context-dependent):
  - **Incoming (Requested)**: 「受ける / Accept」/「辞退する / Decline」(12h countdown)
  - **Confirmed (upcoming)**: 「メッセージを送る」/「予定変更を提案 / Propose Modification」/「キャンセル」
  - **In Progress**: 「メッセージを送る」/「完了にする」/「キャンセル」
  - **Completed**: 「レビューを見る」(if review received)

> **Propose Modification（予定変更を提案）**: opens a slot picker drawing from your account-level calendar's currently-available (unbooked, unheld) slots. Confirm the new slot set; any net-new slots enter HELD state immediately, blocking your calendar across all profiles. The buyer has 12 hours to approve. On approval, the booking's slots are replaced and the price delta is captured (extension) or refunded (shortening) at the booking's originally captured hourly rate. On rejection or timeout, the held delta is released and the original booking is unchanged. You can withdraw your proposal any time before the buyer responds.

> **Cancellation policy (Confirmed bookings)**:
> - Tapping「キャンセル」opens a confirmation sheet with reason picker:
>   - スケジュールの都合 / Scheduling conflict
>   - お客様と連絡が取れない / Cannot reach client
>   - その他 / Other（free text）
> - Client immediately notified with the reason
> - **Penalty rules**:
>   - Cancellation **48+ hours** before: No penalty
>   - Cancellation **within 48 hours**: Warning recorded
>   - **3+ late cancellations within 30 days**: Temporary suspension + admin review
> - Cancellation count visible in Profile → 設定

---

### 3.3 Messages（メッセージ / Tab 3）

- List of conversations sorted by most recent
- Each row: client avatar, name, last message preview, timestamp, unread badge
- Tapping opens a chat screen:
  - Text input with send button
  - Image attachment support
  - Messages as bubbles with timestamps
  - Link to related booking at the top (if exists)

> **Note**: Clients can message sellers before booking (from the seller's public profile). A conversation without a booking is valid.

---

### 3.4 Profile（プロフィール / Tab 4）

- **Profile header**: Photo, display name, rating (★4.8 · 200件), 「XX時間の実績 / XX hours worked」, member since
- **Sections**:
  - **サービス・料金 / Services & Rates**: List of your profiles (one per category). Tappable to edit hourly rate and category description. Add new profile. Remove profile.
  - **ポートフォリオ / Portfolio**: Photos/work samples grid with add/remove
  - **レビュー / Reviews**: List of client reviews with ratings
  - **対応エリア / Service Area**: Manage prefectures and municipalities (per profile)
  - **稼働カレンダー / Availability calendar (account-wide)**: Manage availability windows. Each window splits into 1-hour slots that buyers can claim through any of your profiles (see ADR 0003). Held and booked slots are visible but locked from editing.
  - **売上・振込 / Earnings & Payouts**: Earnings summary, payout history, Stripe Connect status
  - **設定 / Settings**:
    - 通知設定 / Notification preferences
    - 言語 / Language（日本語 / English / 简体中文 / 繁體中文）
    - アカウントセキュリティ / Account security
    - ログアウト / Logout
    - アカウント削除 / Delete account

---

## 4. Notifications

- Push notifications for:
  - 新しい予約リクエスト / New booking request received
  - 予約の回答期限が近づいています / Booking request expiring soon (1 hour remaining)
  - 予約が期限切れになりました / Booking request expired (auto-declined)
  - 予約が確定しました / Booking confirmed
  - 予約リクエストが取り消されました / Booking request withdrawn by client
  - 予定変更が提案されました / Modification proposed by client — review and respond (12h)
  - 提案が承認されました / Your modification proposal was approved
  - 提案が却下されました / Your modification proposal was rejected
  - 提案の期限が切れました / Modification proposal expired
  - 新しいメッセージ / New message from client
  - 入金がありました / Payment received
  - レビューが届きました / Review received
  - 職種が承認されました / Custom job approved by admin
  - キャンセル警告 / Cancellation warning recorded
  - 振込先を設定してください / Please set up your payout method
- Tapping a notification deep-links to the relevant screen
- Notification language follows user's selected language preference

---

## 5. Edge Cases & States

| Scenario | Behavior |
|---|---|
| Custom job pending | Seller can access full app. Job tag shows 「承認待ち」badge. Not visible in client search for that category until approved. Rate can be set in advance. |
| Custom job rejected | Notification sent. Seller prompted to select from defaults or resubmit. |
| Booking request expired | After **12 hours** with no response, auto-declined. Client notified, slot hold + payment hold both released. |
| Client withdraws request | Request disappears immediately from incoming list. Slot hold released across all profiles. |
| Modification proposal expired | After **12 hours** with no response from the counterparty, the proposal is auto-rejected. Held delta slots released; original booking unchanged. |
| Originator withdraws modification | Held delta slots released immediately. Original booking unchanged. |
| Seller cancels (48+ hours before) | No penalty. Client notified. Payment hold released. |
| Seller cancels (within 48 hours) | Warning recorded. Client notified. Client receives 50% compensation. After 3 in 30 days → suspension. |
| Payout method not set | Seller can accept bookings but cannot mark as completed. Persistent banner on Home. |
| No booking requests | Empty state:「予約リクエストはまだありません。プロフィールを充実させましょう。」 |
| Seller paused new bookings (vacation mode) | Hidden from client search entirely. Existing published windows can't be requested against. Existing confirmed bookings not affected; pending requests already received can still be accepted or declined. |
| No profile views | Home shows 0 views. Suggestion: add portfolio photos, improve bio. |
| Network offline | Banner:「オフラインです。一部の機能が制限されています。」Cached data visible. |
| Language switch | UI switches immediately. User-generated content remains in original language. |

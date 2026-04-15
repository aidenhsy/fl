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

For each category selected in 2.1, the seller sets their rate:

- Header: 「料金を設定してください / Set your rates」
- For each selected category, a card showing:
  - Category name (e.g., カメラマン / Photographer)
  - 料金 / Rate: Numeric input in ¥
  - 料金単位 / Pricing unit picker: 1回 (per session) / 1時間 (per hour) / 1日 (per day)
  - 自己紹介 / Short description of what you offer for this category (e.g., 「ポートレート・イベント撮影。機材持ち込み。」). Max 200 characters.
- Categories pending approval (from 2.2) show a 「承認待ち」badge — rate can still be set in advance
- 「次へ / Continue」→ navigates to 2.4

> **Note**: The rate + description per category is what clients see when browsing. This is the seller's "offering" — no separate listing entity needed.

### 2.4 Basic Profile Setup（プロフィール設定）
- Profile photo upload (camera or gallery)
- 表示名 / Display name
- 自己紹介 / Short bio (about the person, not a specific service)
- Service area selection (see 2.5)
- 「保存して始める / Save & Continue」→ Navigate to Home Dashboard (3.1)

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

### 2.6 Payout Setup Prompt（振込先の設定）

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
- **Availability toggle**: 受付中 / 受付停止（Available / Unavailable）— when unavailable, seller is hidden from client search

---

### 3.2 Bookings（予約 / Tab 2）

Segmented tabs at the top: **新着** | **確定済み** | **履歴**

#### 3.2.1 Incoming（新着）
- List of new booking requests from clients
- Each card shows: client name + photo, category booked, requested date/time, rate (seller's rate for that category), **countdown timer showing time remaining to respond**
- Actions per card: 「受ける / Accept」/「辞退する / Decline」
- Tapping opens Booking Detail (3.2.4)
- **Request expiry**: 24-hour response window. Countdown on card. Auto-declined if no response. Red countdown in last 2 hours.

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
- **Booking info**: Category, requested date/time, location (if applicable), client's message/notes
- **Pricing section**:
  - Seller's rate for this category displayed as ¥XX,XXX / unit
  - Platform fee breakdown: 「サービス料 / Service fee: ¥X,XXX」→「受取額 / You receive: ¥XX,XXX」
  - **Expiry countdown** (for incoming requests)
- Action buttons (context-dependent):
  - Incoming: 「受ける / Accept」/「辞退する / Decline」
  - Confirmed/In Progress: 「メッセージを送る」/「完了にする」/「キャンセル」
  - Completed: 「レビューを見る」(if review received)

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
> - Cancellation count visible in Profile → 稼働設定

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
  - **サービス・料金 / Services & Rates**: List of registered categories with rate per category. Tappable to edit rate, pricing unit, and category description. Add new category. Remove category.
  - **ポートフォリオ / Portfolio**: Photos/work samples grid with add/remove
  - **レビュー / Reviews**: List of client reviews with ratings
  - **対応エリア / Service Area**: Manage prefectures and municipalities
  - **稼働設定 / Availability**: Working hours, days off
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
  - 予約の回答期限が近づいています / Booking request expiring soon (2 hours remaining)
  - 予約が期限切れになりました / Booking request expired (auto-declined)
  - 予約が確定しました / Booking confirmed
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
| Booking request expired | After 24 hours with no response, auto-declined. Client notified, payment hold released. |
| Seller cancels (48+ hours before) | No penalty. Client notified. Payment hold released. |
| Seller cancels (within 48 hours) | Warning recorded. Client notified. Client receives 50% compensation. After 3 in 30 days → suspension. |
| Payout method not set | Seller can accept bookings but cannot mark as completed. Persistent banner on Home. |
| No booking requests | Empty state:「予約リクエストはまだありません。プロフィールを充実させましょう。」 |
| Seller unavailable | Hidden from client search entirely. Existing confirmed bookings not affected. |
| No profile views | Home shows 0 views. Suggestion: add portfolio photos, improve bio. |
| Network offline | Banner:「オフラインです。一部の機能が制限されています。」Cached data visible. |
| Language switch | UI switches immediately. User-generated content remains in original language. |

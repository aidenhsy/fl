# Client Mobile UI Flow

## 0. Localization

- **Supported languages**:
  - `ja` — 日本語 / Japanese — primary, default fallback
  - `en` — English
  - `zh-CN` — 简体中文 / Chinese Simplified
  - `zh-TW` — 繁體中文 / Chinese Traditional
- **Language detection**: On first launch, the app reads the device's system language and sets it automatically. If the device language is not one of the four supported languages, the app defaults to Japanese.
- Language can be switched at any time from Settings (3.4) or on the Welcome Screen (1.1)
- All UI labels in this document are shown as: **日本語 / English** for brevity.
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
- 「LINEで続ける / Continue with LINE」button (placeholder)
- 「WeChatで続ける / Continue with WeChat」button (placeholder)
- Language switcher（top-right corner）
- Link to 利用規約 / Terms of Service and プライバシーポリシー / Privacy Policy

### 1.2 Auth Result
- **Success → first-time user**: Navigate to Onboarding (2.1)
- **Success → returning user**: Navigate to Browse (3.1) with saved default category
- **Failure**: Inline error message with retry option

---

## 2. Onboarding (First-Time Only)

### 2.1 Display Name（表示名設定）
- 表示名 / Display name: text field (pre-filled from OAuth provider if available)
- NO photo upload — avatar auto-populated from OAuth provider (already on `users.avatar_url`)
- 「次へ / Next」→ navigates to Category Selection (2.2)

### 2.2 Category Selection（カテゴリ選択）
- Header:「どんなサービスをお探しですか？ / What are you looking for?」
- Grid of category cards with icons from `listJobCategories`. Single select.
- Client selects **one** category — this becomes their default browse category.
- 「始める / Get Started」→ creates `client_profile` → saves selected category to UserDefaults → navigates to Browse (3.1) showing results for the selected category.

> **Note**: Minimal 2-step onboarding. Display name + pick a category, then straight to browsing.

---

## 3. Main App (Footer Navigation)

Footer tabs: **さがす** | **メッセージ** | **予約** | **マイページ**

---

### 3.1 Browse（さがす / Tab 1）

Clients discover sellers by category. The app opens directly to seller results for the client's saved default category — **no landing page, no extra tap**.

**Category dropdown** (top-left, Preply-style):
- Shows current category name with ▼ chevron (e.g., 「カメラマン ▼」)
- Tapping opens a bottom sheet with all categories as a searchable scrollable list
- Each category row: icon + localized name + checkmark on current selection
- Tapping a different category: dismisses sheet, reloads results, saves new default to UserDefaults

**Returning users**: App loads with the last selected category from UserDefaults. No landing page.

#### 3.1.1 Seller Results（プロ一覧）

Filtered list of sellers for the selected category. Styled like Preply's tutor list.

- **Results header**: Bold count「XX人の{カテゴリ名}が対応可能 / XX {category} available」
- **Filter bar** (horizontally scrollable pill chips):
  - 料金 / Price: Min–max range in ¥
  - エリア / Area: Prefecture → municipality picker
  - 評価 / Rating: ★4.0+ / ★4.5+ / ★4.8+
  - Active filters fill with tint color
- **Sort**: 「並び替え ↕」button → bottom sheet with options: おすすめ (recommended) / 料金が安い順 (low→high) / 料金が高い順 (high→low) / 評価が高い順 (highest rated) / 実績が多い順 (most hours worked)

**Seller card** (Preply layout):
- **Left**: Large square photo, rounded corners (not circular), ~120×140px
- **Right** (top section):
  - Row 1: **Name** (bold, title3) + service area tag + ♡ heart icon (placeholder)
  - Row 2: **Rate** (bold, tinted, e.g., ¥5,000) with unit below (1時間) | **Rating** (bold, e.g., 5 ★) with review count below
- **Full width** (below photo+info):
  - Category description: 1–2 lines truncated
  - Stats: 👤 XX時間の実績

- Infinite scroll pagination
- Pull-to-refresh
- Empty state:「この条件に合うプロが見つかりませんでした。フィルターを変更してみてください。」
- Tapping a card → Seller Profile (3.1.2)

#### 3.1.2 Seller Profile（プロのプロフィール）

Full seller profile page, shown in the context of the category the client searched for.

- **Profile header**:
  - Large photo
  - Display name
  - Rating: ★4.8（200件のレビュー）
  - 「XX時間の実績 / XX hours worked」
  - 「メンバー歴: XXXX年XX月から / Member since」
  - Service area chips
  - **Booking availability indicator**: 受付中 (green) when the seller is accepting new bookings, or 受付停止中 (grey) when they have paused new bookings or have no upcoming published windows
- **Rate card** (prominent, sticky or near top):
  - Rate for the searched category: ¥5,000 / 1時間
  - 「予約する / Book Now」button
  - If the seller has paused new bookings or has no upcoming published windows: button disabled,「現在新規予約を受付停止中です / Not accepting new bookings right now」
- **自己紹介 / About**: Seller's bio
- **このカテゴリについて / About this service**: Seller's category-specific description (from their service setup)
- **他のサービス / Other services** (if seller has multiple categories):
  - Horizontal list of other category cards with their rates. Tapping switches the profile context to that category.
- **ポートフォリオ / Portfolio**: Photo grid (read-only)
- **レビュー / Reviews**: Latest 3 reviews with ratings. 「すべて見る / See all」→ paginated list.
- **「メッセージを送る / Send Message」button** → opens or creates a conversation with this seller

#### 3.1.3 Booking Flow（予約手続き）

Triggered by tapping "Book Now" on a seller profile.

**Step 1 — Slot Selection（日時の選択）**
- Calendar view: only dates with seller availability are selectable
- Tap a date → available 1-hour slots displayed as tiles (e.g., `15:00〜16:00`, `16:00〜17:00`, `17:00〜18:00`)
- Buyer selects 1+ **contiguous** slots within a single window. Held or booked slots show as `他の予約あり / Already booked` and are not selectable.
- Total duration and total price update live as slots are added/removed
- 「次へ / Next」

**Step 2 — Details（詳細の入力）**
- 場所 / Location (if location-based service): Address input + map
- メッセージ / Message to seller: Optional textarea for special requests
- 「次へ / Next」

**Step 3 — Confirm & Pay（確認・決済）**
- Summary: seller name + photo, profile/category, slots (date + time range), location
- Price breakdown:
  - 時給 / Hourly rate: ¥X,XXX × N時間
  - サービス料 / Platform fee: ¥X,XXX
  - 合計 / Total: ¥XX,XXX
- **Payment method**:
  - Saved credit cards (Stripe)
  - 「カードを追加 / Add a card」→ Stripe Payment Sheet
- 「予約をリクエスト / Request Booking」→ authorizes payment hold + reserves slots in HELD state → Confirmation
- Confirmation:「予約リクエストを送信しました！プロからの回答をお待ちください（**12時間以内**）。」

> **Payment + slot flow**: On request, slots enter HELD state across all of the seller's profiles, and the card is **authorized (held)** for the total. On accept, slots become BOOKED and the card is captured. If the seller declines or doesn't respond within **12 hours**, slot hold and payment hold are both released. The buyer may withdraw the request any time before the seller responds, releasing both holds immediately.

---

### 3.2 Messages（メッセージ / Tab 2）

- Conversations sorted by most recent
- Each row: seller avatar, name, last message preview, timestamp, unread badge
- Chat screen: iMessage-style bubbles, text input, image attachments, timestamps, link to booking (if exists)
- Tab icon shows badge with total unread count

> **Note**: Clients can message sellers before booking (from Seller Profile). A conversation without a booking is valid — clients may ask questions before deciding.

---

### 3.3 Bookings（予約 / Tab 3）

#### 3.3.1 My Bookings（予約一覧）

**Pending reviews banner**: Shown at top if `pending_reviews_count > 0` from dashboard.

Segmented tabs: **進行中** | **履歴**

**Active bookings**:
- Each card: seller name + photo, profile/category, slots (date + time range), status badge
- Statuses:
  - リクエスト中 / Requested — waiting for seller (shows 12h countdown)
  - 確定済み / Confirmed — seller accepted
  - 変更提案中 / Modification pending — a modification proposal is awaiting either party's response
  - 進行中 / In Progress — booking start time arrived
  - 完了確認待ち / Pending Completion — seller marked complete
- Tapping → Booking Detail (3.3.2)

**History**: Completed, cancelled, expired. Filter by date/category.

#### 3.3.2 Booking Detail（予約詳細）— Client View
- Seller info (name, photo, rating) — tappable → Seller Profile
- Booking details: profile/category, slots booked (date + time range, e.g. `2026年2月12日 15:00〜17:00 (2時間)`), location, client's notes
- Status timeline: リクエスト → 確定 → 進行中 → 完了
- Price breakdown: hourly rate × slot count + platform fee = total
- **Pending modification panel** (when active):
  - If you proposed a change: shows proposed slots, price delta, seller's 12h response window, 「提案を取り消す / Withdraw Proposal」action
  - If the seller proposed a change: shows proposed slots, price delta, your 12h countdown to respond, 「承認する / Approve」/「却下する / Reject」actions
- Action buttons:
  - **Requested** (12h countdown): 「リクエストを取り消す / Withdraw Request」(free anytime before seller responds — hold released)
  - **Confirmed**: 「メッセージを送る」/「予定変更を提案 / Propose Modification」/「キャンセル / Cancel」
  - **In Progress**: 「メッセージを送る」/「キャンセル / Cancel」
  - **Pending Completion**: 「完了を確認 / Confirm Completion」/「問題を報告 / Report Issue」
  - After completion: 「レビューを書く / Leave a Review」
  - Completed: 「レビューを見る / View Review」

> **Client withdrawal/cancellation policy**:
> - **Withdraw before seller responds (Requested state)**: Free anytime within the 12h response window. Slot hold and payment hold released immediately.
> - **Cancel after accept, 48+ hours before**: Free, payment hold released, slot returned to seller's availability
> - **Cancel after accept, within 48 hours**: 50% cancellation fee. Seller receives 50% compensation.
> - Reason required (cancellation only): 予定が変わった / 別の方法で解決した / その他

> **Propose Modification（予定変更を提案）**: opens a slot picker showing the seller's currently-available (unbooked, unheld) slots. Confirm the new slot set; net-new slots enter HELD state immediately, blocking that time across all of the seller's profiles. The seller has 12 hours to approve. On approval, the booking's slots are replaced and the price delta is captured (extension) or refunded (shortening) at the booking's originally captured hourly rate. On rejection or timeout, the held delta is released and the original booking is unchanged. You can withdraw your proposal any time before the seller responds.

#### 3.3.3 Confirm Completion（完了確認）
- Push notification when seller marks complete
- 「完了を確認 / Confirm Completion」→ Stripe charge → Review flow
- 「問題を報告 / Report Issue」→ support form (text + optional photos). Payment hold remains until admin resolves.
- **Auto-confirm**: 72 hours after seller marks complete with no client action → auto-charged. Warning push at 48 hours.

#### 3.3.4 Leave a Review（レビューを書く）
- Star rating: 1–5 stars (required)
- コメント / Comment: Optional text
- 「送信する / Submit」→ review posted, seller notified, rating updated
- Accessible from: Bookings tab banner, Booking Detail, notification deep-link

---

### 3.4 My Page（マイページ / Tab 4）

- **Profile header**: Photo (from OAuth), display name, member since. Tappable to edit name/photo.
- **Sections**:
  - **予約一覧 / My Bookings**: Link to Booking Management (3.3.1)
  - **支払い方法 / Payment Methods**: Saved cards from Stripe. Add/remove. Swipe-to-delete.
  - **支払い履歴 / Payment History**: All charges (completed bookings + cancellation fees). Paginated.
  - **レビュー / My Reviews**: Reviews the client has left
  - **設定 / Settings**:
    - 通知設定 / Notification preferences (toggles per type)
    - 言語 / Language (picker: ja/en/zh-CN/zh-TW)
    - アカウントセキュリティ / Account security (placeholder)
    - ログアウト / Logout
    - アカウント削除 / Delete account (double confirmation)

---

## 4. Notifications

- Push notifications for:
  - 予約が受付されました / Booking accepted by seller
  - 予約が辞退されました / Booking declined by seller
  - 予約が完了しました / Booking marked complete — confirm and review
  - 予約の期限が切れました / Booking expired — seller didn't respond within 12 hours
  - 予定変更が提案されました / Modification proposed by seller — review and respond (12h)
  - 提案が承認されました / Your modification proposal was approved
  - 提案が却下されました / Your modification proposal was rejected
  - 提案の期限が切れました / Modification proposal expired
  - 新しいメッセージ / New message from seller
  - 決済が完了しました / Payment processed
  - セラーがキャンセルしました / Seller cancelled
  - レビューを書きましょう / Review reminder (24h after completion)
  - まもなく自動確認されます / Auto-confirm reminder (48h after seller marks complete)
- Deep-links to relevant screens
- Language follows user's preference

---

## 5. Edge Cases & States

| Scenario | Behavior |
|---|---|
| Seller doesn't respond | **12 hours** → booking expires. Client notified, slot + payment holds released. Prompted to browse other sellers. |
| Seller cancels after accepting | Client notified with reason. Within 48h → seller warning, client gets 50% compensation. |
| Client withdraws before accept | Free, slot + payment holds released. |
| Modification proposal expired | After **12 hours** with no response from the counterparty, the proposal is auto-rejected. Held delta slots released; original booking unchanged. |
| Originator withdraws modification | Held delta slots released immediately. Original booking unchanged. |
| Slot taken before request submitted | If two buyers request the same slot simultaneously, only the first submission acquires the hold. Second buyer sees「この時間は他の方が予約済みです / This slot was just taken」and is returned to slot selection. |
| Client cancels after accept (48+ hours) | Free, hold released. Seller notified. |
| Client cancels after accept (within 48 hours) | 50% fee charged. Seller compensated. |
| Completion dispute | Client reports issue. Support case created. Hold remains until resolved. |
| Auto-confirm | 72 hours no action → auto-charged. Warning at 48 hours. |
| No payment method | Cannot book. Prompted during booking flow Step 3. |
| Pending reviews | Bookings tab banner + push at 24h. Non-blocking. |
| No bookings | Bookings tab empty state. |
| No search results | Suggestion to adjust filters. |
| Seller paused new bookings or has no published windows | Profile still visible but "Book Now" disabled with「現在新規予約を受付停止中です」. |
| Conversation without booking | Valid — pre-booking questions. |
| Network offline | Banner. Cached data visible. |
| Language switch | UI switches immediately. User content stays in original language. |

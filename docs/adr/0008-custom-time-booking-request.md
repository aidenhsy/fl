---
status: accepted
date: 2026-05-16
decision-makers: [aiden]
supersedes: 0003 (windowed-only invariant — see *More Information*)
---

# Custom-time booking request (relax the "must live in a published window" invariant)

## Context and Problem Statement

ADR 0003 made it an invariant that every booking lives inside a published availability window: buyers can only request slots the seller has explicitly published. That model is right for high-volume hourly services (a buyer scanning a driver's published Saturday afternoon for the next free hour) but it dead-ends a common creative-services flow:

- A buyer has a fixed need — *"my wedding is Saturday 2pm-7pm, I want **this** photographer"* — and the seller hasn't pre-published that specific window. The buyer has nowhere to go: the slot grid shows no openings for that day, and there's no mechanism to say *"can you do this time?"* short of starting a chat thread and hoping it converts.

The seller already has the necessary expressive power on their side (they can publish a window and the buyer can then book it), but that's a two-step back-and-forth that requires the buyer to know the seller is reachable via chat, the seller to remember to publish, and the buyer to come back and book before someone else does. For a marketplace whose creative-services buyers often have one specific date in mind, the friction is meaningful.

## Decision Drivers

- Preserve the **no-double-booking** invariant — two buyers cannot end up confirmed for the same hour on the same seller. This is the load-bearing invariant on the seller's calendar; the rest is presentation.
- Keep the **windowed flow** as the default — discovery, the slot grid, and the regular price-per-hour rendering should stay the primary surface. Custom-time is an escape hatch, not a replacement.
- Avoid parallel-entity proliferation. A custom-time request is still fundamentally a booking; the seller's incoming inbox should not bifurcate into "regular bookings" and "availability requests" with two accept buttons.
- Make the seller aware *which* requests came from outside their published windows so they can sanity-check before accepting (they may have personal-time blockouts in their own head that no one else knows about).

## Considered Options

- **A — Custom-time as a booking with `requested_outside_window: true` and no other model changes.** The use case skips the published-window check; slot_occupancy still gets written. Seller accept/decline path unchanged. (Chosen.)
- **B — Custom-time as a "publish window then book" transaction.** On accept, atomically publish a matching availability window and create the booking inside it. Cleaner under the strict ADR 0003 reading. Rejected: the published window adds nothing the calendar didn't already capture (slot_occupancy is the source of truth for "is this hour free?"), and the window record's job is *discovery* — a custom-time slot has no buyer-discovery requirement.
- **C — Custom-time as a separate `availability_requests` table.** Decouples the request from a booking, converts to a booking on accept. Rejected: forces the seller's inbox to render two entity types, adds an accept-side conversion step, and the booking model already has every column we need for the "request → accept/decline → confirm → complete" lifecycle.

## Decision Outcome

**Chosen: Option A.** A custom-time request is a normal booking with a `requested_outside_window` boolean flag on the row. The slot_occupancy ledger is written exactly the same way it is for windowed bookings — so the no-double-booking invariant holds without change. Only the "must fall in a published window" check in `CreateBookingUseCase` is gated by the flag.

What stays unchanged:
- All other create-booking validations: hour-aligned `scheduledAt`, profile ACTIVE, seller charges-enabled, buyer has a payment method, vacation mode, KONBINI amount range.
- Slot_occupancy invariant: HELD rows go in on request, transition to BOOKED on seller accept, are released on decline / expiry / withdrawal.
- The seller's accept/decline/cancel flow, conversation creation, push notifications, Stripe authorisation timing.
- The PACKAGE vs HOURLY discriminator from ADR 0004 — orthogonal to the windowed/custom-time axis. A custom-time booking can be either pricing mode.

What changes:
- New `requested_outside_window BOOLEAN NOT NULL DEFAULT false` column on `bookings`.
- `CreateBookingUseCase` skips `findContainingWindow` when the flag is true, and requires `scheduledAt > now` instead (the window check used to be the only future-time gate for the windowed path; without it we need a light replacement).
- Buyer UI exposes a "Request a different time" affordance in Step 1 of the booking flow. Tapping it swaps the slot grid for a `DatePicker` (date + hour-aligned time, future-only).
- Seller UI shows a "Custom request" chip on the inbox card and booking detail when the flag is set — visual cue that this request did not come out of their published schedule.

## Consequences

**Positive**
- Buyers with a fixed-date need can complete the request flow without abandoning the app for a chat thread.
- The seller's calendar stays the truth — every confirmed booking, windowed or not, holds a slot_occupancy row and prevents double-booking.
- No new entity, no new table, no new accept-side handler. The seller's existing accept/decline flow handles both paths transparently.

**Negative**
- Sellers may receive requests for hours they had implicitly intended to keep free (e.g. dinner plans they didn't model as a "blocked" window). Mitigation: the explicit chip on the inbox card calls out custom-time requests, and the seller's decline action carries the same UX as any other decline.
- A buyer using the custom-time path can effectively ignore the seller's published schedule. We treat this as a feature — the schedule is a recommendation surface, not a barrier. If we later see this becoming a habit (custom-time requests dominating windowed bookings), the right answer is for sellers to publish their schedule more broadly, not to remove the custom-time path.
- The booking detail's "scheduledAt is in a window" semantic from ADR 0003 no longer holds for `requested_outside_window` rows. Anything downstream that assumes a backing window record (modifications, slot-shift proposals) needs to be aware of the flag. Current modification flow does not require the backing window — it operates on slot_occupancy keys — so this is not an immediate concern, but new modification types should consider it.

## More Information

- Backend: `prisma/migrations/20260516240000_add_booking_requested_outside_window/migration.sql` adds the column. `CreateBookingUseCase` gates `findContainingWindow` on the flag. Repository `createBooking` writes `requested_outside_window`. Read DTOs (`BookingDetailResponseDto`, `ListSellerBookingItemDto`, `ListClientBookingItemDto`) expose it.
- Buyer iOS: `BookingFlowViewModel` adds `requestedOutsideWindow` + `customScheduledAt`; `BookingFlowView` adds a toggle row that swaps the slot grid for an inline `DatePicker`.
- Seller iOS: `BookingsView` renders a "Custom request" chip on the card top row when `booking.requestedOutsideWindow` is true.
- ADR 0003's "bookings must live inside a published availability window" wording is superseded **for the windowed/custom-time axis only**. ADR 0003's slot_occupancy and account-level-calendar semantics remain authoritative.

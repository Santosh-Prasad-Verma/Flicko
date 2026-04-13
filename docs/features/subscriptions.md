# Subscriptions & Premium

> **Reading time:** ~10 minutes · **Audience:** Backend, Product Managers · **Last Updated:** 2026-04-11

Flicko monetizes via "Flicko Plus", a recurring subscription managed through Stripe that unlocks premium cosmetic and functional features across the platform. Current implementation supports both Web/Card payments via Stripe and in-app native Paywalls.

---

## Table of Contents

- [Premium Features](#premium-features)
- [Stripe Integration Architecture](#stripe-integration-architecture)
- [Webhook Handling (Source of Truth)](#webhook-handling-source-of-truth)
- [Mobile Implementation (Payment Sheet)](#mobile-implementation-payment-sheet)

---

## Premium Features

When a user's database `users.is_premium` flag is `true`, the following systems unlock:

1. **Animated Avatars:** The API validates that the avatar URL ends in `.gif` or `.webp`. If the user is not premium, the Go backend rejects the profile update.
2. **Custom Badges:** A special `flicko_plus` badge SVG renders next to their name in all server members lists.
3. **Larger Upload Limits:** The frontend File Picker allows up to 50MB (vs 10MB free limit). The Go backend upload signature generator adjusts its max-bytes policy accordingly.
4. **Higher Quality Voice:** Free voice channels default to 64kbps. Premium users force the LiveKit room to upgrade to 128kbps Opus bitrates.

---

## Stripe Integration Architecture

Flicko uses a direct API integration with Stripe for handling the complex state machines of recurring billing, cards experiencing DND (Do Not Honor), and expiration handling.

### Required Environment Variables

- `STRIPE_SECRET_KEY`: Used by the backend to create Setup Intents.
- `STRIPE_WEBHOOK_SECRET`: Used to cryptographically verify incoming webhook signatures.
- `EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY`: Bundled into the React Native app to tokenize cards directly to Stripe (PCI compliance).

---

## Webhook Handling (Source of Truth)

The mobile app NEVER tells the database "I paid successfully." All true state changes must arrive asynchronously from Stripe via Webhooks. This prevents cracked mobile clients from granting themselves premium status.

### The Webhook Listener

Route: `POST /api/v1/webhooks/stripe`

1. **Verification:** The Go middleware intercepts the raw HTTP body and calculates the HMAC signature using `STRIPE_WEBHOOK_SECRET`. If it doesn't match the `Stripe-Signature` header, the request is immediately dropped (401).
2. **Routing:** The backend parses the JSON and looks at `event.type`.
3. **Action:**
   - `checkout.session.completed`: Locates the user UUID via the metadata. Updates `is_premium = true`. Inserts Stripe Customer ID.
   - `customer.subscription.deleted` / `invoice.payment_failed`: Updates `is_premium = false`. Sends a system DM to the user alerting them of the failure.

*Note: In development, Stripe CLI must be used to forward webhooks to `localhost:8080/api/v1/webhooks/stripe`.*

---

## Mobile Implementation (Payment Sheet)

Flicko leverages `@stripe/stripe-react-native` to render a native, Apple Pay/Google Pay enabled UI that requires zero custom form development.

**Checkout Flow:**
1. User taps "Subscribe to Flicko Plus" in settings.
2. The app calls `POST /api/v1/payments/intent`.
3. The backend talks to Stripe API, creates a PaymentIntent for the subscription amount mapped to the specific user's `uuid`, and returns the `client_secret`.
4. The mobile app calls `presentPaymentSheet({ clientSecret })`. This renders the native OS sliding dialog.
5. User authenticates via FaceID or biometric. Stripe processes the card.
6. The app closes the dialog and awaits the WebSocket event (driven by the backend webhook receiver) to update the UI indicating success.

---

## Related Documentation

- [Architecture: Third-Party Integrations](../architecture/third-party-integrations.md) — External architecture footprint
- [Backend: Overview](../backend/overview.md) — Webhook routing logic

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*

# Screens and the API they use

The mobile app uses the same Flask API as the web app (`Kobydon/tabital`, branch `remediation`). The table below lists what each screen calls. Every money amount comes from these responses.

| Screen | Endpoints |
|---|---|
| Sign up | `POST /register` |
| Sign in | `POST /login`, `POST /login/2fa`; forgot password: `POST /forgot-password`, `POST /api/verify-otp`, `POST /reset-password` |
| Home | `GET /customer/upcoming-payments`, `GET /customer/credit`, `GET /customer/instalments`, `GET /customer/notifications/unread-count` |
| Shop list | `GET /customer/products`, `GET /customer/products/categories` |
| Product and plan picker | `GET /customer/products/<id>`, `GET /customer/plan-options`, `POST /installment/calculate` (the quote, schedule, `totals.total_payable`, `key_facts`) |
| Checkout | `POST /customer/purchase` (returns the Paystack `authorization_url` for Payment 1), `GET /customer/payments/config` |
| Payment result | `GET /customer/payments/paystack/verify/<reference>` |
| Plans / plan detail | `GET /customer/instalments`, `GET /customer/instalments/<plan_id>`, `GET /customer/payments/<id>/receipt` |
| Pay | `POST /customer/payments/paystack/initialize` with `{plan_id}`, `{plan_id, amount}` (part) or `{plan_id, settle: true}`; `GET /customer/plans/<id>/settlement-quote` |
| Defer | `GET/POST /customer/plans/<id>/deferment` |
| Saved cards and autopay | `GET /customer/payment-methods`, `PATCH/DELETE /customer/payment-methods/<id>` |
| Verify identity | `GET /customer/identity`, `POST /customer/identity/start`, `POST /customer/identity/<check_id>/submitted` |
| Credit limit | `GET /customer/credit`, `GET /customer/underwriting` |
| Orders | `GET /customer/orders`, `POST /customer/orders/<id>/pay` |
| Disputes | `GET/POST /customer/disputes` |
| Notifications | `GET /customer/notifications`, `POST .../<id>/read`, `POST .../mark-all-read` |
| Support | `/customer/support/ticket(s)` |
| Account | `PUT /customer/password`, `GET /customer/kyc/status` |

## What the backend still needs for the mobile app

These are small backend changes. They'll be done in the main project when the app reaches them, so the app doesn't work around them.

1. **Returning from Paystack.** Today `PAYSTACK_CALLBACK_URL` points at the web app's `/customer/payment-callback`. The app will open Paystack in an in-app browser and watch for that same URL, then call verify. That works without a backend change. A dedicated app link (`https://app.tabitalpay.com/m/payment-callback` with Android App Links) is a later improvement.
2. **Refresh tokens on a phone.** There's **no refresh endpoint** in `routes.py` yet. For now the app keeps the 60-minute access token in Keystore and sends the customer to sign-in on a 401. `JWT_REFRESH_DAYS` is 1 (evaluation R14), so customers would have to sign in again every day. Proposal: keep that, and add biometric unlock in the app, which re-signs in with a refresh token kept in Keystore. A longer mobile-only refresh lifetime needs a decision (security vs. convenience).
3. **Push notifications.** Add a push channel (Firebase Cloud Messaging) to the message outbox, with a `POST /customer/devices` endpoint to register a phone. Until then, reminders come by SMS (mNotify) and in-app.
4. **Smile ID on mobile.** `POST /customer/identity/start` returns what the web widget needs. The Flutter SDK needs the same job details. Check that the response has everything the SDK asks for.
5. **Device signals (§9D, R27).** The app can send a device ID and an emulator check with sign-in and purchase. The backend's fraud checks already flag more than 2 accounts on one device.
6. **CORS** doesn't apply to a native app. The API's rate limits and security headers apply as they are.
7. **`GET /customer/upcoming-payments` leaves out overdue payments** (it filters `due_date >= now`). Like the web Home, the app builds the next-payment card from `GET /customer/instalments` instead. Fix or retire that endpoint in the main project.
8. **Keep the Paystack callback path.** The app closes its Paystack web view when the page reaches any URL whose path ends in `/payment-callback`, then calls verify with the reference from initialize. If `PAYSTACK_CALLBACK_URL` moves to another path, tell the mobile app (`lib/core/paystack_checkout.dart`, `isPaystackCallback`).
9. **Smile ID from the app needs an on-device test against the Smile ID sandbox.** The app runs Smile ID's `smart-camera-web` (the web app's component) in a web view and uploads to `submit_url` itself, with the `smileid-token` header and the exact `fields` from `POST /customer/identity/start`. No backend change, but confirm with Smile ID that the v3 token isn't tied to a browser origin. Closing the camera doesn't use an attempt (only non-`started` checks count).
10. **`GET /customer/orders` returns a bare list**, not `{orders: [...]}`. The app reads both; nothing to change unless the main project wants one shape everywhere.
12. **With debug off, a missing or expired sign-in token gives 500, not 401.** Found 2026-10-05 running the API with `FLASK_DEBUG=0` (`.claude/dev/run_api_lan.cmd`). `GET /customer/payments/config` without a token logged `flask_praetorian.exceptions.MissingToken ... (401)` and returned **500** ("Server error" alert). With debug on it returns 401. Production runs with debug off, so the web app and the mobile app can't tell "signed out" from "server broken": the app shows "Something went wrong on our side" instead of going to sign-in, and every expired session raises a server alert. Fix in the main project: register an error handler for praetorian's errors (`PraetorianError` → its `status_code` and message) that works whatever the debug setting.
11. **The `overpaid` and `duplicate_payment` results promise a refund review, but the main project has no review queue yet (R5.c).** Until it's built, those cases rely on staff noticing them.

## Built in the app (2026-10-03)

| Screen | Route | Notes |
|---|---|---|
| Pay (this payment, part, pay off) | `/plans/:id/pay` | Part amount sent as an exact decimal string (`"300.50"`), never a float. Pay-off shows every line of the settlement quote and the total first |
| Payment result | `/payment-result/:reference` | Same outcome rules as the web `payment-callback` page. Never shows "paid" unless the server applied it |
| Move a payment back | `/plans/:id/defer?payment=` | Fee, its basis, new dates and new total from the quote; agree box; fee paid through Paystack |
| Shop, product, checkout | `/shop`, `/shop/product/:id`, `.../checkout` | Plans priced by `POST /customer/plan-options` (by product id, not a client price). Checkout sends only the choice and `accept_terms` |
| My orders | `/account/orders` | Pays an unpaid down payment again (`POST /customer/orders/<id>/pay`) |
| Verify identity | `/account/identity` | Smile ID camera in a web view, upload straight to Smile ID, then `.../submitted`, then polls every 10 s |
| Sign up | `/sign-up` | The web form's fields and checks; the server's `field` error shows on that field |

**Not in the app yet** (the web app has them): saved cards and autopay, "I've paid" claims by bank transfer, reporting a problem (disputes), forgot password, profile editing, the credit limit page, notifications, support tickets, pay links / QR from a merchant.

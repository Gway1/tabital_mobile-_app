# Mobile app guide checklist

The guide agent (the main project session) maintains this checklist. It reviews the mobile app against CLAUDE.md, the Flask API and the web app. The build session does the work and reports back. The guide re-checks and updates the status here.

**Status values:** Verified (checked by the guide) · Open · In progress · Blocked: founder · Blocked: user

## Review 1, 2026-10-04

Reviewed the code in `app/lib` and `app/android`, reading the code only. Tests weren't re-run, so they don't clash with the build session's running work.

### Verified

| ID | Item | Evidence |
|---|---|---|
| V1 | The app does no money sums. Amounts are read as pesewas and shown as `GHS 1,650.00` | `core/format.dart` |
| V2 | A part payment goes to the API as an exact decimal string, never a float | `pesewasToApi`, `parseAmountInput` |
| V3 | "Paid" only after the server verifies with Paystack; the outcome rules match the web callback page (part, settled, overpaid, duplicate, mismatch, refund) | `features/pay/payment_models.dart`, `run_checkout.dart` |
| V4 | Checkout shows Payment 1 with the delivery fee as its own line, the schedule, the total payable and key facts from the server. Terms and Privacy links use the server's URLs, falling back to the published ones | `features/shop/checkout_screen.dart`, `shop_models.dart` |
| V5 | Plans are priced by product id (`/customer/plan-options`), not by a price from the app. Checkout sends only the choice and `accept_terms` | `features/shop/` |
| V6 | The token is kept in Keystore and sent only to our API, which signs the customer out on a 401. Merchant and admin accounts are turned away | `core/api_client.dart`, `auth_controller.dart` |
| V7 | `X-Device-Id` is a random 32-hex id per install, which matches the backend's format (`fraud._DEVICE_ID_RE`) | `core/secure_store.dart` |
| V8 | `allowBackup=false`, no cleartext traffic in release, camera permission requested only for the identity check | `AndroidManifest.xml`, `MainActivity.kt` |
| V9 | Links match the published website: Terms, Privacy, Help, info@tabitalpay.com | `core/config.dart` |

### Open (in priority order)

| ID | Item | Why | Done when |
|---|---|---|---|
| M1 | **Release signing.** The release build is signed with the debug key (`build.gradle`, `signingConfigs.debug`) | A debug-signed APK can't go to the Play Store or be updated safely. Never commit the upload key | The release build type uses a `key.properties` + keystore kept outside the repo (git-ignored); `docs/release.md` explains it. The keystore itself is created by the user |
| M2 | **Hide sensitive screens** (`FLAG_SECURE`) on pay, checkout, the payment result, identity, plan detail and account | Design brief §7. Stops screenshots and the app-switcher preview showing balances or ID | Set on those routes (a MethodChannel or a small plugin), cleared when leaving; a test checks the route list |
| M3 | **Device flags** `X-Device-Flags: emulator` (and `rooted` if detectable) | The backend already reads it and flags it for fraud review (§9D; R27 in the main project) | Sent on every request from an emulator; a unit test covers the header. Needs a package such as `device_info_plus`, **so ask the user first** |
| M4 | **Restrict the Paystack web view to https.** Today it loads any http(s) page | It's a payment page, so plain http must never load inside it | `onNavigationRequest` blocks `http:`; other schemes still go to the bank or USSD app; a test covers it |
| M5 | **Report a problem (disputes)** on plan detail: `GET/POST /customer/disputes` | Buyer protection is a promise on the website, and it pauses the plan (21 days) | Same fields and rules as the web instalments screen; widget test |
| M6 | **Forgot password**: `/forgot-password` → `/api/verify-otp` → `/reset-password` | Without it, a customer locked out of the app has to use the website | Flow built; errors shown from the server; widget test |
| M7 | **Notifications screen** (`/customer/notifications`, unread count on Home's bell) | Approval of an order and reminders are delivered in-app until push exists | List, mark read, mark all read; widget test |
| M8 | **Saved cards and autopay** (opt-in, with a confirm step) | Phase 4 default: autopay is opt-in with retries | Matches the web make-payment screen; widget test |
| M9 | **App lock**: biometric or device PIN after 5 minutes in the background | Design brief §7. The token stays valid for 60 minutes on a shared phone | Uses `local_auth`, **so ask the user first**; falls back to signing in again |
| M10 | **Account page**: Help (tabitalpay.com/help), support contact, legal entity line (Tabital Pay Ltd, CS 117960626), Terms version | Founder asked that the app reuse the Help page | Shown on Account; tested |
| M11 | **"I've paid" bank transfer claims, support tickets, merchant pay links / QR** | They exist on the web; lower priority for the first release | Built, or listed as "web only" in the README with the founder's OK |
| M12 | **Accessibility pass**: 360 dp width, text scaled to 130%, screen reader labels on amounts and statuses | Design brief §6 | Golden or widget tests at a 1.3 text scale for Home, Pay and Checkout |
| M13 | **Offline**: cached plans with "last updated", pull to refresh; payments always need a live connection | Design brief §6 | Home and Plans show cached data offline; Pay is disabled offline |

### For the main project (backend), logged in `docs/screens_and_api.md`

- No refresh endpoint; a refresh flow, or the biometric re-sign-in decision.
- `GET /customer/upcoming-payments` leaves out overdue payments.
- Push notifications (FCM) and `POST /customer/devices`.
- R5.c, the refund-review queue: the "overpaid" and "duplicate" results the app shows promise a review that has no admin screen yet.

### Blocked

| ID | Item | Waiting on |
|---|---|---|
| ~~B1~~ | The real logo and app icon. **Unblocked 2026-10-04:** the user said to use the website's logo. Now **M14** below | — |

### Added 2026-10-04

| ID | Item | Why | Done when |
|---|---|---|---|
| M14 | **Real logo and app icon** from tabitalpay.com. Launcher icon: `https://tabitalpay.com/wp-content/uploads/2026/09/tabital-pay-site-icon-512.png` (gold mark on navy, 512×512). In-app logo: `https://tabitalpay.com/wp-content/uploads/2026/09/tabital-pay-mark-256.png` (gold mark, transparent, 256×256). The user approved downloading these two files | User decision 2026-10-04 replaces the gold "T" placeholder | Saved in `app/assets/brand/` with a note of the source URLs. The Android launcher icons are generated for every density, plus an adaptive icon (navy background `#02163F`, mark as foreground inside the 66 dp safe zone). The in-app "T" (Welcome, sign-in, app bar) is replaced by the mark. The web build's favicon and manifest icons are updated too. Screenshots of the launcher icon and Welcome. If the 256 px mark looks soft at large sizes, note it and ask the founder for an SVG or 1024 px version |
| B2 | Smile ID sandbox test on a real phone (`smart-camera-web` in a web view) | User / Smile ID account (Ghana enabled, `id_type` confirmed) |
| B3 | Play Store listing, data safety form, release keystore | User / founder |

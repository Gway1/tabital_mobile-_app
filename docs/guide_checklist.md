# Mobile app guide checklist

The guide agent (the main project session) maintains this checklist. It reviews the mobile app against CLAUDE.md, the Flask API and the web app. The build session does the work and reports back. The guide re-checks and updates the status here.

IDs are **G1–G14** (guide items). The standing reviewer's `review_log.md` uses its own IDs (M1, T1, A1…), and the two lists don't share numbers.

**Status values:** Verified (checked by the guide) · Open · In progress · Blocked: founder · Blocked: user

## Review 4, 2026-10-06 (Batch C)

`flutter analyze`: **no issues**. `flutter test`: **115 passed** (up from 104). I re-ran both myself.

| ID | Status | Evidence / notes |
|---|---|---|
| G18 missing amount | **Verified** | `CheckoutStart.tryParse` rejects a missing, zero or non-numeric amount; the re-confirm check is now unconditional; tests cover both |
| G8 cards and autopay | **Verified** | Fields match `PaymentMethod.to_dict` (type, bank, last4, expiry, reusable, autopay). `PUT` / `DELETE /customer/payment-methods/<id>` match `servicing.py:52-79` (G8 in review 1 said PATCH, which was the guide's error). Opt-in confirm uses the web wording; non-reusable cards get no autopay, the same as the API's check |
| G10 Account page | **Verified** | Help, info@tabitalpay.com, Terms and Privacy, the legal line, and the accepted Terms version and date from `GET /account/consents` (`terms_version_accepted`). The marketing switch uses `PUT /account/consents {marketing_consent}`, which matches the API. Nothing is hard-coded |

**Open:** G9 (app lock: the build session is asking the user about `local_auth`), G11, G12, G13.

**Next: Batch E** (G12 accessibility, G13 offline) while G9 waits for the user. Then Batch F (G11).

## Review 3, 2026-10-06 (Batch B)

`flutter analyze`: **no issues**. `flutter test`: **104 passed** (up from 81). I re-ran both myself.

| ID | Status | Evidence / notes |
|---|---|---|
| G5 report a problem | **Verified** | The reasons (`support_models.dart:6-10`) are exactly the API's `DISPUTE_REASONS` (`tabital/app/resources/servicing.py:15`) and the web select. "Open" means `open` / `under_review` / `escalated`, which matches `models/dispute.py:26`. Defer and a new report are hidden while one is open |
| G6 forgot password | **Verified** | Email, then code, then new password (10+), against `/forgot-password` (email only, `auth_service.py:232-250`), `/api/verify-otp` and `/reset-password`. Email-only reset is logged as backend gap #15 |
| G7 notifications and bell | **Verified** | Uses the real `/notifications` inbox. `appRouteForLink` only ever opens the app's own screens and never loads a web address from a notification, which is safe. `/customer/payments/<id>` maps to plan `<id>`, which is correct because the backend puts `payment.plan_id` in that link |
| G2 follow-up | **Verified** | `/home`, `/plans` and `/notifications` are now hidden too |
| G3 device flags | **Verified** | `X-Device-Flags: emulator` from `MainActivity.isEmulator()` (fingerprint, hardware goldfish/ranchu, generic brand/device), sent only when set. It matches `fraud.record_device`, which flags `emulator`. No package was added |
| G15 README | **Verified** | No null bytes; UTF-8 |
| Reviewer M1 re-confirm amount | **Verified**, one gap | `run_checkout.dart:14-48`: if the server's amount differs from what the customer agreed to, a dialog shows both amounts before Paystack opens. It's used by pay, defer, checkout and orders. See G18 |

**New finding**

| ID | Sev | Item | Fix |
|---|---|---|---|
| G18 | Medium | `runCheckout` skips the check when `start.amount` is 0. `CheckoutStart.tryParse` gives 0 when the response has no `amount`, so Paystack would open without the customer seeing the amount. All four API responses send `amount` today (`customer_purchase.py:226`, `deferments.py:85`, `paystack_payments.py`), so this is a guard against change, not a live bug | Treat a missing or zero amount as "can't start the payment": show an error and don't open Paystack. Add a test |

**Backend gaps 13–16** (paused flag, `/customer/notifications` stubs, email-only and off-brand reset emails, `min_part_payment` / "in plans" / verify details) are noted for the main project.

**Next: Batch C**: G8 saved cards and autopay, G10 Account page, plus G18.

## Review 2, 2026-10-06 (Batch A)

Read the code, then ran `flutter analyze` (**no issues**) and `flutter test` (**81 passed**, up from 72). The build session was idle at the time.

| ID | Status | Evidence / notes |
|---|---|---|
| G1 release signing | **Verified** | `android/app/build.gradle.kts:10-60` reads `key.properties`. Without it the release build is **unsigned, never debug-signed**, with a warning. `key.properties`, `*.jks` and `*.keystore` are git-ignored (`android/.gitignore`), and the first GitHub commit contains none of them. `docs/release.md` is present. The user still has to create the upload key (B3) |
| G2 hide sensitive screens | **Verified**, one follow-up | `lib/core/secure_window.dart`: `FLAG_SECURE` on plan detail/pay/defer, the payment result, checkout and all of Account, switched on route change (`app.dart:151-160`), with tests in `test/security_test.dart`. **Follow-up (Low):** Home and the Plans list also show balances and the next amount; add `/home` and `/plans` |
| G4 Paystack web view | **Verified** | `checkoutNavigation`: https loads; http, javascript, file, data, content and blob are blocked; bank/USSD links open outside. `CheckoutStart.tryParse` accepts checkout URLs only on Paystack's own hosts (`isPaystackCheckoutUrl`), and tests cover look-alike hosts |
| G14 logo and icon | **Verified** | Adaptive icon (navy background, gold mark, monochrome layer) for every density. The in-app mark is `assets/brand/mark.png` (1024 px). It was made from the main project's 1182×889 original (`tabital_front/brand/source/mark.png`), which is the same artwork as the website, so the 256 px concern no longer applies. Source documented in `assets/brand/README.md` |

**New findings**

| ID | Sev | Item | Fix |
|---|---|---|---|
| G15 | Low | The last line of `README.md` is UTF-16 text (`# t a b i t a l _ m o b i l e - _ a p p`, with null bytes), probably from GitHub's `echo "# …" >> README.md` run in PowerShell. It shows as garbage on GitHub | Delete that line, or rewrite it in UTF-8 |
| G16 | Info | `dev/seed_demo_customer.py` (now on GitHub) contains local demo passwords. It refuses to run unless `DATABASE_URL` is SQLite, which is fine for local use. If the repo is public, keep it that way: never reuse those passwords anywhere real | No change needed. Confirm with the user whether `Gway1/tabital_mobile-_app` is private |
| G17 | Info, backend | With debug off, a missing or expired token gives **500, not 401** (the app's `screens_and_api.md` #12). The guide confirmed it: flask_restful turns praetorian's errors into 500s outside debug and testing. That's a main-project fix, waiting on the user | App side: nothing to change. Keep treating 401 as signed out |

**Next:** Batch B (G5 disputes, G6 forgot password, G7 notifications and the bell), plus the G2 follow-up and G15. Also clear the standing reviewer's round 1 Top 5 that Batch A didn't cover: M1 (re-confirm a changed amount before Paystack), A1–A3 and X1/X2/D5.

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
| G1 | **Release signing.** The release build is signed with the debug key (`build.gradle`, `signingConfigs.debug`) | A debug-signed APK can't go to the Play Store or be updated safely. Never commit the upload key | The release build type uses a `key.properties` + keystore kept outside the repo (git-ignored); `docs/release.md` explains it. The keystore itself is created by the user |
| G2 | **Hide sensitive screens** (`FLAG_SECURE`) on pay, checkout, the payment result, identity, plan detail and account | Design brief §7. Stops screenshots and the app-switcher preview showing balances or ID | Set on those routes (a MethodChannel or a small plugin), cleared when leaving; a test checks the route list |
| G3 | **Device flags** `X-Device-Flags: emulator` (and `rooted` if detectable) | The backend already reads it and flags it for fraud review (§9D; R27 in the main project) | Sent on every request from an emulator; a unit test covers the header. Needs a package such as `device_info_plus`, **so ask the user first** |
| G4 | **Restrict the Paystack web view to https.** Today it loads any http(s) page | It's a payment page, so plain http must never load inside it | `onNavigationRequest` blocks `http:`; other schemes still go to the bank or USSD app; a test covers it |
| G5 | **Report a problem (disputes)** on plan detail: `GET/POST /customer/disputes` | Buyer protection is a promise on the website, and it pauses the plan (21 days) | Same fields and rules as the web instalments screen; widget test |
| G6 | **Forgot password**: `/forgot-password` → `/api/verify-otp` → `/reset-password` | Without it, a customer locked out of the app has to use the website | Flow built; errors shown from the server; widget test |
| G7 | **Notifications screen** (`/customer/notifications`, unread count on Home's bell) | Approval of an order and reminders are delivered in-app until push exists | List, mark read, mark all read; widget test |
| G8 | **Saved cards and autopay** (opt-in, with a confirm step) | Phase 4 default: autopay is opt-in with retries | Matches the web make-payment screen; widget test |
| G9 | **App lock**: biometric or device PIN after 5 minutes in the background | Design brief §7. The token stays valid for 60 minutes on a shared phone | Uses `local_auth`, **so ask the user first**; falls back to signing in again |
| G10 | **Account page**: Help (tabitalpay.com/help), support contact, legal entity line (Tabital Pay Ltd, CS 117960626), Terms version | Founder asked that the app reuse the Help page | Shown on Account; tested |
| G11 | **"I've paid" bank transfer claims, support tickets, merchant pay links / QR** | They exist on the web; lower priority for the first release | Built, or listed as "web only" in the README with the founder's OK |
| G12 | **Accessibility pass**: 360 dp width, text scaled to 130%, screen reader labels on amounts and statuses | Design brief §6 | Golden or widget tests at a 1.3 text scale for Home, Pay and Checkout |
| G13 | **Offline**: cached plans with "last updated", pull to refresh; payments always need a live connection | Design brief §6 | Home and Plans show cached data offline; Pay is disabled offline |

### For the main project (backend), logged in `docs/screens_and_api.md`

- No refresh endpoint; a refresh flow, or the biometric re-sign-in decision.
- `GET /customer/upcoming-payments` leaves out overdue payments.
- Push notifications (FCM) and `POST /customer/devices`.
- R5.c, the refund-review queue: the "overpaid" and "duplicate" results the app shows promise a review that has no admin screen yet.

### Blocked

| ID | Item | Waiting on |
|---|---|---|
| ~~B1~~ | The real logo and app icon. **Unblocked 2026-10-04:** the user said to use the website's logo. Now **G14** below | — |

### Added 2026-10-04

| ID | Item | Why | Done when |
|---|---|---|---|
| G14 | **Real logo and app icon** from tabitalpay.com. Launcher icon: `https://tabitalpay.com/wp-content/uploads/2026/09/tabital-pay-site-icon-512.png` (gold mark on navy, 512×512). In-app logo: `https://tabitalpay.com/wp-content/uploads/2026/09/tabital-pay-mark-256.png` (gold mark, transparent, 256×256). The user approved downloading these two files | User decision 2026-10-04 replaces the gold "T" placeholder | Saved in `app/assets/brand/` with a note of the source URLs. The Android launcher icons are generated for every density, plus an adaptive icon (navy background `#02163F`, mark as foreground inside the 66 dp safe zone). The in-app "T" (Welcome, sign-in, app bar) is replaced by the mark. The web build's favicon and manifest icons are updated too. Screenshots of the launcher icon and Welcome. If the 256 px mark looks soft at large sizes, note it and ask the founder for an SVG or 1024 px version |
| B2 | Smile ID sandbox test on a real phone (`smart-camera-web` in a web view) | User / Smile ID account (Ghana enabled, `id_type` confirmed) |
| B3 | Play Store listing, data safety form, release keystore | User / founder |

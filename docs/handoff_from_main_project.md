# Handoff: from the main project to the mobile app session (2026-10-03)

This file gives the mobile app session everything it needs from the main project (the Flask API and the Angular web app). Read it, along with `../../CLAUDE.md`, before starting.

## 1. Sources of truth, in order

1. **`CLAUDE.md`** (one folder up from this app folder): the business rules, plan maths (§5), fees (§6), risk (§8), fraud (§9) and every founder decision (§13.1). It wins over everything else.
2. **The Flask API** in `tabital/` (repo `Kobydon/tabital`, branch **`remediation`**). It has all the money logic. The mobile app calls it and never does its own sums.
3. **The Angular web app** in `tabital_front/` (repo `Kobydon/tabital_front`, branch `remediation`). It's the working reference for every customer screen. Copy its behaviour and wording, not its code.
4. **This folder's docs:** `README.md`, `docs/design_brief.md`, `docs/screens_and_api.md`, and `design/prototype.html` (the approved-for-review design).

## 2. Where to look in the main project

| Need | File |
|---|---|
| Every API call a customer screen makes, with the request bodies | `tabital_front/src/app/customers.service.ts` |
| Shop, plan quote, checkout (Payment 1 through Paystack) | `tabital_front/src/app/customer/shop/shop.component.ts` and `.html` |
| Pay: this payment / part / pay off (R5) | `tabital_front/src/app/customer/make-payment/` |
| Paystack return and verify; outcomes `applied`, `part`, `settled`, `overpaid`, `duplicate_payment`, `amount_mismatch`, `refund_required`, `deferred` | `tabital_front/src/app/customer/payment-callback/` |
| Plans, schedule, deferment, disputes | `tabital_front/src/app/customer/customer-instalments/` |
| Pay links / QR from a merchant | `tabital_front/src/app/customer/pay-link/` |
| Identity (Smile ID) flow | `tabital_front/src/app/shared/identity.module.ts`, `tabital/app/services/identity.py`, `tabital/docs/identity_fraud.md` |
| Design tokens (Vault) | `tabital_front/src/styles/_tokens.scss` |
| Shared UI copy and patterns | `tabital_front/src/app/ui/` |
| Unit tests that show the expected behaviour of the money screens | `tabital_front/src/app/**/*.money.spec.ts` |
| Routes (every endpoint) | `tabital/app/routes.py` |
| Paystack initialize / verify / settlement quote | `tabital/app/resources/paystack_payments.py`, `tabital/app/services/payments.py` |
| Plan quote, schedule, key facts | `tabital/app/resources/` (`/installment/calculate`, `/customer/plan-options`) |
| Deferment rules | `tabital/docs/deferment.md` |
| Servicing: reminders, autopay, part payments, pay off early | `tabital/docs/servicing.md` |
| Underwriting (tiers, limit) | `tabital/docs/` and `tabital/app/services/risk.py` |
| Settings (rates are never hard-coded) | `tabital/app/services/business_settings.py` |
| Auth: JWT (flask_praetorian), 2FA, access lifetime 60 min, refresh 1 day | `tabital/app/config.py`, `tabital/app/services/auth_service.py` |
| Running the API locally | `tabital/docs/dev_setup.md` |

## 3. Status of the main project (paused by the user, 2026-10-03)

- The remediation of the Launch Readiness Evaluation is tracked in `QA/launch_remediation_checklist.md`: 87 rows, 67 fully resolved.
- Its next item is **R5.c, a refund-review queue**, then R9 + R25, R22–R24, R17.b, R26 + R27. **Don't work on these from the mobile session.**
- Backend changes the mobile app needs are listed in `docs/screens_and_api.md` ("What the backend still needs"). Note them for the main project rather than editing `tabital/` from here, unless the user says otherwise.

## 4. Website (published 2026-10-03, from the website session)

- Terms: https://tabitalpay.com/elementor-page-3332/ (version 2026-10-03)
- Privacy Policy: https://tabitalpay.com/privacy-policy/ (only this URL; `/privacy-policy-2/` is gone)
- Merchant Agreement: https://tabitalpay.com/merchant-agreement/
- Help (the founder wants the app to use it): https://tabitalpay.com/help/
- Legal entity for footers and receipts: Tabital Pay Ltd, registration CS 117960626; 37 Hillview St. (GZ-097-6119), 7th Avenue, Greda Estate, Teshie, Accra; +233 50 395 0453; info@tabitalpay.com, customerservice@tabitalpay.com

## 5. Working rules carried over from the main project

- **Secrets:** never read `.env` or credential files, and never ask the user to paste API keys or secrets.
- **Logins:** don't type passwords into sign-in forms, even for local test accounts.
- **GitHub:** don't push. The user pushes.
- **Downloads:** downloading files, SDKs or packages needs the user's explicit permission first (say what, from where, and how big). The Flutter SDK, JDK and Android SDK are **not installed** yet.
- **Deleting:** don't delete files without asking.
- **Money:** amounts come from the server. Show the full schedule and the total payable before the customer agrees. Write money as `GHS 1,650.00`. Don't write rates into UI text; use the server's `key_facts`.
- **Design:** Vault. Navy-led; gold only for the one main action, with navy text; Poppins headings; Lucide icons; no emoji. A large next-payment card and a sticky pay bar on Home.
- **Scope:** customers only, Phase 1 plans (Full, Pay in 2/3/4). Extended 6/12-month plans show "Coming soon" (D12).

## 6. Where the mobile app stands

- **Done:** the design brief (16 screens), the screen-to-API map and a clickable prototype of 12 screens.
- **Waiting on the user:**
  1. Feedback on the prototype.
  2. Permission to install Flutter (stable) and Android Studio (Android SDK, emulator, JDK 17), about 3–4 GB, or the user installs them.
- **Then:**
  1. `flutter create --org com.tabitalpay --project-name tabital_pay --platforms android app`.
  2. Set up the theme from the Vault tokens, the API client (base URL per environment, JWT in memory, refresh token in `flutter_secure_storage`), sign in, and Home against the real API.
  3. Write widget tests for every money screen, matching the web app's `*.money.spec.ts`.

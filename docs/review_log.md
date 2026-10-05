# Mobile app review log

Standing reviewer for the Tabital Pay customer app (Flutter). Each round adds a dated section at the top. Findings say what to fix; the reviewer doesn't edit the code.

Severity: **Blocker** (must not ship / breaks a money rule) · **High** (fix before any customer uses it) · **Medium** (fix before release) · **Low** (polish, or later).

---

## Round 1: 2026-10-04

**Scope:** everything in `app/lib/` (41 files) and `app/test/` (12 files), Android manifest, Gradle and `MainActivity.kt`, `docs/*.md`, `design/prototype.html`. Compared with `tabital/` (branch `remediation`, HEAD `b256288`) and `tabital_front/` (branch `remediation`, HEAD `2585922`) and CLAUDE.md.

**Test run:** `flutter test` gives **72 tests, all passed** (about 9 s).

### What already matches (no action)

- **No money is calculated in the app.** A search of `lib/` finds no arithmetic on amounts. The only divisions are progress-bar ratios (`next_payment_card.dart:72`, `plan_detail_screen.dart:91`, `limit_screen.dart:46`), and they're for display only. Amounts are held as `int` pesewas (`format.dart:10-16`). A typed part payment is parsed with a regex into pesewas and sent as an exact decimal string (`format.dart:64-75`, `customer_repository.dart:78`), which matches `Decimal(str(data['amount']))` in `paystack_payments.py:84`.
- **The server prices everything.** Plans come from `POST /customer/plan-options` by product id (`customer_repository.dart:151-155`). Checkout sends only the choice and `accept_terms` (`customer_repository.dart:167-173`), as `customer_purchase.py:41-51` expects.
- **§12 disclosure:** product and checkout show Payment 1, the delivery fee as its own line, every later payment with its date, the total payable and the key facts before the agree box (`checkout_screen.dart:143-178`, `product_screen.dart:319-350`). Every rate in the key facts comes from `key_facts` (`checkout_screen.dart:219-231`, from `system_settings.py:140-156`).
- **D3:** the delivery fee appears only on Payment 1 (`product_screen.dart:339-341`, `checkout_screen.dart:151`). **D12:** a disabled "6 and 12 months / Coming soon" tile (`product_screen.dart:281-303`). **D13:** the order goes to Paystack for Payment 1, and an unpaid order can be paid again from My orders (`orders_screen.dart:38-53`).
- **Paid only when the server says so:** the outcome mapping in `payment_models.dart:66-84` matches the web `payment-callback.component.ts:45-69` one for one. The app always calls verify after the web view closes (`run_checkout.dart:9-18`).
- **Deferment:** the quote fields match `services/deferment.py` (`fee_base`, `fee_percentage`, `schedule[].new_due_date`, `total_payable_before/after`, `deferments_left`, `online_payment`). There's an agree box, the fee is paid through Paystack, and the dates move only after verify. The note "won't count towards a limit increase" is **more accurate than the web app** (see W5).
- **Design tokens:** `tokens.dart` matches `_tokens.scss` exactly (gold `#F5B700`, navy `#02163F`, navy-2 `#0A2D73`, text, muted, line and the status colours). Gold buttons have navy text (`theme.dart:74-85`). Icons are Lucide, there's no emoji, money is shown as `GHS 1,650.00`, and the tagline "Own It Today. Pay Later." matches CLAUDE.md. Support is `info@tabitalpay.com` (`config.dart:9`).
- **Security basics:** no secrets in the app. `usesCleartextTraffic="false"`, `allowBackup="false"`. Smile ID uploads go straight to Smile ID without Tabital's token (`smile_capture.dart:161-176`). The camera web view grants only the camera permission and can't navigate away (`smile_capture.dart:82-99`). The device id matches the backend regex `^[A-Za-z0-9_-]{8,64}$` (32 hex characters, `secure_store.dart:61-70`).

### Findings

#### Money

| # | Sev | Where (app) | Breaks | Fix |
|---|---|---|---|---|
| M1 | **High** | `checkout_screen.dart:81-92`; `pay_screen.dart:95-101`; `defer_screen.dart:45-47` | §12: the customer must see and agree to the amount they pay | The app shows a quoted figure ("Pay GHS 1,650.00", "Pay GHS 880.00", "Pay GHS 80.00 and move it"), then opens Paystack for whatever `amount` the start call returns, **without comparing the two**. If the price, a setting or a late fee changed between the quote and the tap (for example a late fee added at midnight), the customer is charged a different amount from the one they agreed to. `/customer/purchase` returns `due_now`, `total_payable` and `payment_schedule` (`customer_purchase.py:161-167`), and initialize and deferment return `amount`. Fix: if `CheckoutStart.amount` (or `due_now`/`total_payable`) differs from the figure shown, don't open Paystack. Show the new figures and schedule and ask the customer to agree again. For an order, it stays `awaiting_payment`, so it can be paid from My orders. Add a test for each of the three screens. |
| M2 | Low | `plan_models.dart:30, 109` vs `pay_screen.dart:59-61` | Consistency with `payments.py:12` (`PAYABLE_STATUSES` includes `pending_verification`) | Home's next-payment card skips `pending_verification`, but the Pay screen and the server don't. So Home can show "Pay GHS 800 (Payment 2)" while the Pay screen opens on Payment 1, "being checked". Use the same rule in both places: show "Down payment being checked" on Home and hide the pay bar for that plan. |
| M3 | Low | `pay_screen.dart:77-85` | Prototype S11 ("The smallest part payment is GHS 10.00"); `paystack_payments.py:83-91` (`min_part_payment`) | The app checks only the upper limit. The server refuses amounts below the minimum, and the app does show that error. Once the backend exposes the minimum (B1), show it under the field and disable Pay below it. Don't write "10" in the app. |

#### API parity

| # | Sev | Where | Reference | Fix |
|---|---|---|---|---|
| A1 | Medium | `sign_in_screen.dart:74` (hint `024 123 4567`); `auth_controller.dart:31` sends `phone.trim()` | `auth_service.py:132` matches the stored phone exactly. Sign-up stores it without spaces (`sign_up_screen.dart:111`) | A customer who types the number the way the hint shows it gets "Invalid phone or password". Strip spaces (and dashes) before sending, as sign-up does, and change the hint to `0241234567`. |
| A2 | Medium | `api_client.dart:69-72`, `auth_controller.dart:69-74` | `tabital/app/__init__.py:145` returns 401 with `code: account_inactive`; the web shows a different message (`auth.ts:72-74`) | A suspended account currently sees "You were signed out to keep your account safe". Read `body['code']`. For `account_inactive`, show the web wording: "Your account isn't active any more. Please contact Tabital." |
| A3 | Medium | `api_client.dart:43` | §9D; `fraud.py:83, 114` reads `X-Device-Flags` and flags `emulator`; screens_and_api #5 | The app sends `X-Device-Id` but never `X-Device-Flags`. Send `emulator` when the build is running on an emulator (from `Build.FINGERPRINT`/`isPhysicalDevice` through a small platform channel; no new package needed). |
| A4 | Low | `payment_result_screen.dart:31-35` | web `payment-callback.money.spec.ts:75` ("shows an error without a reference, and asks nothing of the server") | With an empty `:ref`, the app calls `verify/`. Show the error panel straight away instead. |
| A5 | Low | `api_client.dart:34-35` | `screens_and_api.md` (saved cards `PATCH/DELETE`, password `PUT`) | Only GET and POST exist. Add `put`, `patch` and `delete` before the saved-cards and password screens. |
| A6 | Low | `docs/screens_and_api.md`, table row "Product and plan picker" | `routes.py:510`, `customer_product.py:129` (POST) | The doc says `GET /customer/plan-options` and lists `/installment/calculate`, which the app doesn't call. Correct the doc to `POST /customer/plan-options` with `{product_id, quantity}`. |

#### Wording

| # | Sev | Where | Reference | Fix |
|---|---|---|---|---|
| W1 | Low | `limit_screen.dart:96` "A late payment lowers it" (also prototype S14) | D14: a late payment cleared within the 7-day grace window with its fee never lowers the limit; late payments stop counting after 12 months | It isn't wrong, but it's stronger than the rule. Use "A late payment can lower it". Don't add day counts unless the server sends them. |
| W2 | Low | `pay_screen.dart:257`, `identity_screen.dart:237` | `config.dart:9` | `info@tabitalpay.com` is written out in the text. Use `AppConfig.supportEmail` so it only exists in one place. |
| W3 | Low | `home_screen.dart:93-95` vs prototype S4b ("…another late fee from being added at 31 days") | Rates and days come from the server | The app's wording leaves out the day count. That's correct. Keep it, or take `second_late_fee_after_days` from the server if a figure is wanted. No change needed. |
| W4 | Low | `checkout_screen.dart:221-223` | `key_facts.second_late_fee_percentage` may be 0 | The sentence always adds "and another X% from Y days". If the second fee is 0, leave that clause out. |
| W5 | Low (main project) | web `customer-instalments.component.html:245`: "doesn't affect your credit limit" | CLAUDE.md deferment defaults (`deferred_plans_count_as_clean` = false: no limit growth) | The app's wording is right and the web's isn't. Note it for the main project. |

#### Design fidelity (screen by screen against `prototype.html`)

| Screen | Status | Differences still open |
|---|---|---|
| S1 Welcome | Close match | It uses the placeholder "T" (see B-1). |
| S4 Home | Close match (navy greeting, overlapping `.next` card, chips, progress, limit card, plan-mini, sticky pay bar) | **D1 (Low):** the notification bell with an unread dot in the header is missing (notifications aren't built yet). Plan-mini uses a `package` icon, while the prototype uses a category icon. |
| S4b Home overdue | Match | The late-fee line leaves out "(10%)". That's intended, so no rate is written into the app. |
| S5 Shop | Match | It adds "+ delivery" to the teaser, the same as the web. |
| S6 Product | Match | |
| S7 Checkout | Mostly | **D2 (Low):** the prototype shows a saved address with "Change". The app has an empty text field. Fill it in from the profile address (sign-up collects it). |
| S9 Result | Match | The steps are generic. The prototype names the merchant and the first due date, which needs B4. |
| S10 Plan detail | Partial | **D3 (Medium):** the **Receipts** button (`GET /customer/payments/<id>/receipt`) is missing. Payment 1 doesn't show "incl. GHS 50 delivery" (needs B3). |
| S11 Pay | Match | The "Pay with" card is generic (no saved card or autopay chip), because saved cards aren't built. |
| S12 Defer | Match | |
| S13 Identity | Match | |
| S14 Limit | Close match | **D4 (Low):** the legend leaves out the amounts ("In plans GHS 4,000"). Showing them needs a server `used_limit` (B2), so the app doesn't subtract. |

Cross-cutting:

- **D5 (Medium) touch targets under 48 dp** (design brief §1, §6): the `CheckRow` checkbox is boxed to 32×32 (`vault.dart:242-246`), and it guards the Terms and the deferment consent. `Segmented` is 40 high (`vault.dart:333`). The quantity stepper uses `VisualDensity.compact` (`product_screen.dart:213-224`). Fix: make the whole row tappable (wrap it in `InkWell`/`MergeSemantics`, and tapping the sentence toggles the box, outside links), and use height 48 in `Segmented`.
- **D6 (Low) type under 13 sp:** nav labels 11, chips and captions 12, facts 12.5. These copy the prototype but break the brief's "13 sp minimum". Decide which one wins, and update the brief or the sizes.
- **D7 (Low):** on My orders, every order awaiting payment gets its own gold button (`orders_screen.dart:120-127`). With two or more, there's more than one gold action on the screen. Make the first one gold and the rest outlined.
- **D8 (Low):** there's no dark theme (`app.dart:168`). The brief §1 says there is one "from the start", but the prototype is light only. Update the brief so the two agree.

#### Brand and logo

| # | Sev | Where | Reference | Fix |
|---|---|---|---|---|
| B-1 | **High** | `android/app/src/main/res/mipmap-*/ic_launcher.png` is the **default Flutter logo** (blue "F"); `web/favicon.png` likewise. `widgets.dart:114-136` `TabitalMark` is the gold "T" placeholder (Welcome) | **The real logo already exists in the main project.** `tabital_front/src/assets/brand/` (commit `6082925`, 2026-09-26, "Real Tabital logo") has `mark-32/64/128/256.png` (transparent gold mark), `icon-192.png` and `icon-512.png` (maskable, gold mark on navy `#02163F`), `apple-touch-icon.png` (180), `favicon.ico`, and `logo-on-navy@1x/@2x.png` (48/96 px high; the mark only). Source: `tabital_front/brand/source/mark.png` (1182×889 RGBA, cleaned) and `tabital-mark-original.webp`. The web app uses it on the login and sign-up pages and in all three shells, and tabitalpay.com uses `mark-256.png` beside "Tabital Pay" text (`Tabital Website/changes.md`, 2026-09-27). There's no wordmark file: the wordmark is Poppins text. | (1) Copy `mark-256.png` (and `logo-on-navy@2x.png`) into `app/assets/brand/` and show the mark on Welcome instead of the "T", with "Tabital Pay" in Poppins beside it, as the web does. (2) Make the Android launcher icon from `icon-512.png`: an adaptive icon with a navy `#02163F` background and the gold mark as the foreground, within the 66 % safe zone. Produce the mipmap PNGs with the existing `brand/prepare_logo.py`, or by hand. Don't add `flutter_launcher_icons` without the user's permission (it's a download). (3) Set the launch background to navy with the mark, not white. (4) Tell the main project that CLAUDE.md's "The real logo file will be supplied… Until then the app uses a gold 'T' mark" is out of date. |
| B-2 | Low | `report.json` warnings | The mark on white is 1.75–2.5:1 (below WCAG 3:1 for graphics) | Show the mark on navy (Welcome, launcher) or inside a navy tile. Don't place it bare on white surfaces. |

Colours, the tagline and the support contact all match (see "What already matches").

#### Architecture and security

| # | Sev | Where | Reference | Fix |
|---|---|---|---|---|
| T1 | **High** | `MainActivity.kt` (no `FLAG_SECURE` anywhere) | Design brief §7: "hides its contents in the app switcher (`FLAG_SECURE` on payment and identity screens)" | Payment, plan, Paystack and selfie screens show up in the recents thumbnail and in screenshots. Add a method channel (`secure on/off`) that sets `WindowManager.LayoutParams.FLAG_SECURE`, and turn it on for `/plans/*`, `/payment-result`, Paystack, identity and checkout. The simplest option is to turn it on for the whole app. |
| T2 | Medium | `paystack_checkout.dart:54-66`; `payment_models.dart:17-19` | Web-view security | `authorization_url` is accepted from any https host, and the web view then navigates anywhere over http(s) with unrestricted JavaScript. Accept the start URL only when its host is `checkout.paystack.com` (or a `*.paystack.com`/`*.paystack.co` host). Keep allowing later navigations, because 3-D Secure goes to bank domains, but show the current host in the app bar so the customer can see where they are. |
| T3 | Medium | `theme.dart:11-16` (`google_fonts`) | Brief §1 (slow mobile data), §7 (privacy) | Fonts are downloaded from Google at run time. The first launch on slow data, or offline, falls back to Roboto, and every start contacts Google. Bundle Poppins (500/600/700) and Open Sans (400/600/700) TTFs (both OFL) under `assets/fonts` and set `GoogleFonts.config.allowRuntimeFetching = false`. Getting the font files is a download, so ask the user first. |
| T4 | Low | `secure_store.dart:40-58`, `auth_controller.dart:23-27` | Brief §7, screens_and_api #2 | The 60-minute access token is kept in the Keystore and restored at launch with no expiry check, so the first call after an expired token signs the customer out with a notice. That's acceptable for now. Biometric unlock after 5 minutes in the background (brief §7) isn't built yet. |
| T5 | Low | `smile_capture.dart:39, 102` | Same as web `verify-identity.component.ts:6` | The Smile ID script is loaded from the CDN without SRI, and the page runs as `https://tabitalpay.com`. Pin the script with an `integrity` hash once Smile ID publishes one. The impact is low (navigation is locked down). |
| T6 | Low | `android/app/build.gradle.kts` | Pre-release | `release` is signed with the debug key, and `applicationId` still has the template TODO. Fix both before any store build. |
| T7 | Low | `app.dart:98` | Style | The `limit` route is mis-indented. `dart format` would fix it. |

Structure is good overall. There's a thin `ApiClient`, one `CustomerRepository` that mirrors `customers.service.ts`, plain model classes, `AppScope` for dependency injection with fakes in tests, `go_router` with a stateful shell and auth redirects, and `changes` notifiers to refresh the tabs that stay alive. Error states (`ErrorPanel`, `EmptyState`, `Notice`) are used consistently, and double taps are guarded on every pay button.

#### Tests

| # | Sev | Missing | Web reference | Fix |
|---|---|---|---|---|
| X1 | Medium | No `PlanDetailScreen` test | `customer-instalments.money.spec.ts:68-76` ("offers deferment only on an upcoming instalment with no late fee (never Payment 1)"; "keeps a balance of 0 as 0") | Test that Defer appears only on the next *pending* payment (not overdue, not Payment 1), that a paid row shows its amount, that an unpaid row shows `amount_due`, and that a late-fee line appears. |
| X2 | Medium | No D12 test | `shop.money.spec.ts:101` ("keeps extended plans closed (D12)") | Check that "6 and 12 months / Coming soon" shows and can't be chosen. |
| X3 | Medium | No test for a changed amount (M1) | §12 | Add the three tests described in M1. |
| X4 | Low | No `LimitScreen` test, and no tests for the sign-in phone normalisation or the `account_inactive` message | | Add them when A1 and A2 are fixed. |

### Gaps (the web has it, the app doesn't yet)

These are already listed in `screens_and_api.md` ("Not in the app yet"), and the list is accurate: saved cards and autopay, "I've paid" claims, disputes ("Report a problem" is a snackbar for now, `plan_detail_screen.dart:125-131`), forgot password, profile editing, notifications, support tickets, pay links and QR (which is also the only way to get **in-store pickup with no delivery fee**, `customer_purchase.py:114`, `in_store=link is not None`). Also missing: **receipts** (D3), **employment verification** (the server returns `code: employment_verification_required` with `reasons`, the app shows them, but like the web it gives no way to provide the details), and biometric unlock.

**Backend needs to add to `docs/screens_and_api.md`** (for the main project):

- **B1.** Expose `min_part_payment` (in `key_facts`, or on the plan detail) so the app can show the minimum without writing it into the app (M3).
- **B2.** Add `used_limit` (or `in_plans`) to `risk.decision_view`, so the limit legend can show both amounts without the app subtracting (D4).
- **B3.** Add `delivery_fee` to each row of `_schedule()` in `customer_dashboard.py:337-363`, so Payment 1 can show "incl. GHS 50 delivery" (prototype S10).
- **B4.** Return `merchant_name` and the first instalment due date in the verify response for `down_payment`, so S9 can show "Accra Phone Hub delivers" and "Payment 2 due 3 Nov" (prototype S9).
- **B5.** CLAUDE.md "UI decisions": change the logo line to point to `tabital_front/src/assets/brand/` (B-1).

### Scorecard: round 1

| Area | Score | Why |
|---|---|---|
| 1. Money and business rules | **8/10** | No client-side money maths, safe pesewas, full schedule and key facts before agreement, D3/D12/D13 and deferment correct, "paid" only from verify. Points lost for M1 (no re-confirmation when the server's amount differs from the one shown). |
| 2. API parity | **8/10** | Every endpoint, body and field checked against Flask matches. `reasons` and `field` are handled. Phone normalisation, `account_inactive`, `X-Device-Flags` and one doc row are off. |
| 3. Wording parity | **8.5/10** | Close to the web and the prototype, and in one place more accurate than the web (deferment). Small items only. |
| 4. Design fidelity | **8/10** | The Vault components map one to one onto the prototype's CSS classes. Missing: Receipts, the notification bell and the saved address. Some touch targets are under 48 dp. |
| 5. Brand and logo | **4/10** | Colours, tagline and contact are right, but the launcher icon is still the Flutter logo and the real mark (already in the main project) isn't used. |
| 6. Technical architecture and tests | **7/10** | Clean layering, testable, 72 passing tests that mirror the web money specs. Missing: `FLAG_SECURE`, a Paystack host check, bundled fonts, and tests for plan detail and D12. |
| 7. Gaps | **6/10** | Core buy and pay flows are done. Disputes, receipts, notifications, saved cards and autopay, password reset and pay links aren't built yet. They're well documented. |

### Top 5 to fix next

1. **M1:** don't open Paystack if the server's amount differs from what the customer agreed to (checkout, pay and defer), with tests.
2. **B-1:** use the real Tabital mark from `tabital_front/src/assets/brand/` for the launcher icon (adaptive, navy background), the splash and Welcome.
3. **T1 + T2:** `FLAG_SECURE` on the money and identity screens, and accept Paystack checkout URLs only from Paystack hosts.
4. **A1 + A2 + A3:** strip spaces from the phone at sign-in, show the right `account_inactive` message, and send `X-Device-Flags`.
5. **X1 + X2 + D5:** tests for plan detail (defer rules) and D12, and 48 dp touch targets on the consent checkbox and the segmented control.

**Blockers: none.**

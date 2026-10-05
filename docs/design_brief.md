# Design brief: Tabital Pay customer app

**Who it's for:** salaried urban Ghanaians, earning at least GHS 2,000 a month, buying phones, laptops and appliances (CLAUDE.md §2). Most will use mid-range Android phones on mobile data. So the app should be light and quick, readable outdoors, and work with one hand.

**The job of the app:** buy today with a clear down payment, then never miss a payment. The home screen answers one question: *what do I owe next, and when?*

## 1. Visual system (Vault, the same tokens as the web app)

| Token | Value | Use |
|---|---|---|
| Navy | `#02163F` | App bar, headings, the next-payment card |
| Navy 2 | `#0A2D73` | Links, secondary buttons, info |
| Gold | `#F5B700` (pressed `#E8A400`) | **Only** the one main action on a screen, with navy text (9.8:1). Never white on gold |
| Background / surface | `#F8F9FC` / `#FFFFFF` | Screen / cards |
| Text / muted | `#475569` / `#64748B` | Body / secondary text |
| Line | `#E2E8F0` | Dividers, card borders |
| Success / warning / error | `#15803D` / `#8A5A00` / `#B42318` | Paid / due soon / overdue, always with an icon and a word, never colour alone |
| Headings | Poppins 600 | 26 / 20 / 17 sp |
| Body | Open Sans 400/600 | 15 sp (13 sp minimum) |
| Radius | 10 (controls), 14 (cards) | |
| Touch targets | 48 dp minimum | Buttons, list rows, plan options |
| Icons | Lucide (`lucide_icons` package) | No emoji anywhere |

The app has a dark theme from the start, built from the same tokens: navy surfaces, with gold still marking only the main action.

## 2. Navigation

There are four bottom tabs, and Pay is always one tap away:

| Tab | Screen |
|---|---|
| **Home** | The next-payment card, a sticky "Pay GHS X" bar, the available limit, and plans at a glance |
| **Shop** | Products from partner merchants, with "N payments of GHS X" on each card |
| **Plans** | Active and completed plans, each with its full schedule |
| **Account** | Profile, credit limit and why, identity, notifications, help, sign out |

## 3. Screens (first release)

| # | Screen | Key content |
|---|---|---|
| S1 | Welcome | Tagline, "Create account", "Sign in", and a link to the eligibility criteria |
| S2 | Sign up | Phone, name and password (10+ characters), plus Terms and Privacy consent. A short first step; the rest is asked when needed |
| S3 | Sign in | Phone and password. 2FA if the account has it on. Biometric unlock for later sessions |
| S4 | Home | The next-payment card (amount, due date, days left, status) and the sticky pay bar. Overdue is shown in red with the late fee as its own line |
| S5 | Shop list | Search, categories, product cards with the server's "4 payments of GHS X" teaser |
| S6 | Product and plan picker | Price, then Full / Pay in 2 / 3 / 4, each priced by the server. The full schedule, the delivery fee shown with Payment 1, and the total payable. Extended plans say "Coming soon" (D12) |
| S7 | Checkout review | Delivery address or in-store pickup, the schedule again, key facts (late fees, cap, deferment), Terms consent, and "Pay GHS X down payment" |
| S8 | Paystack | Paystack's secure checkout in an in-app browser. The app returns on the callback URL and asks the server to verify |
| S9 | Payment result | Confirmed / part payment / plan paid off / being checked / failed. Only the server's answer marks something paid |
| S10 | Plan detail | Progress, the schedule with each payment's status, receipts, Pay, Defer, "Report a problem" (dispute) |
| S11 | Pay | This payment / pay part of it / pay off the plan (R5). The amount comes from the server; pay-off shows every remaining payment first |
| S12 | Defer a payment | The server's quote: the fee and its base, the new dates for this and later payments, the total payable before and after, and an "I agree" box |
| S13 | Verify identity | Consent, then the Smile ID SDK (Ghana Card + selfie with liveness), then status. 3 attempts |
| S14 | Credit limit | Available limit, tier, and why. How the limit grows (on-time plans) and what lowers it |
| S15 | Notifications | In-app messages from the backend outbox. Push notifications in a later step |
| S16 | Help and support | A link to tabitalpay.com/help, support tickets, info@tabitalpay.com |

## 4. Main flows

1. **First purchase:** Welcome → Sign up → Shop → Product (Pay in 4) → *eligibility check* → Verify identity (if needed) → employment details (first credit plan) → Checkout review → Paystack (Payment 1) → Result ("Waiting for approval") → push or in-app message when approved.
2. **Paying an instalment:** a reminder (SMS or in-app) → Home → the sticky "Pay GHS 800" bar → Paystack → Result → Home shows the next payment.
3. **Can't pay this month:** Home → Plan → Defer → quote → agree → Paystack (fee) → the new dates show.
4. **Overdue:** the Home card turns red: "GHS 880 overdue (GHS 800 + GHS 80 late fee)". Pay in full, or pay part of it.

## 5. Money rules every screen follows

- **The amounts on screen come from the server.** The app never works out a down payment, an instalment, a fee or a balance itself.
- **Every plan is shown with its full schedule and the total payable** before the customer agrees (§12). The down payment is shown as Payment 1. The delivery fee is a separate line, paid only with Payment 1 (D3).
- **Rates are never written into the app's text.** Late fee %, the cap and the deferment fee come from the quote's `key_facts`.
- **Money is shown as `GHS 1,650.00`.** That's the ISO code, two decimals and thousands separators. Never "GHC" or "₵".
- **No double charges.** A pay button turns into a spinner after the first tap, and the server's payment reference makes a retry safe.
- **Only the server marks anything paid,** after it verifies the payment with Paystack. A closed app or a lost connection leaves the payment as "being checked", never "paid".
- **Status uses words and icons, not colour alone:** *Paid*, *Due in 3 days*, *Overdue 2 days*.

## 6. Accessibility and phones

- The layout works at 360 dp width and with text scaled to 130%.
- Contrast is at least 4.5:1 for text. The gold button always has navy text.
- Screen reader labels go on amounts and statuses, for example "Next payment, GHS 800, due 3 November".
- It works on slow or patchy data: cached plans show with "last updated" and a pull to refresh. Payments always need a live connection.

## 7. Security on the phone

- The access token is kept in memory and the refresh token in Android Keystore (`flutter_secure_storage`). Both are cleared on sign out.
- Biometric or PIN unlock is used to reopen the app after 5 minutes in the background.
- The app hides its contents in the app switcher (`FLAG_SECURE` on payment and identity screens).
- It talks to the API over HTTPS only.
- No secrets are kept in the app (Paystack and Smile ID keys stay on the server).

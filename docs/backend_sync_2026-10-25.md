# Customer app: what to update to match the latest web app and API (2026-10-25)

Written by the main project session after reviewing the backend (`Gway1/tabital_backend`, `main` at `557ee5c`) and the web app (`Gway1/tabital_frontend`, `main` at `9de7b8e`). Nothing here is a breaking change for the app you have today: the API still accepts everything the app sends now. The updates below make the app match the new behaviour and stop it asking for things the API no longer needs at sign-up.

**Rules for this sync**
- Extend what exists. The Verify identity feature is `lib/features/identity/`; add to it. Don't create a second KYC or documents area.
- No money logic in the app. Every amount still comes from the API.
- Don't duplicate what the API already does: the checklist (what's pending) is computed by the server. Show it; don't recompute it.
- New packages, installs, commits and builds still need the user's approval in chat (the 2026-10-07 freeze). The user has asked for this sync; ask for approval of the packages in U5 before adding them.

## A. Do first (the app is wrong or will fail without them)

**U1. The API address.** The live API is `https://tabital-backend.onrender.com`. `lib/core/config.dart` defaults to `https://tabital-api-staging.onrender.com`, and its comments and the README mention `https://tabital.onrender.com`. Change the default to the live address (keep the `--dart-define=API_BASE_URL` override), and fix the comments, the README and `docs/release.md`. HTTP stays allowed only in debug builds, to `10.0.2.2` and `localhost`.

**U2. Short sign-up.** The web sign-up now asks only for: full name, date of birth, email, phone number, password, the agree box and the optional marketing box. Everything else moved to the verification stage. In `lib/features/auth/sign_up_screen.dart` send only `full_name`, `business_email`, `phone`, `dob`, `agree`, `marketing_consent`, `password`. Remove these fields from the form and the request: `national_id`, `city`, `gps`, `address`, `designation`, `company`, `monthly_salary`, `employment_start_date`, `salary_paid_to_bank`, `momo_number`, `ref_name`, `ref_phone`, `ref_relationship`. Keep mapping the API's `{error, field}` to the field. Under the form, say what comes next: "That's all for now. After you sign up, you'll add your address, work and income, Ghana Card and a person we can contact when you verify your identity." Update the sign-up tests and the screenshots in `design/screens/`.

**U3. The Ghana Card number must be saved before the selfie check.** `POST /customer/identity/start` now fails for a new customer with "Add a valid Ghana Card number (GHA-XXXXXXXXX-X) in your profile first", because the number is no longer collected at sign-up. In the Verify identity flow, put the details step (U4) before "Start selfie check", and don't call `/customer/identity/start` until the checklist no longer lists "Ghana Card number" under `details_missing`. Show the API's message if it still refuses.

**U4. A "Your details" step in Verify identity.** New endpoints:
- `GET /customer/kyc/details` returns `{details, checklist}`.
- `PUT /customer/kyc/details` saves any of these fields (send only what the customer filled in; partial saves are fine) and returns `{message, details, checklist}`:
  - `national_id` (format `GHA-XXXXXXXXX-X`, uppercase, 9 digits then 1)
  - `city`, `address`, `gps` (Ghana Post GPS, optional)
  - `designation`, `company` (optional)
  - `monthly_salary` (number above 0), `employment_start_date` (`YYYY-MM-DD`, not in the future), `salary_paid_to_bank` (true or false)
  - `momo_number` (10-digit Ghana number)
  - `ref_name`, `ref_phone`, `ref_relationship` (the reference's phone must not be the customer's own number)
- Errors are `{error, field}` with status 400 or 409 (for example a MoMo number already linked to another account). Show them on the field.
- Use the same grouping as the web's "Your Details" tab: Ghana Card, Where you live, Work and income, A person we can contact. Reuse the existing field validators from the old sign-up screen (`phoneError`, the date pickers) instead of writing new ones.

**U5. Documents, each on its own, with a "still needed" list.** The web KYC page now shows a checklist and uploads each document as soon as the customer has it. The app has no documents upload yet, so add it to the Verify identity feature.
- The checklist comes from `GET /customer/kyc/details` → `checklist`:
  - `complete` (true when nothing is missing), `kyc_status`
  - `details_missing[]`: plain-language items still to add
  - `documents[]`: one per document, with `field`, `label`, `status` (`missing`, `pending`, `verified` or `rejected`), `rejection_reason`, `can_upload`
  - `documents_to_upload[]` and `documents_in_review[]`: labels
- The four documents (all required): `front_image` (Ghana Card front), `back_image` (Ghana Card back), `salary_certificate`, `bank_statement` (3 months).
- Upload: `POST /customer/documents/upload` as `multipart/form-data` with any of those four fields (one, two or all). Success is 201 with `{message, documents[]}`. Then reload the checklist. Errors are `{error}`: 409 when that document is already waiting for review or verified (the checklist's `can_upload` is false, so the button should be off in the first place), 400 for a wrong file type or a file over the size limit.
- Files: `.jpg`, `.jpeg`, `.png`, `.webp`, `.pdf`. The web page limits each file to 5 MB; use the same. The server no longer checks that a file's contents match its name: the Tabital team reviews every document by hand, so don't add that check in the app either.
- A `pending` document shows "Waiting for review"; `verified` shows "Verified"; `rejected` shows the reason and lets the customer send a new one.
- This needs a way to take or pick a photo or file (for example `image_picker` and `file_picker`) and the Android camera and media permissions. Ask the user to approve the packages and permissions before adding them. Do it the way the Smile ID camera permission was done if a MethodChannel is already in place.

**U6. A pending account can sign in, but can't buy.** New customers now stay "pending" until verification, and they can sign in. The old message "Account not approved yet. Please wait for admin approval." no longer exists; sign-in now refuses only rejected or suspended accounts, with "This account can't sign in. Contact us at info@tabitalpay.com." (status 403). So:
- Show the API's message on a sign-in failure as it is; don't hardcode either sentence.
- A pending customer who taps Checkout gets 403 `{"error": "Verify your identity first: your account is approved once your KYC is checked."}`. Show it, and take them to Verify identity (not the generic "Something went wrong" page). Better still, the Shop banner that already appears while identity isn't verified (`shop_screen.dart:176`) should say what's missing (`checklist.details_missing`, `documents_to_upload`) and open Verify identity, so they aren't surprised at checkout.
- `GET /customer/profile` returns `status` (`pending`, `approved`, `active`, `restricted`). Use it for the account chip.

## B. Check, and change only if needed

**U7. Products from merchants who haven't passed KYB are hidden.** `GET /customer/products` and the categories no longer list them, and `GET /customer/products/<id>` (and so a payment link or QR scan for one) returns 400 `{"error": "Product is not available"}`. Make sure that opens the app's "not available" state, not an error page. An empty shop is possible while merchants are being approved: check the empty state reads sensibly.

**U8. Error messages in general.** The API's `{error, field}` is now shown as it is on the web. The app's `ApiException` already reads `message`, `error` or `msg`. Check the screens that replace it with a fixed sentence, and let the server's own reason through.

**U9. Update the docs.** In `docs/screens_and_api.md`: add the three new rows (kyc/details, documents upload, the checklist), change the Sign up row, and tick off what's done. Correct the API address everywhere. Add a dated entry to `docs/review_log.md` after the work.

## C. Not for the app to fix: know them

- **Smile ID** (when it's switched on in production) verifies identity and approves the account without the documents; the documents are for the team's manual review. Don't make the selfie check wait for the documents.
- **Smile ID's Ghana option isn't enabled yet**, and SMS reminders are not live yet (the server only logs them). Forgot-password goes by email, and the mail server was failing on 2026-10-20: if it fails, show the API's message. These are production set-up tasks.
- **Token expiry:** a missing or expired sign-in token still comes back as 500, not 401, on the live API (items 12 in `screens_and_api.md`). Until the backend is fixed, the app can't tell "signed out" from "server down" from the status alone.
- **Merchant side:** merchants now give their location and what they sell at KYB, and can't sell until approved. Nothing for the customer app.
- Open backend gaps already listed in `docs/screens_and_api.md` (items 2, 3, 7, 13, 15, 16) are unchanged by these updates.

## D. How to report back

Do U1 to U6 first, then U7 to U9. Send the main project session a short summary: what changed, which files, tests added and their result, and what you could not verify. If the toolchain is still blocked on this PC (Windows Smart App Control stopping `dart.exe`, 2026-10-06), say so plainly instead of reporting analyze or tests as passing. Don't push or release anything; wait for the user's go-ahead.

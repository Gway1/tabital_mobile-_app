# Tabital Pay store submission packet

Prepared 27 October 2026. This is a working packet for **Tabital Pay Ltd**, not a claim that either store account or listing has been created.

## Fixed app identity

| Item | Value |
| --- | --- |
| Public app name | Tabital Pay |
| Android application ID | `com.tabitalpay.client` |
| Apple bundle ID | `com.tabitalpay.client` |
| First release | `1.0.0` (build / version code `1`) |
| Primary language | English |
| Initial market | Ghana, subject to the company's distribution decision |
| Audience | Adults 18+; confirm store age ratings from their questionnaires |
| Developer / seller | Tabital Pay Ltd (confirm both account registrations) |
| Support | https://tabitalpay.com/help/ · info@tabitalpay.com |
| Privacy policy | https://tabitalpay.com/privacy-policy/ (verify it loads from both stores) |

The Android and Apple IDs are now set in the project. **Register these exact IDs before uploading a build.** Store IDs are difficult or impossible to change after publication.

## Draft listing copy

**Google Play short description (under 80 characters):** Shop with Tabital Pay and manage your payment plans.

**App Store subtitle (under 30 characters):** Shop and pay in parts

**Description (adapt for each store after product and legal review):**

> Shop from Tabital Pay partner merchants and choose a payment plan that fits your budget. Review the down payment, full schedule, and total payable before confirming your order. Pay by card or Mobile Money through Paystack, see upcoming instalments, and track your plans in the app.
>
> Verify your identity and upload supporting documents from your phone. Get payment reminders, manage saved cards and autopay, and contact support when you need help.
>
> Tabital Pay is available to eligible adults in Ghana. Approval is subject to identity, employment, credit, and fraud checks. Plan availability, amounts, dates, fees, and any delivery charge are shown before you confirm. Late fees may apply. Terms: https://tabitalpay.com/elementor-page-3332/

Do not publish this copy until the company checks every claim against the live backend and current legal terms. Avoid describing plans as loans or claiming an APR without legal and product review.

## Google Play Console order

1. Create or verify a **Tabital Pay Ltd organization** developer account. Complete identity, contact, payments profile, and any required verification. Check whether a personal account's [closed testing gate](https://support.google.com/googleplay/android-developer/answer/14151465) applies: qualifying newer personal accounts need 12 opted-in testers for 14 continuous days before production access.
2. Create an app named **Tabital Pay**, choose app / free, primary language English, and the intended countries. Upload only a **signed** AAB whose package is `com.tabitalpay.client`; enroll in Play App Signing and keep the upload keystore backed up. The unsigned local AAB is for validation only.
3. Complete the main store listing: app name, short and full descriptions, 512 × 512 icon, 1024 × 500 feature graphic, and real phone screenshots. Use only real app screens with demo data. See [Play asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151).
4. Complete App content: privacy policy, Data safety, account deletion web URL, app access / review credentials, ads declaration, content rating, target audience, and the [Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271). The product includes **buy now, pay later**; confirm whether any other categories apply. Supply any required financial authorization documents.
5. Start internal testing, then the required closed testing if applicable. Verify sign-in, KYC, shopping, payment return, and support on real devices. Apply for production access if the account requires it, then submit a staged production rollout.

## Apple Developer and App Store Connect order

1. Enroll or verify the **Tabital Pay Ltd organization** in the Apple Developer Program. Accept the current agreements, confirm the legal seller name and team, then [register](https://developer.apple.com/help/account/identifiers/register-an-app-id/) the explicit App ID `com.tabitalpay.client`.
2. [Create an iOS app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/) named **Tabital Pay**, using that bundle ID and a unique internal SKU such as `TABITAL-CLIENT-IOS`. Confirm the app's availability and pricing (free download; purchases are for physical goods and plans).
3. Set release signing in Xcode under the organization's team; build an IPA with Xcode 26 or newer and an iOS 26 SDK. Upload to TestFlight. Supply an active reviewer account and instructions for any gated KYC or payment screens.
4. Complete the product page: subtitle, description, keywords, category (evaluate Finance versus Shopping), support URL, privacy URL, copyright, screenshots for every supported device class, age rating, App Privacy, and export compliance. The project currently supports iPhone **and iPad**, so capture iPad screenshots or deliberately narrow device support before submission. See [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
5. Provide financial service authorization or licensed partner documentation as needed. [Apple's review guidance](https://developer.apple.com/app-store/review/guidelines/) says financial services should be submitted by the legal entity providing them, and its review help mentions lender partnership documentation. Submit for review only after TestFlight verification.

## Blocking decisions and evidence still needed

| Gate | Current state | Required result |
| --- | --- | --- |
| Account deletion | No complete in-app + web deletion process. Public [Terms section 12](https://tabitalpay.com/elementor-page-3332/) says accounts are not deleted. | Legal/product-approved request flow, backend handling and retention notice, direct web deletion request URL, updated Terms and privacy text. Test the full process. |
| Privacy policy | `https://tabitalpay.com/privacy-policy/` returned HTTP 200 on 27 October 2026. | Review its content for the mobile app's data collection, processors, retention, and deletion path before entering privacy declarations. |
| Financial classification | BNPL is in the app; exact licensed entity/partner and required proofs are not in this repo. | Finance and legal owners approve the declarations, countries, and upload documents. |
| Signing | Android upload key and ignored `key.properties` were created locally on 28 October 2026; signed AAB verification passed. iOS IPA was signed with Apple team `KJ76HLC9YT`. | Back up the Android keystore and passwords separately; retain the same upload key for updates. Confirm the Apple team is the intended company team. |
| Store assets | Branded app icons are present. Feature graphic and verified device screenshots are not. | Capture real Android, iPhone, and (if supported) iPad screenshots; make Play feature graphic. |
| Review access | No dedicated review account or scenario is documented. | Create safe reviewer credentials and a way to reach order, KYC, and payment flows without real customer data. |
| Device QA | Automated tests and unsigned builds do not prove real payments, camera, file picking, or return links. | Execute an end-to-end checklist on physical Android and iPhone devices against the production API. |

Data safety and App Privacy answers must come from a joint mobile, backend, and processor inventory (Tabital API, Smile ID, Paystack, fonts, device signals, and any hosting analytics). Do not guess these declarations from the app code alone.

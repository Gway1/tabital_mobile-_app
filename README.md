# Tabital Pay: customer mobile app

The customer app for Tabital Pay ("Own It Today. Pay Later."). Customers can shop, choose a plan, pay, defer and track their plans from their phone.

| | |
|---|---|
| Framework | **Flutter**, Android first (CLAUDE.md §13.1 D10). iOS later from the same code |
| Backend | The existing Flask API (`Kobydon/tabital`). The app adds **no money logic**: every amount comes from the server |
| Payments | Paystack checkout (cards and MoMo), the same as the web app (D11) |
| Identity | Smile ID Biometric KYC (Ghana Card + selfie), through Smile ID's Flutter SDK |
| SMS | mNotify, sent by the backend; the app shows in-app messages |
| Design | Vault: navy-led, gold only for the one main action, Poppins headings, Lucide icons, no emoji. A large "next payment" card and a sticky pay bar on the home screen (UI decisions, 2026-09-27) |
| Scope | Customers only. Merchants and admins stay on the web app |

## What's here

| Path | What it is |
|---|---|
| `docs/design_brief.md` | Design rules, the screen list, user flows and the money rules every screen follows |
| `docs/screens_and_api.md` | Each screen mapped to the API endpoints it uses, and what the backend still needs for mobile |
| `design/prototype.html` | A clickable phone prototype of the key screens (open it in a browser) |
| `app/` | The Flutter project, created once the Flutter SDK is installed |

## Status

- **2026-10-03:** design stage. The prototype and brief are ready for review.
- **2026-10-03 (later):** the toolchain is installed and the Flutter project is in `app/`. It has:
  - the Vault theme (light and dark)
  - the API client (session token in Keystore, `X-Device-Id` on our own API only)
  - Welcome, Sign in and the four-tab shell
  - Home: the next-payment card, the sticky pay bar and the available limit
  - Plans and Plan detail, with the full schedule

  Every screen runs on the real API. `flutter analyze` is clean and **21 tests** pass. They cover money and date formats, the next-due logic on the §5.3 plan, Home's overdue, on-time, empty and error states, sign-in, session expiry and sign-out. The debug APK runs on the emulator; screenshots are in `design/screens/`.
- **Next:**
  - Pay: Paystack in an in-app browser, then verify
  - Shop, product, plan picker and checkout
  - Defer, Sign up, and Verify identity (Smile ID)

## Setting up

Everything is installed in `C:\Users\LENOVO\dev\` (a path with no spaces):

- Flutter 3.47.6 stable, in `flutter`
- Temurin JDK 17, in `jdk-17.0.20.1+1`
- the Android SDK, in `android-sdk`: platform 36, build-tools 36, NDK 28.2 and the emulator

Your user PATH, `JAVA_HOME` and `ANDROID_HOME` point at them. The emulator is `tabital_pixel` (Pixel 7, Android 15, x86_64).

```
cd app
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
flutter build apk --release
```

The `flutter run` line uses a local Flask server, reached from the emulator. The API defaults to the live API (`https://tabital-backend.onrender.com`); `--dart-define=API_BASE_URL=...` points a build somewhere else. Plain HTTP is allowed only in debug builds, and only to `10.0.2.2`, `localhost` and the laptop's Wi-Fi address used for phone testing (`android/app/src/debug/res/xml/network_security_config.xml`).

## Rules carried over from the web app

- **Server amounts only.** The app never calculates a plan, fee or balance itself. It shows the server's quote, including the full schedule and the total payable, before the customer confirms (§12).
- **Down payment first.** The down payment is Payment 1 and is paid at checkout through Paystack. The order goes to approval only after Paystack confirms it (D13).
- **Late fees are stated plainly.** They're 10% the day after the due date, a second 10% from 31 days, and capped at 25% of the total payable. The key facts come from the server's settings, never from text written into the app.
- **Secrets stay on the server.** The app holds only Paystack's public checkout URL for each payment. No keys are stored in the app.
- **Help** links to https://tabitalpay.com/help/, and the support contact is info@tabitalpay.com.

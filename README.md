# Pennywise – Personal Finance Manager

Pennywise is a Flutter app for tracking personal finances in Indian rupees (₹).
It uses Firebase Authentication for sign-in and Cloud Firestore to keep each
user's financial records under their own Firebase UID.

## Features

- Sign in with email and password, Google, or phone; reset an account password.
- Record money received and expenses, with UPI, cash, and card payment methods.
- Review available balance, daily/weekly/monthly spending, budgets, and savings
  goal progress.
- Organize expenses by category, including Shopping and Investments
  subcategories and Transport modes.
- Search and filter transaction history; edit or delete income and expenses.
- Review spending by category and compare monthly totals and category spending.
- Export a selected month's transactions and summary to CSV or Excel, then share
  the report using the device's sharing options.
- Use the Ocean Blue theme.

## Technology

- Flutter and Dart
- Firebase Core, Firebase Authentication, and Cloud Firestore
- Google Sign-In
- RxDart for combining Firestore streams
- `excel` and `share_plus` for spreadsheet export and sharing

## Project structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App startup, dashboard, expense and income flows, and transaction history |
| `lib/auth_flow.dart` | Firebase Authentication and sign-in screens |
| `lib/expense.dart` | Finance record models and Firestore serialization |
| `lib/expense_repository.dart` | UID-scoped Firestore reads and writes |
| `lib/finance_features.dart` | Monthly comparisons and CSV generation |
| `lib/finance_screens.dart` | Monthly comparison and report export screens |
| `lib/app_theme.dart` | Ocean Blue theme |
| `test/widget_test.dart` | Widget and finance feature tests |
| `firestore.rules` | Owner-scoped Firestore access and record validation |
| `firebase.json` | Firebase CLI configuration for Firestore rules |

## Requirements

- Flutter SDK with Dart 3.13.7 or a compatible Dart 3.x release
- Android Studio and an Android SDK for Android builds
- A Firebase project with Authentication and Cloud Firestore configured
- FlutterFire CLI for generating local Firebase client configuration

## Firebase setup

Firebase client configuration is intentionally excluded from this repository.
Generate it locally for your Firebase project; do not commit generated client
configuration, service-account credentials, or signing keys.

1. Install the Firebase CLI and authenticate:

   ```sh
   firebase login
   ```

2. Install FlutterFire CLI and configure this app:

   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Select the Firebase project and platforms you intend to run. For Android,
   select the registered app with package name `com.example.my_first_app`. This
   generates local platform configuration, including `lib/firebase_options.dart`
   and Android's `google-services.json`.

3. In Firebase Console, enable **Email/Password**, **Google**, and **Phone** in
   **Authentication → Sign-in method**. Register the Android signing SHA-1 and
   SHA-256 fingerprints for the builds you distribute. Phone authentication
   also requires the intended SMS regions to be enabled in the Firebase
   Authentication settings.

4. Create a Cloud Firestore database. The rules in `firestore.rules` restrict
   each user's access to records under `users/{uid}`. Review and deploy them to
   your project with the Firebase CLI:

   ```sh
   firebase deploy --only firestore:rules --project <PROJECT_ID>
   ```

   Replace `<PROJECT_ID>` with your Firebase project ID. This command changes
   Firebase rules; run it only when you intend to deploy the checked-in rules.

## Install, run, and test

From the project root:

```sh
flutter pub get
flutter run
```

Run static analysis and tests:

```sh
dart analyze
flutter test
```

Build an Android release APK:

```sh
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

# Banking Mobile App

Flutter Android app for the personal banking dashboard.

## Build Instructions

### 1. Install Flutter
Download Flutter SDK from https://docs.flutter.dev/get-started/install/windows/android
and add `flutter/bin` to your PATH.

### 2. Accept Android licenses
```
flutter doctor --android-licenses
```

### 3. Install dependencies
```
cd C:\Users\Benjamin\workspace\banking\mobile
flutter pub get
```

### 4. Run on connected device / emulator
```
flutter run
```

### 5. Build release APK
```
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

## Architecture

```
lib/
  main.dart               # App entry, auth routing
  theme/app_theme.dart    # Material 3 dark theme
  models/transaction.dart # Data model + JSON parsing
  services/
    auth_service.dart     # PocketBase auth + secure token storage
    api_service.dart      # All HTTP calls (transactions, categories, CSV upload)
    dashboard_service.dart# Client-side aggregation (KPIs, charts)
  screens/
    login_screen.dart     # Password entry
    main_shell.dart       # Bottom nav scaffold
    dashboard_screen.dart # KPI cards + charts
    transactions_screen.dart # Filtered/sorted transaction list
    import_screen.dart    # CSV file picker + upload
  widgets/
    period_selector.dart  # Horizontal time-period chips
    kpi_card.dart         # Colored metric card
    category_pie_chart.dart  # fl_chart donut chart
    monthly_bar_chart.dart   # fl_chart bar + line overlay
    category_bottom_sheet.dart # Category picker sheet
```

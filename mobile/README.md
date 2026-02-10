# Yoliva Mobile + Web Client

Flutter 3.x + Riverpod + GoRouter + Dio

## Scope

This client is productized for:

- Web
- Android
- iOS

Desktop targets are not part of the product scope.

## Architecture

```text
lib/
|- core/       shared infrastructure (theme, api, router, providers)
|- features/   feature modules (auth, home, trips, bookings, messages, profile)
```

## Branding

- Brand name: `Yoliva`
- Official logo family: `Soft Curve`
- Source assets: `mobile/assets/branding/yoliva/`

## Commands

```bash
flutter pub get
flutter analyze
flutter test

# Web
flutter build web --release --pwa-strategy=none

# Android
flutter build apk --debug
flutter build appbundle --release
```

## Notes

- Guest users can browse/search trips.
- Booking actions require authentication and redirect through `next` query.
- App icons are generated from Soft Curve source via `flutter_launcher_icons` config in `pubspec.yaml`.

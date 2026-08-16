# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter mobile app (Android/iOS) for the nail salon **D'Shaddai · Nail Designer · Beidis Viera**. Clients browse salon info and self-book appointments; an admin configures the calendar, confirms/cancels bookings, and blocks abusive clients. Backend is entirely Firebase.

Planning docs live in `.ia/` (Spanish): `project_scope.md` (product scope/roles), `technical_architecture.md` (Firestore schema, security rules, FCM flow), `modules_diagram.md` (module layout). Read these before changing data models or adding features — they are the spec the code is implementing.

Source comments and user-facing strings are Spanish; UI text belongs in ARB files, not literals.

## Commands

```bash
flutter pub get
flutter run                      # device/emulator
flutter analyze                  # lint (flutter_lints)
flutter test                     # all tests
flutter test test/widget_test.dart --plain-name "some test name"   # single test
flutter gen-l10n                 # regenerate lib/l10n/app_localizations*.dart from the .arb files
flutter build apk / flutter build ios
```

**The Flutter SDK at `/Users/macbookpro/Development/flutter` cannot run on this machine** — it requires macOS 14+ and this host is macOS 13.0. Every `flutter`/`dart` invocation fails with `VM initialization failed`. Do not attempt to build, analyze, or test from here; write code carefully and let the user verify on a supported machine.

`test/widget_test.dart` is still the untouched Flutter counter template and does not match this app (it pumps `MyApp` without a `ProviderScope` or Firebase init). Replace it rather than extending it.

## Architecture

Feature-first layering. Three layers, strictly one-directional (`features → data → Firebase`):

- **`lib/data/`** — the only place that touches Firebase. `models/` hold `fromMap`/`toMap`/`copyWith` mapping; `repositories/` (`auth`, `user`, `booking`, `config`) wrap Firestore/Auth calls. Every repository takes an optional `FirebaseFirestore`/`FirebaseAuth` constructor arg defaulting to `.instance` — this is the seam for injecting fakes in tests. Never call `FirebaseFirestore.instance` from a feature/view.
- **`lib/features/<feature>/`** — `providers/` (Riverpod state + controllers) and `presentation/` (widgets). Views read providers; providers own repositories.
- **`lib/core/`** — `router/app_router.dart` and `constants/theme_colors.dart`.

### State (Riverpod 3)

Repositories are exposed as plain `Provider`s (`authRepositoryProvider`, `userRepositoryProvider` in `features/auth/providers/auth_provider.dart`; `bookingRepositoryProvider`, `configRepositoryProvider` in `features/booking/providers/booking_provider.dart`) and reused across features — the admin feature depends on the auth and booking providers rather than instantiating its own repositories. Follow that pattern; don't create duplicate repository providers.

Live data is `StreamProvider` over Firestore snapshots. Mutations go through controller classes (`AuthController`, `AdminController`) exposed via provider. `StateProvider`/`StateNotifierProvider` come from `package:flutter_riverpod/legacy.dart` in this Riverpod version — that import is required, not accidental.

### Derived availability logic

`availableSlotsProvider` (`lib/features/booking/providers/booking_provider.dart`) is the core business rule and is a pure `Provider` composing three sources: calendar settings, that day's active appointments, and the selected date. It walks from `open` to `close` in `globalSlotDurationMinutes` steps, dropping blocked dates, closed weekdays, past times, and slots overlapping an existing appointment. Weekday keys in `openingHours` are lowercase English (`monday`…), produced by `DateFormat('EEEE')` — locale-dependent formatting here would break the lookup, so keep that format call unlocalized.

### Routing & auth gating

`go_router` with a `StatefulShellRoute.indexedStack` for the four bottom-nav branches (`/home`, `/services`, `/booking`, `/profile`), plus top-level routes `/login`, `/capture_phone`, `/admin`, `/admin/users`, `/admin/settings`. `RouterNotifier` listens to `authStateProvider` and `currentUserProvider` and drives `refreshListenable`.

The `redirect` enforces two rules: unauthenticated users hitting `/booking` go to `/login`; authenticated users without a `phoneNumber` are forced to `/capture_phone`. It returns `null` while `currentUserProvider.isLoading` to avoid redirecting on incomplete data — preserve that guard when editing.

Admin routes are **not** guarded by the router: the `/admin` entry point is merely hidden behind `if (user.role == 'admin')` in `profile_view.dart`. Real enforcement is expected to live in Firestore security rules (see `.ia/technical_architecture.md`). Treat any client-side role check as cosmetic.

### Firestore collections

- `users/{uid}` — `role` (`'cliente'` | `'admin'`), `isBlocked`, `phoneNumber` (WhatsApp), `photoUrl`, `fcmToken`.
- `appointments/{uuid}` — client-generated UUID v4 as doc id; `status` is `'waiting_confirmation'` | `'confirmed'` | `'cancelled'`. Clients see only the first two (`getActiveAppointmentsForDate`); the admin sees all (`getAppointmentsForDate`).
- `settings/calendar` — single doc; `ConfigRepository` falls back to `CalendarSettingsModel.defaultSettings()` when absent and writes with `merge: true`.

Blocked clients are rejected at sign-in (`AuthController.signInWithGoogle` signs them back out) rather than at booking time.

### Localization

Spanish (`app_es.arb`, the template) and Portuguese (`app_pt.arb`), auto-selected from the OS locale — there is no in-app language switcher. Generated `app_localizations*.dart` files are **committed** under `lib/l10n/`; after editing an `.arb`, run `flutter gen-l10n` and commit the regenerated output. Import paths are inconsistent across views (`/l10n/app_localizations.dart` vs relative) — either works; match the file you are editing.

### Not yet implemented

`firebase_messaging` is a dependency and `UserModel.fcmToken` / `UserRepository.updateFcmToken` exist, but nothing requests permissions or captures a token yet. Cloud Functions (the admin push notification on new booking) and Firestore security rules are also unwritten — no `functions/` or `firestore.rules` in this repo.

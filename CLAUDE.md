# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app (Android, iOS and Web) for the nail salon **Studio Shaddai · Nail Designer · Beidis Viera**. Clients browse salon info and self-book appointments; an admin configures the calendar, confirms/cancels bookings, and blocks abusive clients. Backend is entirely Firebase.

Planning docs live in `.ia/` (Spanish): `project_scope.md` (product scope/roles), `technical_architecture.md` (Firestore schema, security rules, FCM flow), `modules_diagram.md` (module layout). Read these before changing data models or adding features. The consolidated product vision and common requirements are in `docs/ESPECIFICACION.md`; feature requirements live in `specs/` (see "Spec-Driven Development" below).

### Unification in progress (decided 2026-10-20)

This repo is the base for merging in `../shaddai-web` (landing page and design system). Decisions:
- Keep this repo's feature-first architecture; do **not** adopt shaddai-web's `ui/view_model`/`domain`/`Result<T>` layout, nor its Dio/Retrofit stack.
- Adopt shaddai-web's design: `AppColors` + `LandingColors` (light, dark and system, **system by default** — changed in spec 001), Cormorant Garamond + **Inter**, and a persisted ES/PT language switcher.
- Same features on every platform, but **separate UI per platform**: Web (`kIsWeb`) is the single-page scrolling landing; Android/iOS use the `BottomNavigationBar`.
- Services and prices move to **Firestore**.
- Web hosting: **Hostinger**, domain **dshaddai.com** (not Firebase Hosting).

Source comments and user-facing strings are Spanish; UI text belongs in ARB files, not literals.

## Commands

```bash
flutter pub get
flutter run                      # device/emulator
flutter analyze                  # lint (flutter_lints)
flutter test                     # all tests
flutter test test/app/app_locale_test.dart --plain-name "some test name"   # single test
flutter gen-l10n                 # regenerate lib/l10n/app_localizations*.dart from the .arb files
flutter build apk / flutter build ios
```

The author works on more than one machine. On the current Mac (macOS 27, SDK at `/Users/juliangg/develop/flutter`, Flutter 3.47.7) `flutter`/`dart` run normally: build, analyze and test here. On an older Mac with macOS 13 (SDK at `/Users/macbookpro/Development/flutter`) Flutter fails with `VM initialization failed`, because it needs macOS 14+. If `flutter --version` fails, write the code carefully and let the author verify it on a supported machine.

Run `dart format lib test` rather than `dart format .`: the latter also reformats the git-ignored `build/` folder.

Tests never touch Firebase. Screen tests use `pumpApp` (`test/helpers/pump_app.dart`), which mounts the real `MyApp` with `goRouterProvider` replaced and in-memory preferences; `test/helpers/fake_session.dart` and `fake_auth.dart` hold the session overrides and hand-written fake repositories. `test/core/no_hardcoded_style_test.dart` fails on any hard-coded color or font under `lib/features` and `lib/core/widgets`; brand-mandated exceptions (e.g. the Google button) live in their own file and are listed there.

## Architecture

Feature-first layering. Three layers, strictly one-directional (`features → data → Firebase`):

- **`lib/data/`** — the only place that touches Firebase. `models/` hold `fromMap`/`toMap`/`copyWith` mapping; `repositories/` (`auth`, `user`, `booking`, `config`) wrap Firestore/Auth calls. Every repository takes an optional `FirebaseFirestore`/`FirebaseAuth` constructor arg defaulting to `.instance` — this is the seam for injecting fakes in tests. Never call `FirebaseFirestore.instance` from a feature/view.
- **`lib/features/<feature>/`** — `providers/` (Riverpod state + controllers) and `presentation/` (widgets). Views read providers; providers own repositories.
- **`lib/core/`** — `router/app_router.dart`; `theme/` (`AppTheme.light/dark`, `BrandColors` tokens read with `context.brand`, `AppText`, WCAG contrast helpers, system bar style); `preferences/` (pure theme/language rules); `utils/` (`weekdayKey`, `capitalizeFirst`); `platform/` (`isWebProvider`, use it instead of reading `kIsWeb` in views); `widgets/` (shared widgets, including `BrandLogo`, the Studio Shaddai SVG seal shared with shaddai-web).

### Theme and colors

Views never hard-code colors or fonts: they use `context.brand` tokens and `AppText`, so both light and dark themes work. Text and icons must meet WCAG AA in both themes (`brand_colors_contrast_test`). In the light theme the brand gold `#C7A86D` fails contrast on cream: use `accentText` for gold text, `accentIcon` for meaningful gold icons, and `accent` only for decoration. `textContrastGuideline` ignores `Opacity`, so don't fade informative text.

### State (Riverpod 3)

Repositories are exposed as plain `Provider`s (`authRepositoryProvider`, `userRepositoryProvider` in `features/auth/providers/auth_provider.dart`; `bookingRepositoryProvider`, `configRepositoryProvider` in `features/booking/providers/booking_provider.dart`) and reused across features — the admin feature depends on the auth and booking providers rather than instantiating its own repositories. Follow that pattern; don't create duplicate repository providers.

Live data is `StreamProvider` over Firestore snapshots. Mutations go through controller classes (`AuthController`, `AdminController`) exposed via provider. `StateProvider`/`StateNotifierProvider` come from `package:flutter_riverpod/legacy.dart` in this Riverpod version — that import is required, not accidental.

### Derived availability logic

`availableSlotsProvider` (`lib/features/booking/providers/booking_provider.dart`) is the core business rule and is a pure `Provider` composing three sources: calendar settings, that day's active appointments, and the selected date. It walks from `open` to `close` in `globalSlotDurationMinutes` steps, dropping blocked dates, closed weekdays, past times, and slots overlapping an existing appointment. Weekday keys in `openingHours` are lowercase English (`monday`…), produced by the pure `weekdayKey()` (`lib/core/utils/weekday_key.dart`), not by `DateFormat`, so the lookup never depends on the UI language.

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

Spanish (`app_es.arb`, the template) and Portuguese (`app_pt.arb`). The user picks the language (Profile → Preferences on Android/iOS, top bar on Web) and it is stored on the device with `shared_preferences`, never in Firestore; with no stored choice the app follows the device language live (Spanish if it is neither). Theme works the same way: light, dark or system (default). Dates and times use `intl` with `AppLocalizations.of(context)!.localeName`; read localized strings inside dialog builders so an open dialog also switches language. Generated `app_localizations*.dart` files are **committed** under `lib/l10n/`; after editing an `.arb`, run `flutter gen-l10n` and commit the regenerated output. Import paths are inconsistent across views (`/l10n/app_localizations.dart` vs relative) — either works; match the file you are editing.

### Not yet implemented

`firebase_messaging` is a dependency and `UserModel.fcmToken` / `UserRepository.updateFcmToken` exist, but nothing requests permissions or captures a token yet. Cloud Functions (the admin push notification on new booking) and Firestore security rules are also unwritten — no `functions/` or `firestore.rules` in this repo.

## Spec-Driven Development

Work follows SDD as taught in the Big School course "Desarrollo con IA" (same setup as the SpinStreak project): skill `sdd` (`.claude/skills/sdd/`) plus the user-invoked skills `/sdd-constitution`, `/sdd-spec`, `/sdd-clarify`, `/sdd-plan`, `/sdd-tasks`, `/sdd-implement`, `/sdd-validate`, `/sdd-change` and `/sdd-status`.

- Flow: constitution → spec → clarification → plan → tasks → implementation (one task at a time) → validation. Never move to the next phase without the author's explicit approval; `spec.md`/`plan.md`/`tasks.md` only become `aprobada` when the author says so.
- Files: `docs/constitution.md` (non-negotiable principles), `docs/ESPECIFICACION.md` (global vision + common requirements), `specs/NNN-nombre/{spec,plan,tasks}.md`.
- **Tests first** (author's decision, 2026-10-20): each task writes its tests first (red), then the code (green). Never advance with failing tests. Fakes for Firebase are injected through the repository constructors; never hit real Firebase from a test.
- Gate for every task: `dart format .` with no changes, `flutter analyze` with no errors or warnings, `flutter test` green.
- Fixes and refactors that don't change behaviour don't need a spec.
- Ask before: adding dependencies, changing the architecture, changing Firestore collections/fields or security rules. Never commit unless asked.

## Memory

Read `MEMORY.md` at the start of a session. After finishing a task or SDD phase, update it: status, decisions (with their why) and mistakes to avoid. Keep it to ~50 lines and never store secrets.

## Project documentation (Obsidian vault)

Project notes: `01 - Projects/DShaddai/` in the vault (Mac: `~/Documents/DriveSalva/Obsidian Vault/`; Windows: `D:\Obsidian Vault\`). The repo is the source of truth; the vault holds a summary.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app (Android, iOS and Web) for the nail salon **Studio Shaddai · Nail Designer · Beidis Viera**. Clients browse salon info and self-book appointments; an admin configures the calendar, confirms/cancels bookings, and blocks abusive clients. Backend is entirely Firebase.

Planning docs live in `.ia/` (Spanish): `project_scope.md` (product scope/roles), `technical_architecture.md` (Firestore schema, security rules, FCM flow), `modules_diagram.md` (module layout). Read these before changing data models or adding features. The consolidated product vision and common requirements are in `docs/ESPECIFICACION.md`; feature requirements live in `specs/` (see "Spec-Driven Development" below).

### Unification in progress (decided 2026-10-20)

This repo is the base for merging in `../shaddai-web` (landing page and design system). Decisions:
- Keep this repo's feature-first architecture; do **not** adopt shaddai-web's `ui/view_model`/`domain`/`Result<T>` layout, nor its Dio/Retrofit stack.
- Adopt shaddai-web's design (done in specs 001 and 002): its palette as `BrandColors` tokens (light, dark and system, **system by default**), Cormorant Garamond + **Inter**, a persisted ES/PT language switcher, and its landing content.
- Same features on every platform, but **separate UI per platform**: Web is the single-page scrolling landing with a top bar (spec 002); Android/iOS use the `BottomNavigationBar`.
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

Web and mobile tests that need the real router use `pumpWebApp` and `pumpMobileApp` (`test/helpers/pump_web_app.dart`). Both start the app directly at the requested location (`defaultRouteNameTestValue`). `pumpMobileApp` replaces the native Google map through `salonMapProvider`. Both use the real router with `isWebProvider` set, a `FakeWebSession` that can sign in and out during the test, the window width, and the app's real fonts (`loadAppFonts`; the default test font makes text almost twice as wide). It asks the system to reduce motion by default, so the landing's animated strip stops and `pumpAndSettle` can finish. External links go through `externalLinkLauncherProvider`; `RecordingLinkLauncher` records them instead of opening them.

## Architecture

Feature-first layering. Three layers, strictly one-directional (`features → data → Firebase`):

- **`lib/data/`** — the only place that touches Firebase. `models/` hold `fromMap`/`toMap`/`copyWith` mapping; `repositories/` (`auth`, `user`, `booking`, `config`) wrap Firestore/Auth calls. Every repository takes an optional `FirebaseFirestore`/`FirebaseAuth` constructor arg defaulting to `.instance` — this is the seam for injecting fakes in tests. Never call `FirebaseFirestore.instance` from a feature/view.
- **`lib/features/<feature>/`** — `providers/` (Riverpod state + controllers) and `presentation/` (widgets). Views read providers; providers own repositories.
- **`lib/core/`** — `router/app_router.dart`; `theme/` (`AppTheme.light/dark`, `BrandColors` tokens read with `context.brand`, `AppText`, WCAG contrast helpers, system bar style); `preferences/` (pure theme/language rules); `utils/` (`weekdayKey`, `capitalizeFirst`); `platform/` (`isWebProvider`, use it instead of reading `kIsWeb` in views; `externalLinkLauncherProvider`, which opens web links in a new tab and `tel:`/`mailto:` in the same one, and never surfaces a launch error); `widgets/` (shared widgets, including `BrandLogo`, the Studio Shaddai SVG seal shared with shaddai-web).

### Theme and colors

Views never hard-code colors or fonts: they use `context.brand` tokens and `AppText`, so both light and dark themes work. Text and icons must meet WCAG AA in both themes (`brand_colors_contrast_test`). In the light theme the brand gold `#C7A86D` fails contrast on cream: use `accentText` for gold text, `accentIcon` for meaningful gold icons, and `accent` only for decoration. On the Web landing's brand surface (`brandSurface`: cream in light, green in dark) use `onBrandSurface`, `onBrandSurfaceMuted` and `onBrandSurfaceAccent` for gold text, because `accentText` fails on the cream. `textContrastGuideline` ignores `Opacity`, so don't fade informative text.

### State (Riverpod 3)

Repositories are exposed as plain `Provider`s (`authRepositoryProvider`, `userRepositoryProvider` in `features/auth/providers/auth_provider.dart`; `bookingRepositoryProvider`, `configRepositoryProvider` in `features/booking/providers/booking_provider.dart`) and reused across features — the admin feature depends on the auth and booking providers rather than instantiating its own repositories. Follow that pattern; don't create duplicate repository providers.

Live data is `StreamProvider` over Firestore snapshots. Mutations go through controller classes (`AuthController`, `AdminController`) exposed via provider. `StateProvider`/`StateNotifierProvider` come from `package:flutter_riverpod/legacy.dart` in this Riverpod version — that import is required, not accidental.

### Derived availability logic

`availableSlotsProvider` (`lib/features/booking/providers/booking_provider.dart`) is the core business rule and is a pure `Provider` composing three sources: calendar settings, that day's active appointments, and the selected date. It walks from `open` to `close` in `globalSlotDurationMinutes` steps, dropping blocked dates, closed weekdays, past times, and slots overlapping an existing appointment. Weekday keys in `openingHours` are lowercase English (`monday`…), produced by the pure `weekdayKey()` (`lib/core/utils/weekday_key.dart`), not by `DateFormat`, so the lookup never depends on the UI language.

### Routing & auth gating

`goRouterProvider` builds one of two route tables, depending on `isWebProvider`. `RouterNotifier` listens to `authStateProvider` and `currentUserProvider` and drives `refreshListenable`.

- **Android/iOS (spec 003):** a `StatefulShellRoute.indexedStack` for the four bottom-nav branches (`/home`, `/services`, `/booking`, `/profile`) inside `MainScaffold`, plus top-level `/login`, `/capture_phone`, `/admin`, `/admin/users` and `/admin/settings`.
  - **Bar:** `MainScaffold` uses Material 3 `NavigationBar` (destinations ≥ 48 px, selected state announced). Above 1.3× text scale it shows icons only, with names in tooltips and semantics.
  - **Scroll:** each tab's main scroll view uses `tabScrollControllerProvider(MobileTab.x)`. Tapping the active tab scrolls it to the top, and Inicio's "Ver lista de precios" opens Servicios at the top.
  - **Content:** Inicio (`HomeView`) and Servicios (`ServicesView`) are built from the landing sections (see "Web landing"). Inicio's contact adds the map (`salonMapProvider`) and the social links.
  - **Reservas without a session:** shows `BookingSignInPrompt` inside the tab. `GoogleSignInControls` (button, spinner, `authErrorMessage`) is shared with `LoginView`.
- **Web (spec 002):** a `ShellRoute` whose `WebShell` holds the fixed `WebTopBar` (logo, section links, theme and language selectors, "Reservar", `AccountButton`; below 900 px the links and selectors move to `WebMenuDrawer`).
  - `/` is the `LandingPage`; `/?section=prices` opens it at a section (`LandingSection`).
  - Account pages (`/login`, `/capture_phone`, `/booking`, `/profile`, `/admin…`) are wrapped in `WebAccountPage` per route, which centers them at 640 px. Don't constrain the shell's nested navigator instead: the outgoing landing would be laid out narrow during the transition.
  - `/home` and `/services` only redirect to the landing.
  - Section links use `goToLandingSection`/`goToLandingTop`: they scroll the landing in place if it is showing (`landingPageKey`), otherwise they go to `/?section=…`.

All redirect rules live in the pure `resolveRedirect` (`lib/core/router/redirect_logic.dart`, fully table-tested):
- **Mobile (spec 003):** no redirect without a session, because the Reservas tab shows its own sign-in prompt. Authenticated users without a `phoneNumber` are sent to `/capture_phone?next=<where they were>`, and come back there after saving it. `/login` and `/capture_phone` with a complete user go to `safeNext(next, isWeb: false)`, which defaults to `/home`.
- **Web:** account pages require a session (`/login?next=…`) and a WhatsApp number (`/capture_phone?next=…`), while the landing stays visible without them. After sign-in, `safeNext` sends the user to the requested internal page or to `/`; it rejects external or unknown targets. Non-admins on `/admin…` go to `/`.

Both return `null` while `currentUserProvider.isLoading`, to avoid redirecting on incomplete data. Preserve that guard when editing.

Admin routes are only cosmetically guarded (hidden entry points, plus the Web redirect above). Real enforcement is expected to live in Firestore security rules (spec 009, see `.ia/technical_architecture.md`). Treat any client-side role check as cosmetic.

### Web landing (also Inicio and Servicios on mobile)

`lib/features/landing/`:
- **Content:** ten sections in order (`LandingSection`), each in a `LandingSectionFrame`, under `presentation/sections/`. Sections pick their wide or narrow layout with `landingIsWide(context)`, which reads the nearest `LandingLayout`: `LandingPage` sets it from the window width (≥ 900 px), and the mobile tabs set none, so they are always narrow, also on landscape tablets. Texts come from the `.arb` files with the `landing` prefix. Non-translatable data (links, contact, prices, combos, image paths) lives in `LandingContent` (`landing_content.dart`); spec 004 replaces prices and combos with Firestore.
- **Images:** they live in `assets/images/landing/` and are shown with `LandingImage`, which provides a screen-reader description and a fallback box.
- **WhatsApp button:** the floating button sits in its own `FocusTraversalGroup`, so Tab doesn't keep returning to it while the page scrolls. Contrast tests hide it with `showLandingFloatButtonProvider`, because `textContrastGuideline` reads the colours of whatever covers a text as its background.

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

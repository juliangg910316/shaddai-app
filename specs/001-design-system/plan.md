# Plan 001 — Design system: tema, tipografía e idioma
Estado: aprobada

Spec: `specs/001-design-system/spec.md`, aprobada el 2026-10-20 y revisada con `/sdd-change`. Este plan cubre:
- RF-1 a RF-27 y RNF-1 a RNF-6;
- los requisitos comunes RC-1 a RC-4. RC-4 de forma provisional en Web hasta la spec 002 (RF-27).

Sustituye al plan aprobado anterior. Las decisiones que el autor ya aprobó se mantienen: D-1 (`shared_preferences`), D-6 (barra de Web provisional), D-7 (Perfil siempre visible) y D-8 (ajuste de tonos por contraste).

## 1. Qué existe ya en el código

| Pieza | Estado actual | Qué falta | RF |
| --- | --- | --- | --- |
| Paleta | `lib/core/constants/theme_colors.dart`: constantes estáticas (`bone`, `darkGreen`, `gold`, `olive`, `danger`, `sand`…), **solo tema claro** | Tema oscuro y colores que dependan del tema activo | RF-14 |
| Tipografías | Cormorant Garamond y **Jost** incluidas en `assets/fonts/` (variables, con licencia OFL) | Cambiar Jost por **Inter** | RF-13, RNF-5 |
| Estilos de texto | `AppText.serif/sans/eyebrow`, con color por defecto `ThemeColors.black` fijo | Que el color salga del tema | RF-15 |
| Uso en pantallas | ~350 referencias directas a colores fijos en 12 archivos | Pasarlas a los tokens del tema | RF-15, RF-16 |
| Texto sobre foto | El bloque principal de Inicio pone una foto al 50 % sobre verde oscuro, con un degradado negro de 10 % a 55 % | Comprobar el contraste del velo en el peor caso (RNF-1) | RF-16 |
| Barra de estado | Solo el panel de admin fija iconos claros (`AnnotatedRegion` con `darkGreen`). El resto usa el valor por defecto | Estilo según el tema en toda la app | RF-23 |
| Idioma | `MaterialApp` con `supportedLocales` es/pt, sin `locale`: sigue al sistema, pero sin la vuelta a español de RF-9 | Elegir, recordar y resolver el idioma | RF-8 a RF-12, RF-20 |
| Fechas | `spanish_dates.dart`, **solo en español**. `TableCalendar` ya empieza en lunes. Las horas ya van en `HH:mm` | Fechas en el idioma activo | RF-10, RF-21 |
| Lógica de días | `availableSlotsProvider` usa `DateFormat('EEEE')` sin locale | Quitar esa dependencia del idioma | Refactor (D-5) |
| Errores mostrados | Cinco textos `.arb` incluyen el error técnico (`{error}`): `adminAgendaLoadError`, `adminClientsLoadError`, `bookingCreateError`, `slotsLoadError`, `myAppointmentsLoadError`. Login muestra `'${authState.error}'` en crudo. `AuthController` emite el literal en español `'Cuenta bloqueada por el administrador.'`, que además incumple el principio 6 | Textos propios de la app en el idioma activo | RF-22 |
| Preferencias guardadas | No existen | Guardar tema e idioma | RF-6, RF-11 |
| Perfil sin sesión | La pestaña se oculta sin sesión, y `ProfileView` se queda cargando para siempre si `user == null` | Pestaña siempre visible, Preferencias e "Iniciar sesión" | RF-24 a RF-26 |
| Web | Usa el mismo `MainScaffold` que móvil | Barra superior con los selectores | RF-27 |
| Tests | Solo `test/widget_test.dart`, la plantilla del contador | Sustituirla | — |

## 2. Archivos

Capas: `features → data`. Esta spec **no toca Firebase** (RNF-3).

### Se crean
| Archivo | Capa | Responsabilidad | RF |
| --- | --- | --- | --- |
| `lib/core/theme/brand_colors.dart` | core | `BrandColors extends ThemeExtension`: tokens con versión `light` y `dark` (§5), `copyWith`, `lerp` y la extensión `context.brand` | RF-14, RF-16 |
| `lib/core/theme/app_theme.dart` | core | `AppTheme.light` / `.dark`: `ColorScheme`, temas de los componentes, `BrandColors`, Inter como fuente base, Cormorant en los estilos de título y `appBarTheme.systemOverlayStyle` | RF-13 a RF-15, RF-23 |
| `lib/core/theme/app_text.dart` | core | `AppText.serif/sans/eyebrow` con el mismo API, sin color por defecto fijo | RF-13, RF-15 |
| `lib/core/theme/contrast.dart` | core (Dart puro) | `relativeLuminance`, `composite`, `contrastRatio` y `isLargeText` sobre enteros ARGB | RNF-1, RF-23 |
| `lib/core/theme/system_bars.dart` | core | `systemBarsStyleFor(Color background)`: elige iconos claros u oscuros con `prefersLightIcons` | RF-23 |
| `lib/core/preferences/preferences_logic.dart` | core (Dart puro) | `ThemePreference`, `AppLanguage`, `parseThemePreference`, `parseLanguage`, `resolveLanguage`, `languageFromDevice` | RF-1, RF-2, RF-8, RF-9, RF-20 |
| `lib/core/utils/weekday_key.dart` | core (Dart puro) | `weekdayKey(DateTime)` → `'monday'`…`'sunday'` | D-5 |
| `lib/data/repositories/preferences_repository.dart` | data | Lee y escribe `theme` y `language` en el almacenamiento del dispositivo, recibido por constructor. Nunca lanza | RF-6, RF-7, RF-11, RF-12, RNF-3 |
| `lib/features/preferences/providers/preferences_provider.dart` | features | `preferencesRepositoryProvider`, `ThemePreferenceController`/`themePreferenceProvider`, `LanguageController`/`languagePreferenceProvider` | RF-1 a RF-12, RF-20 |
| `lib/features/preferences/presentation/theme_menu_button.dart` | features | Menú de tema para Web, con las tres opciones | RF-18, RF-27, RNF-4 |
| `lib/features/preferences/presentation/language_switch.dart` | features | Pastillas ES/PT para Web | RF-19, RF-27, RNF-4 |
| `lib/features/preferences/presentation/preferences_section.dart` | features | Sección "Preferencias" de Perfil | RF-17 a RF-19, RF-25, RNF-4, RNF-6 |
| `lib/features/auth/providers/auth_failure.dart` | features | `enum AuthFailure { blocked, cancelled, unknown }`: errores de inicio de sesión sin texto | RF-22 |
| `assets/fonts/Inter-Variable.ttf` y `assets/fonts/OFL-Inter.txt` | assets | Inter incluida en la app, con su licencia | RF-13, RNF-5 |

### Se modifican
| Archivo | Cambio | RF |
| --- | --- | --- |
| `pubspec.yaml` | Inter en lugar de Jost. Se añade **`shared_preferences`** (aprobada, D-1) | RF-13, RNF-5, RF-6 |
| `lib/main.dart` | Carga el almacenamiento antes de `runApp` y lo inyecta en el `ProviderScope`. `MaterialApp.router` recibe `theme`, `darkTheme`, `themeMode`, `locale` y `localeListResolutionCallback` (§4), y un `builder` que pone el estilo de las barras del sistema según el tema | RF-3 a RF-7, RF-10, RF-12, RF-20, RF-23 |
| `lib/features/auth/providers/auth_provider.dart` | `AsyncError(AuthFailure.blocked)` en lugar del literal. Otros errores → `AuthFailure.unknown` (cancelar el inicio de sesión → `cancelled`), con `debugPrint` del error técnico | RF-22 |
| `lib/features/booking/providers/booking_provider.dart` | `DateFormat('EEEE')` pasa a `weekdayKey(date)` | D-5 |
| `lib/core/widgets/app_widgets.dart` | Colores desde `context.brand` y el tema | RF-15 |
| Las 10 vistas y `google_map_container.dart` | Tokens en lugar de colores fijos (tabla de §5). `SpanishDates` pasa a `DateFormat(…, localeName)`. Los errores se muestran sin `err` | RF-10, RF-15, RF-16, RF-21, RF-22 |
| `login_view.dart` | `switch (authState.error)`: cada `AuthFailure` tiene su texto `.arb`, y `cancelled` no muestra nada | RF-22 |
| `admin_dashboard_view.dart` | El `AnnotatedRegion` de la cabecera usa `systemBarsStyleFor(brand.brand)` | RF-23 |
| `main_scaffold.dart` | Perfil siempre en la barra. En Web, barra superior con los dos selectores | RF-24, RF-27 |
| `profile_view.dart` | Sin sesión: Preferencias + "Iniciar sesión" → `/login`. Con sesión: lo de ahora + Preferencias | RF-24 a RF-26 |
| `app_es.arb`, `app_pt.arb` y archivos generados | Textos nuevos (§8). Los cinco textos `…Error` pierden `{error}` | RC-1, RF-22 |
| `test/widget_test.dart` | Se elimina | — |
| `CLAUDE.md`, `MEMORY.md` | Al terminar: selector de idioma, `lib/core/theme/` y fin del aviso de `DateFormat('EEEE')` | — |

### Se eliminan
`lib/core/constants/theme_colors.dart`, `lib/core/constants/spanish_dates.dart`, `assets/fonts/Jost-Variable.ttf` y `assets/fonts/OFL-Jost.txt`.

## 3. Lógica pura (sin Flutter ni Firebase)

Ninguna regla depende de la hora, así que ninguna función recibe "ahora".

```
enum ThemePreference { light, dark, system }
enum AppLanguage { es, pt }

parseThemePreference(String? stored) -> ThemePreference          // RF-2 y valor corrupto
  'light' -> light | 'dark' -> dark | 'system' -> system | otro o null -> system

parseLanguage(String? stored) -> AppLanguage?                    // 'es' | 'pt' -> valor; otro o null -> null

languageFromDevice(String? deviceLanguageTag) -> AppLanguage     // RF-9, variantes regionales
  code = minúsculas(tag ?? '').split(/[-_]/).first               // 'pt-BR' -> 'pt', 'es_AR' -> 'es'
  code == 'pt' -> pt | code == 'es' -> es | otro -> es

resolveLanguage(String? stored, String? deviceLanguageTag) -> AppLanguage   // RF-9, RF-12
  parseLanguage(stored) ?? languageFromDevice(deviceLanguageTag)

weekdayKey(DateTime d) -> String                                 // monday … sunday, por d.weekday

relativeLuminance(int argb) -> double                            // WCAG 2.1
composite(int fgArgb, int bgArgb) -> int                         // mezcla alfa
contrastRatio(int fgArgb, int bgArgb) -> double                  // fg ya compuesto sobre bg
isLargeText(double sizePx, bool bold) -> bool                    // RNF-1: >= 24, o >= 18.66 en negrita
prefersLightIcons(int backgroundArgb) -> bool                    // RF-23
  contrastRatio(blanco, bg) >= contrastRatio(negro, bg)
```

## 4. Estado (Riverpod), arranque y `MaterialApp`

```
// data
class PreferencesRepository {
  PreferencesRepository(this._store)        // SharedPreferences? (null = almacenamiento no disponible)
  String? readTheme() / readLanguage()       // try ... catch -> null
  Future<void> saveTheme(String) / saveLanguage(String)   // try ... catch -> no hace nada
}

// main
store = try await SharedPreferences.getInstance() catch -> null
runApp(ProviderScope(overrides: [preferencesRepositoryProvider.overrideWithValue(PreferencesRepository(store))], child: MyApp()))

// providers
ThemePreferenceController extends Notifier<ThemePreference>
  build()    -> parseThemePreference(repo.readTheme())              // RF-2, RF-7
  select(p)  -> state = p; repo.saveTheme(p.name)                   // RF-5, RF-6 (el estado cambia aunque falle el guardado)

LanguageController extends Notifier<AppLanguage?>                   // null = sin preferencia guardada
  build()    -> parseLanguage(repo.readLanguage())                  // RF-12
  select(l)  -> state = l; repo.saveLanguage(l.name)                // RF-10, RF-11

// MyApp
MaterialApp.router(
  theme: AppTheme.light, darkTheme: AppTheme.dark,
  themeMode: light | dark | system según la preferencia,           // RF-3, RF-4
  locale: saved == null ? null : Locale(saved.name),               // con preferencia manda ella (RF-12)
  localeListResolutionCallback: (deviceLocales, _) =>              // sin preferencia: RF-9 y RF-20
      Locale(languageFromDevice(deviceLocales?.first.toLanguageTag()).name),
  supportedLocales: [es, pt], localizationsDelegates: [...igual que ahora],
  builder: (context, child) => AnnotatedRegion(                     // RF-23
      value: systemBarsStyleFor(context.brand.background), child: child),
  routerConfig: ref.watch(goRouterProvider),                        // no depende del tema ni del idioma
)
```

- **RF-20, idioma del dispositivo en vivo:** con `locale: null`, Flutter vuelve a llamar a `localeListResolutionCallback` cada vez que el sistema avisa de un cambio de idioma. No hace falta escuchar ese cambio a mano. Con preferencia guardada, `locale` fija el idioma y los cambios del dispositivo se ignoran (caso límite).
- **El selector muestra el idioma efectivo**, no la preferencia: lee `Localizations.localeOf(context)`. Así marca el idioma correcto aunque no haya nada guardado (RF-19).
- **RF-4, tema del dispositivo en vivo:** con `ThemeMode.system`, `MaterialApp` ya reacciona a `platformBrightness`.
- **RF-7 / RF-12, desde el primer fotograma:** el almacenamiento se carga antes de `runApp` y se lee de forma síncrona.
- **RF-5 / RF-10, estado conservado:** al cambiar el tema o el idioma solo se reconstruye `MaterialApp`. El `GoRouter` es el mismo objeto, así que el `Navigator`, la pestaña, el scroll, los `State` (texto escrito, fecha y hora elegidas) y los diálogos abiertos se conservan.
- **RNF-2:** el cambio se pinta en el siguiente fotograma.
- `Notifier`/`NotifierProvider` vienen de `flutter_riverpod`, no de `legacy.dart`.

## 5. Interfaz

### Tokens de `BrandColors`
Los valores salen de la tabla *Paleta de la marca* de la spec. Los marcados con ⚠ son variantes exigidas por RNF-1: se ajustan hasta que pasa `brand_colors_contrast_test` y el valor final se anota aquí.

| Token | Uso | Claro | Oscuro | Sustituye a |
| --- | --- | --- | --- | --- |
| `background` | fondo de pantalla | `#F5F1E8` crema | `#17170F` | `bone` |
| `surface` | tarjetas, barras y campos | `#FAFAF8` | `#202018` | `white` |
| `placeholder` / `placeholderStrong` | fondos de foto | `#EDE7D9` / `#E4DFD0` | `#2A2A21` / `#33332A` | `sand` / `sandDark` |
| `ink` | texto principal | `#201F18` | `#F5F1E8` | `black` |
| `inkStrong` | títulos | `#2E3D28` | `#F5F1E8` | `darkGreen` usado como texto |
| `inkMuted` | texto secundario e indicaciones de los campos | `#5F6650` (5,32:1; `#7A8264` daba 3,58:1) | `#9AA184` (6,09:1) | `olive` |
| `accent` | **solo** adornos y líneas decorativas (sin contraste exigido) | `#C7A86D` | `#C7A86D` | `gold` |
| `accentIcon` | iconos dorados con significado (≥ 3:1). Añadido en T2 por decisión del autor: `#C7A86D` da 2,01:1 sobre crema | `#9A7B40` (3,53:1) | `#C7A86D` | `gold` usado como icono |
| `accentText` | texto dorado | `#856933` (4,58:1) | `#C7A86D` (7,9:1) | `gold` usado como texto |
| `sage` | acento secundario | `#BFC8B3` | `#BFC8B3` | — |
| `brand` / `onBrand` / `onBrandMuted` | barra inferior, botón principal, cabecera de admin | `#2E3D28` / `#C7A86D` / crema al 60 % | iguales | `darkGreen`, y `gold`/`bone` encima |
| `photoScrimStart` / `photoScrimEnd` | velo bajo el texto sobre foto | negro 35 % → 55 % (con 10 % daba 2,99:1 en el peor caso) | igual | degradado actual de Inicio |
| `onPhoto` | texto sobre el velo | `#F5F1E8` (5,13:1 en el peor caso) | igual | `bone`/`white` sobre foto |
| `hairline`, `hairlineStrong`, `goldHairline`, `goldHairlineSoft` | bordes de 1 px | verde al 10 %/25 %, dorado al 50 %/35 % | crema al 10 %/25 %, dorado al 50 %/35 % | getters actuales |
| `danger` | cancelados, acciones destructivas, errores | `#9C4A41` (5,37:1) | `#D98A80` (6,16:1; `#9C4A41` daba 2,98:1) | `danger` |
| ~~`success`~~ | No se crea: ninguna pantalla usa un color propio para "confirmado" (usan tokens de marca) | — | — | — |

- **Componentes Material** (`AppBar`, `Card`, `Dialog`, `SnackBar`, `InputDecoration`, `BottomNavigationBar`, botones, `ProgressIndicator`, `DatePicker`, `SegmentedButton`, `MenuAnchor`): sus temas se definen una vez en `AppTheme`, para claro y para oscuro (RF-15).
- **Títulos (RF-13):** `display*`, `headline*`, `titleLarge` y `AppText.serif` (precios y horas) en Cormorant Garamond. El resto del `textTheme`, en Inter.
- **Excepciones de color (RF-15):**
  - El mapa (`google_map_container.dart`) se queda claro. Solo su borde usa un token.
  - El botón de Google en Web y `_GoogleSignInButton` en móvil, que usa los colores de la guía de Google.
  - Las fotos (`Image.network`, `NetworkImage`).
  - Los logotipos de terceros.

  `no_hardcoded_style_test` lleva una **lista blanca** con esos archivos o widgets; cualquier otro uso de color fijo hace fallar el test.

### Android/iOS
- **Barra inferior:** Inicio · Servicios · Reservas · **Perfil, siempre** (RF-24).
- **Perfil sin sesión:** título "Perfil", sección Preferencias y botón "Iniciar sesión" → `context.go('/login')` (RF-25, RF-26).
- **Perfil con sesión:** lo de ahora y, al final, Preferencias.
- **`PreferencesSection`:**
  - "Tema": `SegmentedButton` con Claro / Oscuro / Sistema.
  - "Idioma": `SegmentedButton` con Español / Português.
  - La opción activa lleva una marca ✓ y fondo relleno: no depende solo del color, y `SegmentedButton` la anuncia como "seleccionada" (RNF-4).
  - Área táctil de al menos 48 px.
  - Con el texto al 200 %, los segmentos pasan a una columna (`LayoutBuilder`/`Wrap`) para no cortar el texto (RNF-6).
- **Barras del sistema (RF-23):** el `builder` de `MaterialApp` las ajusta al fondo del tema. La cabecera verde de admin las sobrescribe con su propio `AnnotatedRegion`.
- **Login, captura de WhatsApp y admin:** sin selectores (limitación aceptada en la spec).

### Web (provisional hasta la spec 002, RF-27)
- `MainScaffold` añade, solo en Web (`kIsWeb`, inyectable para los tests), una barra superior con `ThemeMenuButton` y `LanguageSwitch` a la derecha.
- **`ThemeMenuButton`:**
  - `MenuAnchor` con un icono que indica la preferencia (sol, luna o pantalla) y tooltip "Cambiar tema".
  - Abre tres `MenuItemButton`; la activa lleva una marca ✓ y `Semantics(selected: true)`.
  - Teclado: Tab llega al botón, Intro o Espacio lo abre, las flechas recorren las opciones, Intro elige y Esc cierra. `MenuAnchor` ya trae este manejo; el foco es visible gracias al tema (RNF-4).
- **`LanguageSwitch`:**
  - Dos botones "ES" y "PT" (textos del `.arb`). El activo va relleno y en negrita, con `Semantics(selected: true)` y la etiqueta "Cambiar idioma: Español/Português".
  - Son botones con foco, así que funcionan con Tab, Intro y Espacio.
- Cambiar una preferencia no cambia de ruta ni la posición del scroll.
- **Varias pestañas:** cada pestaña lee el almacenamiento al arrancar, así que los cambios de otra pestaña se ven al recargar (caso límite). No se escucha el evento `storage` del navegador.

### Fechas (RF-10, RF-21)
- `localeName = AppLocalizations.of(context)!.localeName`.
- **Calendario de reservas:** `TableCalendar(locale: localeName, startingDayOfWeek: monday)`. La cabecera usa `DateFormat.yMMMM(localeName)` con la primera letra en mayúscula. Los días usan la inicial de `DateFormat.E(localeName)`.
- **Fechas largas** (diálogo de reserva, admin y perfil): `DateFormat.yMMMMEEEEd(localeName)`. Las cortas: `DateFormat.MMMd(localeName)`.
- **Horas:** `DateFormat.Hm(localeName)`, siempre 24 h.
- **Selectores de fecha y hora de Material**, si se usan: `MediaQuery(alwaysUse24HourFormat: true)` en el `builder`.
- Los datos de `intl` para es y pt los carga `GlobalMaterialLocalizations.delegate`.

### Errores (RF-22)
- **Errores de carga** (agenda, clientes, horarios, mis turnos) y **error al crear una reserva**: se muestra solo el texto `.arb`, sin `{error}`. El error técnico va a `debugPrint`.
- **Inicio de sesión:** `AuthFailure.blocked` → `authBlockedError`; `unknown` → `authGenericError`; `cancelled` → no se muestra nada.
- Con eso quedan cubiertos dos casos límite: la clienta bloqueada ve el aviso en el idioma y el tema vigentes, y nunca aparece un mensaje técnico del servicio.

### Rutas y guardas
No hay rutas nuevas ni cambios en `redirect`. `/profile` ya era accesible sin sesión: solo estaba oculta en la barra.

## 6. Datos (Firestore)
- **Ningún cambio:** no hay colecciones, campos, `firestore.rules` ni índices nuevos.
- Las preferencias se guardan solo en el dispositivo, con las claves `theme` (`light`/`dark`/`system`) y `language` (`es`/`pt`) (RNF-3).
- No hay datos anteriores que migrar: `shaddai-web` no está publicada.

## 7. Casos límite

| Caso | Cómo se cubre |
| --- | --- |
| Dispositivo en inglés u otro idioma | `languageFromDevice` → `es` |
| es-AR, pt-BR, pt-PT | `languageFromDevice` se queda con el idioma y descarta la región |
| Valor guardado corrupto | `parseThemePreference` → `system`; `parseLanguage` → `null`, así que se usa el idioma del dispositivo |
| Almacenamiento no disponible | Repositorio con `null`: las lecturas devuelven `null`, las escrituras se ignoran y el estado vive en memoria durante la sesión |
| Cerrar sesión o cambiar de cuenta | Las preferencias no dependen del usuario |
| Cambio de tema o idioma a mitad de algo | El `GoRouter` y los `State` se conservan (§4). Hay test con texto escrito, fecha y hora elegidas y un diálogo abierto |
| Sin modo oscuro en el dispositivo | El brillo del sistema es `light`, así que *sistema* da claro |
| Idioma del dispositivo cambiado con la app abierta | `locale: null` + callback de resolución (RF-20). Con preferencia guardada no cambia |
| Fuente que tarda en cargar en Web | Va como asset; mientras carga, Flutter usa la fuente de reserva y el texto nunca queda invisible |
| Portugués con texto al 200 % | Preferencias y selectores se adaptan (§5). Test a 320 px y escala 2.0 |
| Login, captura de WhatsApp y admin | Sin selectores: usan el idioma y el tema vigentes |
| Clienta bloqueada | `AuthFailure.blocked` → texto `.arb` |
| Error de un servicio externo | Texto `.arb` sin el detalle técnico |
| Varias pestañas en Web | Se aplica al recargar |
| Sin conexión | Tema, idioma y fuentes son locales; no cambia nada |
| Mapa en tema oscuro | Excepción de color: se queda claro |

## 8. Textos de los `.arb`

**Nuevos:**

| Clave | ES | PT |
| --- | --- | --- |
| `preferencesTitle` | Preferencias | Preferências |
| `themeLabel` | Tema | Tema |
| `themeLight` | Claro | Claro |
| `themeDark` | Oscuro | Escuro |
| `themeSystem` | Sistema | Sistema |
| `themeMenuTooltip` | Cambiar tema | Alterar tema |
| `languageLabel` | Idioma | Idioma |
| `languageSpanish` | Español | Español |
| `languagePortuguese` | Português | Português |
| `languageCodeEs` | ES | ES |
| `languageCodePt` | PT | PT |
| `languageSwitchLabel` | Cambiar idioma | Alterar idioma |
| `selectedOption` | Seleccionado | Selecionado |
| `profileGuestTitle` | Perfil | Perfil |
| `profileGuestLoginButton` | Iniciar sesión | Entrar |
| `authBlockedError` | Tu cuenta está bloqueada. Escríbenos por WhatsApp si crees que es un error. | Sua conta está bloqueada. Fale conosco pelo WhatsApp se achar que é um erro. |
| `authGenericError` | No pudimos iniciar sesión. Inténtalo de nuevo. | Não foi possível entrar. Tente novamente. |

**Modificados** (se quita `{error}`; los textos de PT se revisan igual):

| Clave | ES nuevo |
| --- | --- |
| `adminAgendaLoadError` | No pudimos cargar la agenda. Inténtalo de nuevo. |
| `adminClientsLoadError` | No pudimos cargar los clientes. Inténtalo de nuevo. |
| `bookingCreateError` | No pudimos crear la reserva. Inténtalo de nuevo. |
| `slotsLoadError` | No pudimos cargar los horarios. Inténtalo de nuevo. |
| `myAppointmentsLoadError` | No pudimos cargar tus reservas. Inténtalo de nuevo. |

Los nombres de días y meses los da `intl`: no van en los `.arb`.

## 9. Estrategia de tests
**Sin Firebase.**
- Las vistas se prueban con `ProviderScope(overrides: …)`: `authStateProvider`, `currentUserProvider`, `clientAppointmentsProvider` y los providers de turnos y calendario se sobrescriben con `Stream.value`/`AsyncData` en memoria.
- Las preferencias usan `SharedPreferences.setMockInitialValues`.
- El idioma y el brillo del dispositivo se simulan con `tester.platformDispatcher.localesTestValue` y `platformBrightnessTestValue`.
- `AuthController` se prueba con un `AuthRepository`/`UserRepository` falsos escritos a mano (implementan la misma interfaz).
- Un helper `test/helpers/pump_app.dart` monta la app o una vista con un tema y un idioma dados.
- No hace falta ninguna dependencia de test nueva.

| Test | Tipo | Cubre |
| --- | --- | --- |
| `preferences_logic_test` | unitario | RF-1, RF-2, RF-8, RF-9; valor corrupto; es-AR, pt-BR, en y vacío |
| `weekday_key_test` | unitario | Los 7 días, igual que el `DateFormat('EEEE')` de antes (D-5) |
| `contrast_test` | unitario | `contrastRatio` frente a valores WCAG conocidos (21:1 y 1:1), `composite`, `isLargeText` en los límites, `prefersLightIcons` |
| `brand_colors_contrast_test` | unitario | **RNF-1, RF-14, RF-16**, en `light` y `dark`: `ink`, `inkStrong`, `inkMuted` (incluidas las indicaciones de los campos), `accentText` y `danger` sobre `background`/`surface` ≥ 4,5:1; `onBrand`/`onBrandMuted` sobre `brand` ≥ 4,5:1; `accent` como icono ≥ 3:1; texto claro sobre `photoScrim` en el peor caso (foto blanca) ≥ 4,5:1 |
| `preferences_repository_test` | unitario | RF-6, RF-11, RNF-3: guarda y relee; con almacenamiento `null` o que lanza, no hay excepción |
| `preferences_controllers_test` | unitario (`ProviderContainer`) | RF-2, RF-5, RF-6, RF-7, RF-11, RF-12; `select` cambia el estado aunque falle el guardado |
| `app_theme_mode_test` | widget | RF-3, RF-4 (cambia `platformBrightnessTestValue` → cambia el tema tras un `pump()`), RF-7, RNF-2; sin modo oscuro → claro |
| `app_locale_test` | widget | RF-9 (pt-BR → PT, en → ES), RF-10 (`.arb` y `MaterialLocalizations` en PT), RF-12, **RF-20** (cambia `localesTestValue` sin preferencia → cambia el idioma; con preferencia → no cambia) |
| `state_preserved_test` | widget | RF-5, RF-10: con texto escrito, una fecha y hora elegidas en Reservas y un diálogo abierto, cambiar el tema y el idioma lo conserva todo |
| `typography_test` | widget | RF-13: los estilos de título en Cormorant y el resto en Inter, en los dos temas |
| `system_bars_test` | widget | RF-23: el `AnnotatedRegion` raíz da iconos oscuros en claro y claros en oscuro, con ≥ 3:1 sobre `background` |
| `no_hardcoded_style_test` | código fuente (`dart:io`) | RF-15: en `lib/features/**` y `lib/core/widgets/**` no hay `ThemeColors.`, `Color(0x`, `Colors.` (salvo `transparent`) ni `fontFamily:`, fuera de la lista de excepciones |
| `screens_theme_test` | widget | RF-15, RF-16: cada pantalla existente (con sus estados vacío, de carga y de error), en claro y oscuro: fondo = `brand.background` y `meetsGuideline(textContrastGuideline)`. Inicio se prueba con el mapa sustituido (§11) |
| `localized_dates_test` | widget | RF-21: cabecera del calendario "Outubro de 2026" / "Octubre de 2026", semana desde el lunes, horas `HH:mm`, fecha larga en el idioma activo |
| `error_messages_test` | widget + unitario | RF-22: `AuthController` con usuaria bloqueada → `AuthFailure.blocked`; Login muestra `authBlockedError` en ES y PT sin texto técnico; un error de carga muestra el texto `.arb` sin el detalle técnico |
| `preferences_section_test` | widget | RF-17 a RF-19, RF-24, RF-25, RF-26; RNF-4 (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `selected` en la semántica, ✓ visible) |
| `web_selectors_test` | widget | RF-27 (barra solo en Web), RF-18, RF-19, RNF-4 con teclado (`sendKeyEvent`: Tab, Intro, flechas y Esc en el menú; Tab y Espacio en las pastillas) |
| `text_scale_test` | widget | RNF-6 y caso límite PT: escala 2.0, 320 px y PT; sin errores de desbordamiento en Preferencias ni en los selectores de Web |

**Verificación manual en la validación** (criterios de la spec):
- RF-4 y RF-20 en un dispositivo real;
- RF-23, mirando la barra de estado y la de navegación del sistema;
- RNF-5, primer arranque en modo avión;
- el teclado en Web, en Chrome;
- las preferencias que sobreviven a cerrar y abrir la app o a recargar la web.

## 10. Decisiones

| # | Decisión | Por qué | Alternativa descartada |
| --- | --- | --- | --- |
| D-1 | Dependencia **`shared_preferences`** (aprobada por el autor) | Paquete oficial de Flutter para Android, iOS y Web, con modo de prueba en memoria | Firestore: lo prohíbe RNF-3. Un archivo propio: no sirve en Web |
| D-2 | Inter como archivo de fuente incluido | RNF-5 sin dependencias, igual que Cormorant | `google_fonts`: dependencia nueva que descarga en tiempo de ejecución |
| D-3 | Tokens en un `ThemeExtension` (`BrandColors`) | Los colores cambian con el tema sin condicionales por vista | `ThemeColors` estático + `if (dark)` en ~350 sitios |
| D-4 | Un solo `BrandColors` para toda la app | Una única fuente de verdad. La spec 002 puede añadir tokens propios de la landing | Copiar `AppColors` + `LandingColors` de la web, con nombres pensados para la landing |
| D-5 | `weekdayKey()` puro en vez de `DateFormat('EEEE')` | Con las fechas localizadas, cambiar el idioma por defecto de `intl` rompería los horarios | Confiar en no tocar `Intl.defaultLocale` |
| D-6 | Barra provisional de Web en `MainScaffold` (ahora RF-27) | Los selectores son piezas reutilizables, así que la spec 002 solo los recoloca | Esperar a la 002: RF-17 no se podría verificar en Web |
| D-7 | Perfil siempre visible, con Preferencias e "Iniciar sesión" (ahora RF-24 a RF-26) | Lo pide la spec | — |
| D-8 | Variantes de tono por contraste (ahora respaldadas por la spec: RNF-1 prevalece) | El dorado (2,01:1) y el olivo (3,58:1) sobre crema no cumplen | Mantener los colores de la web tal cual |
| D-9 | `locale: null` + `localeListResolutionCallback` cuando no hay preferencia | Flutter ya reacciona al cambio de idioma del sistema (RF-20) | Un observador de `didChangeLocales` con un provider propio: más código para lo mismo |
| D-10 | `AuthFailure` (enum) en lugar de mensajes de texto en el controlador | Los controladores no deben tener textos (principio 6). La vista traduce, y el detalle técnico va al log | Pasar el texto ya traducido al controlador: necesitaría `BuildContext` |
| D-11 | Estilo de las barras del sistema en el `builder` de `MaterialApp`, con `prefersLightIcons` | Una sola regla para todas las pantallas, incluidas las que no tienen `AppBar` (casi todas). Admin la sobrescribe | `appBarTheme.systemOverlayStyle`: solo vale en pantallas con `AppBar` |
| D-12 | Lista blanca explícita de excepciones en `no_hardcoded_style_test` | Hace verificable la definición *Excepciones de color* | Revisión manual: no es un test |

## 11. Riesgos
- **Volumen de la migración:** ~350 referencias en 12 archivos. Se migra pantalla a pantalla, cada una con sus tests.
- **Mapa de Google en los tests:** es una vista de plataforma. En `screens_theme_test`, Inicio sustituye `GoogleMapContainer` con un constructor inyectable. El mapa ya es una excepción de color.
- **Aspecto en el tema claro:** los textos dorados y olivos serán más oscuros que en la web actual. Lo exige RNF-1.
- **`textContrastGuideline`** no compone bien los fondos semitransparentes y los degradados. Para el bloque principal de Inicio manda `brand_colors_contrast_test` (peor caso del velo), y la guía se omite en ese widget.

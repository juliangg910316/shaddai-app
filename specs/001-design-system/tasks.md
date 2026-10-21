# Tareas 001 — Design system: tema, tipografía e idioma
Estado: aprobada

Spec: `spec.md` (aprobada, revisada) · Plan: `plan.md` (aprobado, revisado). D-x y § remiten al plan.

**Reglas para todas las tareas:**
- Tests primero: se escriben, se ve que fallan (rojo) y luego se escribe el código hasta que pasan (verde).
- Puerta de cada tarea: `dart format .` sin cambios, `flutter analyze` sin errores ni avisos y `flutter test` en verde.
- Ningún test usa Firebase real: los providers se sobrescriben con datos en memoria y los repositorios falsos se escriben a mano (§9).
- Durante la migración (T9 a T13), el `ThemeColors`/`AppText` antiguo convive con el nuevo. Cada archivo migrado importa solo el nuevo, y el antiguo se borra en T14.

**Tests que crecen tarea a tarea** (para no dejar tests en rojo entre tareas):
- `no_hardcoded_style_test` revisa una **lista de archivos ya migrados**, más su lista blanca de *Excepciones de color* (D-12). Cada tarea de migración añade los suyos. En T14 pasa a revisar las carpetas enteras.
- `screens_theme_test` también tiene una lista de pantallas que crece en cada tarea.

## Bloque A — Base: lógica, tema, idioma, selectores y errores

- [x] **T1. Lógica pura de preferencias y día de la semana.** RF-1, RF-2, RF-8, RF-9, D-5
  - Tests:
    - `preferences_logic_test`:
      - `parseThemePreference` con `light`, `dark`, `system`, `null` y `'xyz'`;
      - `parseLanguage`;
      - `languageFromDevice` con `pt-BR`, `es_AR`, `PT`, `en`, `''` y `null`;
      - `resolveLanguage`: lo guardado manda sobre el dispositivo, y un valor guardado corrupto da paso al dispositivo.
    - `weekday_key_test`: los 7 días dan `monday`…`sunday`, igual que el `DateFormat('EEEE').toLowerCase()` de antes.
  - Código: `preferences_logic.dart` y `weekday_key.dart` (§3). `availableSlotsProvider` pasa a usar `weekdayKey`.
  - Hecho cuando: los dos tests pasan y `grep "DateFormat('EEEE')" lib` no devuelve nada.
  - Hecha el 2026-10-20: 15 tests en verde. Por decisión del autor, aquí se borró también `test/widget_test.dart` (adelantado de T5), que ya fallaba antes de empezar.

- [x] **T2. Contraste y tokens `BrandColors` claro y oscuro.** RF-14, RF-16, RNF-1
  - Tests:
    - `contrast_test`: negro sobre blanco 21:1, color sobre sí mismo 1:1, `composite` con alfa, `isLargeText` en los límites (24 px y 18,66 px en negrita) y `prefersLightIcons` sobre `#2E3D28` y sobre `#F5F1E8`.
    - `brand_colors_contrast_test`: todos los pares de §9 en `light` y `dark`, incluidos texto sobre `photoScrim` con foto blanca y `accent` como icono (≥ 3:1).
  - Código: `contrast.dart` y `brand_colors.dart` (`ThemeExtension`, `copyWith`, `lerp`, `context.brand`). Los valores ⚠ de §5 se ajustan hasta que el test pasa (D-8).
  - Hecho cuando: los dos tests pasan y los valores finales están anotados en la tabla de §5 del plan.
  - Hecha el 2026-10-20: 50 tests nuevos en verde (`contrast_test`, `brand_colors_contrast_test` y `brand_colors_test`). Por decisión del autor se añadió el token `accentIcon`. También se añadió `onPhoto`, y no se creó `success` (sin uso). Valores finales en §5 del plan.

- [x] **T3. Inter, `AppTheme` claro/oscuro, `AppText` y estilo de las barras del sistema.** RF-13, RF-14, RF-15 (componentes), RF-23 (regla), RNF-5
  - Tests:
    - `typography_test`, en los dos temas:
      - `display*`, `headline*`, `titleLarge` y `AppText.serif` en Cormorant; el resto en Inter;
      - los temas de los componentes toman sus colores de `BrandColors`;
      - `AppText.sans()` sin color hereda el del tema.
    - `systemBarsStyleFor`: iconos oscuros sobre `background` claro y claros sobre oscuro.
  - Código:
    - `Inter-Variable.ttf` + `OFL-Inter.txt`, declarados en `pubspec.yaml`.
    - `app_theme.dart`, `app_text.dart` y `system_bars.dart` (D-2, D-11).
  - Hecho cuando: los tests pasan y `pubspec.yaml` no tiene ningún paquete de fuentes.
  - Hecha el 2026-10-20: 26 tests nuevos en verde (`typography_test` y `system_bars_test`).
    - Inter variable (OFL 1.1) descargada de `google/fonts`.
    - En el tema oscuro, `colorScheme.primary` es el dorado, porque el verde de marca casi no se ve sobre el fondo.
    - Los temas de `SegmentedButton` y `MenuAnchor` se añaden en T6/T7, junto con sus widgets.
    - Nadie usa todavía `AppTheme`: se conecta en T5.

- [x] **T4. Repositorio y controladores de preferencias.** RF-2, RF-5, RF-6, RF-7, RF-11, RF-12, RNF-3, casos límite de almacenamiento
  - Tests:
    - `preferences_repository_test`: con `SharedPreferences.setMockInitialValues`, guarda y relee. Con almacenamiento `null` o que lanza, devuelve `null` y no lanza.
    - `preferences_controllers_test` (`ProviderContainer`):
      - sin nada guardado, el tema es `system` y el idioma `null`;
      - con un valor guardado, se lee;
      - `select` cambia el estado y lo guarda;
      - `select` cambia el estado aunque el guardado falle.
  - Código: dependencia **`shared_preferences`** (D-1, aprobada), `preferences_repository.dart` y `preferences_provider.dart` (§4).
  - Hecho cuando: los dos tests pasan y el repositorio no importa nada de Firebase.
  - Hecha el 2026-10-20: 16 tests nuevos en verde. `shared_preferences: ^2.5.6` añadida. El almacenamiento que falla se simula con `test/helpers/throwing_preferences.dart`. Los providers aún no los usa la app: se conectan en T5.

- [x] **T5. Conectar tema, idioma y barras del sistema a `MaterialApp`.** RF-3, RF-4, RF-5, RF-7, RF-9, RF-10, RF-12, RF-20, RF-23, RNF-2
  - Tests (con el nuevo `test/helpers/pump_app.dart`; `test/widget_test.dart` ya se borró en T1):
    - `app_theme_mode_test`:
      - con `dark` guardado, el primer fotograma ya es oscuro;
      - con `system`, cambiar `platformBrightnessTestValue` cambia el tema tras un `pump()`;
      - un dispositivo sin modo oscuro da claro.
    - `app_locale_test`:
      - `pt-BR` → PT y `en` → ES;
      - con `pt` guardado y el dispositivo en `es` → PT desde el primer fotograma;
      - `select(pt)` pone en portugués los textos de los `.arb` y los de `MaterialLocalizations`;
      - **RF-20**: sin preferencia, cambiar `localesTestValue` cambia el idioma; con preferencia, no lo cambia;
      - lo escrito en un `TextField` se conserva al cambiar el tema o el idioma.
    - `system_bars_test`: el `AnnotatedRegion` raíz cambia con el tema y sus iconos tienen ≥ 3:1 sobre `background`.
  - Código: `main.dart` (§4: carga del almacenamiento, `themeMode`, `locale` + `localeListResolutionCallback` y `builder` con las barras; D-9).
  - Hecho cuando: los tres tests pasan y, al reiniciar la app, se conservan el tema y el idioma guardados.
  - Hecha el 2026-10-20: 17 tests nuevos en verde (`test/app/`; el de barras se llama `app_system_bars_test` para no chocar con el de T3).
    - Los tests montan `MyApp` con `goRouterProvider` sustituido por una página de prueba (`test/helpers/pump_app.dart`), sin Firebase.
    - `themeAnimationDuration: Duration.zero`: sin animación, el cambio de tema se ve en el siguiente fotograma (RNF-2).
    - Reiniciar la app con preferencias guardadas lo cubren los tests de primer fotograma (RF-7, RF-12); la prueba en un dispositivo real queda para la validación.

- [x] **T6. Sección Preferencias y Perfil sin sesión (Android/iOS).** RF-17, RF-18, RF-19, RF-24, RF-25, RF-26, RNF-4, RNF-6
  - Tests:
    - `preferences_section_test`:
      - sin sesión, la barra inferior incluye Perfil, y Perfil muestra Preferencias y "Iniciar sesión", que lleva a `/login`;
      - con sesión, Perfil muestra lo de ahora más Preferencias;
      - pulsar Oscuro o Português cambia el tema o el idioma sin cambiar de ruta;
      - la opción activa tiene ✓ y `selected` en la semántica;
      - se cumplen `androidTapTargetGuideline` y `labeledTapTargetGuideline`.
    - `text_scale_test` (parte de Perfil): escala 2.0, 320 px y PT, sin errores de desbordamiento.
  - Código:
    - Claves nuevas de §8 en `app_es.arb`/`app_pt.arb` + `flutter gen-l10n`.
    - `preferences_section.dart`.
    - `main_scaffold.dart`: Perfil siempre en la barra.
    - `profile_view.dart`: estado sin sesión. Esta pantalla aún no se migra al nuevo tema.
  - Hecho cuando: los dos tests pasan.
  - Hecha el 2026-10-20: 11 tests nuevos en verde. Se añadieron las 17 claves nuevas de §8 (incluidas las de T7 y T8).
    - Helpers nuevos: `test/helpers/fake_session.dart` (sesión falsa y router con la barra real) y `pumpApp` con `router` y `overrides`.
    - Las opciones pasan a ir en vertical con el texto ≥ 130 %.
    - La guía de tamaño táctil se mide solo en Perfil: la barra inferior actual tiene pestañas de 46 px de alto (pendiente para la spec 003).

- [x] **T7. Selectores de Web en la barra provisional.** RF-18, RF-19, RF-27, RNF-4, RNF-6
  - Tests:
    - `web_selectors_test`:
      - la barra aparece solo con el indicador de Web activado (inyectable);
      - `ThemeMenuButton` muestra 3 opciones con la activa marcada, y elegir una cambia el tema;
      - `LanguageSwitch` marca la activa, y "PT" cambia el idioma;
      - teclado con `sendKeyEvent`: Tab, Intro, flechas y Esc en el menú; Tab y Espacio en las pastillas;
      - etiquetas en el idioma activo y guías de tamaño táctil.
    - `text_scale_test` (parte de Web): escala 2.0 en PT, sin desbordamiento en la barra.
  - Código: `theme_menu_button.dart`, `language_switch.dart` y la barra de Web en `main_scaffold.dart` (D-6).
  - Hecho cuando: los tests pasan y, en `flutter run -d chrome`, los selectores funcionan con ratón y con teclado.
  - Hecha el 2026-10-20: 11 tests nuevos en verde. **Pendiente que el autor lo pruebe en `flutter run -d chrome`** (ratón y teclado).
    - Para simular Web en los tests, `kIsWeb` pasa por el provider `isWebProvider` (`lib/core/platform/platform_provider.dart`).
    - El tema usa `MenuAnchor` + `IconButton`; el idioma, dos `ChoiceChip` rellenos y en negrita cuando están activos.
    - Tab sale de la página de la pestaña hacia las barras solo si la página tiene algo enfocable. Con una página vacía el foco se queda atrapado; por eso las páginas de prueba de `fake_session.dart` llevan un botón.

- [x] **T8. Errores propios de la app en el idioma activo.** RF-22, caso límite de clienta bloqueada
  - Tests:
    - `error_messages_test`:
      - `AuthController` con un `UserRepository` falso que devuelve una usuaria bloqueada → `AsyncError(AuthFailure.blocked)` y sesión cerrada;
      - una excepción del repositorio → `AuthFailure.unknown`;
      - Login muestra `authBlockedError` en ES y en PT, sin texto técnico;
      - los errores de carga de Reservas, Perfil y Admin muestran su texto `.arb` sin el detalle de la excepción.
  - Código:
    - `auth_failure.dart` y `auth_provider.dart` (D-10).
    - El bloque de error de `login_view.dart`.
    - Los cinco textos `…Error` sin `{error}` (§8) + `flutter gen-l10n`.
    - Las llamadas a esos textos en las vistas, con `debugPrint` del error técnico.
  - Hecho cuando: el test pasa y `grep -rn "authState.error}\|Cuenta bloqueada" lib` no devuelve nada.
  - Hecha el 2026-10-20: 14 tests nuevos en verde. Repositorios falsos en `test/helpers/fake_auth.dart`.
    - `AuthRepository.signInWithGoogle` ya devolvía `null` tanto al cancelar como ante cualquier error de Google (lo registra en el log), así que el controlador no puede distinguirlos: los dos dan `AuthFailure.cancelled` y no se muestra nada. Es el comportamiento que había, sin cambios.
    - Login tiene el título literal "Autenticacion" en la barra (incumple el principio 6): se corrige al migrar Login en T9.

## Bloque B — Migración de las pantallas existentes

Cada tarea:
- Cambia `ThemeColors.*`, `Colors.*`, `Color(0x…)` y el `AppText` antiguo por `context.brand`, el tema y el `AppText` nuevo, según la tabla de §5.
- Añade sus archivos a `no_hardcoded_style_test` y sus pantallas a `screens_theme_test`. Este último pinta cada pantalla en claro y en oscuro, con sus estados vacío, de carga y de error, y comprueba que el fondo es `brand.background` y que se cumple `textContrastGuideline`.

- [x] **T9. Migrar los widgets compartidos, la barra inferior, Login y la captura de WhatsApp.** RF-15, RF-16
  - Archivos: `app_widgets.dart` (34 referencias), `main_scaffold.dart`, `login_view.dart` (19) y `phone_capture_view.dart` (13).
  - Tests: Login y PhoneCapture en las dos listas. El botón de Google va en la lista blanca. Test de los widgets compartidos en los dos temas.
  - Hecho cuando: los tests pasan en claro y en oscuro.
  - Hecha el 2026-10-20: 22 tests nuevos en verde (`no_hardcoded_style_test`, `screens_theme_test` y `app_widgets_theme_test`).
    - El botón de Google móvil sale de `login_view.dart` a `widgets/google_brand_button.dart`, con los colores de la guía de Google. Es la primera entrada de la lista blanca.
    - Los colores de los widgets compartidos pasan a ser opcionales (con `null` se usa el tema), así las pantallas aún no migradas siguen compilando.
    - `AppointmentStatusStyle.forClient/forAdmin` reciben `BrandColors`: se ajustaron sus dos llamadas (perfil y admin).
    - El título literal "Autenticacion" de Login pasa a la clave `loginAppBarTitle` (ES "Autenticación", PT "Autenticação").

- [x] **T10. Migrar Inicio y Servicios.** RF-15, RF-16, RNF-1 (texto sobre foto)
  - Archivos: `home_view.dart` (35), `google_map_container.dart` y `services_view.dart` (18).
  - Tests: Home (con el mapa sustituido, §11) y Services en las dos listas. El mapa va en la lista blanca, y el bloque principal usa `photoScrim`.
  - Hecho cuando: los tests pasan y el velo del bloque principal es `brand.photoScrim`.
  - Hecha el 2026-10-20: 12 tests nuevos en verde (Inicio con y sin sesión y Servicios en `screens_theme_test`, más `home_hero_test`).
    - `HomeView` recibe el mapa por constructor (`map`, por defecto `GoogleMapContainer`) para poder sustituirlo en los tests.
    - El mapa no necesitó entrar en la lista blanca: en el código solo tiene su borde, que ya usa un token.
    - El velo usa `photoScrimStart`/`photoScrimEnd` y el texto sobre la foto, `onPhoto`.

- [x] **T11. Migrar Reservas con fechas localizadas y estado conservado.** RF-5, RF-10, RF-15, RF-16, RF-21
  - Archivos: `booking_view.dart` (59).
  - Tests:
    - Booking en las dos listas.
    - `localized_dates_test`: cabecera "Outubro de 2026" / "Octubre de 2026", semana desde el lunes, horas `HH:mm` y fecha larga del diálogo en el idioma activo.
    - `state_preserved_test`: con una fecha y una hora elegidas y el diálogo de confirmación abierto, cambiar el tema y el idioma no pierde nada.
  - Hecho cuando: los tests pasan y `booking_view` ya no usa `SpanishDates`.
  - Hecha el 2026-10-20: 20 tests nuevos en verde (`localized_dates_test`, `state_preserved_test`, Reservas en 4 estados en `screens_theme_test` y `capitalize_test`).
    - Nuevo `lib/core/utils/capitalize.dart`, porque `intl` da los meses en minúscula. Su test se escribió a la vez que la función, no antes.
    - Los textos y la fecha del diálogo de confirmación se calculan dentro de su `builder`: si cambia el idioma con el diálogo abierto, el diálogo también cambia.
    - El `GoldPillButton` deshabilitado pasa a fondo `placeholder` y texto `inkMuted`, legible (la guía de contraste del test no exime lo deshabilitado).
    - Los días pasados y los de otro mes del calendario usan `inkMuted` (legibles) en lugar de un oliva al 35 %.
    - Los tests usan como día elegido "mañana", porque el calendario no admite días pasados.

- [x] **T12. Migrar Perfil.** RF-10, RF-15, RF-16, RF-21
  - Archivos: `profile_view.dart` (34).
  - Tests: Profile, con y sin sesión, en las dos listas. Las fechas de "mis turnos" salen en el idioma activo.
  - Hecho cuando: los tests pasan y `profile_view` ya no usa `SpanishDates`.
  - Hecha el 2026-10-20: 12 tests nuevos en verde (Perfil sin sesión, con turnos en los tres estados, de admin y con error en `screens_theme_test`, más `profile_dates_test`).
    - Los turnos cancelados ya no van al 72 % de opacidad: su texto quedaba en 3,02:1 en claro y 4,05:1 en oscuro. Se distinguen por el tono suave y la etiqueta "CANCELADA".
    - `textContrastGuideline` no tiene en cuenta la opacidad, así que un test aparte comprueba que no hay `Opacity` (se vio fallar con ella puesta).

- [x] **T13. Migrar las tres pantallas de administración.** RF-10, RF-15, RF-16, RF-21, RF-23
  - Archivos: `admin_dashboard_view.dart` (38), `admin_users_view.dart` (16) y `admin_settings_view.dart` (18).
  - Tests:
    - AdminDashboard, AdminUsers y AdminSettings en las dos listas.
    - La fecha del panel sale en el idioma activo.
    - El `AnnotatedRegion` de la cabecera usa `systemBarsStyleFor(brand.brand)`.
  - Hecho cuando: los tests pasan y ningún archivo usa `SpanishDates`.
  - Hecha el 2026-10-20: 18 tests nuevos en verde (6 estados de admin en `screens_theme_test`, más `admin_header_test`).
    - La cabecera usa solo `brand`, `onBrand` y `onBrandMuted`, como fija §5 del plan: la fecha y los iconos pasan de crema a dorado.
    - Las cajas de la fecha y de los contadores pierden su relleno crema al 8 %, que bajaba el contraste a 4,08:1 y 4,15:1. Quedan solo con borde dorado.
    - `screens_theme_test` usa dos `pump()` en vez de `pumpAndSettle`, porque los indicadores de carga giran sin fin.
    - Fallo previo, fuera de esta spec: Ajustes del calendario lee la configuración con `ref.read` una sola vez. Si nadie la tiene cargada (no se pasó por Reservas), se queda cargando para siempre. En el test se mantiene escuchada.

- [x] **T14. Cierre: borrar lo antiguo y actualizar la documentación.** RF-15, criterios de finalización
  - Tests: `no_hardcoded_style_test` pasa a revisar `lib/features/**` y `lib/core/widgets/**` enteros, con su lista blanca.
  - Código:
    - Se borran `theme_colors.dart`, `spanish_dates.dart`, `Jost-Variable.ttf` y `OFL-Jost.txt`, y se quita Jost de `pubspec.yaml`.
    - Se actualizan `CLAUDE.md` (selector de idioma, `lib/core/theme/` y fin del aviso de `DateFormat('EEEE')`) y `MEMORY.md`.
  - Hecho cuando: la puerta está en verde, `grep -rE "ThemeColors|SpanishDates|Jost" lib pubspec.yaml` no devuelve nada y la spec está lista para `/sdd-validate`.
  - Hecha el 2026-10-20: 257 tests en verde.
    - `no_hardcoded_style_test` revisa `lib/features` y `lib/core/widgets` enteros (24 archivos, más la excepción del botón de Google).
    - Test nuevo `legacy_cleanup_test`: lo antiguo no existe y Cormorant e Inter siguen incluidas.
    - Borrados `theme_colors.dart`, `spanish_dates.dart`, `Jost-Variable.ttf` y `OFL-Jost.txt` (sin preparar en git), y Jost quitada de `pubspec.yaml`.
    - `CLAUDE.md` actualizado (tests, tema y colores, idioma, `weekdayKey`). `MEMORY.md` resumido.

## Propuesta de división

Salen **14 tareas**, más de 10. El corte natural es entre los dos bloques:

- **001-design-system** (Bloque A, T1 a T8): todo lo que no es migrar pantallas.
  - Tema, idioma, guardado y selectores.
  - Barras del sistema y errores localizados.
  - RF-1 a RF-14, RF-17 a RF-20, RF-22 a RF-27 y RNF-1 a RNF-6 (en los tokens).

  Al terminarlo, todo funciona, aunque las pantallas antiguas sigan con colores fijos en el tema oscuro.
- **001b-migracion-pantallas** (Bloque B, T9 a T14): RF-15, RF-16, RF-21 y la parte de RF-5 y RF-10 que depende de las pantallas.

Dividir obliga a pasar por `/sdd-change`: se mueven esos RF a una spec nueva y las dos vuelven a borrador.

**Recomendación: no dividir.** Cada tarea es de 20 a 30 minutos y van en orden, así que partir la spec solo añade trámite. Propongo en su lugar una **validación parcial al terminar el Bloque A**: un recorrido manual de tema e idioma antes de empezar la migración.

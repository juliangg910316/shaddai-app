# Tareas 003 — Navegación móvil (Android/iOS)
Estado: aprobada

Spec: `spec.md` (aprobada) · Plan: `plan.md` (aprobado). En cada tarea, los tests se escriben primero y se ven en rojo. La tarea termina con `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde.

- [x] **T1. Disposición de las secciones sin depender del ancho de la ventana.** RF-5, RF-12, D-4
  - Tests:
    - `landing_layout_scope_test.dart`:
      - una sección sin `LandingLayout` encima se dibuja en estrecho también a 1280 px (tableta en horizontal);
      - con `LandingLayout(wide: true)`, en ancho;
    - los tests de la landing de Web siguen en verde sin tocarlos.
  - Hecho cuando: ninguna sección usa `WebShell.isWide` y `LandingPage` pone el `LandingLayout`.
  - Hecha (2026-10-21):
    - `LandingLayout` y `landingIsWide` (`lib/features/landing/presentation/landing_layout.dart`);
    - las 10 secciones usan `landingIsWide`;
    - `LandingPage` pone `LandingLayout(wide: ancho ≥ 900)`;
    - 4 tests;
    - los tests de Web, sin cambios;
    - suite completa: 534 en verde.

- [x] **T2. Reglas de redirección de móvil.** RF-16, RF-17, D-6
  - Tests: `redirect_logic_test`, con la tabla de móvil actualizada:
    - `/booking` sin sesión → nada;
    - sin WhatsApp en `/booking` → `/capture_phone?next=/booking`;
    - captura completa con `next=/booking` → `/booking`;
    - `/login` con sesión y sin `next` → `/home`;
    - `safeNext` de móvil (por defecto `/home`, sin `/`);
    - la tabla de Web sin cambios.
  - Hecho cuando: `resolveRedirect` y `safeNext` cumplen la tabla y los tests de Web siguen en verde.
  - Hecha (2026-10-21):
    - en móvil, sin sesión no se redirige; sin WhatsApp, a `/capture_phone?next=<origen>`; tras login o captura, a `safeNext(next, isWeb: false)`, que por defecto lleva a `/home`;
    - `safeNext` recibe `isWeb`;
    - `CLAUDE.md` actualizado;
    - 18 tests nuevos en la tabla;
    - suite completa: 552 en verde.
    
    **Estado intermedio hasta T7:** en móvil, Reservas sin sesión muestra el calendario sin poder reservar, porque `_confirmBooking` exige usuaria. El aviso llega en T7.

- [x] **T3. Barra inferior con `NavigationBar` y volver arriba.** RF-1–4, RNF-1, RNF-4 (barra), D-2, D-3, D-5
  - Tests:
    - helper `pumpMobileApp` (router real, `isWebProvider` = `false`, sesión falsa, fuentes reales, `salonMapProvider`);
    - `mobile_tabs_test.dart`:
      - **barra:** cuatro destinos con y sin sesión; la activa marcada y "seleccionada"; destinos de 48 px o más;
      - **estado:** al cambiar de pestaña y volver se conserva el scroll;
      - **volver arriba:** tocar la pestaña activa vuelve al comienzo;
      - **texto al 200 %:** solo iconos con nombre accesible y sin desbordes a 320 px;
    - se actualizan los tests que buscaban `BottomNavigationBar` (`web_shell_test`, `preferences_section_test`, `web_selectors_test`).
  - Hecho cuando:
    - `MainScaffold` usa `NavigationBar` con `navigationBarTheme` de los tokens;
    - `tabScrollControllerProvider` existe;
    - la barra pasa las guías de tamaño en claro y oscuro.
  - Hecha (2026-10-21):
    - `MainScaffold` con `NavigationBar` (iconos con relleno en la activa y tooltips); por encima de 1,3× de texto, solo iconos;
    - `navigationBarTheme`;
    - `tabScrollControllerProvider` y `MobileTab`; el scroll principal de las cuatro pestañas usa su controlador, y tocar la activa vuelve arriba;
    - `pumpMobileApp`;
    - `salonMapProvider` adelantado de T4, porque el helper lo necesita para no construir el mapa nativo;
    - los helpers arrancan la app directamente en la dirección pedida (`defaultRouteNameTestValue`);
    - se actualizan `typography_test`, `home_hero_test`, `preferences_section_test` y `web_shell_test`;
    - 11 tests nuevos;
    - suite completa: 564 en verde.

- [x] **T4. Contacto con mapa y redes.** RF-10, RF-11, D-7
  - Tests: `contact_section_mobile_test.dart`:
    - con `map` y `showSocialLinks`, el contacto muestra el mapa (sustituido) con su etiqueta accesible y las cuatro redes, que abren su enlace;
    - sin esos parámetros, igual que en Web;
    - el mapa mide 220 px de alto.
  - Hecho cuando: `ContactSection` acepta los dos parámetros, `GoogleMapContainer` tiene alto fijo y `salonMapProvider` existe.
  - Hecha (2026-10-21):
    - `ContactSection(map:, showSocialLinks:)`: las redes van debajo de los datos y el mapa al final, con el nombre accesible `salonMapLabel` (ES/PT); sin parámetros, igual que en Web;
    - `GoogleMapContainer.height = 220`;
    - `salonMapProvider` ya venía de T3;
    - 9 tests;
    - suite completa: 573 en verde.

- [x] **T5. Nueva pestaña Inicio.** RF-5–11, RF-20 (Inicio)
  - Tests: `mobile_home_test.dart`, en ES y PT:
    - presentación, galería, "Sobre mí" y contacto, en orden;
    - "Reservar cita" (presentación y contacto) → pestaña Reservas;
    - "Ver lista de precios" → Servicios desde arriba;
    - URL registrada de galería, "Ver más", dirección, WhatsApp, teléfono, correo, Instagram y redes;
    - mapa en el contacto;
    - ningún texto de ejemplo (`$25`, "Servicios populares", "Nuestros trabajos").
    
    Se reescriben `home_hero_test` y los casos de Inicio de `screens_theme_test`.
  - Hecho cuando: `HomeView` solo muestra contenido de la landing y usa el `ScrollController` de su pestaña.
  - Hecha (2026-10-21):
    - `HomeView` reescrita: `HeroSection` ("Ver lista de precios" abre Servicios arriba), `GallerySection`, `AboutSection` y `ContactSection(map, showSocialLinks: true)`, en el scroll de su pestaña;
    - `home_hero_test` pierde el test del Inicio de ejemplo;
    - `screens_theme_test` sigue montando `HomeView` y pasa con el contenido nuevo;
    - 18 tests nuevos;
    - suite completa: 589 en verde.
    
    Las claves de ejemplo se borran en T8.

- [x] **T6. Nueva pestaña Servicios.** RF-12–15, RF-20 (Servicios), RF-21
  - Tests: `mobile_services_test.dart`:
    - "Reservar cita", precios, combos, catálogo y atención, en orden;
    - los 34 importes iguales a los de la landing en ES y PT;
    - el catálogo se amplía y se cierra con el botón, tocando fuera y con "atrás", sin mover el scroll;
    - "más páginas" → Instagram;
    - "Reservar cita" → Reservas.
    
    Se reescriben los casos de Servicios de `screens_theme_test`.
  - Hecho cuando: `ServicesView` solo muestra contenido de la landing y usa el `ScrollController` de su pestaña.
  - Hecha (2026-10-21):
    - `ServicesView` reescrita: "Reservar cita" (dorado, a `/booking`), `PricesSection`, `CombosSection`, `CatalogSection` e `InfoSection`, en el scroll de su pestaña;
    - el "atrás" del sistema cierra el catálogo ampliado sin código nuevo, porque el diálogo es una ruta;
    - `screens_theme_test` sigue montando `ServicesView` y pasa;
    - 10 tests;
    - suite completa: 599 en verde.

- [x] **T7. Aviso de inicio de sesión en Reservas.** RF-16–19
  - Tests: `mobile_booking_sign_in_test.dart`:
    - sin sesión, el aviso aparece con la barra visible (ES y PT);
    - al iniciar sesión con WhatsApp, la reserva en la misma pestaña;
    - sin WhatsApp: captura y vuelta a Reservas;
    - bloqueada: su mensaje;
    - fallo: error;
    - cancelación: sin mensaje;
    - al cerrar sesión con una fecha elegida, vuelve al aviso.
  - Hecho cuando: `BookingView` muestra `BookingSignInPrompt` sin sesión, `LoginView` usa `authErrorMessage` y los textos `bookingSignIn…` están en ES y PT.
  - Hecha (2026-10-21):
    - `BookingSignInPrompt`: sello, título, texto y controles de Google;
    - `authErrorMessage`;
    - `GoogleSignInControls`, compartido por el login y el aviso (no estaba en el plan; evita duplicar el bloque, sin cambiar el comportamiento);
    - `BookingView` muestra el aviso sin sesión;
    - textos `bookingSignInTitle`/`bookingSignInBody` en ES y PT;
    - 9 tests;
    - suite completa: 611 en verde.
    
    Termina el estado intermedio de T2.

- [x] **T8. Retirada del contenido de ejemplo.** RF-20, RNF-5
  - Tests: `mobile_content_test.dart`:
    - las 34 claves de ejemplo ya no existen en los `.arb`;
    - Inicio y Servicios no cargan ninguna imagen de red (sin conexión se ven, salvo el mapa);
    - las mismas claves en ES y PT.
  - Hecho cuando: se han borrado las claves, `flutter gen-l10n` está regenerado y no queda código de ejemplo en `home/` ni `services/`.
  - Hecha (2026-10-21):
    - borradas 36 claves en ES y PT: las 34 del plan más `welcomeBack` y `bookAction`, que también eran del Inicio y la carta de ejemplo. `bookAppointment` se queda, porque la usa la cabecera de la reserva;
    - el borrado se hizo línea a línea, conservando el formato;
    - `mobile_content_test`: sin claves de ejemplo, las mismas claves en ES y PT, e Inicio y Servicios sin imágenes de red;
    - 5 tests;
    - suite completa: 616 en verde.
    
    Quedan sin uso `adminTab` y `selectedOption`, restos anteriores que no son de ejemplo.

- [x] **T9. Accesibilidad de las pestañas.** RNF-2–4
  - Tests: `mobile_accessibility_test.dart`, en claro y oscuro, a 320 y 412 px:
    - Inicio, Servicios y el aviso, recorridos sección a sección, con `textContrastGuideline`, `labeledTapTargetGuideline` y `androidTapTargetGuideline`;
    - al 200 %, sin desbordes;
    - imágenes con descripción en el idioma activo.
  - Hecho cuando: todo pasa, y lo que falle se corrige con tokens o con la disposición, no quitando el test.
  - Hecha (2026-10-21):
    - `mobile_accessibility_test`: Inicio, Servicios y el aviso, en claro y oscuro, a 320 y 412 px, con las tres guías; al 200 % a 320 px en ES y PT; descripciones de las imágenes;
    - no apareció ningún fallo real. El único rojo fue la medición: un texto a medias bajo la barra inferior daba 1,42:1 con el verde de la barra. El contenido se mide con la pestaña sola, como en Web; la barra, en `mobile_tabs_test`;
    - 20 tests;
    - suite completa: 636 en verde.

- [x] **T10. Cierre.** Criterios de finalización
  - Tests: suite completa en verde; los tests de Web, sin cambios en su comportamiento.
  - Hecho cuando:
    - `CLAUDE.md` describe la barra inferior (`NavigationBar`), `LandingLayout`, las reglas de móvil de `resolveRedirect` y `pumpMobileApp`;
    - `MEMORY.md` está actualizado;
    - se indican al autor los pasos del recorrido manual en Android e iOS.
  - Hecha (2026-10-21):
    - `mobile_closure_test` protege los criterios: sin literales de interfaz, secciones sin depender del ancho de la ventana, sin `BottomNavigationBar` y sin excepciones de color nuevas. Pasó a la primera porque los criterios ya se cumplían;
    - `CLAUDE.md` describe la barra, el scroll por pestaña, Inicio y Servicios, el aviso, `LandingLayout` y `pumpMobileApp`;
    - suite completa: 640 en verde.
    
    Pendiente para la spec 010: el nombre bajo el icono es "shaddai" (Android) y "Shaddai" (iOS), no "Studio Shaddai".

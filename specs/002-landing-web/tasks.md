# Tareas 002 — Landing de una página en Web
Estado: aprobada

Spec: `spec.md` (aprobada) · Plan: `plan.md` (aprobado). En cada tarea, los tests se escriben primero y se ven en rojo. La tarea termina con `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde.

## Base

- [x] **T1. Enlaces externos.** RF-8–10, RF-12 (base), D-1, D-12
  - Tests:
    - `test/core/platform/external_links_test.dart`: el lanzador abre las URLs `https` en pestaña nueva y `tel:`/`mailto:` en la misma;
    - si `launchUrl` devuelve `false` o lanza, no propaga el error;
    - helper `RecordingLinkLauncher` en `test/helpers/`.
  - Hecho cuando: `url_launcher` está en `pubspec.yaml` y `externalLinkLauncherProvider` existe y pasa sus tests.
  - Hecha (2026-10-21):
    - `url_launcher` ^6.3.3;
    - `lib/core/platform/external_links.dart`: `externalLinkLauncher` recibe `launchUrl` como parámetro para poder probarlo;
    - 8 tests;
    - suite completa: 278 en verde.

- [x] **T2. Redirección como función pura.** RF-19–21, RF-24, RF-29, D-3, D-4, D-10
  - Tests: `test/core/router/redirect_logic_test.dart`, con una tabla de casos para `resolveRedirect` y `safeNext`:
    - **móvil:** el mismo resultado que el `redirect` actual en todos los casos;
    - **Web:** sin sesión en página de cuenta → `/login?next=…`; sin WhatsApp en landing → nada; sin WhatsApp en cuenta → `/capture_phone?next=…`; clienta en `/admin` → `/`; `/home` → `/`; `/services` → `/?section=prices`; `/login` con sesión → `next` validado;
    - **`next` inválido** (`https://x`, `//x`, `/nada`) → `/`.
  - Hecho cuando: `goRouterProvider` usa `resolveRedirect` y los tests de móvil existentes siguen en verde.
  - Hecha (2026-10-21):
    - `lib/core/router/redirect_logic.dart` (`RedirectInput` con `needsPhone`, `resolveRedirect`, `safeNext`);
    - 71 tests;
    - suite completa: 349 en verde.
    
    El router pasa `isWeb: false` hasta que T4 cree la tabla de rutas de Web; **T4 debe cambiarlo a `isWebProvider`**.

- [x] **T3. Tokens de superficie de marca.** RNF-1, D-6
  - Tests: `brand_colors_contrast_test` ampliado con `brandSurface`, `onBrandSurface`, `onBrandSurfaceMuted` y `accentText`/`accentIcon` sobre `brandSurface`, en claro y oscuro; `brand_colors_test` con `copyWith` y `lerp` de los nuevos.
  - Hecho cuando: los cuatro tokens existen con valores opacos que cumplen AA y quedan anotados en el plan (§ D-6).
  - Hecha (2026-10-21):
    - cinco tokens: los cuatro previstos más `onBrandSurfaceAccent` (decisión del autor), porque `accentText` sobre la crema solo daba 4,26:1;
    - valores finales en el plan, § D-6;
    - 12 tests nuevos;
    - suite completa: 361 en verde.

## Estructura de Web

- [x] **T4. Rutas de Web y `WebShell`.** RF-1 (entrada), RF-13, RF-18, RF-29, RF-30
  - Tests:
    - helper `pumpWebApp` (router real, `isWebProvider` = `true`, sesión falsa, ancho);
    - `web_shell_test.dart`: `/` muestra la landing (vacía por ahora) dentro de `WebShell`; `/home` → `/`; en Web no hay `BottomNavigationBar` ni barra provisional, en móvil sí;
    - las páginas de cuenta a 1280 px no pasan de 640 px y van centradas.
  - Hecho cuando: Web usa su tabla de rutas con `ShellRoute` y `MainScaffold` queda solo para móvil.
  - Hecha (2026-10-21):
    - el router lee `isWeb` de `isWebProvider` y tiene dos tablas de rutas: en Web, `ShellRoute(WebShell)` con la landing en `/`;
    - `WebShell` centra las páginas de cuenta a 640 px;
    - `WebTopBar` ya lleva los selectores de tema e idioma, para no dejar Web sin ellos (RF-27 de la 001); T5 la completa;
    - la página va en su propio contenedor semántico: el `BlockSemantics` de la ruta anidada ocultaba la barra a los lectores de pantalla;
    - `web_selectors_test` pasa a la barra de Web; sus pruebas de teclado arrancan en `/login` porque la landing aún no tiene nada enfocable. **T13 debe probar el teclado en la landing**;
    - helper `pumpWebApp`;
    - suite completa: 373 en verde.

- [x] **T5. Barra superior y menú lateral.** RF-13–15, caso límite de ancho
  - Tests: `web_top_bar_test.dart`:
    - **a 1280 px:** logotipo con nombre, tres enlaces, selectores de tema e idioma y "Reservar";
    - **a 360 px:** sin nombre, enlaces ni selectores y con botón de menú; el menú lateral muestra los selectores de tema e idioma y los tres enlaces, no se cierra al cambiar el tema y se cierra al ensanchar la ventana (RF-15, cambio del 2026-10-21);
    - **siempre:** el logotipo lleva a `/` arriba; la barra sigue visible tras desplazar; todo lo pulsable mide ≥ 48 px y tiene etiqueta.
  - Tests afectados: en `web_selectors_test`, la prueba del texto al 200 % a 360 px busca los selectores en el menú lateral.
  - Hecho cuando: la barra se ve en todas las páginas de Web y sus textos están en los `.arb` en ES y PT.
  - Hecha (2026-10-21):
    - `WebTopBar` completa y `WebMenuDrawer`;
    - `WebShell` cierra el menú al ensanchar la ventana;
    - `LandingSection` y `goToLandingSection`/`goToLandingTop`: desplazan la landing si ya se ve (`landingPageKey`) o vuelven a `/?section=…`;
    - 7 textos `web…` en los `.arb`;
    - `GoogleBrandButton` parte su texto en vez de desbordarse a 360 px;
    - 19 tests nuevos;
    - suite completa: 392 en verde.
    
    Pendiente: el desplazamiento real a cada sección (las claves de sección llegan en T8; se prueba en T12) y el botón de cuenta (T6).

- [x] **T6. Botón de cuenta.** RF-24–28, caso límite de admin
  - Tests: `account_button_test.dart`:
    - **sin sesión:** "Entrar" → `/login` → tras la sesión, `/`;
    - **con sesión:** foto o, si no hay, inicial;
    - **menú de clienta:** "Mis turnos" y "Cerrar sesión", sin panel;
    - **menú de admin:** además, "Panel de administración" → `/admin`;
    - "Mis turnos" → `/profile`;
    - "Cerrar sesión" → `/` sin sesión;
    - clienta en `/admin` → `/`.
  - Hecho cuando: el botón de cuenta está en la barra y pasa los tests en ES y PT.
  - Hecha (2026-10-21):
    - `AccountButton`: "Entrar", o foto o inicial con un menú `MenuAnchor`. Si la foto no carga, muestra la inicial. "Cerrar sesión" lleva a `/` y después cierra la sesión;
    - 5 textos `account…`;
    - `pumpWebApp` usa `FakeWebSession`, una sesión que cambia durante el test (`signIn`/`signOut`);
    - en la barra, el nombre del logotipo se recorta y el grupo de botones se reduce de escala si no cabe (fuente de los tests o texto grande);
    - 15 tests nuevos;
    - suite completa: 407 en verde.
    
    **Para T13:** la reducción de escala puede dejar los botones por debajo de 48 px con el texto al 200 %. Comprobarlo allí con `androidTapTargetGuideline`, que mide lo pintado.

- [x] **T7. Reserva y perfil en Web.** RF-19–23, RF-31
  - Tests: `web_booking_flow_test.dart`:
    - "Reservar" sin sesión → login → sesión simulada → reserva;
    - sin WhatsApp → captura → reserva;
    - con sesión → reserva;
    - reserva creada con repositorio falso → diálogo → "Volver al inicio" → `/`;
    - clienta bloqueada → sigue en el login con su mensaje.
    
    Además, el perfil en Web no tiene Preferencias y su botón de salir lleva a `/`; en móvil, sin cambios.
  - Hecho cuando: el recorrido de reserva funciona en Web con fakes y los tests de reserva y perfil en móvil siguen en verde.
  - Hecha (2026-10-21):
    - en Web, la reserva creada abre un diálogo "Reserva creada" con "Cerrar" (texto de Material) y "Volver al inicio"; en móvil sigue el SnackBar;
    - el perfil en Web va sin Preferencias, y su botón de salir lleva a `/` antes de cerrar la sesión;
    - 2 textos `booking…`;
    - helpers: `RecordingBookingRepository`; `pumpWebApp` acepta repositorios propios y guarda el WhatsApp en la sesión falsa;
    - 11 tests nuevos;
    - suite completa: 418 en verde.

## Landing

- [x] **T8. Contenido, assets y esqueleto de la landing.** RF-1, RF-2 (base), RNF-6
  - Tests:
    - `landing_page_test.dart`: las diez secciones aparecen en orden, por posición vertical de sus claves;
    - `legacy_cleanup_test` (o uno nuevo): las 19 imágenes existen y están en `pubspec.yaml`;
    - el título de la pestaña sale de `webAppTitle` en ES y PT.
  - Hecho cuando:
    - los unos 140 textos de shaddai-web están en los `.arb` con prefijo `landing`;
    - `landing_content.dart` y `LandingSection` existen;
    - `MyApp` usa `onGenerateTitle`;
    - las secciones existen como esqueleto con su título.
  - Hecha (2026-10-21):
    - 134 textos `landing…` en ES y PT: los 131 de shaddai-web, sin los de navegación y los genéricos, más "Soft Gel", "Combos" y "Shaddai", que allí estaban en el código; además, `webAppTitle`;
    - `LandingContent` con enlaces, contacto, redes, cifras e imágenes. Precios y combos llegan con sus secciones (T9, T10);
    - 19 imágenes en `assets/images/landing/` (3,5 MB); la carpeta `instagram` pasa a llamarse `galeria`;
    - `LandingSectionFrame` marca cada sección;
    - `onGenerateTitle`;
    - 6 tests;
    - suite completa: 425 en verde.

- [x] **T9. Hero, franja y lista de precios.** RF-2, RF-3, RF-5, RF-9 (hero)
  - Tests:
    - hero en ES y PT: textos, cifras fijas, dirección → URL de Maps registrada, "Ver lista de precios" desplaza a precios;
    - la franja se detiene con `disableAnimations` y queda fuera del árbol semántico;
    - los seis bloques de precios y sus importes en R$ son iguales en los dos idiomas.
  - Hecho cuando: las tres secciones coinciden con shaddai-web y los tests no usan `pumpAndSettle` con la franja activa.
  - Hecha (2026-10-21):
    - `HeroSection`: "Reservar cita" lleva a `/booking` (en shaddai-web abría WhatsApp); la dirección abre Maps; la foto va con insignia;
    - `MarqueeStrip`: sin semántica; con `disableAnimations` para su `Ticker`;
    - `PricesSection` con los datos de `LandingContent.priceCards` (seis bloques);
    - `LandingSectionHeader` y `LandingImage`, adelantado de T10 porque lo necesita la foto del hero;
    - 3 literales más de shaddai-web pasan a los `.arb`: "1ª visita ♡", "Baby boomer" y "Reversa";
    - `pumpWebApp` pide reducir animaciones por defecto (`reduceMotion`); el test del movimiento lo desactiva;
    - 17 tests nuevos;
    - suite completa: 442 en verde.

- [x] **T10. Combos, catálogo y atención.** RF-3, RF-6–8, RNF-3
  - Tests:
    - los tres combos en R$;
    - una página del catálogo se amplía y se cierra con el botón, con un clic fuera y con Esc, sin cambiar el scroll;
    - "más páginas" → Instagram;
    - cada imagen tiene su descripción en el idioma activo;
    - una imagen rota muestra el recuadro con la descripción;
    - las cuatro normas de atención en ES y PT.
  - Hecho cuando: las tres secciones coinciden con shaddai-web.
  - Hecha (2026-10-21):
    - `CombosSection` sobre `brandSurface`; `LandingSectionHeader` acepta `onBrandSurface`;
    - `CatalogSection`: fila horizontal con las 9 páginas y la tarjeta de Instagram. La página ampliada va en un `Dialog` con velo `photoScrimEnd`; su botón de cerrar usa el texto de Material, así que no hace falta la clave `catalogCloseLabel` del plan;
    - `InfoSection`;
    - combos y descripciones del catálogo como datos en `LandingContent`;
    - la tarjeta de Instagram reduce su contenido si no cabe con el texto al 200 %;
    - 18 tests nuevos;
    - suite completa: 459 en verde.
    
    **Para T13:** el catálogo es un carrusel con scroll horizontal propio, que no es scroll de la página (RNF-5). El test de disposición debe admitirlo.

- [x] **T11. Galería, sobre mí, contacto, pie y WhatsApp flotante.** RF-8–12, RNF-3
  - Tests:
    - cada foto de la galería y "Ver más en Instagram" → Instagram;
    - contacto: teléfono, correo, dirección, Instagram y "Agenda por WhatsApp" → su URL;
    - pie: TikTok, Facebook, YouTube e Instagram → su URL;
    - el botón flotante sigue visible tras desplazar al final y abre WhatsApp;
    - con el lanzador fallando, la página sigue igual.
  - Hecho cuando: la landing tiene las diez secciones completas.
  - Hecha (2026-10-21):
    - `GallerySection`, `AboutSection`, `ContactSection`, `FooterSection` y `WhatsappFloatButton`; ya no queda ninguna sección en esqueleto;
    - el botón flotante usa los colores de la marca (dorado sobre verde, ≥ 4,5:1) y no el verde de WhatsApp: el icono blanco sobre #25D366 da 1,98:1 y la excepción de color de la 001 cubre el logotipo, no el botón;
    - el centrado de las páginas de cuenta pasa de `WebShell` a `WebAccountPage`, en cada ruta. Si se limitaba el navegador entero, la landing se desbordaba durante la transición al salir de ella;
    - `LandingSectionHeader` acepta `trailing`;
    - 29 tests nuevos;
    - suite completa: 488 en verde.

- [x] **T12. Ir a una sección.** RF-4, RF-5, RF-16, RF-17, RF-29
  - Tests: `landing_navigation_test.dart`:
    - Servicios, Catálogo y Sobre mí de la barra dejan el comienzo de la sección justo debajo de la barra;
    - lo mismo desde el menú lateral, que se cierra;
    - `/?section=about` abre en esa sección;
    - desde `/profile`, "Catálogo" → landing en el catálogo;
    - `/services` → landing en precios;
    - cambiar el tema a media página mantiene el scroll.
  - Hecho cuando: todos los enlaces de sección funcionan en ancho amplio y estrecho.
  - Hecha (2026-10-21):
    - `LandingPage` recibe la sección de `?section=` y salta a ella tras el primer fotograma, sin animación;
    - la barra, el menú lateral y el logotipo ya funcionaban desde T5 y T8 (`goToLandingSection`/`goToLandingTop` y las claves de sección); ahora quedan probados;
    - una sección desconocida abre la landing arriba;
    - 11 tests nuevos;
    - suite completa: 499 en verde.

- [x] **T13. Accesibilidad y disposición.** RNF-1–5
  - Tests:
    - `landing_accessibility_test.dart`, en claro y oscuro, a 360 y 1280 px: `textContrastGuideline`, `labeledTapTargetGuideline` y `androidTapTargetGuideline`; Tab recorre la barra y activa "Reservar" con Intro;
    - `landing_layout_test.dart`: a 320, 360 y 1280 px sin desbordamientos; con `textScaler` 2.0 a 360 y 1280 px sin desbordamientos; el único scroll de página es vertical.
  - Hecho cuando: todo pasa sin excepciones, y lo que haya fallado se ha corregido con tokens o con la disposición, no quitando el test.
  - Hecha (2026-10-21):
    - **fallos reales corregidos:**
      - con el texto al 200 %, la reducción de escala de la barra dejaba los botones en 44,6 px: la barra ya no reduce; crece y pasa los botones a otra fila (`Wrap`, alto mínimo de 64 px);
      - con Tab, el botón flotante de WhatsApp volvía a quedar "a continuación" cada vez que la landing se desplazaba: contenido y botón van en dos `FocusTraversalGroup`;
      - con sesión, el avatar de la cuenta hacía la barra 5 px más alta: pasa a 32 px;
      - el pie deja sitio abajo para el botón flotante;
    - **tests:**
      - `pumpWebApp` carga Inter y Cormorant reales (`loadAppFonts`);
      - el contraste del contenido se mide con la landing sola y sin el botón flotante (`showLandingFloatButtonProvider`), porque la guía tomaba como fondo de un texto los colores de la barra o del botón que lo tapaban;
      - la barra se mide aparte;
      - el teclado se prueba en la landing (pendiente de T4);
      - el carrusel del catálogo y la franja son los únicos scroll horizontales permitidos (pendiente de T10);
      - 24 tests nuevos;
    - suite completa: 523 en verde.

- [x] **T14. Cierre.** Criterios de finalización
  - Tests: `no_hardcoded_style_test` sin excepciones nuevas para `lib/features/landing` y `navigation`; suite completa en verde.
  - Hecho cuando:
    - `CLAUDE.md` describe las rutas de Web, `resolveRedirect`, `WebShell`, la landing y `externalLinkLauncherProvider`;
    - `MEMORY.md` está actualizado;
    - se indican al autor los pasos del recorrido manual en Chrome, incluido `flutterfire configure` con Web.
  - Hecha (2026-10-21):
    - `web_closure_test.dart`: sin literales de interfaz en `landing` ni `navigation`, sin excepciones de color nuevas y el título de `web/index.html`;
    - `web/index.html` se titulaba "Shaddai", el nombre antiguo, mientras cargaba la app; ahora "Studio Shaddai · Nail Designer";
    - `CLAUDE.md` describe las rutas de Web, `resolveRedirect`, `WebShell`/`WebAccountPage`, la landing, `externalLinkLauncherProvider` y `pumpWebApp`;
    - suite completa: 526 en verde.
    
    Pendiente para la spec 010: `web/manifest.json` es todavía la plantilla de Flutter (nombre, descripción y colores), y `firebase.json` no tiene la entrada de Web, aunque `firebase_options.dart` sí la tiene.

## Cambio pendiente (RF-32, 2026-10-21)

- [x] **T15. "Reservar cita" en contacto.** RF-19, RF-32
  - Tests: en `landing_gallery_contact_test`, el botón "Reservar cita" de contacto:
    - existe, en ES y PT;
    - sin sesión lleva a `/login?next=/booking`;
    - "Agenda por WhatsApp" sigue abriendo WhatsApp.
    
    Además, `landing_layout_test` y `landing_accessibility_test` deben seguir en verde.
  - Hecho cuando: contacto muestra los dos botones, "Reservar cita" como principal, y la suite está en verde.
  - Hecha (2026-10-21):
    - en `ContactSection`, "Reservar cita" (dorado, a `/booking`) y "Agenda por WhatsApp" (contorno) van en un `Wrap`;
    - reutiliza `landingHeroCtaReserve`, sin textos nuevos;
    - 3 tests nuevos;
    - la prueba de teclado de `landing_accessibility_test` vuelve a buscar el botón de WhatsApp;
    - suite completa: 529 en verde.

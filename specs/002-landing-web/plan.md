# Plan 002 — Landing de una página en Web
Estado: aprobada

Spec: `specs/002-landing-web/spec.md` (aprobada el 2026-10-21).

## 1. Qué existe ya

| Pieza | Dónde | Uso en esta spec |
| --- | --- | --- |
| Tema claro/oscuro/sistema, idioma ES/PT, tokens `BrandColors`, `AppText`, ayudas de contraste | `lib/core/theme/`, spec 001 | Base de todos los colores y textos de la landing (RNF-1) |
| Selectores de tema (`ThemeMenuButton`) e idioma (`LanguageSwitch`) | `lib/features/preferences/presentation/` | Se reutilizan en la barra superior |
| Sello de la marca (`BrandLogo`) | `lib/core/widgets/brand_logo.dart` | Logotipo de la barra superior (RF-14) |
| `isWebProvider` | `lib/core/platform/` | Elige las rutas de Web o de móvil |
| Login, captura de WhatsApp, reserva, perfil y panel de administración | `lib/features/{auth,booking,profile,admin}` | Son las *páginas de cuenta*. Se integran sin rediseñarlas (RF-30) |
| Redirección por sesión y WhatsApp | `redirect` en `lib/core/router/app_router.dart` | Se extrae a una función pura y se amplía para Web |
| `InitialsAvatar` (foto o inicial), `WhatsAppIcon`, `PhotoPlaceholder` | `lib/core/widgets/app_widgets.dart` | Botón de cuenta (RF-25), botón flotante (RF-11), imágenes que no cargan |
| Bloqueo de clientas al iniciar sesión | `AuthController.signInWithGoogle` | RF-23 sin cambios |
| Contenido, imágenes y diseño de la landing | `../shaddai-web` (`lib/ui/home/widgets/`, `assets/images/`, `.arb`) | Se traen y se adaptan a los tokens y a la estructura de este repo |

No existe aún:
- la landing;
- la barra superior de Web;
- el botón de cuenta;
- la vuelta a la página de origen tras el login (`next`);
- los enlaces externos (no hay `url_launcher`).

## 2. Archivos

Capas: `features → data → Firebase`. Esta spec no toca `lib/data/` ni Firestore.

### Se crean
| Archivo | Responsabilidad | RF |
| --- | --- | --- |
| `lib/core/router/redirect_logic.dart` | Función pura `resolveRedirect`: decide la redirección según plataforma, ruta, sesión, WhatsApp, rol y `next`. Incluye `safeNext` (valida `next`) | RF-19–21, RF-24, RF-29, casos límite |
| `lib/core/platform/external_links.dart` | `externalLinkLauncherProvider`: abre una URL en una pestaña nueva (`tel:`/`mailto:` en la misma). Los tests lo sustituyen por un registrador | RF-8–10, RF-12 |
| `lib/features/landing/landing_content.dart` | Datos fijos que no se traducen: URLs, teléfono, correo, dirección, usuario de Instagram, precios, combos, cifras del hero, rutas de las imágenes. La spec 004 sustituye precios y combos | RF-2, RF-3, RNF-6 |
| `lib/features/landing/landing_section.dart` | `enum LandingSection { hero, marquee, prices, combos, catalog, info, gallery, about, contact, footer }` y su valor en la ruta (`?section=`) | RF-1, RF-4, RF-17, RF-29 |
| `lib/features/landing/presentation/landing_page.dart` | Página de la landing: scroll vertical con las diez secciones en orden, una `GlobalKey` por sección, desplazamiento a la sección pedida y botón flotante de WhatsApp | RF-1, RF-4, RF-5, RF-11, RF-16, RF-17 |
| `lib/features/landing/presentation/sections/*.dart` | Una por sección: `hero`, `marquee_strip`, `prices`, `combos`, `catalog` (con la ampliación), `info`, `gallery`, `about`, `contact`, `footer`, más `section_header` (título con parte en cursiva) | RF-2, RF-3, RF-5–10, RF-12 |
| `lib/features/landing/presentation/widgets/landing_image.dart` | Imagen de asset con descripción para el lector de pantalla y, si no carga, recuadro de `placeholder` con la descripción | RNF-3, caso límite |
| `lib/features/landing/presentation/widgets/whatsapp_float_button.dart` | Botón flotante | RF-11, RF-12 |
| `lib/features/navigation/presentation/web_shell.dart` | Estructura de Web:<br>• barra superior fija y contenido debajo;<br>• las páginas de cuenta van centradas con ancho máximo de 640 px mediante `WebAccountPage` en cada ruta (T11): si se limitaba el navegador entero, la landing se desbordaba al salir de ella;<br>• menú lateral en ancho estrecho (se cierra al pasar a amplio) | RF-13, RF-15, RF-16, RF-18, RF-30 |
| `lib/features/navigation/presentation/web_top_bar.dart` | Barra superior:<br>• logotipo y nombre (sin nombre en estrecho);<br>• enlaces de sección (en amplio);<br>• selectores de tema e idioma;<br>• "Reservar";<br>• botón de cuenta;<br>• botón de menú (en estrecho) | RF-4, RF-13–15, RF-17, RF-19, RF-21 |
| `lib/features/navigation/presentation/account_button.dart` | Botón de cuenta:<br>• sin sesión, "Entrar";<br>• con sesión, `InitialsAvatar` y un menú (`MenuAnchor`, como el de tema) con "Mis turnos", "Panel de administración" (solo admin) y "Cerrar sesión" | RF-24–28 |
| `assets/images/landing/{catalogo,galeria}/…`, `assets/images/landing/profile.jpeg` | Imágenes de shaddai-web: 9 páginas de catálogo, 9 de galería y la foto del hero (≈ 3,5 MB) | RF-2, RF-6 |

### Se modifican
| Archivo | Cambio | RF |
| --- | --- | --- |
| `lib/core/router/app_router.dart` | Dos tablas de rutas según `isWebProvider`:<br>• **móvil**, la de hoy sin cambios;<br>• **Web**, `ShellRoute(WebShell)` con `/` (landing), `/login`, `/capture_phone`, `/booking`, `/profile`, `/admin`, `/admin/users` y `/admin/settings`, más `/home` y `/services`, que solo redirigen.<br>El `redirect` llama a `resolveRedirect`. | RF-1, RF-13, RF-18, RF-19–21, RF-24, RF-29 |
| `lib/core/theme/brand_colors.dart` | Tokens nuevos para las superficies de marca de la landing (D-6), incluidos en `copyWith` y `lerp` | RNF-1 |
| `lib/main.dart` | `onGenerateTitle` con el texto de los `.arb` en lugar del literal `'Shaddai'` (título de la pestaña del navegador) | RNF-6 |
| `lib/features/navigation/presentation/main_scaffold.dart` | Se quita la barra provisional de Web. `MainScaffold` queda solo para móvil | RF-18 |
| `lib/features/booking/presentation/booking_view.dart` | En Web, al crear la reserva, diálogo de confirmación con "Volver al inicio" (→ `/`) y "Cerrar". En móvil sigue el SnackBar | RF-22 |
| `lib/features/profile/presentation/profile_view.dart` | En Web:<br>• sin `PreferencesSection`;<br>• el botón de salir lleva a `/` antes de cerrar sesión. | RF-28, RF-31 |
| `lib/l10n/app_es.arb`, `app_pt.arb` (+ `flutter gen-l10n`) | Textos de la landing y de la barra (sección 7) | RF-2, RNF-6 |
| `pubspec.yaml` | `url_launcher` (aprobado por el autor, D-1) y los assets de la landing | RF-8–12 |
| `test/helpers/` | `pumpWebApp` (sección 9) y un registrador de enlaces externos | — |

Firestore: **sin cambios**. No hay colecciones, campos, `firestore.rules` ni índices nuevos. La comprobación de admin en Web es cosmética, como en móvil. La seguridad real llega en la spec 009.

## 3. Funciones puras

`lib/core/router/redirect_logic.dart`, sin Flutter ni Firebase. No depende de la hora: no recibe "ahora".

```
class RedirectInput {
  bool isWeb;
  String path;              // ruta sin query, p. ej. '/booking'
  Map<String,String> query;
  bool isLoggedIn;
  bool isUserLoading;
  bool needsPhone;           // con ficha y sin WhatsApp
  bool isAdmin;
}
String? resolveRedirect(RedirectInput input)   // null = no redirigir
String safeNext(String? next)                  // ruta interna permitida o '/'
```

`safeNext` solo acepta `/booking`, `/profile`, `/admin` (y sus subrutas) y `/`. Cualquier otra cosa da `/`: URLs externas, `//dominio` o rutas desconocidas. Así un enlace manipulado no puede sacar a la persona de la web tras el login.

## 4. Algoritmo

### resolveRedirect

**Móvil:** idéntico al `redirect` de hoy. Un test de tabla lo fija.
```
si !isLoggedIn y path empieza por /booking → /login
si isLoggedIn:
  si isUserLoading → null
  si needsPhone → (path == /capture_phone ? null : /capture_phone)
  si path ∈ {/login, /capture_phone} → /home
null
```

**Web:**
```
cuenta = path empieza por /booking, /profile o /admin

1. path == /home                     → /
2. path == /services                 → /?section=prices                  (RF-29)
3. !isLoggedIn:
     cuenta                          → /login?next=<path>                (RF-19, RF-29, sesión caducada)
     si no                           → null                              (landing y /login visibles)
4. isUserLoading                     → null                              (guarda actual)
5. needsPhone:
     path == /capture_phone          → null
     cuenta o path == /login         → /capture_phone?next=<safeNext(query.next ?? path)>
     si no                           → null                              (la landing se ve sin WhatsApp)
6. path empieza por /admin y !isAdmin → /                                (caso límite)
7. path ∈ {/login, /capture_phone}   → safeNext(query.next)              (RF-20, RF-24)
8. null
```

Recorridos resultantes:
- "Reservar" sin sesión: `/booking` → `/login?next=/booking` → login → (`/capture_phone?next=/booking`) → `/booking` (RF-19, RF-20).
- "Entrar": `/login` → login → `/` (RF-24).

### Ir a una sección (RF-4, RF-5, RF-16, RF-17, RF-29)
```
LandingPage(section: LandingSection?)          // de ?section= en la ruta
  al montar o al cambiar section:
    tras el primer fotograma → Scrollable.ensureVisible(clave[section], alignment 0, 400 ms)
enlace de sección en la barra o en el menú:
  si la ruta actual es / → desplazar directamente (sin cambiar la URL)
  si no                  → context.go('/?section=<valor>')
"Ver lista de precios" en el hero → desplazar a prices
```
La barra superior está fuera del área con scroll. Por eso la sección queda justo debajo de ella y no se tapa (RF-4).

### Barra superior y menú lateral (RF-13, RF-15, caso límite)
```
ancho = MediaQuery.width
amplio = ancho ≥ 900
WebShell.build:
  si amplio y el menú lateral está abierto → cerrarlo tras el fotograma
```

### Cerrar sesión (RF-28)
```
context.go('/') y después authController.signOut()
```
Primero se navega para que la redirección de la página de cuenta no lleve al login.

## 5. Interfaz

### Web
- **`/`, landing**, dentro de `WebShell`. `SingleChildScrollView` con las diez secciones del contenido de referencia, adaptadas así:
  - `LandingColors` → tokens de `BrandColors` (D-6);
  - `Theme.textTheme` → `AppText`;
  - cada texto, de los `.arb`.
  
  En ancho estrecho las rejillas pasan a una o dos columnas, como en shaddai-web. El botón flotante de WhatsApp va en un `Stack`, abajo a la derecha.
- **Catálogo:** al pulsar una página se abre un `Dialog` con la imagen y un botón "Cerrar" con etiqueta. Se cierra con el botón, con un clic fuera (`barrierDismissible`) o con Esc, que Material ya trae en los diálogos. El scroll de la landing no se toca (RF-6, RF-7).
- **Franja de servicios:** animación con `Ticker`, como en shaddai-web. Se para si `MediaQuery.disableAnimations` está activo, por accesibilidad. Es decorativa y queda fuera del árbol semántico.
- **Páginas de cuenta** dentro de `WebShell`: la vista actual de cada una, centrada con ancho máximo de 640 px (RF-30).
- **Barra superior**, de izquierda a derecha:
  - **en amplio:** logotipo y nombre, enlaces, tema, idioma, "Reservar" y cuenta;
  - **en estrecho:** logotipo (sin nombre), "Reservar", cuenta y menú. Tema e idioma pasan al menú lateral (RF-15, cambio del 2026-10-21). Ocupa unos 250 px, así que cabe en 320 px.
  
  Fondo `brandSurface` y altura de 64 px. Cada elemento pulsable mide al menos 48 × 48 y tiene foco visible (RNF-2).
- **Menú lateral** (`endDrawer`): botón de cerrar, selectores de tema e idioma y los tres enlaces de sección. Elegir un enlace lo cierra; cambiar tema o idioma no lo cierra.

### Android/iOS
Sin cambios. Misma tabla de rutas y mismo `MainScaffold`; solo desaparece la rama `isWeb` de la barra provisional, que en móvil no se veía. Los tests de móvil existentes deben seguir en verde.

### Riverpod
- Sin providers de estado nuevos.
- `externalLinkLauncherProvider` (`Provider<Future<void> Function(Uri)>`).
- El botón de cuenta lee `currentUserProvider` y `authControllerProvider`.
- `goRouterProvider` lee `isWebProvider` para elegir la tabla de rutas.

### Rutas y guardas
Las guardas son las de la sección 4. Todas las rutas de Web, incluida `/`, van dentro del `ShellRoute`, así que la barra superior está en todas (RF-13).

## 6. Datos (Firestore)
Sin cambios. Precios y combos son constantes en `landing_content.dart` hasta la spec 004.

## 7. Textos nuevos (.arb, ES y PT)

**Textos de la landing**
- Los de shaddai-web, unos 140, se traen con el prefijo `landing` para no chocar con las claves de la app. Ejemplos: `landingHeroKicker`, `landingServices1Row3`, `landingInfo4Body`, `landingGalleryItemLabel(n)`. El texto en español y en portugués es el de shaddai-web, sin cambios.
- Se añaden como claves los literales que en shaddai-web estaban en el código: "Soft Gel", "Combos" / "Shaddai" y "Studio Shaddai" en el pie (RNF-6).

**Claves nuevas para la barra, la cuenta y la reserva**

| Clave | ES | PT |
| --- | --- | --- |
| `webAppTitle` | Studio Shaddai · Nail Designer | Studio Shaddai · Nail Designer |
| `webNavServices` / `webNavCatalog` / `webNavAbout` | Servicios / Catálogo / Sobre mí | Serviços / Catálogo / Sobre mim |
| `webNavReserve` | Reservar | Agendar |
| `webMenuOpenLabel` / `webMenuCloseLabel` | Abrir menú / Cerrar menú | Abrir menu / Fechar menu |
| `webHomeLinkLabel` | Studio Shaddai, ir al inicio | Studio Shaddai, ir para o início |
| `accountSignIn` | Entrar | Entrar |
| `accountMenuLabel` | Menú de cuenta | Menu da conta |
| `accountMyAppointments` | Mis turnos | Meus horários |
| `accountAdminPanel` | Panel de administración | Painel de administração |
| `accountSignOut` | Cerrar sesión | Sair |
| `catalogCloseLabel` | Cerrar | Fechar |
| `bookingCreatedWebTitle` | Reserva creada | Agendamento criado |
| `bookingBackToLanding` | Volver al inicio | Voltar ao início |

Los textos de la barra en portugués son los de shaddai-web (por ejemplo, "Agendar").

## 8. Decisiones

| # | Decisión | Alternativa descartada |
| --- | --- | --- |
| D-1 | **`url_launcher` (aprobado por el autor el 2026-10-21)** para abrir WhatsApp, Maps, redes, teléfono y correo, detrás de `externalLinkLauncherProvider`. Es el que usa shaddai-web, funciona también en móvil (spec 003) y los tests lo sustituyen sin canales de plataforma | `package:web` (`window.open`) con import condicional: también sería dependencia directa nueva, solo sirve en Web y obliga a otra solución en la 003 |
| D-2 | Un solo `goRouterProvider` con dos tablas de rutas según `isWebProvider` | Dos routers o un `if (kIsWeb)` en `main.dart`: duplica `RouterNotifier` y no se puede probar simulando Web |
| D-3 | La redirección pasa a una función pura con tabla de tests, y móvil conserva su comportamiento exacto | Seguir con la lógica dentro del closure: la Web añade cinco casos y sería imposible probarlos sin montar la app |
| D-4 | Destino tras el login en `?next=`, validado por `safeNext` | Guardarlo en un provider: se pierde al recargar la página del login, y Google en Web puede recargar |
| D-5 | Sección a mostrar en `/?section=` (sirve para RF-17 y RF-29) | Un provider con la sección pendiente: no funciona al abrir `/services` directamente. No son enlaces `#`: no hay anclas en la página ni se cambia la URL al desplazarse (fuera de alcance de la spec) |
| D-6 | Se amplía `BrandColors` con las superficies de marca de la landing: `brandSurface`, `onBrandSurface`, `onBrandSurfaceMuted` y `brandSurfaceHairline`. Los valores parten de `surfBrand`, `inkBrand`, `inkBrandMuted` y `borderOnBrand` de shaddai-web: claro crema #EFE9DA con verde, oscuro verde #2E3D28 con crema. Se ajustan hasta pasar `brand_colors_contrast_test`; en el texto atenuado, colores opacos en lugar de alfa. El resto se asigna a tokens existentes:<br>• `surfEd` → `surface`;<br>• `inkEd` → `ink`;<br>• `surfPaper` → `background`;<br>• dorado de texto → `accentText` (salvo sobre `brandSurface`).<br>**Valores finales (T3, 2026-10-21):**<br>• `brandSurface`: claro #EFE9DA, oscuro #2E3D28;<br>• `onBrandSurface`: claro #2E3D28 (9,56:1), oscuro #F5F1E8 (10,27:1);<br>• `onBrandSurfaceMuted`: claro #5F6650 (4,95:1), oscuro #BEBFB3 (6,22:1). Es opaco: con el alfa de shaddai-web, el claro se quedaba en 4,47:1;<br>• `onBrandSurfaceAccent`, quinto token, decisión del autor: claro #7A602E (4,9:1), oscuro #C7A86D (5,1:1). En claro, `accentText` sobre la crema solo da 4,26:1;<br>• `brandSurfaceHairline`: claro 0x262E3D28, oscuro 0x2EF5F1E8 (decorativo);<br>• `accentIcon` sobre `brandSurface`: 3,28:1 en claro. | Traer `LandingColors` como segunda extensión: dos paletas para lo mismo, sin las correcciones de contraste de la 001 |
| D-7 | Textos en los `.arb` con prefijo `landing`. Datos que no se traducen (precios, contacto, URLs, cifras) en `landing_content.dart` | Precios en los `.arb`: la 004 los moverá a Firestore y no son traducibles |
| D-8 | Imágenes como assets de la app (≈ 3,5 MB, también en el paquete móvil, que las usará en la 003) | Cargarlas de Instagram o de un CDN: dependen de terceros y no funcionan sin conexión a ese servicio |
| D-9 | En Web, confirmación de reserva en un diálogo con "Volver al inicio". En móvil, sin cambios | SnackBar con acción: desaparece solo y no es fiable con teclado y lector de pantalla |
| D-10 | La guarda de admin se aplica solo en Web: la spec 002 no cambia móvil | Aplicarla también en móvil: cambio de comportamiento fuera de la spec (queda para la 007) |
| D-11 | La franja animada se para con `disableAnimations`. En los tests no se usa `pumpAndSettle` sobre la landing (el `Ticker` no termina nunca) | Animación implícita repetida: mismo problema en tests y sin respetar la preferencia de accesibilidad |
| D-12 | Si `launchUrl` devuelve `false` o falla, solo `debugPrint` y la landing sigue igual (caso límite de pestaña bloqueada) | Mostrar un SnackBar: la spec pide no mostrar error propio |

## 9. Tests

Helpers nuevos en `test/helpers/`:
- **`pumpWebApp(tester, {location, user, width})`:** monta `MyApp` con el `goRouterProvider` real, `isWebProvider` = `true`, la sesión con los fakes de `fake_session.dart` (sin, cliente, cliente sin WhatsApp, admin), el registrador de enlaces y el tamaño de ventana.
- **`RecordingLinkLauncher`:** guarda las URLs abiertas.

Nunca se usa Firebase real: autenticación y usuarias se sustituyen por los providers falsos ya existentes.

| Test | Cubre |
| --- | --- |
| `test/core/router/redirect_logic_test.dart`. Tabla de `resolveRedirect`:<br>• móvil igual que hoy;<br>• Web: sin sesión, sin WhatsApp, admin y no admin;<br>• `next` válido e inválido (`https://…`, `//x`, `/nada`);<br>• `/home` y `/services` | RF-19–21, RF-24, RF-29, casos límite (sin WhatsApp, admin, sesión caducada) |
| `test/features/landing/landing_page_test.dart`:<br>• las diez secciones en orden (posición vertical de cada clave);<br>• textos de muestra en ES y PT;<br>• precios y combos en R$ iguales en los dos idiomas | RF-1–3, RNF-6 |
| `landing_navigation_test.dart`:<br>• Servicios, Catálogo y Sobre mí dejan la sección justo debajo de la barra;<br>• "Ver lista de precios" lleva a precios;<br>• `/?section=about` abre en esa sección;<br>• enlace desde `/profile` vuelve a la landing en la sección | RF-4, RF-5, RF-17, RF-29 |
| `landing_catalog_test.dart`:<br>• ampliar una página;<br>• cerrar con el botón, con un clic fuera y con Esc;<br>• el scroll no cambia | RF-6, RF-7 |
| `landing_links_test.dart`. URL registrada para:<br>• galería, "Ver más en Instagram" y la tarjeta de más páginas del catálogo;<br>• la dirección del hero y la de contacto;<br>• teléfono, correo y cada red del pie y de contacto;<br>• WhatsApp flotante y de contacto.<br>También: un lanzador que falla no rompe la página; el flotante sigue visible tras desplazar | RF-8–12, caso límite de pestaña bloqueada |
| `web_top_bar_test.dart`:<br>• a 1280 px, logotipo y nombre, enlaces, selectores, "Reservar" y cuenta;<br>• a 360 px, sin nombre, enlaces ni selectores y con el botón de menú;<br>• el menú lateral tiene los selectores y los enlaces, y lleva a la sección y se cierra;<br>• cambiar el tema desde el menú no lo cierra;<br>• al ensanchar, el menú se cierra;<br>• el logotipo lleva arriba;<br>• la barra sigue visible tras desplazar;<br>• en Web no hay `BottomNavigationBar` y en móvil sí | RF-13–16, RF-18, caso límite de ancho |
| `web_booking_flow_test.dart`:<br>• "Reservar" sin sesión → login;<br>• tras la sesión simulada → reserva;<br>• sin WhatsApp → captura → reserva;<br>• con sesión → reserva directa;<br>• reserva creada (repositorio falso) → diálogo → "Volver al inicio" → landing;<br>• clienta bloqueada → sigue en el login con su mensaje | RF-19–23 |
| `account_button_test.dart`:<br>• sin sesión, "Entrar" → login → tras la sesión, landing;<br>• con foto o con inicial;<br>• el menú de clienta no tiene panel y el de admin sí;<br>• "Mis turnos" → perfil;<br>• panel → `/admin`;<br>• cerrar sesión → landing y sin sesión;<br>• una clienta en `/admin` → landing | RF-24–28, caso límite de admin |
| `web_account_pages_test.dart`:<br>• a 1280 px el contenido de cada página de cuenta no pasa de 640 px y está centrado;<br>• el perfil en Web no tiene Preferencias y en móvil sí | RF-30, RF-31 |
| `brand_colors_contrast_test` (ampliado) con los tokens nuevos en los dos temas | RNF-1 |
| `landing_accessibility_test.dart`. En claro y oscuro, a 360 y 1280 px:<br>• `textContrastGuideline`, `labeledTapTargetGuideline` y `androidTapTargetGuideline`;<br>• cada imagen de catálogo y galería con descripción en el idioma activo;<br>• con imagen rota se ve el recuadro con la descripción;<br>• Tab recorre la barra y activa "Reservar" con Intro | RNF-1–3, caso límite de imagen |
| `landing_layout_test.dart`:<br>• a 320, 360 y 1280 px, sin errores de desbordamiento;<br>• con `textScaler` 2.0, a 360 y 1280 px, sin desbordamiento;<br>• el único scroll de página es vertical | RNF-4, RNF-5 |
| `no_hardcoded_style_test` (sin cambios) cubre también `lib/features/landing` | RNF-1, RC-2 |
| Tests existentes de móvil sin cambios | Plataformas: Android/iOS no cambian |

Manual (criterios de finalización), con `flutter run -d chrome`:
- recorrido completo en claro y oscuro, ES y PT, a 360 y 1280 px, con ratón y teclado;
- apertura real de las pestañas externas;
- inicio de sesión real con Google en Web, que no se puede simular.

Antes, `flutterfire configure` con Web (pendiente en `MEMORY.md`).

## 10. Cobertura de la spec

| RF/RNF | Plan |
| --- | --- |
| RF-1–3 | `landing_page`, secciones, `landing_content`, `.arb` |
| RF-4, RF-5, RF-16, RF-17 | `LandingSection`, `?section=`, `ensureVisible`, barra y menú |
| RF-6, RF-7 | Diálogo de catálogo |
| RF-8–12 | `externalLinkLauncherProvider` + `url_launcher` (D-1), botón flotante |
| RF-13–15, RF-18 | `WebShell`, `WebTopBar`, rutas de Web, `MainScaffold` solo móvil |
| RF-19–21, RF-24, RF-29 | `resolveRedirect` + `next` |
| RF-22 | Diálogo de reserva en Web |
| RF-23 | `AuthController` existente |
| RF-25–28 | `AccountButton` |
| RF-30, RF-31 | `WebShell` (ancho máximo), `ProfileView` en Web |
| RNF-1 | Tokens nuevos + test de contraste + guideline |
| RNF-2, RNF-3 | Tamaños táctiles, foco, `semanticLabel`/`Semantics` |
| RNF-4, RNF-5 | Rejillas adaptables, test de 320/360/1280 y 200 % |
| RNF-6, RC-1 | `.arb` ES/PT; datos fijos sin traducir |
| RC-2, RC-3 | Selectores de la 001 en la barra |
| RC-4 | Web = landing con scroll; móvil sin cambios hasta la 003 |

## 11. Riesgos
- **Tamaño:** unos 140 textos, diez secciones y doce archivos de test. Al hacer las tareas probablemente salgan más de 10, y habrá que proponer dividir: (a) landing y enlaces, (b) barra, cuenta y rutas.
- **Inicio de sesión con Google en Web:** depende de la configuración de Firebase para Web, que aún no está. Hasta tenerla, el recorrido manual de reserva no puede hacerse en Chrome.
- **Contraste de las superficies de shaddai-web:** algunos colores con alfa no llegarán a AA. Se corrigen con tokens opacos, como en la 001, y el aspecto puede variar ligeramente respecto a shaddai-web.

## 12. Cambio pendiente: RF-32 (2026-10-21, aprobado)
Viene de `/sdd-validate`: RF-19 nombraba un "Reservar" en contacto que no existía. Hay que cambiar:
- **`sections/contact_section.dart`:** botón principal "Reservar cita" (`context.go('/booking')`, dorado) y "Agenda por WhatsApp" como secundario (contorno), en un `Wrap` para que pasen a dos filas con poco ancho o con texto grande.
- **Textos:** ninguno nuevo; se reutiliza `landingHeroCtaReserve` ("Reservar cita" / "Agendar horário").
- **Tests:**
  - en `landing_gallery_contact_test`, "Reservar cita" de contacto sin sesión lleva a `/login?next=/booking`, en ES y PT, y "Agenda por WhatsApp" sigue abriendo WhatsApp;
  - `landing_layout_test` y `landing_accessibility_test` siguen sirviendo: los dos botones a 320/360/1280 px, al 200 % y en los dos temas;
  - `web_closure_test` sigue igual.

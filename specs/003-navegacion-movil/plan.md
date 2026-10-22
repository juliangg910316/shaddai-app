# Plan 003 — Navegación móvil (Android/iOS)
Estado: aprobada

Spec: `specs/003-navegacion-movil/spec.md` (aprobada el 2026-10-21).

## 1. Qué existe ya

| Pieza | Dónde | Uso en esta spec |
| --- | --- | --- |
| Barra inferior con 4 pestañas y estado por pestaña (`StatefulShellRoute.indexedStack`) | `MainScaffold`, `app_router.dart` (`_mobileRoutes`) | Se conserva la estructura; cambia el widget de la barra (RNF-1) y el gesto de volver arriba (RF-4). RF-3 ya se cumple |
| Las diez secciones de la landing, el contenido y las imágenes | `lib/features/landing/` (spec 002) | Inicio y Servicios las reutilizan tal cual (RF-5, RF-12, RF-21) |
| Datos fijos (`LandingContent`), textos `landing…`, `LandingImage` | ídem | Misma fuente que Web, así que el contenido siempre coincide (RF-21) |
| Enlaces externos (`externalLinkLauncherProvider`, `url_launcher`) | `lib/core/platform/` | En móvil abre la app o el navegador (RF-8, RF-9, RF-11, RF-14) |
| Mapa incrustado (`GoogleMapContainer`) | `lib/features/home/presentation/` | Pasa a la sección de contacto de Inicio (RF-10) |
| Inicio de sesión con Google, `AuthFailure` y sus mensajes | `login_view.dart`, `AuthController` | El aviso de Reservas reutiliza el botón y los mensajes (RF-17 a RF-19) |
| Redirección pura `resolveRedirect` y `safeNext` (`?next=`) | `lib/core/router/redirect_logic.dart` | Cambian las reglas de móvil para Reservas sin sesión (RF-16, RF-17) |
| Diálogo del catálogo | `catalog_section.dart` | El "atrás" de Android cierra la ruta del diálogo; ya funciona (RF-13) |

No existe aún:
- el aviso de inicio de sesión dentro de Reservas;
- volver arriba al tocar la pestaña activa;
- la disposición de las secciones independiente del ancho de la ventana;
- la retirada del contenido de ejemplo.

## 2. Archivos

Capas: `features → data → Firebase`. Esta spec no toca `lib/data/` ni Firestore.

### Se crean
| Archivo | Responsabilidad | RF |
| --- | --- | --- |
| `lib/features/landing/presentation/landing_layout.dart` | `LandingLayout`, un `InheritedWidget` con `wide`, y `landingIsWide(context)`, que devuelve `false` si no hay `LandingLayout` encima. Sustituye a `WebShell.isWide` en las secciones | RF-5, RF-12, fuera de alcance (tableta) |
| `lib/features/navigation/providers/tab_scroll_provider.dart` | `tabScrollControllerProvider(MobileTab)`: un `ScrollController` por pestaña, que se libera con su provider | RF-4, RF-7 |
| `lib/features/booking/presentation/booking_sign_in_prompt.dart` | Aviso de inicio de sesión: título, texto, botón de Google (el mismo `GoogleBrandButton`) y mensaje de error (`AuthFailure`) | RF-16, RF-18, RF-19 |
| `lib/features/auth/presentation/auth_error_text.dart` | `authErrorMessage(Object? error, AppLocalizations)`: lo que hoy hace `LoginView._errorMessage`, compartido con el aviso | RF-18, RF-19 |

### Se modifican
| Archivo | Cambio | RF |
| --- | --- | --- |
| `lib/features/home/presentation/home_view.dart` | Se reescribe: scroll con presentación (`HeroSection`), galería, "Sobre mí" y contacto (con mapa y redes). "Ver lista de precios" lleva a Servicios arriba. Usa el `ScrollController` de su pestaña. Sin contenido de ejemplo | RF-5 a RF-11, RF-20 |
| `lib/features/services/presentation/services_view.dart` | Se reescribe: lista de precios, combos, catálogo y atención, con un "Reservar cita" arriba. Usa el `ScrollController` de su pestaña. Sin contenido de ejemplo | RF-12 a RF-15, RF-20 |
| `lib/features/landing/presentation/sections/*.dart` | `WebShell.isWide(context)` pasa a `landingIsWide(context)` | RF-5, RF-12 |
| `lib/features/landing/presentation/landing_page.dart` | Envuelve las secciones en `LandingLayout(wide: ancho ≥ 900)`. Web no cambia | — |
| `sections/contact_section.dart` | Parámetros `map` (widget opcional, debajo de los datos) y `showSocialLinks` (las redes del pie, para móvil, que no tiene pie). Web no los usa | RF-10, RF-11 |
| `lib/features/navigation/presentation/main_scaffold.dart` | `NavigationBar` (Material 3) en lugar de `BottomNavigationBar` (D-2). Con el texto grande, solo los iconos (D-3). Tocar la pestaña activa vuelve arriba (RF-4) | RF-1, RF-2, RF-4, RNF-1, RNF-4 |
| `lib/core/theme/app_theme.dart` | `navigationBarTheme` con los tokens de la barra actual: fondo `brand`, activa `onBrand`, inactiva `onBrandMuted` e indicador | RF-2, RNF-2 |
| `lib/core/router/redirect_logic.dart` | Reglas de móvil nuevas (sección 4) | RF-16, RF-17 |
| `lib/features/booking/presentation/booking_view.dart` | Sin sesión muestra `BookingSignInPrompt` en lugar del calendario | RF-16 |
| `lib/features/auth/presentation/login_view.dart` | Usa `authErrorMessage` (sin cambio de comportamiento) | — |
| `lib/features/home/presentation/google_map_container.dart` | Alto fijo de 220 px en lugar del 25 % de la pantalla, porque ahora va dentro de un scroll; sin conexión muestra su recuadro (caso límite) | RF-10 |
| `lib/l10n/app_es.arb`, `app_pt.arb` (+ `flutter gen-l10n`) | Textos nuevos (sección 7). Se borran las 34 claves que solo usaba el contenido de ejemplo | RF-20 |

Firestore: **sin cambios**. No hay colecciones, campos, `firestore.rules` ni índices nuevos.
Dependencias: **ninguna nueva**.

## 3. Funciones puras
`lib/core/router/redirect_logic.dart`, sin Flutter ni Firebase y sin "ahora":
- `resolveRedirect(RedirectInput)`: cambia la rama de móvil (sección 4). La de Web no cambia.
- `safeNext(String? next, {required bool isWeb})`: el destino por defecto es `/` en Web y `/home` en móvil. En móvil se aceptan `/home`, `/services`, `/booking`, `/profile` y `/admin…`.

## 4. Algoritmo

### Redirección en móvil (RF-16, RF-17)
```
si !isLoggedIn                      → null                        (Reservas muestra el aviso; antes iba a /login)
si isUserLoading                    → null
si needsPhone:
  path == /capture_phone            → null
  si no                             → /capture_phone?next=<path>  (vuelve a donde estaba: /booking si venía de Reservas)
si path ∈ {/login, /capture_phone}  → safeNext(query.next, isWeb: false)    (por defecto /home, como hoy)
null
```
Cambia frente a hoy:
- `/booking` sin sesión ya no va a `/login`;
- la captura de WhatsApp vuelve a la pestaña de origen.

El login desde Perfil sigue llevando a `/home`.

### Volver arriba al tocar la pestaña activa (RF-4) e ir a Servicios arriba (RF-7)
```
MainScaffold.onDestinationSelected(i):
  si i == pestaña actual → tabScrollController(i).animateTo(0) si tiene clientes
  goBranch(i, initialLocation: i == actual)
HomeView "Ver lista de precios":
  tabScrollController(services).jumpTo(0) si tiene clientes; context.go('/services')
```

### Disposición de las secciones
```
landingIsWide(context) = LandingLayout.maybeOf(context)?.wide ?? false
Web: LandingPage → LandingLayout(wide: MediaQuery.width ≥ 900)
Móvil: sin LandingLayout → siempre estrecho (también en tableta en horizontal)
```

### Barra inferior con texto grande (RNF-4)
```
si MediaQuery.textScaler.scale(14) > 14 × 1.3 → NavigationBar.labelBehavior = alwaysHide
   (iconos con su etiqueta en tooltip y semántica)
si no                                          → alwaysShow
```

## 5. Interfaz

### Android/iOS
- **Inicio** (`HomeView`): un `CustomScrollView`, o columna con scroll, con su `ScrollController` de pestaña y sin barra superior propia. Contiene:
  - `HeroSection`, con la foto arriba porque es estrecho;
  - `GallerySection`, con 2 columnas;
  - `AboutSection`;
  - `ContactSection(map: GoogleMapContainer(), showSocialLinks: true)`.
  
  "Reservar cita" (presentación y contacto) hace `context.go('/booking')`, que cambia de pestaña.
- **Servicios** (`ServicesView`): "Reservar cita" arriba (botón dorado, RF-15), `PricesSection`, `CombosSection`, `CatalogSection` e `InfoSection`.
- **Reservas** (`BookingView`): con sesión, sin cambios. Sin sesión muestra el aviso:
  - título y texto;
  - el botón de Google;
  - el error, si hay.
  
  Al iniciar sesión, `currentUserProvider` cambia y la vista muestra la reserva. Si falta el WhatsApp, la redirección lleva a la captura y vuelve a `/booking`.
- **Perfil:** sin cambios.
- **Barra:** `NavigationBar` con cuatro destinos (iconos y etiquetas actuales). Indicador de la pestaña activa y semántica "seleccionado" (RF-2). Destinos de 48 px o más (RNF-1).

### Web
Sin cambios. Solo cambia de dónde sacan las secciones si son anchas (`LandingLayout`); el resultado es el mismo.

### Riverpod
- `tabScrollControllerProvider` (family por `MobileTab`, nuevo).
- El aviso de Reservas lee `authControllerProvider` y `currentUserProvider`.
- Sin estado nuevo de negocio.

### Rutas
Las mismas. Solo cambian las reglas de móvil de `resolveRedirect`.

## 6. Datos (Firestore)
Sin cambios.

## 7. Textos (.arb, ES y PT)

**Nuevos:**

| Clave | ES | PT |
| --- | --- | --- |
| `bookingSignInTitle` | Inicia sesión para reservar | Entre para agendar |
| `bookingSignInBody` | Usamos tu cuenta de Google para guardar tus turnos y que Beidis pueda confirmarlos por WhatsApp. | Usamos sua conta Google para guardar seus horários e para que Beidis possa confirmá-los pelo WhatsApp. |
| `salonMapLabel` | Mapa con la ubicación del estudio | Mapa com a localização do estúdio |

Los nombres de las pestañas (`homeTab`, `servicesTab`, `appointmentsTab` y `profileTab`) ya existen.

**Se borran** las 34 claves que solo usaban Inicio y Servicios de ejemplo:
- servicios de ejemplo (`service…`), sus duraciones (`duration…`) y categorías (`category…`);
- textos de portada: `appTitle`, `heroTitle`, `heroSubtitle`, `popularServicesTitle`, `ourWorkTitle`, `findUsTitle`, `viewAllAction`, `welcomeGreeting`, `guestFallbackName`;
- datos del salón de ejemplo: `salonName`, `salonAddress`, `salonPhotoPlaceholder`;
- de la carta: `bookAppointment`, `servicesMenuEyebrow`, `ourServicesTitle`.

## 8. Decisiones

| # | Decisión | Alternativa descartada |
| --- | --- | --- |
| D-1 | Inicio y Servicios reutilizan los widgets de sección de la landing. Las secciones siguen en `lib/features/landing/`, ahora compartidas por las dos plataformas | Copiar las secciones a `home/` y `services/`: dos versiones del mismo contenido, que acabarían distintas (RF-21) |
| D-2 | `NavigationBar` de Material 3: destinos de 48 px o más, indicador de la pestaña activa y semántica de selección de serie (RNF-1, RF-2) | Seguir con `BottomNavigationBar` y forzar la altura: sus destinos miden 46 px y no se puede cambiar sin reimplementarlo |
| D-3 | Con el texto grande (más de 1,3×), la barra muestra solo iconos, con el nombre en el tooltip y en la semántica (caso límite de la spec) | Etiquetas en dos líneas: la barra crecería mucho y quitaría espacio al contenido en pantallas de 320 px |
| D-4 | `LandingLayout`, un `InheritedWidget`, decide si las secciones van anchas. Móvil siempre estrecho, también en tableta (fuera de alcance de la spec) | Seguir con el ancho de la ventana: en una tableta en horizontal saldría la disposición de Web |
| D-5 | Un `ScrollController` por pestaña en un provider family, para volver arriba (RF-4) y abrir Servicios arriba (RF-7) | `PrimaryScrollController` de la ruta: en Web y en escritorio no se asigna solo, y no se puede alcanzar desde la barra sin buscar en el árbol de la pestaña |
| D-6 | Reservas sin sesión: la redirección deja ver `/booking` y la vista muestra el aviso. La captura de WhatsApp vuelve con `?next=` | Ruta propia de aviso dentro de la rama: duplica la entrada a Reservas y complica volver a ella |
| D-7 | Mapa incrustado de alto fijo (220 px) | El 25 % de la pantalla: dentro de un scroll y con el texto grande quedaba demasiado bajo o demasiado alto |
| D-8 | `url_launcher` sin `<queries>` en Android ni `LSApplicationQueriesSchemes` en iOS: solo se llama a `launchUrl`, no a `canLaunchUrl`, y un fallo no muestra error (D-12 de la 002) | Declarar esquemas: solo hacen falta para preguntar antes si se puede abrir. Si el recorrido manual muestra que no se abre WhatsApp o `tel:` en algún dispositivo, se añaden |

## 9. Tests
Helper nuevo, `pumpMobileApp(tester, {location, user, width, textScale})`:
- monta la app real con `isWebProvider` = `false`, el router real y la sesión falsa (`FakeWebSession`, que se generaliza);
- usa las fuentes reales y la reducción de animaciones;
- sustituye el mapa por un recuadro mediante `salonMapProvider`, una costura como `isWebProvider`, porque la vista nativa de Google Maps no se pinta en los tests.

Nunca se usa Firebase real.

| Test | Cubre |
| --- | --- |
| `redirect_logic_test` (actualizado): tabla de móvil nueva (`/booking` sin sesión se queda, la captura vuelve con `next`, el login desde Perfil va a `/home`); Web sin cambios | RF-16, RF-17 |
| `mobile_tabs_test`:<br>• cuatro destinos con y sin sesión;<br>• la pestaña activa marcada y "seleccionada";<br>• al cambiar de pestaña y volver se conservan el scroll y la fecha elegida;<br>• tocar la pestaña activa vuelve arriba;<br>• cada destino mide 48 px o más;<br>• al 200 %, solo iconos con nombre accesible y sin desbordes a 320 px | RF-1 a RF-4, RNF-1, RNF-4 |
| `mobile_home_test`:<br>• cuatro secciones en orden;<br>• "Reservar cita" (presentación y contacto) lleva a Reservas;<br>• "Ver lista de precios" lleva a Servicios arriba;<br>• enlaces registrados (galería, Instagram, dirección, WhatsApp, teléfono, correo, redes);<br>• hay mapa en el contacto;<br>• no queda contenido de ejemplo | RF-5 a RF-11, RF-20 |
| `mobile_services_test`:<br>• cuatro secciones en orden y los 34 importes iguales a los de Web, en ES y PT;<br>• catálogo ampliado que se cierra con el botón, tocando fuera y con "atrás" (`tester.pageBack` o `handlePopRoute`), sin mover el scroll;<br>• "más páginas" abre Instagram;<br>• "Reservar cita" lleva a Reservas | RF-12 a RF-15, RF-21 |
| `mobile_booking_sign_in_test`:<br>• sin sesión, el aviso aparece con la barra visible;<br>• tras iniciar sesión con WhatsApp, la reserva en la misma pestaña;<br>• sin WhatsApp: captura y vuelta a Reservas;<br>• bloqueada: mensaje;<br>• fallo: error;<br>• cancelación: sin mensaje;<br>• cerrar sesión con fecha elegida vuelve al aviso | RF-16 a RF-19, casos límite de sesión |
| `mobile_accessibility_test`. Inicio, Servicios y el aviso, en claro y oscuro, a 320 y 412 px:<br>• `textContrastGuideline`, `labeledTapTargetGuideline` y `androidTapTargetGuideline`, recorriendo cada pestaña;<br>• al 200 %, sin desbordes;<br>• imágenes con descripción en el idioma activo | RNF-2 a RNF-4 |
| `mobile_content_test`:<br>• ninguna URL de red en Inicio ni Servicios (sin conexión se ven, salvo el mapa);<br>• las 34 claves de ejemplo ya no existen en los `.arb` | RNF-5, RF-20 |
| `landing_layout_test` y los tests de Web existentes, sin cambios | Plataformas: Web no cambia |
| `screens_theme_test`, `home_hero_test` y `preferences_section_test`: se actualizan a las nuevas Inicio y Servicios y a `NavigationBar` | Regresión |

Manual (criterios de finalización), con `flutter run` en Android e iOS:
- las cuatro pestañas en claro y oscuro, ES y PT, con el texto normal y al 200 %;
- los enlaces externos en un dispositivo real: WhatsApp, Instagram y Maps en su app o en el navegador; llamada y correo;
- el mapa;
- reserva desde el aviso;
- el gesto "atrás".

## 10. Cobertura de la spec

| RF/RNF | Plan |
| --- | --- |
| RF-1, RF-2, RNF-1 | `NavigationBar` en `MainScaffold`, `navigationBarTheme` |
| RF-3 | `StatefulShellRoute.indexedStack` (existente) y un `ScrollController` por pestaña |
| RF-4, RF-7 | `tabScrollControllerProvider` |
| RF-5, RF-6, RF-8 a RF-11 | `HomeView` con las secciones de la landing, `ContactSection(map, showSocialLinks)` |
| RF-12 a RF-15 | `ServicesView` con las secciones y "Reservar cita" |
| RF-16 a RF-19 | `resolveRedirect` (móvil), `BookingSignInPrompt`, `authErrorMessage` |
| RF-20 | Nuevas Inicio y Servicios, claves de ejemplo borradas |
| RF-21 | D-1: mismas secciones y mismo `LandingContent` |
| RNF-2, RNF-3 | Tokens y guías de accesibilidad |
| RNF-4 | `labelBehavior` según la escala (D-3); secciones ya probadas al 200 % |
| RNF-5 | Imágenes como assets (existentes) |
| RC-1 a RC-4 | ES/PT, tema, idioma; móvil con barra inferior y el mismo contenido que Web |

## 11. Riesgos
- **Tamaño:** unas 10 tareas.
- **Tests existentes:** al cambiar a `NavigationBar` y quitar el contenido de ejemplo, varios tests de pantalla de la 001 hay que reescribirlos (no quitarlos): `screens_theme_test` y `home_hero_test`.
- **Enlaces externos en dispositivo real:** WhatsApp, `tel:` y `mailto:` solo se pueden comprobar en el recorrido manual (D-8).

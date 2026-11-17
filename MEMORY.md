# MEMORY.md — Studio Shaddai (shaddai-app)

## Estado actual (2026-11-17)
- Se unifica `shaddai-app` (Firebase, reservas, admin) con `../shaddai-web` (landing y design system). SDD en `.claude/skills/`. Mapa: 005 reservas, 006 editar turno, 007 reserva de la admin, 008 agenda admin, 009 perfil, 010 admin, 011 push, 012 reglas, 013 publicación (las specs 001-004 citan la numeración original).
- **Implementadas** con recorrido del autor: 001 a 004 (2026-10-23), 005-reservas (2026-11-05), 006-editar-turno (2026-11-15), 007-reserva-admin (2026-11-17, rama `spec/007-reserva-admin`, 1667 tests; reglas comprobadas en el simulador y en la app).
- 007, decisiones que el autor revisó en el recorrido: D-1 (el 55 solo se quita tras `+` o con 12+ dígitos, porque 55 también es DDD), D-6 (enlace a WhatsApp en todos los turnos), D-8 (tras agendar se vacía también el día). Hallazgo fuera de la 007, sin arreglar: en la cabecera verde del panel de la admin, "PANEL DE BEIDIS" y el contador (`onBrandMuted`, 10-11 px, w300) no pasan `textContrastGuideline`, y un icono mide 22 px (candidato para la 010).
- **008-agenda-admin** (rama `spec/008-agenda-admin`): spec aprobada; plan aprobado (2026-11-17), con la colección nueva `closures` y los cambios de reglas aprobados por el autor; 17 tareas aprobadas (2026-11-17), siguiente: T1. Cierres (franja o días enteros; si chocan con turnos no se guardan), la admin edita cualquier turno activo (también la persona; queda confirmado) y el margen de edición con opciones fijas. Todo en una spec por decisión del autor.
- Decisiones vigentes: `settings/priceList` único, céntimos, transacciones (004); `busySlots` solo con inicio y fin, en lote con el turno (005); copia `booked` en el turno; Curitiba = −3 h fijo; lógica pura en `lib/features/booking/logic/`; 1 turno activo hasta su fin, 60 días (admin 365); margen de edición `settings/calendar.editMarginMinutes` (solo en la consola hasta la 008); `clientId: null` = persona sin cuenta y `createdByAdmin` (007).
- Requisitos comunes RC-1 a RC-4: propuesta, pendiente de revisión del autor. Sin implementar: token FCM y permisos, Cloud Functions.

## Decisiones (y por qué)
- Nombre comercial **Studio Shaddai**; marca = sello SVG de shaddai-web (`BrandLogo`, `flutter_svg` aprobado). Identificadores `com.juliangg.shaddai` sin cambiar.
- Repo base `shaddai-app` y su arquitectura feature-first: ya tiene Firebase en las 3 plataformas. No se traen Dio/Retrofit, `Result<T>` ni la estructura de carpetas de la web.
- Diseño de shaddai-web: Cormorant Garamond + Inter incluidas en la app, ES/PT guardado, tema claro/oscuro/**sistema por defecto**. Preferencias solo en el dispositivo.
- Mismas funciones en las 3 plataformas, **UI separada**: Web = landing con barra superior; Android/iOS = barra inferior (`NavigationBar`).
- Servicios y precios irán a **Firestore** (spec 004). Hosting web en **Hostinger** (dshaddai.com).
- **Tests primero** (decisión del autor). `CLAUDE.md` es la guía para los agentes.
- Sin cuentas de desarrollador, política de privacidad ni fecha de publicación todavía.

## Pendientes que se resuelven en las specs
- 005: el turno no guarda el servicio elegido (`AppointmentModel`); reservar desde el detalle con el servicio ya elegido.
- 013: `firebase.json` sin la entrada de Web (sí está en `firebase_options.dart`; volver a ejecutar `flutterfire configure`); `web/manifest.json` es la plantilla de Flutter; clave de Google Maps para web; nombre bajo el icono "shaddai"/"Shaddai" (Android/iOS).
- Sin spec asignada: claves `.arb` sin uso `adminTab` y `selectedOption`. `AuthRepository.signInWithGoogle` devuelve `null` también ante errores de Google, y no se ve ningún aviso.

## Errores a evitar
- Esta máquina está en −03:00 (= Curitiba): un test de hora del salón pasa sin el arreglo. Para verlo en rojo, `TZ=Europe/Lisbon flutter test …`.
- Web en local: siempre `--web-port 5050` (`.vscode/launch.json`; el 5000 lo ocupa el Receptor AirPlay de macOS). Google solo acepta orígenes registrados en el cliente OAuth web (`http://localhost:5050`); con otro puerto da `origin_mismatch`. Al publicar, registrar también `https://dshaddai.com`.
- `DateFormat.Hm('es')` da "9:00" y `'pt'`, "09:00": en los tests, buscar la hora con el formato del idioma.
- Riverpod 3 reintenta solo un provider que falla: queda `AsyncLoading` con el error dentro, y `whenData` lo pierde. Comprobar `hasError` antes que `isLoading`.
- Tests de la reserva: `ListView` construye poco fuera de la pantalla; para volver al calendario, `tabScrollControllerProvider(MobileTab.booking).jumpTo(0)`. `TableCalendar` tiene construidos los meses de al lado: buscar los días con `.hitTestable()`.
- `adminControllerProvider` crea los repositorios de reservas, usuarias y ajustes: un test que toque sus botones debe sustituir los tres, o llega a Firebase.
- Una vista con `BookingView` necesita sustituir también `myAppointmentsProvider` (`sessionOverrides` o `bookingDataOverrides`), o muestra el aviso de error.
- Riverpod 3: `ref.read(provider.future)` de un provider que nadie escucha se queda en pausa y no termina (el test se cuelga). Leer `.value` de algo que la pantalla ya escucha, o escucharlo en el test.
- Un `StreamProvider` que lee otro con `.value` vuelve a construirse (y a suscribirse a Firestore) con cada valor: usar `select` sobre lo que importa (el día, el `uid`). En los tests de la reserva, fijar `salonNowProvider` (`bookingDataOverrides`) para no dejar su temporizador de 30 s pendiente.
- `DateTime ==` exige el mismo instante **y** la misma zona (UTC o local): comparar instantes con `isAtSameMomentAs`. Las fechas de Firestore llegan en hora local (`decodeDates`); la hora del salón se obtiene con `toSalon`.
- Flutter 3.47.8 (2026-11-02): `dart format lib test` reformatea 27 archivos que no se tocaron (líneas en blanco entre grupos de imports y cortes de línea). El autor decidió dejar ese formato (2026-11-02).
- Tests con `tomorrow()`/`DateTime.now()` se rompen al cambiar de mes: un nombre de mes fijo ("outubro") o un mes de 6 semanas que baja las horas fuera de la pantalla de 800×600. Usar fechas fijas e inyectar "ahora" (`clockProvider` en la 005), o calcular el mes y dar alto de sobra.
- Cada Mac tiene su propia clave de depuración de Android: si el inicio de sesión con Google falla con `[16] Account reauth failed` / `canceled`, falta su SHA-1 en Firebase (app Android → Agregar huella digital) y hay que volver a descargar `google-services.json`. Ver la SHA-1 con el `keytool` de Android Studio (`/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).
- `currentUserProvider` escucha la ficha en vivo desde la 005 (T7). Los fakes de `UserRepository` necesitan `watchUser`, y los tests de providers con varios streams encadenados necesitan varias vueltas del bucle (`Future.delayed(Duration.zero)` × 5) antes de comprobar.
- `textContrastGuideline` falla con un texto pequeño dentro de un `Container` con borde ajustado (lee el borde como fondo): la etiqueta "Oculto" va sin borde. Y no leas `adminServicesControllerProvider` en `build`: crea `ConfigRepository` con Firebase real y rompe los tests; léelo al pulsar. Tampoco mide bien un texto de 10 px en w400 (títulos `AppText.eyebrow`): los de la reserva van a 12 px en w600.
- Los errores nunca se muestran en crudo: textos `.arb` sin `{error}` y el detalle a `debugPrint`. El login emite `AuthFailure`.
- Riverpod 3: `Override` viene de `flutter_riverpod/misc.dart`. `final x = a ?? ref.watch(p)` puede inferirse nullable: anotar el tipo.
- Editar `.arb` como texto (añadir al final, borrar línea a línea), no con `json.dump`: quita las líneas en blanco que agrupan las claves.
- En macOS, `grep` no entiende `\b`: para buscar usos de una clave, Python con `(?![A-Za-z0-9_])` o `grep -w`.
- Rutas anidadas (`ShellRoute`/`StatefulShellRoute`):
  - llevan `BlockSemantics`: la página va en `Semantics(container: true)` para no ocultar la barra;
  - sin nada enfocable, Tab no sale de la página;
  - no limitar el ancho del navegador anidado: la página que sale se dibuja con ese ancho en la transición.
- Lo que tiene que caber con el texto grande: dejar que crezca o pase a otra fila, no reducirlo (baja de 48 px).
- Un diálogo que aparece o se cierra no está en el árbol de semántica mientras se anima: `pump()` sin duración no avanza el tiempo. Tras abrirlo, `pump(300 ms)`; tras cerrarlo, `pump()` y `pump(300 ms)`.
- go_router 18: para saber si una navegación viene del navegador (atrás/adelante) o de la app, mirar `routeInformationProvider.value.state` **dentro del aviso** (`RouteInformationState` = app; el `Map` del historial = navegador). Después del aviso el router escribe el `Map` sin avisar. En tests, el navegador se simula guardando `routeInformationUpdated` y devolviéndolo con `pushRouteInformation` (`booking_edit_web_test.dart`).
- `textContrastGuideline` no mide los textos de un nodo con `excludeSemantics` (p. ej., una fila con una frase propia para el lector de pantalla): medir esos textos aparte con `contrastRatio` (`booking_edit_accessibility_test.dart`).
- `textContrastGuideline` toma como fondo lo que tapa a medias un texto (barra superior o inferior, botón flotante): medir el contenido sin ellos (la página o la pestaña sola).
- go_router en Web: `push` no cambia la dirección del navegador. Para una página con dirección propia y la de debajo conservada, usar una ruta hija y `go`. Una página tapada por otra no tiene tamaño: desplazarla en el fotograma siguiente a quitar la de encima.
- Contenido que llega de Firestore después del primer fotograma cambia la altura de la landing: lo que salta a una sección debe volver a colocarse al llegar (`LandingPage._reopenWhenPricesLoad`); los tests que montan secciones a mano necesitan un `pump()` extra.
- Riverpod 3: al invalidar un `StreamProvider`, `.value` conserva el dato anterior mientras recarga; comprobar `isLoading` si hay que mostrar la carga (p. ej. tras "Reintentar").
- Los tests con el router real (`pumpWebApp`, `pumpMobileApp`):
  - arrancan en la dirección pedida (`defaultRouteNameTestValue`);
  - cargan las fuentes reales;
  - reducen animaciones;
  - necesitan repositorios de autenticación falsos.
- En la consola de Firebase, los números de las reglas: `editMarginMinutes` como `int64`. Con `double`, `duration.value` falla y la regla deniega (`PERMISSION_DENIED`), aunque la app lo lea bien. Un documento creado a mano debe tener todos los campos que lee la app.
- Un `SnackBar` con `backgroundColor: brand.danger` necesita su propio color de texto (`brand.background`): el del tema es `onBrand` (dorado), que no se lee sobre el peligro.
- Tests con la lista de la reserva: tras `jumpTo`/`ensureVisible`, la lista puede recolocarse con una animación que ignora los toques (el `tap` avisa "would not hit test"). Dejar pasar varios fotogramas con tiempo (`pump(100 ms)` × 10) antes de tocar.
- `ConsumerState`: no crear con `late final x = …ref.read…` algo que `dispose` usa; si nunca se usó, se crea en `dispose` y falla. Crearlo en `initState`.
- Tests de semántica: `ensureSemantics()` se cierra con `dispose()` dentro del test (`addTearDown` llega tarde); el nombre de un `IconButton` es su `tooltip`, que `bySemanticsLabel` no encuentra: usar `find.byTooltip` / `isSemantics(tooltip:)` (`containsSemantics` está obsoleto).
- Accesibilidad (007): un `Semantics(liveRegion:)` o una fila con frase propia necesita `container: true`, o se funde con el texto vecino; con `excludeSemantics`, dar `onTap` al `Semantics`. Un texto en un `Row` sin `Flexible` (botones con etiqueta larga, hora y estado) se desborda al 200 % en 320 px. Los errores de un `TextField` llevan `errorStyle` con `brand.danger`. Para medir solo una parte de la pantalla: `expectTextContrast` (`test/helpers/dialog_contrast.dart`).

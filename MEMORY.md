# MEMORY.md — Studio Shaddai (shaddai-app)

## Estado actual (2026-10-23)
- Se unifica `shaddai-app` (Firebase, reservas, admin) con `../shaddai-web` (landing y design system). SDD instalado (`.claude/skills/`). Constitución y mapa de 10 specs aprobados (2026-10-20).
- **Implementadas** (con recorrido manual del autor): 001-design-system y 002-landing-web (2026-10-21), 003-navegacion-movil (2026-10-21), **004-servicios-firestore (2026-10-23)**, 16 tareas, 895 tests.
- Decisiones de la 004 que siguen vigentes:
  - documento único `settings/priceList`, precios en céntimos, escrituras en transacción; la admin edita desde la app (Perfil → Panel → Servicios en móvil);
  - textos ES y PT obligatorios; detalle por servicio y combo (adicionales sin detalle), como ruta hija con `go`;
  - sin datos: aviso + Reintentar + WhatsApp, sin precios fijos en el código; sin conexión se ven los últimos datos;
  - `firestore.rules`: reglas de la lista de precios; para users, appointments y settings/calendar, regla provisional con sesión hasta la 012. Las reglas se comprueban a mano en la consola.
- **Reservas divididas (2026-10-24, decisión del autor), las tres en borrador tras la revisión QA**: 005-reservas (clienta + reglas de turnos/usuarias), 006-editar-turno, 007-reserva-admin. Mapa: 008 agenda admin, 009 perfil, 010 admin, 011 push, 012 reglas, 013 publicación (las specs 001-004 citan la numeración original). Siguiente: aprobar las tres specs y luego /sdd-plan 005-reservas.
- Decisiones clave de reservas: una vista (calendario, horas cada 30 min fijas, servicios desactivados si no caben, "Agendar turno" siempre activo); 1 turno activo y 60 días (admin 365); todo en hora de Curitiba; las clientas solo ven inicio/fin de turnos ajenos; margen de edición global (0 por defecto); WhatsApp comparado por dígitos sin 55.
- Pendiente: "spec 009" → 012 en comentarios de `firestore.rules`, `redirect_logic.dart` y `test/core/firestore_rules_test.dart` (refactor sin cambio de comportamiento).
- Requisitos comunes RC-1 a RC-4: propuesta, pendiente de revisión del autor.
- Sin implementar: token FCM y permisos, Cloud Functions.

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
- 010: Ajustes del calendario se queda cargando si `calendarSettingsProvider` no estaba cargado (`ref.read` en `initState`).
- 013: `firebase.json` sin la entrada de Web (sí está en `firebase_options.dart`; volver a ejecutar `flutterfire configure`); `web/manifest.json` es la plantilla de Flutter; clave de Google Maps para web; nombre bajo el icono "shaddai"/"Shaddai" (Android/iOS).
- Sin spec asignada: claves `.arb` sin uso `adminTab` y `selectedOption`. `AuthRepository.signInWithGoogle` devuelve `null` también ante errores de Google, y no se ve ningún aviso.

## Errores a evitar
- Las reglas de tema, colores, tests, rutas y landing están en `CLAUDE.md`: leerlas antes de tocar esas partes.
- Cada Mac tiene su propia clave de depuración de Android: si el inicio de sesión con Google falla con `[16] Account reauth failed` / `canceled`, falta su SHA-1 en Firebase (app Android → Agregar huella digital) y hay que volver a descargar `google-services.json`. Ver la SHA-1 con el `keytool` de Android Studio (`/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).
- `currentUserProvider` es un `FutureProvider`: lee la ficha una vez cuando cambia la sesión. Firebase Auth avisa antes de que `AuthController` cree la ficha de una cuenta nueva, así que hay que invalidarlo después de `saveUser` (arreglado el 2026-10-22, `test/features/auth/new_user_profile_test.dart`). Si no, no se pide el WhatsApp hasta reiniciar la app. Hacerlo `StreamProvider` sobre la ficha queda para la 009.
- `textContrastGuideline` falla con un texto pequeño dentro de un `Container` con borde ajustado (lee el borde como fondo): la etiqueta "Oculto" va sin borde. Y no leas `adminServicesControllerProvider` en `build`: crea `ConfigRepository` con Firebase real y rompe los tests; léelo al pulsar.
- Los errores nunca se muestran en crudo: textos `.arb` sin `{error}` y el detalle a `debugPrint`. El login emite `AuthFailure`.
- Riverpod 3: `Override` viene de `flutter_riverpod/misc.dart`. `containsSemantics` está obsoleto: usar `isSemantics`. `final x = a ?? ref.watch(p)` puede inferirse nullable: anotar el tipo.
- Editar `.arb` como texto (añadir al final, borrar línea a línea), no con `json.dump`: quita las líneas en blanco que agrupan las claves.
- En macOS, `grep` no entiende `\b`: para buscar usos de una clave, Python con `(?![A-Za-z0-9_])` o `grep -w`.
- Rutas anidadas (`ShellRoute`/`StatefulShellRoute`):
  - llevan `BlockSemantics`: la página va en `Semantics(container: true)` para no ocultar la barra;
  - sin nada enfocable, Tab no sale de la página;
  - no limitar el ancho del navegador anidado: la página que sale se dibuja con ese ancho en la transición.
- Lo que tiene que caber con el texto grande: dejar que crezca o pase a otra fila, no reducirlo (baja de 48 px).
- `textContrastGuideline` toma como fondo lo que tapa a medias un texto (barra superior o inferior, botón flotante): medir el contenido sin ellos (la página o la pestaña sola).
- Elementos fijos sobre un scroll (botón flotante) en su propio `FocusTraversalGroup`.
- go_router en Web: `push` no cambia la dirección del navegador. Para una página con dirección propia y la de debajo conservada, usar una ruta hija y `go`. Una página tapada por otra no tiene tamaño: desplazarla en el fotograma siguiente a quitar la de encima.
- Contenido que llega de Firestore después del primer fotograma cambia la altura de la landing: lo que salta a una sección debe volver a colocarse al llegar (`LandingPage._reopenWhenPricesLoad`); los tests que montan secciones a mano necesitan un `pump()` extra.
- Riverpod 3: al invalidar un `StreamProvider`, `.value` conserva el dato anterior mientras recarga; comprobar `isLoading` si hay que mostrar la carga (p. ej. tras "Reintentar").
- Los tests con el router real (`pumpWebApp`, `pumpMobileApp`):
  - arrancan en la dirección pedida (`defaultRouteNameTestValue`);
  - cargan las fuentes reales;
  - reducen animaciones;
  - necesitan repositorios de autenticación falsos.

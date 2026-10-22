# MEMORY.md — Studio Shaddai (shaddai-app)

## Estado actual (2026-10-21)
- Se unifica `shaddai-app` (Firebase, reservas, admin) con `../shaddai-web` (landing y design system). SDD instalado (`.claude/skills/`). **Constitución** y **mapa de 10 specs** aprobados (2026-10-20).
- **Spec 001-design-system: implementada** (2026-10-21; recorrido del autor en móvil y Chrome correcto).
- **Spec 002-landing-web: implementada** (2026-10-21; recorrido del autor en Chrome correcto). Decisiones del autor:
  - "Reservar" va a la reserva de la app; WhatsApp queda como contacto; contacto tiene "Reservar cita" (RF-32);
  - botón de cuenta en la barra; en estrecho, tema e idioma van en el menú lateral (RF-15);
  - precios fijos hasta la 004; mapa como enlace; `url_launcher` aprobado.
- **Spec 003-navegacion-movil: implementada** (validada 2026-10-21; recorrido del autor en Android/iOS correcto). 10 tareas, 640 tests. Decisiones del autor:
  - Inicio: presentación, galería, sobre mí y contacto con mapa;
  - Servicios: precios, combos, catálogo y atención;
  - fuera el contenido de ejemplo; sin WhatsApp flotante;
  - aviso de inicio de sesión dentro de Reservas;
  - el detalle de servicio con "Reservar" ya elegido va en las specs 004 y 005.
  Siguiente spec del mapa: 004-servicios-firestore.
- Requisitos comunes RC-1 a RC-4: propuesta, pendiente de revisión del autor.
- Sin implementar: token FCM y permisos, Cloud Functions, `firestore.rules`.

## Decisiones (y por qué)
- Nombre comercial **Studio Shaddai**; marca = sello SVG de shaddai-web (`BrandLogo`, `flutter_svg` aprobado). Identificadores `com.juliangg.shaddai` sin cambiar.
- Repo base `shaddai-app` y su arquitectura feature-first: ya tiene Firebase en las 3 plataformas. No se traen Dio/Retrofit, `Result<T>` ni la estructura de carpetas de la web.
- Diseño de shaddai-web: Cormorant Garamond + Inter incluidas en la app, ES/PT guardado, tema claro/oscuro/**sistema por defecto**. Preferencias solo en el dispositivo.
- Mismas funciones en las 3 plataformas, **UI separada**: Web = landing con barra superior; Android/iOS = barra inferior (`NavigationBar`).
- Servicios y precios irán a **Firestore** (spec 004). Hosting web en **Hostinger** (dshaddai.com).
- **Tests primero** (decisión del autor). `CLAUDE.md` es la guía para los agentes.
- Sin cuentas de desarrollador, política de privacidad ni fecha de publicación todavía.

## Pendientes que se resuelven en las specs
- 004: esquema de servicios en Firestore, si la admin los edita, y vista de detalle de servicio.
- 005: el turno no guarda el servicio elegido (`AppointmentModel`); reservar desde el detalle con el servicio ya elegido.
- 007: Ajustes del calendario se queda cargando si `calendarSettingsProvider` no estaba cargado (`ref.read` en `initState`).
- 010: `firebase.json` sin la entrada de Web (sí está en `firebase_options.dart`; volver a ejecutar `flutterfire configure`); `web/manifest.json` es la plantilla de Flutter; clave de Google Maps para web; nombre bajo el icono "shaddai"/"Shaddai" (Android/iOS).
- Sin spec asignada: claves `.arb` sin uso `adminTab` y `selectedOption`. `AuthRepository.signInWithGoogle` devuelve `null` también ante errores de Google, y no se ve ningún aviso.

## Errores a evitar
- Las reglas de tema, colores, tests, rutas y landing están en `CLAUDE.md`: leerlas antes de tocar esas partes.
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
- Los tests con el router real (`pumpWebApp`, `pumpMobileApp`):
  - arrancan en la dirección pedida (`defaultRouteNameTestValue`);
  - cargan las fuentes reales;
  - reducen animaciones;
  - necesitan repositorios de autenticación falsos.

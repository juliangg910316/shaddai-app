# MEMORY.md — Studio Shaddai (shaddai-app)

## Estado actual (2026-10-20)
- Se unifica `shaddai-app` (Firebase, reservas, admin) con `../shaddai-web` (landing y design system) en este repo.
- SDD instalado: skill `sdd` + skills `/sdd-*` en `.claude/skills/`. `docs/ESPECIFICACION.md` creado.
- **Constitución aprobada** (2026-10-20, `docs/constitution.md`, 6 principios).
- **Mapa de 10 specs aprobado** (`docs/ESPECIFICACION.md`, sección 8).
- **Spec 001-design-system: implementada** (validada 2026-10-21; recorrido manual del autor en móvil y Chrome correcto). 270 tests en verde.
- **Spec 002-landing-web: implementada** (validada 2026-10-21; recorrido manual del autor en Chrome correcto). 15 tareas, 529 tests en verde. Decisiones del autor:
  - "Reservar" lleva a la reserva de la app y WhatsApp queda como contacto; contacto tiene "Reservar cita" (RF-32);
  - botón de cuenta en la barra;
  - en estrecho, tema e idioma van en el menú lateral (RF-15);
  - precios fijos de shaddai-web hasta la 004; mapa como enlace;
  - `url_launcher` aprobado.
  Siguiente spec del mapa: 003-navegacion-movil (reparte en móvil el contenido de la landing).
- Requisitos comunes RC-1 a RC-4: propuesta, pendiente de revisión del autor.
- Sin implementar: token FCM y permisos, Cloud Functions, `firestore.rules`.

## Decisiones (y por qué)
- Nombre comercial: **Studio Shaddai** (2026-10-20). Identificadores `com.juliangg.shaddai` sin cambiar.
- Repo base `shaddai-app` con su arquitectura feature-first: ya tiene Firebase en las 3 plataformas.
- Diseño de `shaddai-web`: Cormorant Garamond + Inter, selector ES/PT guardado. Tema claro/oscuro/**sistema**, con **sistema por defecto** (cambiado el 2026-10-20 en la spec 001; RC-2 actualizado). Fuentes incluidas en la app (no se descargan). Preferencias solo en el dispositivo, nunca en Firestore.
- No se traen de la web Dio/Retrofit, `Result<T>` ni su estructura de carpetas: eran de la plantilla y no hacen falta con Firebase.
- Mismas funciones en las 3 plataformas, **UI separada**: Web = landing con scroll; Android/iOS = `BottomNavigationBar`.
- Servicios y precios en **Firestore** (esquema por definir en su spec).
- Hosting web en **Hostinger** con el dominio **dshaddai.com**.
- **Tests primero** (decisión del autor, 2026-10-20), como en el curso de Big School.
- `CLAUDE.md` es la guía principal para los agentes (no se crea `AGENTS.md`).
- Sin cuentas de desarrollador, política de privacidad ni fecha de publicación todavía.
- Marca: el sello SVG de shaddai-web (`BrandLogo`, `assets/images/logo_monogram.svg`) sustituye al monograma "D'S"; se añade `flutter_svg` (autor, 2026-10-21), que la landing también usará.

## Pendientes que se resuelven en las specs
- Spec 007 (admin): Ajustes del calendario se queda cargando si `calendarSettingsProvider` no estaba ya cargado (lo lee con `ref.read` en `initState`).
- `AuthRepository.signInWithGoogle` devuelve `null` también ante errores de Google: la persona no ve ningún aviso. Revisar si alguna spec lo cubre.
- Spec 003: las pestañas de la barra inferior miden 46 px de alto (< 48, guía de Android). Se vio en T6 de la 001.
- Si el turno guarda el servicio elegido (hoy la pantalla lo muestra, pero `AppointmentModel` no lo guarda).
- Esquema de servicios en Firestore y si la admin los edita.
- Spec 003: cómo se reparte en las pestañas móviles el contenido de la landing (catálogo, atención, galería, sobre mí).
- Clave de Google Maps para web.

## Errores a evitar
- Las reglas de tema, colores, tests y fechas de la spec 001 están en `CLAUDE.md` (secciones Commands, Theme and colors y Localization).
- Los errores nunca se muestran en crudo: textos `.arb` sin `{error}` y el detalle a `debugPrint`. El login emite `AuthFailure`, no textos.
- Con `StatefulShellRoute`, si la página de la pestaña no tiene nada enfocable, Tab no sale de ella hacia las barras.
- Riverpod 3: el tipo `Override` se importa de `package:flutter_riverpod/misc.dart`. En Flutter 3.47, `containsSemantics` está obsoleto: usar `isSemantics`.
- `firebase.json` no incluye la web (aunque `firebase_options.dart` sí): volver a ejecutar `flutterfire configure` con web. `web/manifest.json` sigue siendo la plantilla de Flutter (spec 010).
- Las rutas admin no están protegidas en el router: la seguridad va en `firestore.rules`.
- En Web (`ShellRoute`), la ruta anidada lleva `BlockSemantics`: sin `Semantics(container: true)` alrededor de la página, la barra superior desaparece del árbol semántico. Y si la página no tiene nada enfocable, Tab no sale de ella.
- Editar `.arb` añadiendo texto al final, no con `json.dump`: quita las líneas en blanco que agrupan las claves.
- La fuente por defecto de los tests da a cada letra el ancho de su tamaño. `pumpWebApp` carga Inter y Cormorant reales (`loadAppFonts`). Para que algo quepa con texto grande: dejar que crezca o pase a otra fila, no reducirlo (baja de 48 px).
- La franja animada de la landing pide fotogramas sin parar: `pumpWebApp` pide reducir animaciones por defecto para que `pumpAndSettle` termine. Para probar movimiento, `reduceMotion: false` y `pump` con duración.
- En Web, no limitar el ancho del navegador anidado del `ShellRoute`: la página que sale se dibuja con ese ancho durante la transición. El ancho máximo va en cada página (`WebAccountPage`).
- `textContrastGuideline` mide el rectángulo entero de cada texto: si una barra fija o un botón flotante lo tapa a medias, toma sus colores como fondo. El contenido se mide sin ellos (landing sola, `showLandingFloatButtonProvider`).
- Elementos fijos sobre un scroll (botón flotante) en su propio `FocusTraversalGroup`: si no, Tab vuelve a ellos cada vez que la página se mueve.
- Los tests con el router real (`pumpWebApp`) necesitan `authRepositoryProvider`/`userRepositoryProvider` falsos: el login crea `FirebaseAuth.instance`.

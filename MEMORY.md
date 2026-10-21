# MEMORY.md — Studio Shaddai (shaddai-app)

## Estado actual (2026-10-20)
- Se unifica `shaddai-app` (Firebase, reservas, admin) con `../shaddai-web` (landing y design system) en este repo.
- SDD instalado: skill `sdd` + skills `/sdd-*` en `.claude/skills/`. `docs/ESPECIFICACION.md` creado.
- **Constitución aprobada** (2026-10-20, `docs/constitution.md`, 6 principios).
- **Mapa de 10 specs aprobado** (`docs/ESPECIFICACION.md`, sección 8).
- **Spec 001-design-system: implementada** (validada 2026-10-21; recorrido manual del autor en móvil y Chrome correcto). 268 tests en verde.
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
- Acceso a perfil y admin en Web; qué secciones de la landing reutilizan las pestañas móviles.
- Clave de Google Maps para web.

## Errores a evitar
- Las reglas de tema, colores, tests y fechas de la spec 001 están en `CLAUDE.md` (secciones Commands, Theme and colors y Localization).
- Los errores nunca se muestran en crudo: textos `.arb` sin `{error}` y el detalle a `debugPrint`. El login emite `AuthFailure`, no textos.
- Con `StatefulShellRoute`, si la página de la pestaña no tiene nada enfocable, Tab no sale de ella hacia las barras.
- Riverpod 3: el tipo `Override` se importa de `package:flutter_riverpod/misc.dart`. En Flutter 3.47, `containsSemantics` está obsoleto: usar `isSemantics`.
- `firebase.json` no incluye la web: volver a ejecutar `flutterfire configure` con web.
- Las rutas admin no están protegidas en el router: la seguridad va en `firestore.rules`.

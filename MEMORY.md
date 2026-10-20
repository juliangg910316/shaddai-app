# MEMORY.md — Studio Shaddai (shaddai-app)

## Estado actual (2026-10-20)
- Se unifica `shaddai-app` (Firebase, reservas, admin) con `../shaddai-web` (landing y design system) en este repo.
- SDD instalado: skill `sdd` + skills `/sdd-*` en `.claude/skills/`. `docs/ESPECIFICACION.md` creado.
- **Constitución aprobada** (2026-10-20, `docs/constitution.md`, 6 principios).
- **Mapa de 10 specs aprobado** (`docs/ESPECIFICACION.md`, sección 8). Ninguna empezada. Siguiente paso: `/sdd-spec 001-design-system <idea>`.
- Requisitos comunes RC-1 a RC-4: propuesta, pendiente de revisión del autor.
- Sin tests reales: `test/widget_test.dart` es la plantilla del contador y hay que sustituirlo.
- Sin implementar: token FCM y permisos, Cloud Functions, `firestore.rules`.

## Decisiones (y por qué)
- Nombre comercial: **Studio Shaddai** (2026-10-20). Identificadores `com.juliangg.shaddai` sin cambiar.
- Repo base `shaddai-app` con su arquitectura feature-first: ya tiene Firebase en las 3 plataformas.
- Diseño de `shaddai-web`: tema claro/oscuro (oscuro por defecto), Cormorant Garamond + Inter, selector ES/PT guardado.
- No se traen de la web Dio/Retrofit, `Result<T>` ni su estructura de carpetas: eran de la plantilla y no hacen falta con Firebase.
- Mismas funciones en las 3 plataformas, **UI separada**: Web = landing con scroll; Android/iOS = `BottomNavigationBar`.
- Servicios y precios en **Firestore** (esquema por definir en su spec).
- Hosting web en **Hostinger** con el dominio **dshaddai.com**.
- **Tests primero** (decisión del autor, 2026-10-20), como en el curso de Big School.
- `CLAUDE.md` es la guía principal para los agentes (no se crea `AGENTS.md`).
- Sin cuentas de desarrollador, política de privacidad ni fecha de publicación todavía.

## Pendientes que se resuelven en las specs
- Si el turno guarda el servicio elegido (hoy la pantalla lo muestra, pero `AppointmentModel` no lo guarda).
- Esquema de servicios en Firestore y si la admin los edita.
- Acceso a perfil y admin en Web; qué secciones de la landing reutilizan las pestañas móviles.
- Clave de Google Maps para web.

## Errores a evitar
- `DateFormat('EEEE')` de `availableSlotsProvider` debe seguir **sin locale**: las claves de `openingHours` son en inglés.
- `firebase.json` no incluye la web: volver a ejecutar `flutterfire configure` con web.
- Las rutas admin no están protegidas en el router: la seguridad va en `firestore.rules`.

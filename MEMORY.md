# MEMORY.md — Studio Shaddai (shaddai-app)

## Estado actual (2026-10-20)
- Se unifica `shaddai-app` (Firebase, reservas, admin) con `../shaddai-web` (landing y design system) en este repo.
- SDD instalado: skill `sdd` + skills `/sdd-*` en `.claude/skills/`. `docs/ESPECIFICACION.md` creado.
- **Constitución aprobada** (2026-10-20, `docs/constitution.md`, 6 principios).
- **Mapa de 10 specs aprobado** (`docs/ESPECIFICACION.md`, sección 8). Spec 001-design-system **aprobada** de nuevo tras `/sdd-change` (2026-10-20: hallazgos del QA, RF-20 a RF-27 y RNF-6 nuevos). Plan revisado **aprobado** (2026-10-20; RF-1 a RF-27, decisiones D-1 a D-12). Tareas **aprobadas** (2026-10-20; 14, bloques A y B, sin dividir la spec). **T1 a T8 hechas** (2026-10-20; T7 pendiente de probar en Chrome). Bloque A terminado. Siguiente: T9 (o validación parcial antes). Hasta T9–T13, en tema oscuro las pantallas siguen con sus colores fijos (previsto). `shared_preferences` añadida en T4.
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

## Pendientes que se resuelven en las specs
- `AuthRepository.signInWithGoogle` devuelve `null` también ante errores de Google: la persona no ve ningún aviso. Revisar si alguna spec lo cubre.
- Spec 003: las pestañas de la barra inferior miden 46 px de alto (< 48, guía de Android). Se vio en T6 de la 001.
- Si el turno guarda el servicio elegido (hoy la pantalla lo muestra, pero `AppointmentModel` no lo guarda).
- Esquema de servicios en Firestore y si la admin los edita.
- Acceso a perfil y admin en Web; qué secciones de la landing reutilizan las pestañas móviles.
- Clave de Google Maps para web.

## Errores a evitar
- Los errores nunca se muestran en crudo: textos `.arb` sin `{error}` y el detalle a `debugPrint`. El login emite `AuthFailure`, no textos.
- Para saber si es Web en una vista, leer `isWebProvider` (se puede sobrescribir en los tests), no `kIsWeb` directamente.
- Con `StatefulShellRoute`, si la página de la pestaña no tiene nada enfocable, Tab no sale de ella hacia las barras.
- Riverpod 3: el tipo `Override` se importa de `package:flutter_riverpod/misc.dart`. En Flutter 3.47, `containsSemantics` está obsoleto: usar `isSemantics`.
- Tests de pantallas: usar `pumpApp` (`test/helpers/pump_app.dart`), que sustituye `goRouterProvider` y las preferencias; nunca montar `MyApp` con el router real (usa Firebase).
- El `AppText` nuevo (`lib/core/theme/app_text.dart`) y el antiguo (`theme_colors.dart`) tienen el mismo nombre: un archivo no puede importar los dos (conviven hasta T14).
- Dorado de marca `#C7A86D` sobre crema da 2,01:1: en tema claro, para texto `accentText` y para iconos `accentIcon`. `accent` solo para adornos (decisión del autor en T2).
- `dart format .` reformatea `build/` (ignorado por git): ejecutar la puerta con `dart format lib test`.
- `test/widget_test.dart` (plantilla del contador) ya se borró en T1 de la spec 001.
- Las claves de `openingHours` son en inglés: usar `weekdayKey()` (`lib/core/utils/weekday_key.dart`), nunca un `DateFormat` del nombre del día.
- `firebase.json` no incluye la web: volver a ejecutar `flutterfire configure` con web.
- Las rutas admin no están protegidas en el router: la seguridad va en `firestore.rules`.

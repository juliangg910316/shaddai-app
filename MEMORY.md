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
- **Spec y plan 005 aprobados (2026-11-02).** Decisiones del plan: colección `busySlots` (solo inicio/fin, lote con el turno, `getAfter` en reglas), `booked` en turnos, `firestore.indexes.json`, `currentUserProvider` → `StreamProvider`, Curitiba = −3 h fijo sin `timezone`, PT "horário", "confirmación de Beidis". **Tareas 005 aprobadas (2026-11-02):** 18 en 3 bloques (A lógica/datos/providers T1–T9, B vista y rutas T10–T15, C admin/reglas/cierre T16–T18), sin dividir la spec (decisión del autor). La vista antigua convive hasta T17. **T1 a T6 hechas (2026-11-03)** en la rama `005-reservas`: lógica pura en `lib/features/booking/logic/`; modelos sin Firebase (`decodeDates`/`encodeDates` en `lib/data/firestore_dates.dart`). T7: `currentUserProvider` es `StreamProvider` (se sobrescribe con `Stream.value(user)`). T8: providers de lectura, `FakeBookingRepository` y `bookingDataOverrides`. T9: `bookingSelectionProvider` y `bookingSubmitProvider` (bloque A completo). T10: textos de § 6 en los `.arb`. T11: estados de la pantalla (`switch (bookingScreenProvider)`), `AppNotice` público. T12: `BookingForm`, `BookingCalendar`, `SlotGrid`; T13: servicios, adicionales, resumen, "Agendar turno" y diálogo; T14: un aviso por resultado al guardar; con `alreadyActive` se vuelven a pedir los turnos. T15: `/booking?service|combo=<id>` (validado en `safeNext`), `BookingView(request:)`. Bloque B completo. T16: lo reservado en la tarjeta de la admin. T17: accesibilidad y limpieza (vista antigua borrada). T18: reglas, índice, hora de Curitiba en la tarjeta de la admin y `rules-check.md`. RF-59 / T19 (2026-11-05, decisión del autor): tocar otra vez la hora o el servicio elegidos los quita. Siguiente: el autor comprueba `rules-check.md` y el recorrido manual; después, /sdd-validate 005-reservas. 006 y 007 siguen en borrador. Decisiones de la revisión: el turno activo dura hasta su fin; al abrir se elige el primer día con horas libres; la app solo evita choques con turnos ya guardados (simultáneos → 012); RF-38 adelanta la ficha en vivo (antes 009); sin compatibilidad con turnos antiguos: se borran antes de publicar las reglas. Revisar en 006 la mención a "turnos antiguos" (RF-6, casos límite).
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
- Esta máquina está en −03:00 (= Curitiba): un test de hora del salón pasa sin el arreglo. Para verlo en rojo, `TZ=Europe/Lisbon flutter test …`.
- Web en local: siempre `--web-port 5050` (`.vscode/launch.json`; el 5000 lo ocupa el Receptor AirPlay de macOS). Google solo acepta orígenes registrados en el cliente OAuth web (`http://localhost:5050`); con otro puerto da `origin_mismatch`. Al publicar, registrar también `https://dshaddai.com`.
- `DateFormat.Hm('es')` da "9:00" y `'pt'`, "09:00": en los tests, buscar la hora con el formato del idioma.
- `AsyncValue.whenData` pierde el error durante el reintento automático: comprobar `hasError` antes.
- Tests de la reserva: `ListView` construye poco fuera de la pantalla; para volver al calendario, `tabScrollControllerProvider(MobileTab.booking).jumpTo(0)`. `TableCalendar` tiene construidos los meses de al lado: buscar los días con `.hitTestable()`.
- `adminControllerProvider` crea los repositorios de reservas, usuarias y ajustes: un test que toque sus botones debe sustituir los tres, o llega a Firebase.
- Riverpod 3 reintenta solo un provider que falla: queda `AsyncLoading` con el error dentro (`isLoading` y `hasError` a la vez). Para mostrar el error, comprobar `hasError` antes que `isLoading`.
- Una vista con `BookingView` necesita sustituir también `myAppointmentsProvider` (`sessionOverrides` o `bookingDataOverrides`), o muestra el aviso de error.
- Riverpod 3: `ref.read(provider.future)` de un provider que nadie escucha se queda en pausa y no termina (el test se cuelga). Leer `.value` de algo que la pantalla ya escucha, o escucharlo en el test.
- Un `StreamProvider` que lee otro con `.value` vuelve a construirse (y a suscribirse a Firestore) con cada valor: usar `select` sobre lo que importa (el día, el `uid`). En los tests de la reserva, fijar `salonNowProvider` (`bookingDataOverrides`) para no dejar su temporizador de 30 s pendiente.
- `DateTime ==` exige el mismo instante **y** la misma zona (UTC o local): comparar instantes con `isAtSameMomentAs`. Las fechas de Firestore llegan en hora local (`decodeDates`); la hora del salón se obtiene con `toSalon`.
- Flutter 3.47.8 (2026-11-02): `dart format lib test` reformatea 27 archivos que no se tocaron (líneas en blanco entre grupos de imports y cortes de línea). El autor decidió dejar ese formato (2026-11-02).
- Tests con `tomorrow()`/`DateTime.now()` se rompen al cambiar de mes: un nombre de mes fijo ("outubro") o un mes de 6 semanas que baja las horas fuera de la pantalla de 800×600. Usar fechas fijas e inyectar "ahora" (`clockProvider` en la 005), o calcular el mes y dar alto de sobra.
- Las reglas de tema, colores, tests, rutas y landing están en `CLAUDE.md`: leerlas antes de tocar esas partes.
- Cada Mac tiene su propia clave de depuración de Android: si el inicio de sesión con Google falla con `[16] Account reauth failed` / `canceled`, falta su SHA-1 en Firebase (app Android → Agregar huella digital) y hay que volver a descargar `google-services.json`. Ver la SHA-1 con el `keytool` de Android Studio (`/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).
- `currentUserProvider` escucha la ficha en vivo desde la 005 (T7). Los fakes de `UserRepository` necesitan `watchUser`, y los tests de providers con varios streams encadenados necesitan varias vueltas del bucle (`Future.delayed(Duration.zero)` × 5) antes de comprobar.
- `textContrastGuideline` falla con un texto pequeño dentro de un `Container` con borde ajustado (lee el borde como fondo): la etiqueta "Oculto" va sin borde. Y no leas `adminServicesControllerProvider` en `build`: crea `ConfigRepository` con Firebase real y rompe los tests; léelo al pulsar. Tampoco mide bien un texto de 10 px en w400 (títulos `AppText.eyebrow`): los de la reserva van a 12 px en w600.
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

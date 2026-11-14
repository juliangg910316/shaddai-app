# Tareas 006 — Editar el turno
Estado: aprobada

Spec: `spec.md` (aprobada) · Plan: `plan.md` (aprobado). En cada tarea, los tests se escriben primero y se ven en rojo. La tarea termina con `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde. Si una tarea añade textos, los añade en `app_es.arb` y `app_pt.arb` (claves del plan § 6), añade sus claves a `test/features/booking/booking_texts_test.dart` y ejecuta `flutter gen-l10n`.

Salen 15 tareas, en tres bloques:
- **A** es solo datos, lógica pura y providers. La app sigue igual por fuera.
- **B** cambia la vista: el botón, la edición, el guardado, el detalle y la Web.
- **C** contiene las reglas, la accesibilidad y el cierre.

Son más de 10, pero la spec no se divide (decisión del autor, 2026-11-14): todos los bloques dependen de la lógica del bloque A.

Los repositorios no tienen tests propios (tocarían Firebase): su contrato lo fija `FakeBookingRepository`, y su comportamiento real se comprueba en el recorrido manual de `rules-check.md`, como en la 005.

## Bloque A — Datos, lógica y providers

- [x] **T1. Margen de edición en el calendario e igualdad de lo reservado.** RF-12, RF-21
  - Tests:
    - `test/data/models/calendar_settings_model_test.dart` (nuevo): `editMarginMinutes` vale 0 si falta, si es texto o si es negativo; se lee un entero; `defaultSettings()` lo deja en 0; `toMap` no lo escribe (D-4).
    - `test/data/models/booked_service_model_test.dart`: dos `BookedServiceModel` con los mismos datos son iguales y tienen el mismo `hashCode`; cambiar el nombre, el precio, la duración o un adicional los hace distintos; lo mismo con `BookedAddonModel`.
  - Hecho cuando: los tests pasan y `AdminSettingsView` no cambia (como `toMap` no escribe el margen y guarda con `merge: true`, no lo pisa).
  - Hecha (2026-11-14):
    - `CalendarSettingsModel.editMarginMinutes` (por defecto 0): `fromMap` acepta un entero ≥ 0, también como decimal sin parte fraccionaria; lo demás vale 0. `toMap` no lo escribe;
    - `==` y `hashCode` por valor en `BookedServiceModel` y `BookedAddonModel`. El nombre se compara por sus dos textos, sin tocar `BilingualText`, y los adicionales en orden, sin importar Flutter en `lib/data/models`;
    - 21 tests nuevos (10 del calendario y 11 de igualdad); suite completa, 1261 en verde.

- [x] **T2. Si un turno es editable.** RF-1 a RF-3, RF-22, RF-23, RNF-1
  - Tests: `test/features/booking/logic/booking_edit_test.dart` (nuevo), en tabla:
    - `isEditable`: margen 0 (editable hasta que empieza), margen 30 justo en el límite (9:30 de un turno de las 10:00 → no) y un minuto antes (→ sí), bloqueada (→ no), con el dispositivo en Lisboa (mismo resultado, porque usa instantes);
    - `startsWithinEditMargin`: dentro, en el límite y fuera; margen 0 con una hora futura → nunca;
    - `editAvailability`: bloqueada (aunque el calendario falle) → `blocked`; error → `error`; cargando → `loading`; editable → `editable`; dentro del margen → `closed`.
  - Hecho cuando: `booking_edit.dart` (`lib/features/booking/logic/`) pasa los tests y no importa Flutter ni Firebase.
  - Hecha (2026-11-14):
    - `booking_edit.dart`: `isEditable`, `startsWithinEditMargin` (en el límite ya cuenta como dentro), `EditAvailability` y `editAvailability`;
    - `editAvailability` recibe `settingsError` y `marginMinutes` (`null` mientras carga) en lugar de un `AsyncValue`, como `bookingScreen` de la 005: la lógica pura no depende de Riverpod. Mismo comportamiento que el plan;
    - sin imports: ni Flutter ni Firebase;
    - 20 tests de tabla, también en verde con `TZ=Europe/Lisbon`; suite completa, 1282 en verde.

- [x] **T3. El turno original y sus horas.** RF-5, RF-7 a RF-9, RNF-1
  - Tests: `booking_edit_test.dart`, en tabla:
    - `EditOriginal` desde un `AppointmentModel` (horas en hora del salón);
    - `isEditDaySelectable`: el día original más allá de los 60 días, cerrado o bloqueado → sí; otro día así → no; un día normal → sí;
    - `editFreeSlots`:
      - con el propio turno quitado de los ocupados, su hora sale libre;
      - hora original fuera de la rejilla (apertura cambiada): sale, en orden, con la cobertura hasta el siguiente ocupado;
      - día original ya cerrado: sale su hora, con el límite de D-3 (el cierre o el fin original, lo que sea más tarde, sin pasar del siguiente ocupado);
      - hora original ya pasada, o dentro de otro turno ocupado: no se añade;
      - otro día: igual que `freeSlots`.
  - Hecho cuando: los tests pasan.
  - Hecha (2026-11-14):
    - `booking_edit.dart`: `EditOriginal` (con `EditOriginal.of(turno)`, horas en hora del salón), `isEditDaySelectable` y `editFreeSlots`;
    - D-3 aclarado con el autor: el límite de la hora original es el cierre (si el día abre) o el fin original, lo que sea más tarde, y nunca pasa del siguiente turno ocupado. En un día ahora cerrado solo cabe un servicio igual o más corto. Actualizado en el plan (§ 4.2 y D-3);
    - `EditOriginal.booked` admite `null`, como `AppointmentModel.booked`;
    - 17 tests de tabla, también en verde con `TZ=Europe/Lisbon`; suite completa, 1299 en verde.

- [x] **T4. Antes y después, y comprobación al guardar.** RF-11, RF-12, RF-14, RF-15, RF-17, RNF-1
  - Tests: `booking_edit_test.dart`, en tabla:
    - `draftOfOriginal` y `draftOfSelection` (con los precios y la duración actuales del catálogo, adicionales incluidos, y `totalFrom` de un servicio "desde");
    - `changedFields`: sin cambios → vacío; cada campo por separado (fecha, inicio, fin, servicio, adicionales, duración, total); varios a la vez; mismo servicio con otro adicional → solo adicionales y total;
    - `checkEditBeforeSave`, cada resultado y su orden: turno borrado, cancelado o terminado → `notActive` (aunque también haya cambiado); horas, estado o lo reservado distintos → `changed`; dentro del margen → `notEditable`; hora ocupada → `slotTaken`; servicio que ya no cabe → `doesNotFit`; la hora original fuera de la rejilla con el mismo servicio → `ok`; todo bien → `ok`.
  - Hecho cuando: los tests pasan.
  - Hecha (2026-11-14):
    - `booking_edit.dart`: `BookingDraft`, `draftOfOriginal`, `draftOfSelection` (`null` sin servicio o si no está disponible; sin hora, sin inicio ni fin), `EditField`, `changedFields`, `EditCheck` y `checkEditBeforeSave`;
    - `changedFields` compara el inicio y el fin por la hora del día (si solo cambia el día, cambia la fecha), el servicio por su nombre en los dos idiomas y los adicionales sin importar el orden;
    - la duración del turno original es su fin menos su inicio;
    - `checkEditBeforeSave` recibe el turno leído como `AppointmentModel?`;
    - 21 tests de tabla, también en verde con `TZ=Europe/Lisbon`; suite completa, 1320 en verde.

- [ ] **T5. La selección en la edición.** RF-4 a RF-9, RF-27 a RF-30, RNF-1
  - Tests: `test/features/booking/logic/booking_selection_test.dart` (casos nuevos):
    - `selectionOf`: con el catálogo listo, el día, la hora, el servicio y los adicionales del turno; con el servicio no disponible → sin servicio y `itemUnavailable`; con un adicional no disponible → sin él y `editAddonsUnavailable`; con el catálogo cargando, `reconcile` lo hace al llegar;
    - `reconcile` con `original`: no salta del día original aunque esté cerrado o fuera de la ventana; mantiene su hora fuera de la rejilla; al elegir otro día, aplica las reglas de la 005;
    - `requestItemInEdit`: más corto → cambia, sin adicionales, aviso `editItemChanged` con antes y después; igual de largo → cambia; más largo con hueco después → cambia; más largo con el tiempo de después ocupado o pasado el cierre → no cambia y `editItemDoesNotFit` con N y M; sin hora → cambia; el mismo servicio → sin cambios ni aviso, con sus adicionales; no disponible → sin cambios e `itemUnavailable`; catálogo cargando → pendiente, y se aplica al llegar.
  - Hecho cuando: los tests pasan y los de la 005 de `booking_selection_test.dart` siguen en verde.

- [ ] **T6. Repositorio y guardado de la edición.** RF-12 a RF-16, RF-26
  - Código: `BookingRepository.fetchEditCheck` y `updateEditedAppointment` (transacción, plan § 3); `FakeBookingRepository` con los dos métodos (respuesta, `false` o error programables, y registro de lo guardado); `BookingEditor` / `bookingEditSaveProvider` con `EditSaveResult`.
  - Tests: `test/features/booking/booking_edit_save_test.dart` (parte de providers, con `ProviderContainer` y el fake):
    - `ok`: guarda el mismo id con las horas nuevas, la copia nueva de lo reservado y el turno ocupado con las mismas horas; devuelve los campos cambiados; termina la edición;
    - `ok` sin cambios → guarda igual y devuelve un conjunto vacío;
    - `slotTaken` / `doesNotFit`: no guarda, quita la hora y conserva lo demás;
    - `notEditable` / `notActive` / `changed` (de la comprobación o porque la transacción devuelve `false`): no guarda como hecho y termina la edición;
    - error o tiempo agotado → `failed`, la edición sigue igual.
  - Hecho cuando: los tests pasan.

- [ ] **T7. Providers de la edición.** RF-1 a RF-9, RF-18; casos límite
  - Código: `editTargetProvider`; `busyRangesProvider` sin el propio turno; `freeSlotsOfDayProvider` (lo usan `SlotGrid` y `selectedFreeSlotProvider`); `editAvailabilityProvider`; `BookingScreenEditing` en `bookingScreen`; `BookingSelectionController` escucha la edición, la ficha y los turnos; `bookingDataOverrides` acepta un calendario con margen.
  - Tests: `test/features/booking/booking_providers_test.dart` y `logic/booking_rules_test.dart` (casos nuevos):
    - `bookingScreen` → `BookingScreenEditing` solo si el turno en edición es el activo y no está bloqueada;
    - empezar la edición carga `selectionOf`; terminarla vuelve a la selección vacía;
    - el propio turno no sale en `busyRangesProvider`;
    - `editAvailabilityProvider` cambia al pasar el tiempo, al cambiar el margen y al bloquearla;
    - bloquearla o cancelar el turno mientras edita termina la edición (con `editNotActive` en el segundo caso).
  - Hecho cuando: los tests pasan y los de la 005 siguen en verde (la vista de reserva no cambia por fuera).

## Bloque B — Vista

- [ ] **T8. "Editar turno" en el turno activo.** RF-1 a RF-3, RF-22, D-6
  - Tests: `test/features/booking/booking_edit_screen_test.dart` (nuevo, `pumpApp`):
    - con margen 0, "Editar turno" se ve; dentro del margen, no, y sale el texto de RF-2 con WhatsApp (abre el enlace del salón);
    - aparece o desaparece sin recargar al pasar el tiempo, al cambiar el margen y al bloquearla;
    - bloqueada: solo el aviso de bloqueo;
    - error del calendario: sin botón, aviso con "Reintentar", que vuelve a leerlo.
    - `booking_screen_states_test.dart` se adapta si hace falta.
  - Hecho cuando: los tests pasan, en ES y PT.

- [ ] **T9. Abrir la edición, elegir y cancelar.** RF-4 a RF-10, RF-18
  - Tests: `test/features/booking/booking_edit_form_test.dart` (nuevo, `pumpApp`) y `booking_edit_screen_test.dart`:
    - "Editar turno" abre la edición con el título "Editar turno", el día, la hora, el servicio y los adicionales elegidos, y la vista sube al principio;
    - servicio o adicional no disponibles: abre sin ellos y avisa;
    - el día original fuera de la ventana o cerrado se puede elegir; su hora sale libre aunque esté fuera de la rejilla; la hora del propio turno no sale ocupada;
    - otra fecha sigue las reglas normales;
    - "Guardar cambios" sin hora o sin servicio dice qué falta y lo marca;
    - "Cancelar" vuelve al turno sin cambios.
  - Hecho cuando: los tests pasan.

- [ ] **T10. Diálogo de antes y después, y aviso del margen al reservar.** RF-11, RF-23
  - Tests: `booking_edit_form_test.dart`:
    - "Guardar cambios" con todo elegido abre el diálogo con la tabla: las filas que cambian con antes → después y "cambia" para el lector de pantalla; las demás con un valor; "volverá a esperar la confirmación"; "Cancelar" lo cierra sin guardar;
    - en ES y PT, y al cambiar de idioma con el diálogo abierto;
    - en una reserva nueva (005) dentro del margen, el diálogo de confirmación lleva la línea de RF-23; con margen 0, no.
  - Hecho cuando: los tests pasan.

- [ ] **T11. Guardar y avisar.** RF-12 a RF-17, RF-26
  - Tests: `booking_edit_save_test.dart` (parte de vista, `pumpApp`):
    - confirmar guarda y abre "Cambios guardados" con lo que cambió, o "No cambiaste nada…"; al cerrarlo se ve el turno esperando confirmación (también si estaba confirmado);
    - `slotTaken` y `doesNotFit`: los avisos de la 005 y la edición sigue sin la hora;
    - `notEditable`, `notActive` y `changed`: cada uno con su texto, y se vuelve al turno;
    - error: aviso sin detalles técnicos y la edición sigue igual;
    - el turno ocupado guardado tiene las horas nuevas (RF-26).
  - Hecho cuando: los tests pasan, en ES y PT.

- [ ] **T12. Cambiar el servicio desde el detalle.** RF-19, RF-27 a RF-30
  - Tests: `test/features/booking/booking_edit_detail_test.dart` (nuevo, `pumpMobileApp` y `pumpWebApp`):
    - con la edición abierta, "Reservar cita" en un servicio que cabe vuelve a la edición con la misma fecha y hora, el servicio nuevo sin adicionales y el aviso con antes → después (servicio, fin, duración y total);
    - uno que no cabe: no cambia y avisa con N y M;
    - uno no disponible: no cambia y avisa (005, RF-44);
    - el mismo servicio: sin cambios, con sus adicionales;
    - en Android/iOS, cambiar de pestaña y volver conserva la edición.
  - Hecho cuando: los tests pasan.

- [ ] **T13. Web: enlace de la app y "atrás" del navegador.** RF-19, RF-20, D-8
  - Primero, comprobar con un test si go_router 18 deja distinguir una navegación del navegador de una de la app. **Si no es fiable, parar y preguntar al autor.**
  - Tests: `test/features/booking/booking_edit_web_test.dart` (nuevo, `pumpWebApp`):
    - ir a otra página con un enlace de la app (barra superior, detalle) y volver conserva la edición;
    - "atrás" del navegador (mensaje de plataforma `pushRouteInformation`) la cierra y, al volver, se ve el turno;
    - recargar (app nueva) muestra el turno.
  - Hecho cuando: los tests pasan.

## Bloque C — Reglas, accesibilidad y cierre

- [ ] **T14. Reglas y comprobación manual.** RF-24, RF-25, RNF-4
  - Tests: `test/core/firestore_rules_test.dart`:
    - `editMarginMinutes()` con `exists` y 0 por defecto;
    - `update` de `appointments`: la rama de la admin igual; la de la clienta con `!isBlocked()`, turno propio, estado activo, el margen, `hasOnly` de los cuatro campos, `waiting_confirmation`, fin después del inicio y `getAfter` del turno ocupado;
    - `update` de `busySlots` con `hasOnly(['start', 'end'])`, turno propio y `getAfter` del turno con las mismas horas;
    - `settings/calendar`: lectura con sesión, escritura de la admin, sin "PROVISIONAL" (sustituye al test de la 005).
  - Código: `firestore.rules`; `specs/006-editar-turno/rules-check.md` con los casos del simulador (plan § 9) y el recorrido de lo que ya existía.
  - Hecho cuando: los tests pasan y el autor publica las reglas y confirma `rules-check.md`.

- [ ] **T15. Accesibilidad, textos y cierre.** RNF-2, RNF-3
  - Tests:
    - `test/features/booking/booking_edit_accessibility_test.dart` (nuevo): contraste, 48 px y nombres en los dos temas para "Editar turno", "Guardar cambios", "Cancelar", el diálogo de antes y después y "Cambios guardados"; "cambia" y los avisos se anuncian; texto al 200 % y 320 px en ES y PT sin desbordes;
    - `booking_texts_test.dart`: todas las claves del plan § 6 en ES y PT;
    - `booking_accessibility_test.dart` de la 005, si el botón entra en sus pantallas.
  - Código: `CLAUDE.md` (`settings/calendar` ya no es provisional, la clienta edita su turno, el margen de edición).
  - Hecho cuando: los tests pasan, la suite completa está en verde (también con `TZ=Europe/Lisbon`) y el autor hace el recorrido manual de los criterios de finalización.

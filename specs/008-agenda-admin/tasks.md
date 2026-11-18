# Tareas 008 — Agenda de la admin
Estado: aprobada

Spec: `spec.md` (aprobada) · Plan: `plan.md` (aprobado). En cada tarea, los tests se escriben primero y se ven en rojo. La tarea termina con `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde. Si una tarea añade textos, los añade en `app_es.arb` y `app_pt.arb` (claves del plan § 6), añade sus claves a `test/features/booking/booking_texts_test.dart` y ejecuta `flutter gen-l10n`.

Salen 17 tareas, en cuatro bloques:
- **A** pone los cierres en los datos y en la reserva. La admin aún no los crea desde la app.
- **B** contiene la pantalla de cierres de la admin y la agenda.
- **C** permite a la admin editar un turno.
- **D** contiene el margen de edición, las reglas, la accesibilidad y el cierre.

Son más de 10, pero la spec no se divide (decisión del autor, 2026-11-17).

## Bloque A — Los cierres en los datos y en la reserva

- [x] **T1. Lógica pura de los cierres.** RF-3, RF-4, RF-5, RF-8, RF-9, RF-13, RNF-1
  - Tests: `test/features/booking/closures_test.dart` (nuevo, tablas):
    - `closureRange` de una franja y de unos días;
    - `closureErrors`:
      - fin no posterior al inicio y días al revés;
      - cierre ya pasado, también una franja de hoy que ya terminó;
      - el día 365 vale y el 366 no;
    - `closureKind`;
    - `closureConflicts`:
      - un turno que toca el borde no choca; uno en curso sí;
      - uno cancelado o terminado no choca;
      - los que chocan salen en orden;
    - `closureEntries`: fechas bloqueadas como días enteros, pasados fuera, orden por inicio;
    - `closuresOfDay`: cierre de varios días y cierre de otro día;
    - `isClosedAllDay`: una franja que cubre el horario, dos que se unen, un hueco, un día que ya no abre;
    - el archivo no importa Flutter ni Firebase.
  - Hecho cuando: `lib/features/booking/logic/closures.dart` cumple el plan § 4.1 y los tests pasan.
  - Hecha (2026-11-17):
    - `closures.dart`: `RangeDraft`/`DaysDraft`, `closureRange`, `closureErrors` (sin "pasado" si el orden está mal; un cierre que empezó y no terminó vale), `closureKind`, `overlaps`, `closureConflicts` (genérica, con `AppointmentTimes`), `closureEntries` (con `StoredClosure`, un registro: no depende aún del modelo de T3; ignora fechas bloqueadas que no son una fecha), `closuresOfDay` e `isClosedAllDay` (unión de cierres que se cruzan o se tocan);
    - `closures_test.dart`: 49 tests; suite completa, 1717 en verde.

- [x] **T2. Los cierres en las horas libres y los días.** RF-12, RF-13, RF-14, RF-16, RNF-1
  - Tests, ampliando los que ya existen:
    - `free_slots_test`: un cierre al principio, en medio y al final del día; un cierre pegado a un turno; un cierre de varios días; uno que cruza la medianoche. Comprueban horas libres y cobertura;
    - `booking_window_test`: `isSelectableDay` e `initialDay` saltan un día cerrado entero por cierres;
    - `booking_selection_test`: un cierre nuevo quita la hora elegida con `slotGone`;
    - `booking_rules_test`, `booking_edit_test` y `admin_booking_test`: `checkSlot`, `checkEditBeforeSave` y `checkAdminBeforeSave` dan "hora ocupada" o "no cabe" por un cierre.
  - Hecho cuando: `isSelectableDay`, `BookingContext` y las tres comprobaciones reciben los cierres (plan § 4.2), y lo que ya existía sigue en verde.
  - Hecha (2026-11-17):
    - `isSelectableDay`, `initialDay` e `isEditDaySelectable` reciben `closures` (por defecto, ninguno): un día con todo su horario dentro de cierres no se elige;
    - `BookingContext.closures` (`null` mientras no llegan: no se toca la hora ni el día) se suma a los turnos ocupados en `freeSlotsOf`;
    - `checkSlot`, `checkBeforeSave`, `checkEditBeforeSave` y `checkAdminBeforeSave` reciben `closures` y los suman a `busy`. `freeSlots` no cambia;
    - los providers aún no pasan cierres (T4);
    - 22 tests nuevos en seis archivos; suite completa, 1739 en verde.

- [x] **T3. Datos de los cierres y del calendario.** RF-8, RF-41, RNF-4
  - Tests:
    - `closure_model_test` (nuevo): `fromMap` con datos buenos, sin campo y con el fin no posterior al inicio; `toMap` solo con `start` y `end`;
    - `calendar_settings_model_test`: `toMap` sin `blockedDates`, y la lectura de documentos con `blockedDates` igual que antes;
    - `test/helpers/fake_config.dart` (nuevo o ampliado): cierres en vivo (`emitClosures`), `fetchClosures`, `created`/`deleted`, `removedBlockedDates`, `margin`, `saveError`.
  - Hecho cuando:
    - existe `ClosureModel`;
    - `ConfigRepository` tiene `watchClosures`, `fetchClosures`, `createClosure`, `deleteClosure`, `removeBlockedDate` y `updateEditMargin` (plan § 3);
    - `toMap` ya no escribe `blockedDates`;
    - el fake está listo.
  - Hecha (2026-11-17):
    - `ClosureModel` (`closure_model.dart`), con `stored` para la lógica: un registro, sin que `lib/data` importe la capa de features;
    - `ConfigRepository`: `watchClosures`/`fetchClosures` (`end >= desde`; la segunda, del servidor), `createClosure`, `deleteClosure`, `removeBlockedDate` (`arrayRemove`) y `updateEditMargin` (`set` con `merge`), con `saveTimeout` de 15 s;
    - `CalendarSettingsModel.toMap` ya no escribe `blockedDates`;
    - `test/helpers/fake_config.dart`: `FakeConfigRepository`, probado en `test/data/fake_config_test.dart` (filtra por "desde" como Firestore, en vivo, errores y `merge`);
    - 15 tests nuevos; suite completa, 1754 en verde.

- [x] **T4. La reserva no ofrece las horas de un cierre.** RF-12 a RF-17
  - Tests: `test/features/booking/booking_closures_test.dart` (nuevo):
    - la reserva de la clienta, su edición y la de la admin no muestran las horas del cierre, y un día cerrado entero no se elige;
    - un cierre que llega en vivo quita la hora elegida y avisa;
    - si fallan los cierres, sale el aviso con "Reintentar" en lugar de las horas;
    - los tres submitters leen los cierres del servidor y no guardan una hora dentro de un cierre;
    - la clienta no ve ninguna marca de cierre.
  - Hecho cuando:
    - `closuresProvider` y `closureRangesProvider` existen;
    - `busyRangesProvider`, `freeSlotsOfDayProvider`, `BookingContext` y `BookingCalendar` usan los cierres;
    - los submitters leen `fetchClosures` (plan § 5);
    - `bookingDataOverrides` sustituye el repositorio del calendario por el fake.
  - Hecha (2026-11-17):
    - `closuresProvider` (desde hoy a las 0:00 del salón, en vivo) y `closureRangesProvider` (con el error delante de la carga);
    - `busyRangesProvider` suma los cierres: la rejilla de horas, `freeSlotsOfDayProvider` y su aviso de error los usan sin cambios. `BookingContext` recibe `closures` y el controlador de la selección los escucha;
    - `BookingCalendar` pasa los cierres a `isSelectableDay`/`isEditDaySelectable`; "Reintentar" del aviso de la agenda también vuelve a pedir los cierres;
    - los tres submitters leen del servidor los cierres desde el día elegido (`fetchClosureRanges`) y, si fallan, no guardan;
    - `bookingDataOverrides`/`bookingScheduleOverrides` aceptan `config` (por defecto, un `FakeConfigRepository` vacío). Cuatro archivos de tests con su propio contenedor añaden el fake, o escuchan `closuresProvider` antes de leer las horas libres;
    - `booking_closures_test.dart`: 13 tests (vista de la clienta, edición, admin a 365 días y los tres guardados); suite completa, 1767 en verde.

## Bloque B — Cierres de la admin y agenda

- [x] **T5. Guardar y quitar cierres.** RF-3 a RF-8, RF-11
  - Tests: `test/features/admin/admin_closures_provider_test.dart` (nuevo):
    - `save`: con errores no lee ni guarda; con turnos que chocan los devuelve sin guardar; sin choques guarda inicio y fin; si falla devuelve `failed`;
    - la lectura de los turnos activos es del servidor, justo antes de guardar;
    - `delete`: borra un cierre o quita una fecha bloqueada; si falla, lo indica.
  - Hecho cuando:
    - existen `ClosureController`, `adminClosureEntriesProvider` y `adminDayClosuresProvider`;
    - existe `BookingRepository.fetchActiveAppointments`, también en el fake.
  - Hecha (2026-11-17):
    - `admin_closures_provider.dart`: `ClosureController` (`save` devuelve `ClosureSaveInvalid`/`Conflicts`/`Ok`/`Failed`; `delete` borra el cierre o quita la fecha bloqueada), `adminClosureEntriesProvider` (próximos, con el error de los cierres o del calendario) y `adminDayClosuresProvider` (pide los cierres desde el día de la agenda, también si es pasado);
    - `fetchActiveAppointments(now)` lee del servidor los turnos que terminan desde "ahora"; el fake registra `activeFetches` y acepta `activeFetchError`;
    - 16 tests; suite completa, 1784 en verde.

- [x] **T6. Pantalla de cierres.** RF-1, RF-2, RF-7, RF-8, RF-10
  - Tests: `test/features/admin/admin_closures_view_test.dart` (nuevo):
    - lista ordenada, con fechas, horas o "Todo el día", y las fechas bloqueadas;
    - sin cierres: el texto y "Nuevo cierre";
    - error: aviso y "Reintentar", sin "Nuevo cierre";
    - "Quitar" pide confirmación; al confirmar, lo quita y avisa; al cancelar, no hace nada;
    - el botón "Cierres" del panel abre la pantalla (48 px y tooltip).
  - Hecho cuando:
    - existen `AdminClosuresView` y la ruta `/admin/closures` (Android/iOS y Web);
    - el panel tiene el botón "Cierres";
    - los textos de la lista están en ES y PT.
  - Hecha (2026-11-17):
    - `AdminClosuresView`: tarjetas con las fechas (o "Del … al …") y las horas o "Todo el día" (`closureLabels`); "Quitar" (48 px, tooltip) con confirmación y aviso; vacía, el texto; con error, aviso y "Reintentar" (vuelve a pedir cierres y calendario), sin "Nuevo cierre". "Nuevo cierre" abre `/admin/closures/new`, que llega en la T7;
    - ruta `/admin/closures` en Web (`WebAccountPage`) y Android/iOS, y en `safeNext`; botón "Cierres" (`event_busy_outlined`) en la cabecera del panel;
    - 11 textos nuevos en ES y PT; se reutilizan `bookingTimeRange`, `bookingRetry` y `cancelAction`;
    - `admin_closures_view_test.dart`: 11 tests; suite completa en verde.

- [x] **T7. Nuevo cierre y turnos que chocan.** RF-3 a RF-6, RF-11
  - Tests, en `admin_closures_view_test`:
    - "Unas horas" y "Días enteros";
    - las horas, en pasos de 15 minutos;
    - las fechas, hasta 365 días;
    - cada error bajo su campo;
    - con choques: se listan con fecha, hora, persona y lo reservado, y cada uno tiene "Editar" y "Cancelar". "Cancelar" pide confirmación y cancela; después, "Guardar" vuelve a comprobar y guarda;
    - sin choques: "Cierre guardado" y vuelta a la lista;
    - si falla: aviso, y conserva lo elegido.
  - Hecho cuando:
    - existen `AdminClosureFormView` y la ruta `/admin/closures/new`;
    - "Editar" de un choque lleva a la ruta de edición de T13. Mientras tanto, el test solo comprueba la dirección.
  - Hecha (2026-11-17):
    - `AdminClosureFormView` en `/admin/closures/new` (Web y Android/iOS, y en `safeNext`): "Unas horas" (fecha, desde, hasta) o "Días enteros" (primer y último día); horas de 0:00 a 23:45 cada 15 minutos; fechas con `showDatePicker` de hoy a hoy + 365; tras el primer "Guardar", los errores bajo su campo y en vivo;
    - choques: título, explicación y una tarjeta por turno (fecha, hora, persona y lo reservado) con "Editar" (`openAdminEdit`: `go` en Web, `push` en Android/iOS) y "Cancelar" (confirmación "Volver"/"Cancelar turno"; al cancelar sale de la lista). Cambiar lo elegido borra los choques;
    - guardado: "Cierre guardado." y vuelta a la lista; si falla, aviso y se conserva lo elegido;
    - `bookedLabel` sale de la agenda para compartirse;
    - 21 textos nuevos (ES y PT). Fuera del plan § 6, tres para la confirmación de cancelar: `adminCancelAppointmentConfirm`, `adminCancelAppointmentKeep` y `adminCancelAppointmentError`;
    - 10 tests nuevos en `admin_closures_view_test`; suite completa, 1812 en verde.

- [x] **T8. La agenda muestra los cierres y "Editar".** RF-9, RF-10, RF-18
  - Tests, en `admin_appointments_booked_test`:
    - los cierres del día salen entre los turnos, en orden de hora, con "CERRADO";
    - un cierre de varios días sale en cada uno;
    - si fallan los cierres: aviso y "Reintentar";
    - "Editar" solo aparece en los turnos esperando confirmación o confirmados que no han terminado: también en uno en curso, nunca en uno cancelado ni en uno terminado.
  - Hecho cuando: la agenda usa `adminDayClosuresProvider` y `_AppointmentCard` tiene "Editar", que lleva a `/admin/appointments/<id>/edit`.
  - Hecha (2026-11-17):
    - la agenda mezcla turnos y cierres del día por su inicio (`_ClosureCard`: "CERRADO", sus horas o "Todo el día" y, si es de varios días, cuáles); con solo cierres, ya no dice "No hay reservas";
    - si fallan los cierres, aviso con "Reintentar" encima de la lista, y los turnos siguen; `adminAgendaClosuresProvider` pasa a ser público para reintentar;
    - "Editar" (`openAdminEdit`) junto a "Cancelar" en los turnos esperando o confirmados que terminan después de "ahora";
    - "Cerrado" en ES y PT;
    - 7 tests nuevos en `admin_appointments_booked_test`. Seis archivos de tests que montan el panel reciben un `FakeConfigRepository` (Riverpod no deja sustituir dos veces el mismo provider, así que no puede ir por defecto en `pumpApp`); suite completa, 1819 en verde.

## Bloque C — La admin edita un turno

- [x] **T9. Lógica pura de la edición de la admin.** RF-20 a RF-26, RF-29 a RF-31, RNF-1
  - Tests: `test/features/booking/admin_edit_test.dart` (nuevo, tablas):
    - `recipientOf`: cuenta, y sin cuenta con la casilla marcada;
    - `personChanged`: otra clienta, de cuenta a sin cuenta, nombre con espacios, WhatsApp con otro formato;
    - `adminEditChanges`: sin cambios, solo la persona, la hora y el servicio;
    - `markAfterEdit`;
    - `checkAdminEditBeforeSave` en cada resultado y en su orden, sin margen de edición;
    - `editFreeSlots(allowStarted: true)` con un turno en curso, y `false` igual que antes.

    `EditOriginal.of` copia la persona y la marca.
  - Hecho cuando: `logic/admin_edit.dart` y los cambios de `booking_edit.dart` cumplen el plan § 4.3 y § 4.4.
  - Hecha (2026-11-17):
    - `EditOriginal` lleva la persona y la marca (campos opcionales: la edición de la clienta no cambia); `editFreeSlots(allowStarted)`;
    - `admin_edit.dart`: `recipientOf`, `personChanged`, `adminEditChanges` (devuelve `AdminEditChanges(fields, person)` en lugar del `Set<AdminEditField>` del plan, para reutilizar `EditField` sin tocar la edición de la clienta), `markAfterEdit` y `checkAdminEditBeforeSave` con `AdminEditCheck`;
    - los pasos de la persona de `checkAdminBeforeSave` salen a `checkRecipient`, que comparten las dos;
    - 50 tests nuevos en `admin_edit_test.dart`; suite completa, 1869 en verde.

- [x] **T10. Datos de la edición de la admin.** RF-28, RF-30, RF-31
  - Tests: el fake de turnos implementa `watchAppointment` (`emitAppointment`), `fetchAdminEditCheck` y `updateAppointmentByAdmin`, que respeta `expected` y registra lo guardado. También hay tests del fake: no guarda si `expected` falla y conserva los campos que no se envían.
  - Hecho cuando: `BookingRepository` tiene `watchAppointment`, `fetchAdminEditCheck` y `updateAppointmentByAdmin`: la transacción de plan § 2, con el turno ocupado escrito con `set`.
  - Hecha (2026-11-17):
    - `BookingRepository`: `watchAppointment(id)`; `fetchAdminEditCheck` (turno, ocupados del día y activos, del servidor); `updateAppointmentByAdmin` (transacción: horas, lo reservado y `confirmed`; con `person` también la persona, con `clientId` `null` escrito para una persona sin cuenta, y `createdByAdmin: true`; el turno ocupado con `set` de `start`/`end`);
    - tipos `AdminEditCheckData` y `AppointmentPerson`;
    - el fake: `watchAppointment`/`emitAppointment`, `fetchAdminEditCheck` (`adminEditCheckData`, `adminEditCheckError`, `adminEditCheckRequests`) y `updateAppointmentByAdmin` (respeta `expected`, conserva lo que no se envía, crea o sustituye el turno ocupado, registra `adminEdits`);
    - `test/data/fake_booking_test.dart`: 10 tests. Los métodos reales no tienen test, como los demás del repositorio (no hay Firestore falso); se comprueban en el recorrido y en `rules-check.md` (T16). Suite completa, 1879 en verde.

- [x] **T11. Abrir y cerrar la edición sin perder la reserva a medias.** RF-19, RF-23, RF-24, RF-25, RF-33, RF-35
  - Tests: `test/features/booking/admin_edit_provider_test.dart` (nuevo):
    - `start` guarda aparte la selección y "Para quién", y carga la persona, el día, la hora y lo reservado;
    - `end` los devuelve, y `reconcile` los ajusta;
    - el turno en edición no cuenta como turno activo de la persona;
    - `_checkEdit` no cierra la edición de la admin;
    - una clienta bloqueada se quita con su aviso.
  - Hecho cuando: existe `AdminEditController` con `start`/`end`, y `recipientActiveAppointmentProvider` y `BookingSelectionController` están ajustados (plan § 5).
  - Hecha (2026-11-17):
    - `admin_edit_provider.dart`: `adminEditAppointmentProvider(id)` y `AdminEditController` (`adminEditProvider`, el id en edición). `start` guarda aparte la selección y "Para quién" (solo la primera vez), pone `recipientOf` y abre `editTargetProvider`; `end` cierra, devuelve lo guardado y no hace nada sin edición abierta;
    - `BookingSelectionController.restore(selection)` (pasa por `reconcile`) y `RecipientController.restore(recipient)`;
    - `_checkEdit` no actúa con la sesión de la admin; `recipientActiveAppointmentProvider` no cuenta el turno en edición;
    - 10 tests en `admin_edit_provider_test.dart`. Se comprobó que fallan si se quitan la guarda de `_checkEdit` o el filtro del turno en edición. Suite completa, 1890 en verde.

- [x] **T12. Guardar la edición de la admin.** RF-26, RF-28 a RF-31, RF-34
  - Tests, en `admin_edit_provider_test`:
    - `save` sin cambios o con algo sin elegir: no guarda;
    - `save` en cada resultado: `ok`, `slotTaken`, `doesNotFit` (quitan la hora), `recipientBlocked`, `personActive`, `notActive`, `changed`, `failed`;
    - con `ok`:
      - la persona solo se escribe si cambió;
      - la marca sigue o se pone;
      - el turno queda confirmado;
      - devuelve el día y el nombre;
    - la vigilancia avisa si el turno se cancela o cambia mientras se edita.
  - Hecho cuando: `AdminEditController.save` y la vigilancia cumplen el plan § 5.
  - Hecha (2026-11-17):
    - `AdminEditController.save` devuelve `AdminEditResult(outcome, {active, name, day})`; además de los resultados del plan, `noChanges` e `incomplete` (antes de leer nada). Lee del servidor el turno, los ocupados, los activos, los cierres y la ficha; su propio turno ocupado no cuenta. Con `ok`, cierra la edición (devuelve la reserva a medias);
    - la persona solo se escribe si cambió, con los datos de su ficha del servidor (o, sin cuenta, sin espacios alrededor); `expected` usa la misma comprobación que la vigilancia;
    - `adminEditAlert` (pura, en `admin_edit.dart`, también usada por `checkAdminEditBeforeSave`) y `adminEditAlertProvider`, que calla mientras se guarda;
    - el fake de turnos acepta `adminEditLatency`: el turno guardado llega antes de que termine el guardado, como en Firestore;
    - 23 tests nuevos en `admin_edit_provider_test`; el de la vigilancia durante el guardado falla sin esa guarda. Suite completa, 1913 en verde.

- [x] **T13. La vista de edición.** RF-19, RF-22, RF-27, RF-28, RF-34, RF-35
  - Tests: `test/features/admin/admin_edit_view_test.dart` (nuevo):
    - se abre desde la agenda con todo cargado, con "Guardar cambios" y "Cancelar";
    - sin cambios: lo avisa y no abre el diálogo;
    - el diálogo muestra el antes y el después de la persona, "quedará confirmado" y el aviso del margen solo con cuenta;
    - al guardar, vuelve a la agenda en el día del turno con el aviso;
    - "Cancelar" y el botón atrás salen sin cambiar nada;
    - un turno que no existe: el aviso y "Volver a la agenda";
    - un cambio de idioma con el diálogo abierto se traduce.
  - Hecho cuando:
    - existen `AdminAppointmentEditView` y la ruta `/admin/appointments/:id/edit` (Android/iOS y Web);
    - `BookingForm` recibe `scrollController`;
    - `BookButton` y `confirmEditChanges` tienen el modo de la admin;
    - los textos están en ES y PT.
  - Hecha (2026-11-17):
    - `AdminAppointmentEditView` (`lib/features/admin/presentation/admin_edit_view.dart`) y la ruta `/admin/appointments/:id/edit` en Android/iOS y Web; `safeNext` la acepta solo con un id válido. `closeAdminEdit` vuelve atrás en Android/iOS si se llegó desde el panel; si no, y en Web, va a `/admin`;
    - la vista empieza la edición una vez, en el fotograma siguiente; sin el turno, o si ya no está activo, el aviso y "Volver a la agenda". Al desmontarse, cierra la edición en una microtarea (no se cambia un provider mientras se desmonta el árbol); `end()` no hace nada si la app ya se cerró;
    - `BookingForm` recibe `scrollController`, `onCancel` y `showTitle` (el título va en la barra de la página). El aviso del margen de `BookButton` pasa a ser público (`BookingMarginWarning`); `confirmEditChanges(admin: true)` añade la fila "Para quién", "quedará confirmado" y ese aviso;
    - arreglo en `AdminEditController.end`: se vacía la selección antes de quitar el turno en edición. Si no, tras guardar, el turno ocupado nuevo contaba como ajeno y salía "La hora elegida ya no está disponible" (lo detectan un test del provider y los dos de guardar de la vista);
    - 6 textos nuevos (ES y PT), como en el plan § 6;
    - 13 tests en `admin_edit_view_test` y 6 en `redirect_logic_test`. Suite completa, 1935 en verde.
    - Para la T14: en Web, `WebShell` cierra `editTargetProvider` cuando el navegador sale de `/booking`, también durante la edición de la admin; debe dejarla a su vista. Y en Android/iOS, con la pestaña Reservas montada debajo, sus avisos de la selección podrían salir dos veces.

- [x] **T14. Flujos completos de la edición.** RF-32, RF-33, RF-35
  - Tests:
    - `test/features/admin/admin_edit_flow_test.dart` (nuevo, `pumpMobileApp` y `pumpWebApp`):
      - en Android/iOS la pestaña Reservas sigue montada y conserva lo que la admin tenía a medio agendar;
      - en Web la edición tiene su dirección, y atrás del navegador sale sin guardar;
      - después, Reservar muestra lo que tenía;
    - `test/features/booking/admin_edited_client_test.dart` (nuevo): la clienta ve el cambio sin recargar en Reservas y en Perfil; si cambia la persona, la clienta anterior deja de verlo y la nueva lo ve.
  - Hecho cuando: los dos tests pasan sin cambios fuera de lo que piden.
  - Hecha (2026-11-17):
    - `admin_edit_flow_test` (3 tests) y `admin_edited_client_test` (5 tests: Reservas en Android/iOS y Web, Perfil, y el cambio de persona para la clienta anterior y la nueva);
    - cambio de código: en Android/iOS, con Reservas montada debajo, un aviso de la edición salía dos veces. `BookingView` deja sus avisos a la vista de la edición mientras `adminEditProvider` tiene un turno (el test falló antes del arreglo);
    - lo anotado en la T13 sobre `WebShell` no hizo falta: "atrás" del navegador durante la edición de la admin sale sin guardar, sin avisos y devuelve lo que tenía, sin cambios;
    - ayudas de test: `getClientAppointments` del repositorio falso filtra por `clientId`, como la consulta de Firestore (sin romper ningún test); `pumpWebApp`/`pumpMobileApp` aceptan `appointments: null` para recibir los turnos en vivo; el historial del navegador pasa a `test/helpers/browser_history.dart` (`booking_edit_web_test` lo usa);
    - Suite completa, 1943 en verde.

## Bloque D — Margen, reglas y cierre

- [x] **T15. Margen de edición en los ajustes.** RF-36 a RF-41, RNF-1
  - Tests:
    - `test/features/booking/edit_margin_test.dart` (nuevo, tablas): `marginChoices` y `marginParts`;
    - `test/features/admin/admin_settings_margin_test.dart` (nuevo):
      - las opciones;
      - un valor que no está en la lista se muestra en horas y minutos;
      - al elegir otra opción se guarda solo el margen, con aviso;
      - si falla, vuelve al valor anterior;
      - "Guardar" del horario no escribe el margen ni `blockedDates`;
    - `booking_edit_margin_live_test` (nuevo): la clienta ve aparecer y desaparecer "Editar turno" al cambiar el margen.
  - Hecho cuando: `lib/features/booking/logic/edit_margin.dart`, la sección del margen de `AdminSettingsView` y `AdminController.updateEditMargin` cumplen el plan.
  - Hecha (2026-11-17):
    - `edit_margin.dart`: `editMarginOptions`, `marginChoices` y `marginParts` (12 tests de tabla);
    - `AdminSettingsView`: la sección "Margen de edición" va antes de los días, con su explicación y un desplegable. El título hace de nombre del campo para el lector de pantalla, sin repetirse a la vista. `marginLabel` da "Sin margen", "N horas" o "N h M min". Al elegir, guarda solo el margen y avisa; si falla, avisa y el desplegable vuelve al margen guardado (un contador rehace el campo tras cada guardado; el test de RF-39 falla sin él);
    - `AdminController.updateEditMargin`. "Guardar" del horario no cambió: ya no escribía el margen ni `blockedDates`, y ahora lo prueba un test;
    - `booking_edit_margin_live_test` (Android/iOS y Web): el margen que guarda la admin llega a la clienta por el repositorio. Pasó sin cambios, como preveía el plan (RF-40 ya se cumplía);
    - 7 textos nuevos (ES y PT), como en el plan § 6;
    - Suite completa, 1965 en verde.

- [x] **T16. Reglas de Firestore.** RF-42, RF-43, RF-44, RNF-5
  - Tests: `test/core/firestore_rules_test.dart` amplía la estructura con `closures`, la edición de la admin en `appointments` y `busySlots`, y el margen en `settings/calendar`.
  - `specs/008-agenda-admin/rules-check.md` (nuevo) recoge:
    - los casos del simulador de cierres, de la edición de la admin y del margen;
    - un margen `double` guardado a mano que no impide guardar el horario;
    - los casos de las specs 005 a 007 que tocan estas reglas;
    - los pasos en la app.
  - Hecho cuando: `firestore.rules` tiene los cambios del plan § 2 y el autor los comprueba en el simulador.
  - Hecha (2026-11-17); el autor comprobó las reglas en el simulador (2026-11-17):
    - `firestore.rules`: colección `closures`; la edición de la admin en `appointments`; la admin crea y cambia el turno ocupado de cualquier turno con sus mismas horas; `settings/calendar` separa `create`/`update`/`delete` y valida el margen con `validEditMargin()` (en `update`, solo si cambia, D-7);
    - cambio deliberado respecto a la 007: la admin puede crear el turno ocupado de un turno que no marcó (caso 15 de su `rules-check.md`, ahora permitido), por el `set` de la edición (D-8);
    - `firestore_rules_test`: 9 tests nuevos o cambiados (31 en total). El de la 007 "la clienta no toca la marca" mira ahora solo la parte de la clienta;
    - `rules-check.md`: 39 casos del simulador, el margen `double` guardado a mano, los casos de las specs 006 y 007 y los pasos en la app;
    - no se pudieron compilar las reglas en local: el emulador pide Java 21 y la máquina tiene 17;
    - Suite completa, 1972 en verde.

- [x] **T17. Accesibilidad y cierre.** RNF-2, RNF-3
  - Tests: `test/features/admin/admin_agenda_accessibility_test.dart` (nuevo). Cubre la lista de cierres, el formulario y sus choques, la agenda con cierres, la edición de la admin con su diálogo y el margen:
    - contraste en tema claro y oscuro;
    - objetivos de 48 px;
    - semántica;
    - texto al 200 % en 320 px, en ES y PT.

    Además, todas las claves nuevas en ES y PT.
  - Hecho cuando:
    - los tests pasan;
    - `CLAUDE.md` describe los cierres, la edición de la admin y el margen;
    - `MEMORY.md` está al día;
    - el recorrido manual de los criterios de finalización queda para el autor.
  - Hecha (2026-11-17):
    - `admin_agenda_accessibility_test` (28 tests): contraste, 48 px y nombres en los dos temas, en la lista de cierres, el formulario con errores y con choques, la agenda con un cierre y "Editar", la edición, su diálogo y el margen; lector de pantalla; 200 % en 320 px en ES y PT. `booking_texts_test` comprueba las claves del plan § 6 y las añadidas, en ES y PT;
    - arreglos que pidieron los tests:
      - "Quitar" de cada cierre dice qué cierre quita (`closureDeleteFor`);
      - en la cabecera de la agenda, "Clientes" y "Horarios" pasan de iconos de 22 px sin nombre a `IconButton` con nombre, y las flechas de día, de 40 px sin nombre a 48 px con "Día anterior"/"Día siguiente";
      - en los ajustes, el ✓ de guardar el horario tiene nombre ("Guardar"), y la fila de cada día pasa a `Wrap` con su semántica unida (al 200 % en 320 px se desbordaba);
    - 3 claves nuevas (ES y PT): `closureDeleteFor`, `adminAgendaPreviousDay`, `adminAgendaNextDay`;
    - `CLAUDE.md` describe los cierres, la edición de la admin, el margen, las rutas y las reglas; `MEMORY.md`, al día;
    - Suite completa, 2001 en verde. Quedan para el autor la T16 en el simulador y el recorrido manual (`/sdd-validate`).

## Validación (2026-11-17)
- Tests que faltaban: RF-20 (la edición usa la ventana de 365 días y guarda un día a más de 60) y RF-23/RF-24 en pantalla (cambiar a otra clienta con el buscador, a una persona sin cuenta, y la casilla ya marcada al corregir el nombre de un turno sin cuenta), en `admin_edit_view_test`.
- Fallo del recorrido (paso 4): al editar un turno que choca con un cierre, se volvía al panel en lugar de al cierre (spec, Navegación). En Web, la edición iba a `/admin`; en Android/iOS volvía al cierre, pero la lista de choques seguía mostrando el turno ya movido. Arreglo:
  - en Web, `/admin` → `closures` → `new` → `appointments/:id/edit` son rutas anidadas y se abren con `go` (`openAdminPage`); `closeAdminEdit` vuelve al cierre si la dirección está debajo de él; las direcciones no cambian;
  - al terminar una edición, el formulario vuelve a pedir los choques (`ClosureController.conflicts`);
  - tests: `closure_conflict_edit_test` (guardar, cancelar y "atrás" del navegador, en Android/iOS y Web) y la redirección acepta la dirección nueva.
- Ajustes del horario (visto en Web): "CERRADO" quedaba pegado al nombre del día, porque el `Wrap` de la T17 se encogía al ancho de su contenido. Ahora `_DayHeader` pone el día a la izquierda y "Cerrado" con su interruptor al extremo derecho; si no caben (texto al 200 % en 320 px), bajan a otra línea, también a la derecha. Tests en `admin_settings_view_test`.
- Suite completa: 2015 en verde.
- Recorrido manual aprobado por el autor (2026-11-17): spec implementada.

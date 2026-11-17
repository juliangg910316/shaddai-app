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

- [ ] **T3. Datos de los cierres y del calendario.** RF-8, RF-41, RNF-4
  - Tests:
    - `closure_model_test` (nuevo): `fromMap` con datos buenos, sin campo y con el fin no posterior al inicio; `toMap` solo con `start` y `end`;
    - `calendar_settings_model_test`: `toMap` sin `blockedDates`, y la lectura de documentos con `blockedDates` igual que antes;
    - `test/helpers/fake_config.dart` (nuevo o ampliado): cierres en vivo (`emitClosures`), `fetchClosures`, `created`/`deleted`, `removedBlockedDates`, `margin`, `saveError`.
  - Hecho cuando:
    - existe `ClosureModel`;
    - `ConfigRepository` tiene `watchClosures`, `fetchClosures`, `createClosure`, `deleteClosure`, `removeBlockedDate` y `updateEditMargin` (plan § 3);
    - `toMap` ya no escribe `blockedDates`;
    - el fake está listo.

- [ ] **T4. La reserva no ofrece las horas de un cierre.** RF-12 a RF-17
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

## Bloque B — Cierres de la admin y agenda

- [ ] **T5. Guardar y quitar cierres.** RF-3 a RF-8, RF-11
  - Tests: `test/features/admin/admin_closures_provider_test.dart` (nuevo):
    - `save`: con errores no lee ni guarda; con turnos que chocan los devuelve sin guardar; sin choques guarda inicio y fin; si falla devuelve `failed`;
    - la lectura de los turnos activos es del servidor, justo antes de guardar;
    - `delete`: borra un cierre o quita una fecha bloqueada; si falla, lo indica.
  - Hecho cuando:
    - existen `ClosureController`, `adminClosureEntriesProvider` y `adminDayClosuresProvider`;
    - existe `BookingRepository.fetchActiveAppointments`, también en el fake.

- [ ] **T6. Pantalla de cierres.** RF-1, RF-2, RF-7, RF-8, RF-10
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

- [ ] **T7. Nuevo cierre y turnos que chocan.** RF-3 a RF-6, RF-11
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

- [ ] **T8. La agenda muestra los cierres y "Editar".** RF-9, RF-10, RF-18
  - Tests, en `admin_appointments_booked_test`:
    - los cierres del día salen entre los turnos, en orden de hora, con "CERRADO";
    - un cierre de varios días sale en cada uno;
    - si fallan los cierres: aviso y "Reintentar";
    - "Editar" solo aparece en los turnos esperando confirmación o confirmados que no han terminado: también en uno en curso, nunca en uno cancelado ni en uno terminado.
  - Hecho cuando: la agenda usa `adminDayClosuresProvider` y `_AppointmentCard` tiene "Editar", que lleva a `/admin/appointments/<id>/edit`.

## Bloque C — La admin edita un turno

- [ ] **T9. Lógica pura de la edición de la admin.** RF-20 a RF-26, RF-29 a RF-31, RNF-1
  - Tests: `test/features/booking/admin_edit_test.dart` (nuevo, tablas):
    - `recipientOf`: cuenta, y sin cuenta con la casilla marcada;
    - `personChanged`: otra clienta, de cuenta a sin cuenta, nombre con espacios, WhatsApp con otro formato;
    - `adminEditChanges`: sin cambios, solo la persona, la hora y el servicio;
    - `markAfterEdit`;
    - `checkAdminEditBeforeSave` en cada resultado y en su orden, sin margen de edición;
    - `editFreeSlots(allowStarted: true)` con un turno en curso, y `false` igual que antes.

    `EditOriginal.of` copia la persona y la marca.
  - Hecho cuando: `logic/admin_edit.dart` y los cambios de `booking_edit.dart` cumplen el plan § 4.3 y § 4.4.

- [ ] **T10. Datos de la edición de la admin.** RF-28, RF-30, RF-31
  - Tests: el fake de turnos implementa `watchAppointment` (`emitAppointment`), `fetchAdminEditCheck` y `updateAppointmentByAdmin`, que respeta `expected` y registra lo guardado. También hay tests del fake: no guarda si `expected` falla y conserva los campos que no se envían.
  - Hecho cuando: `BookingRepository` tiene `watchAppointment`, `fetchAdminEditCheck` y `updateAppointmentByAdmin`: la transacción de plan § 2, con el turno ocupado escrito con `set`.

- [ ] **T11. Abrir y cerrar la edición sin perder la reserva a medias.** RF-19, RF-23, RF-24, RF-25, RF-33, RF-35
  - Tests: `test/features/booking/admin_edit_provider_test.dart` (nuevo):
    - `start` guarda aparte la selección y "Para quién", y carga la persona, el día, la hora y lo reservado;
    - `end` los devuelve, y `reconcile` los ajusta;
    - el turno en edición no cuenta como turno activo de la persona;
    - `_checkEdit` no cierra la edición de la admin;
    - una clienta bloqueada se quita con su aviso.
  - Hecho cuando: existe `AdminEditController` con `start`/`end`, y `recipientActiveAppointmentProvider` y `BookingSelectionController` están ajustados (plan § 5).

- [ ] **T12. Guardar la edición de la admin.** RF-26, RF-28 a RF-31, RF-34
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

- [ ] **T13. La vista de edición.** RF-19, RF-22, RF-27, RF-28, RF-34, RF-35
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

- [ ] **T14. Flujos completos de la edición.** RF-32, RF-33, RF-35
  - Tests:
    - `test/features/admin/admin_edit_flow_test.dart` (nuevo, `pumpMobileApp` y `pumpWebApp`):
      - en Android/iOS la pestaña Reservas sigue montada y conserva lo que la admin tenía a medio agendar;
      - en Web la edición tiene su dirección, y atrás del navegador sale sin guardar;
      - después, Reservar muestra lo que tenía;
    - `test/features/booking/admin_edited_client_test.dart` (nuevo): la clienta ve el cambio sin recargar en Reservas y en Perfil; si cambia la persona, la clienta anterior deja de verlo y la nueva lo ve.
  - Hecho cuando: los dos tests pasan sin cambios fuera de lo que piden.

## Bloque D — Margen, reglas y cierre

- [ ] **T15. Margen de edición en los ajustes.** RF-36 a RF-41, RNF-1
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

- [ ] **T16. Reglas de Firestore.** RF-42, RF-43, RF-44, RNF-5
  - Tests: `test/core/firestore_rules_test.dart` amplía la estructura con `closures`, la edición de la admin en `appointments` y `busySlots`, y el margen en `settings/calendar`.
  - `specs/008-agenda-admin/rules-check.md` (nuevo) recoge:
    - los casos del simulador de cierres, de la edición de la admin y del margen;
    - un margen `double` guardado a mano que no impide guardar el horario;
    - los casos de las specs 005 a 007 que tocan estas reglas;
    - los pasos en la app.
  - Hecho cuando: `firestore.rules` tiene los cambios del plan § 2 y el autor los comprueba en el simulador.

- [ ] **T17. Accesibilidad y cierre.** RNF-2, RNF-3
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

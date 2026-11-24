# Tareas 012 — Reglas del servidor para los turnos
Estado: aprobada

Spec: `specs/012-reglas/spec.md` · Plan: `specs/012-reglas/plan.md` (aprobados el 2026-11-23).

Cada tarea: tests primero (rojo), luego el código (verde). En Flutter: `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde; tras cambiar un `.arb`, `flutter gen-l10n`. En `functions/`: `npm test` en verde y `npm run build` sin errores. Nunca Firebase real en los tests.

- [x] **T1. Casos compartidos y reglas de horas en TypeScript** (`test/fixtures/agenda_rules_cases.json`, `functions/src/agenda_rules.ts`, plan § 3 compartido, § 4, D-4). RF-1, RF-2, RF-4, RF-9, RF-10, RF-15, RNF-2
  - Tests:
    - `test/features/booking/agenda_rules_cases_test.dart` pasa los casos por las funciones de Dart que ya existen (`checkSlot`, `editFreeSlots` y `fits`, con `bookingWindow`), así que se pone en verde en cuanto los casos están bien escritos;
    - `functions/test/agenda_rules_cases.test.ts` pasa los mismos casos por `agenda_rules.ts` (rojo hasta que exista);
    - `functions/test/agenda_rules.test.ts` prueba `salonDay`, `weekdayKey`, `dayGrid`, `overlaps` (un turno que empieza justo al terminar otro no se solapa) y la ventana con «ahora» en otro día UTC.
  - Los casos cubren:
    - hora libre, ocupada, en un cierre y en una fecha bloqueada;
    - día cerrado, fuera de la rejilla, después del cierre y antes de «ahora»;
    - día 60 y 61 para la clienta, y día 365 y 366 para la admin;
    - cobertura justa y corta;
    - los turnos cancelados y los terminados no cuentan;
    - en una edición: mismo inicio fuera del horario nuevo, fin ampliado sobre otro turno y otro inicio sin contar el propio turno.
  - Hecho cuando: los casos dan el mismo veredicto en Dart y en TypeScript, `agenda_rules.ts` no importa Firebase y `npm run build` compila.

- [x] **T2. Persona activa y lo reservado en TypeScript** (`agenda_rules.ts`, `functions/src/booked_catalog.ts`, plan D-5). RF-6, RF-7, RF-11 a RF-13
  - Tests:
    - en `agenda_rules.test.ts`, `normalizeWhatsApp` y `activeAppointmentOfPerson`:
      - la misma persona por `clientId` o por WhatsApp normalizado;
      - no cuentan los cancelados, los terminados ni el turno que se edita;
      - los mismos números que `whatsapp_test.dart`, copiados en los casos compartidos;
    - en `functions/test/booked_catalog.test.ts`, `checkBooked`:
      - un servicio con adicionales y un combo;
      - un adicional de otra categoría, un combo con adicionales, y un servicio, combo o adicional no disponible → `item_unavailable`;
      - otro nombre, precio, «desde» o duración → `item_changed`;
      - el resumen igual al que guarda la app (`snapshotOf`);
    - `bookedKey` estable aunque cambie el orden de las claves.
  - Hecho cuando: los tests pasan sin Firebase y la lista de precios se lee con la forma de `settings/priceList`.

- [x] **T3. Reservar en el servidor** (`functions/src/agenda_write.ts`: `bookAppointment`, `AgendaError`, interfaz `AgendaStore`, plan § 4). RF-1, RF-3, RF-4, RF-6, RF-8 a RF-12
  - Tests: `functions/test/agenda_write.test.ts`, con un almacén en memoria que aplica las transacciones de una en una y reintenta si el candado cambió.
    - **Como clienta:**
      - guarda a su nombre, esperando confirmación, con nombre, WhatsApp y foto de su ficha, el fin calculado y su turno ocupado;
      - bloqueada → `blocked`; con un turno activo → `already_active`.
    - **Como admin:**
      - guarda confirmado y marcado para una clienta o para una persona sin cuenta;
      - persona activa (por cuenta o por WhatsApp) → `person_active`; destinataria bloqueada → `recipient_blocked`;
      - para sí misma o para otra admin → `invalid`.
    - **Rechazos de horas y de lo reservado:** `slot_taken`, `closed`, `outside_hours`, `outside_window`, `past`, `does_not_fit`, `item_unavailable` e `item_changed`.
    - **Sin ficha o con un id ya usado:** `permission-denied` e `invalid`.
    - **Dos reservas a la vez:** de la misma hora, o de la misma clienta en días distintos → se guarda una y la otra recibe `slot_taken` o `already_active` (RF-3, RF-8).
  - Hecho cuando: los tests pasan y lo escrito tiene la forma de `AppointmentModel.toMap` (lo comprueba un test con un turno de ejemplo).

- [x] **T4. Editar y cerrar en el servidor** (`agenda_write.ts`: `editAppointment` y `saveClosure`, plan § 4). RF-2, RF-5, RF-7, RF-13 a RF-15
  - Tests: en `agenda_write.test.ts`.
    - **Edición de la clienta:**
      - vuelve a esperar confirmación;
      - otro dueño, bloqueada o dentro del margen → `not_editable`;
      - cancelado o terminado → `not_active`;
      - distinto de lo esperado → `changed`.
    - **Edición de la admin:**
      - queda confirmada y la marca se conserva o se pone;
      - otra persona activa → `person_active`; destinataria bloqueada → `recipient_blocked`.
    - **Turnos existentes:**
      - sin cambiar lo reservado, se conserva la copia aunque cambie la lista (RF-13);
      - la misma hora fuera del horario nuevo → `ok`; la misma hora bajo un cierre nuevo → `slot_taken` (RF-15, como la app);
      - fin ampliado sobre otro turno → `does_not_fit`;
      - otra hora ocupada → `slot_taken`.
    - **Cierre:**
      - solo la admin;
      - fin antes del inicio, en el pasado o demasiado lejos → `invalid`;
      - con turnos activos encima → `conflicts` con sus ids;
      - un cierre y una reserva a la vez en la misma hora → se guarda solo uno (RF-5).
  - Hecho cuando: los tests pasan; la edición solo escribe los campos que cambian, igual que las transacciones de hoy.

- [x] **T5. Adaptador, almacén y callables** (`agenda_handler.ts`, `agenda_store.ts`, `index.ts`, `README.md`, plan § 2, § 6, D-3). RF-16, RF-17, RNF-4
  - Tests: `functions/test/agenda_handler.test.ts`.
    - El uid sale de la sesión, nunca de los datos. Sin sesión → `unauthenticated`.
    - Datos con otra forma (sin `start`, con un tipo equivocado o con campos de más) → `invalid-argument`.
    - Cada `AgendaError` → `failed-precondition` con `details.reason` (y `ids` en `conflicts`).
    - Otro error → `internal`, sin detalles, y queda en el registro.
    - Los detalles nunca llevan nombres, WhatsApp ni lo reservado de otra persona.
  - Hecho cuando:
    - `index.ts` exporta `bookAppointment`, `editAppointment` y `saveClosure` en `southamerica-east1`;
    - `agenda_store.ts` hace la transacción sobre `locks/agenda` con las lecturas de § 2 (`endTime >= now` y `end >= now`, sin índices nuevos);
    - `README.md` describe las funciones y el orden de despliegue (funciones → app → reglas);
    - `npm test` y `npm run build` pasan.

- [x] **T6. App: llamar a las funciones** (`lib/data/repositories/agenda_functions.dart`, `agendaFunctionsProvider`, el fake en `test/helpers/`, plan § 3 data). RF-16, RF-17
  - Tests: `test/data/agenda_functions_test.dart`, con un `FirebaseFunctions` falso como en `account_repository_test.dart`:
    - llama a la función correcta, en `southamerica-east1`, con los datos esperados (fechas en texto ISO 8601 en UTC, como las acepta el servidor; decidido por el autor el 2026-11-23; servicio, adicionales, lo reservado, lo esperado y la persona);
    - cada `details.reason` se traduce a su `AgendaRejection` (con `conflictIds` en un cierre);
    - un código desconocido, sin conexión o con otra forma → `failed`; si tarda demasiado → `TimeoutException`.
  - Hecho cuando: `FakeAgendaFunctions` (`test/helpers/fake_agenda.dart`) guarda en la `FakeBookingRepository` lo que la función escribiría y puede responder con un rechazo; `pumpApp`, `pumpWebApp` y `pumpMobileApp` la inyectan por defecto; todos los tests existentes siguen en verde.

- [ ] **T7. La clienta reserva y edita por la función** (`booking_provider.dart`, `booking_edit_provider.dart`, `.arb`, plan § 6, § 7). RF-1, RF-2, RF-12, RF-16, RF-17, RF-19
  - Tests:
    - `BookingSubmitter` y `BookingEditor` con la función falsa:
      - la comprobación previa no cambia;
      - tras ella, llaman a la función en lugar de escribir;
      - cada motivo → su resultado: `slot_taken` y los de horas → `slotTaken` quitando la hora; `does_not_fit`; `already_active`; `item_unavailable` e `item_changed` (resultados nuevos); `not_active`, `changed` y `not_editable` en la edición; el resto → `failed` conservando lo elegido;
    - en la vista de reserva y en la de edición, el aviso de cada resultado, en ES y PT, y la elección intacta.
  - Hecho cuando: `bookingItemChangedOnSave` está en `app_es.arb` (con descripción) y en `app_pt.arb`, `flutter gen-l10n` está ejecutado, `BookingRepository` ya no tiene `createAppointment` ni `updateEditedAppointment`, y todo está en verde.

- [ ] **T8. La admin agenda, edita y cierra por la función** (`admin_booking_provider.dart`, `admin_edit_provider.dart`, `admin_closures_provider.dart`, `config_repository.dart`). RF-1, RF-2, RF-5 a RF-7, RF-16 a RF-19
  - Tests: con la función falsa.
    - `AdminBookingSubmitter` y `AdminEditController`, cada motivo → su resultado:
      - `person_active`, que vuelve a leer el turno para el texto de siempre;
      - `recipient_blocked`, `slot_taken`, `does_not_fit`, `item_changed`, `not_active`, `changed` y `failed`.
      - Al guardar, se vacían la selección y la persona, como hoy.
    - `ClosureController.save`: `conflicts` → vuelve a leer y devuelve `ClosureSaveConflicts`; el formulario los muestra con «Editar» y «Cancelar» (RF-18).
  - Hecho cuando: `updateAppointmentByAdmin` y `createClosure` ya no existen, las suites de las specs 007, 008 y 010 siguen en verde, y todo está en verde.

- [ ] **T9. Reglas de Firestore y comprobación manual** (`firestore.rules`, `test/core/firestore_rules_test.dart`, `specs/012-reglas/rules-check.md`, plan § 5, D-7). RF-1, RF-2, RF-4, RF-5, RF-14, RNF-3, RNF-5
  - Tests: en `firestore_rules_test.dart`.
    - `appointments`:
      - `allow create: if false`;
      - sin las ramas de edición de la 006 ni de la 008;
      - la admin solo cambia `status` desde un estado activo.
    - `busySlots`: `create` y `update` en `false`, y `delete` como hoy.
    - `closures`: `create` en `false`.
    - La cabecera cita la spec 012 y su `rules-check.md`.
  - Hecho cuando: `rules-check.md` tiene:
    - el orden de despliegue;
    - los casos del simulador: crear o editar un turno, crear un turno ocupado o un cierre → denegado; confirmar uno cancelado → denegado; confirmar, cancelar, cancelar de la clienta, copiar el WhatsApp y borrar un cierre → permitidos;
    - el recorrido real: dos dispositivos con la misma hora, cierre contra reserva, la misma clienta en dos dispositivos, el turno de un horario anterior, tiempos de guardado (RNF-1, D-8), tema claro y oscuro, ES/PT, Android, iOS y Web;
    - la sección «Resultado» para el autor.
  - Todo en verde.

- [ ] **T10. Documentos** (`CLAUDE.md`, `docs/ESPECIFICACION.md`, `MEMORY.md`). RF-19
  - Tests: ninguno nuevo; las suites completas de Flutter y `functions/` en verde.
  - Hecho cuando:
    - `CLAUDE.md` explica que turnos y cierres se escriben solo por las tres callables (con su candado y los casos compartidos), qué sigue escribiendo la app, las reglas nuevas y el fake de los tests;
    - `docs/ESPECIFICACION.md` tiene la 012 al día en el mapa y en «Fuera de alcance» o pendientes;
    - `MEMORY.md` tiene el estado y las lecciones;
    - `dart format`, `flutter analyze`, `flutter test`, `npm test` y `npm run build` pasan.

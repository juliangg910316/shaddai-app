# Tareas 010 — Panel de administración
Estado: aprobada

Spec: `specs/010-admin/spec.md` · Plan: `specs/010-admin/plan.md` (aprobados el 2026-11-19).

Cada tarea: tests primero (rojo), luego el código (verde); `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde. Tras cambiar un `.arb`, `flutter gen-l10n`. Nunca Firebase real en los tests.

- [x] **T1. Lógica pura de la agenda** (`admin/logic/admin_agenda.dart`, plan § 4). RF-1 a RF-11, RF-15
  - Tests: `test/features/admin/admin_agenda_logic_test.dart`:
    - `agendaDay`, `agendaToday`, `agendaRange` (también con `TZ=Asia/Tokyo`);
    - `agendaPickerBounds` y `agendaPickerInitial` (dentro, antes y después de los límites);
    - `agendaCounts` sin cancelados;
    - `agendaActions`: activo, en curso, justo en el fin, pasado esperando o confirmado, y cancelado;
    - `checkAdminCancelBeforeSave`: ok, solo confirmado → ok, cancelado/terminado/borrado → notActive, otra hora o servicio → changed, dentro del margen → ok;
    - `checkAdminConfirmBeforeSave`.
  - Hecho cuando: el archivo no importa Flutter ni Firebase y sus tests pasan, también con `TZ=Asia/Tokyo`.

- [x] **T2. Lógica pura de las clientas** (`admin/logic/admin_clients.dart`, plan § 4). RF-19, RF-20, RF-26, RF-28
  - Tests: `test/features/admin/admin_clients_logic_test.dart`:
    - `clientsForAdmin` sin admins, ordenada sin mayúsculas ni acentos, con empates estables;
    - `clientActiveAppointment` solo por `clientId`: un turno sin cuenta con su WhatsApp no cuenta, y uno terminado o cancelado tampoco;
    - `checkBlockBeforeSave` en sus cinco casos.
  - Hecho cuando: sin imports de Flutter ni Firebase y los tests pasan.

- [x] **T3. Repositorios y fakes** (plan § 5 y § 10). RF-1, RF-11, RF-14, RF-17, RF-27, RF-30
  - **`BookingRepository`:** añade `watchAppointmentsBetween`, `cancelByAdmin` y `confirmByAdmin` (transacciones con `saveTimeout`).
  - **`UserRepository`:** añade `blockClient` (transacción: ficha + turno + turno ocupado) y `unblockClient`.
  - **Se eliminan** `getAppointmentsForDate`, `updateAppointmentStatus` y `toggleBlockUser`. Mientras llegan T6, T7 y T9, sus llamadas se cambian a los métodos nuevos sin cambiar el comportamiento:
    - el día de la agenda usa el rango local del día;
    - los botones Cancelar y Confirmar, sin comprobar nada;
    - el interruptor de bloqueo usa `blockClient` sin turno, o `unblockClient`.
  - **Fakes:** `FakeBookingRepository` y `FakeUserRepository` con lo del plan § 10 (errores, *gates* y registros).
  - Tests: `test/features/admin/admin_repositories_fake_test.dart`, sobre los fakes:
    - `expected` decide si se guarda;
    - bloquear cancela el turno y lo saca de los activos;
    - los errores no cambian nada.
    
    Además, los tests existentes de la agenda, los cierres y las clientas, adaptados a los métodos nuevos sin cambiar lo que comprueban.
  - Hecho cuando: nadie usa los tres métodos eliminados y toda la suite está en verde.

- [x] **T4. Día del salón, "Hoy" y calendario en la agenda** (plan D-1, D-10, § 6 y § 7). RF-1 a RF-5
  - Tests: `test/features/admin/admin_agenda_day_test.dart`:
    - con "ahora" fijo y el dispositivo en otra zona, abre en hoy del salón y pide el rango del salón;
    - "Hoy" solo fuera de hoy, y vuelve a hoy;
    - la fecha es un botón que abre el calendario en el día o en el límite, entre −365 y +365, y elegir cambia el día;
    - "<" y ">" funcionan sin límite;
    - textos en ES y PT;
    - la edición de la 008 sigue abriendo la agenda en el día del turno.
  - Hecho cuando:
    - `adminSelectedDateProvider` es el día del salón;
    - existen `adminTodayProvider` y `adminAppointmentsProvider` con `agendaRange`;
    - `admin_edit_view` guarda el día como día del salón;
    - las claves `adminAgendaToday` y `adminAgendaPickDate` están en los dos `.arb`;
    - los tests pasan.

- [x] **T5. Cabecera: contadores y contraste** (plan D-8, D-9). RF-6, RNF-1
  - Tests: en `admin_agenda_day_test.dart`:
    - los contadores no cuentan los cancelados;
    - "TURNOS DEL DÍA" / "HORÁRIOS DO DIA".
    
    En `test/features/admin/admin_accessibility_test.dart` (nuevo): la cabecera pasa `textContrastGuideline` en claro y oscuro (hoy falla).
  - Hecho cuando:
    - la cabecera usa `agendaCounts` y `onBrand`;
    - el texto de `adminStatAppointmentsToday` está cambiado;
    - el pendiente de contraste de `MEMORY.md` queda cerrado;
    - los tests pasan.

- [x] **T6. Acciones de la tarjeta y confirmar** (plan D-4, § 6 y § 7). RF-7 a RF-11, RF-16, RF-17, RF-37
  - Tests: `test/features/admin/admin_agenda_actions_test.dart`:
    - botones según el turno: activo, esperando, en curso, pasado o cancelado;
    - "SIN CONFIRMAR" en los pasados nunca confirmados;
    - al avanzar `salonNowProvider` más allá del fin, los botones desaparecen;
    - confirmar sin diálogo; mientras guarda, el botón está desactivado y un segundo toque no repite;
    - si el turno ya no está activo o falla el guardado, sale un aviso sin detalles del error;
    - WhatsApp y las marcas siguen en todos los casos.
  - Hecho cuando:
    - existe `AdminAppointmentActions.confirm` y la tarjeta usa `agendaActions`;
    - las claves `adminAppointmentUnconfirmed` y `adminConfirmFailed` están en los dos `.arb`;
    - los tests pasan.

- [ ] **T7. Diálogo de cancelar de la admin, en la agenda y en los cierres** (plan D-2, D-3). RF-12 a RF-18
  - Tests: `test/features/admin/admin_cancel_dialog_test.dart`:
    - muestra la persona, la fecha, las horas del salón y el servicio;
    - "No, mantener" y cerrar el diálogo no cambian nada;
    - "Sí, cancelar" cancela y avisa "Turno cancelado.";
    - cada resultado da su aviso: ya no está activo, cambió o falló (sin detalles, y se puede reintentar);
    - mientras guarda, todo está desactivado y no se repite la cancelación;
    - cambia de idioma con el diálogo abierto;
    - desde los choques de un cierre: el turno sale de la lista en `ok` y en `notActive`.
  - Hecho cuando:
    - existe `AdminAppointmentActions.cancel`;
    - `admin_cancel_dialog.dart` está en uso en la agenda y en `admin_closure_form_view`;
    - las claves `adminCancelDone` y `adminCancelChanged` están en los dos `.arb`, y las tres del diálogo antiguo eliminadas;
    - los tests de la 008 siguen en verde.

- [ ] **T8. Lista de clientas** (plan § 6 y § 7). RF-19 a RF-24, RF-33
  - Tests: `test/features/admin/admin_clients_view_test.dart`:
    - sin admins y en orden;
    - avatar, nombre, WhatsApp o correo, y estado;
    - el botón de WhatsApp solo con número, y abre el enlace (`RecordingLinkLauncher`);
    - si falla la carga, sale "Reintentar" y vuelve a cargar;
    - la lista cambia en vivo;
    - la fila se lee como una frase;
    - el interruptor no cambia al tocarlo: abre el diálogo de T9 (aquí, que se abre).
  - Hecho cuando:
    - existe `adminClientsProvider`;
    - `AdminUsersView` está rehecha, con el interruptor controlado;
    - la clave `adminBlockSwitch` está en los dos `.arb`;
    - los tests pasan.

- [ ] **T9. Bloquear y desbloquear** (plan D-5, D-6, D-7). RF-25 a RF-34
  - Tests: `test/features/admin/client_block_dialog_test.dart`:
    - bloquear sin turno activo: el diálogo no menciona turnos;
    - bloquear con turno: muestra fecha, horas y servicio, y el turno aparece o cambia en vivo;
    - confirmar bloquea y cancela a la vez;
    - si el turno cambió, no bloquea y avisa; al reabrir, sale el turno actual;
    - si falla, avisa y no cambia nada;
    - volver o cerrar el diálogo no cambia nada;
    - desbloquear funciona, y su fallo avisa;
    - mientras guarda, todo está desactivado;
    - el interruptor solo cambia cuando llega la ficha nueva;
    - los avisos con el nombre.
  - Hecho cuando:
    - existen `clientActiveAppointmentProvider`, `ClientBlocker` y `client_block_dialog.dart`;
    - las claves de bloquear y desbloquear del plan § 8 están en los dos `.arb`;
    - los tests pasan.

- [ ] **T10. Accesibilidad, reglas y cierre** (plan § 3 y § 10). RNF-1 a RNF-5, RF-35, RF-36, RF-38, RC-1
  - Tests:
    - **`admin_accessibility_test.dart`**, en claro y oscuro: contraste, áreas táctiles y nombres en la agenda, la lista y los tres diálogos (`expectDialogTextContrast`);
    - en el mismo archivo, la semántica de "Hoy", la fecha, el interruptor y la fila, y que nada se desborde al 200 % en 320 px, en ES y PT;
    - **`admin_texts_test.dart`:** las claves del plan § 8 están en los dos `.arb` y las eliminadas no.
  - Hecho cuando:
    - existe `specs/010-admin/rules-check.md`, con los casos del simulador y el recorrido en la app;
    - `CLAUDE.md` y `docs/ESPECIFICACION.md` describen el panel de la 010;
    - `MEMORY.md` está al día;
    - toda la suite está en verde, con `flutter analyze` limpio.

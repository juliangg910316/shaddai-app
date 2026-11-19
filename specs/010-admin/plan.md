# Plan 010 — Panel de administración
Estado: aprobada

Spec: `specs/010-admin/spec.md` (aprobada el 2026-11-19).

## 1. Qué existe ya

| Parte | Estado en el código | RF |
| --- | --- | --- |
| Agenda por día con cabecera verde, "<" / ">", contadores, turnos y cierres ordenados por hora | `AdminDashboardView`, `_AdminHeader`, `_StatTile`, `_AppointmentCard`, `_ClosureCard` (`admin_dashboard_view.dart`) | RF-5, RF-37 |
| Día de la agenda | `adminSelectedDateProvider` (`admin_provider.dart`) empieza en `DateTime.now()` (fecha **del dispositivo**). `adminAppointmentsProvider` → `BookingRepository.getAppointmentsForDate`, que corta en la medianoche **local**. Los cierres ya toman año/mes/día como día del salón (`_agendaDay`) | RF-1, RF-2 (mal fuera de −03:00) |
| Horas de cada turno en hora del salón | `toSalon` en `_AppointmentCard` | RF-1 |
| Contadores | Total = todos los turnos del día, **cancelados incluidos**; texto "TURNOS HOY" también en otros días | RF-6 (corregir) |
| "Editar" solo en turnos activos sin terminar | `editable` en `_AppointmentCard`, con `salonNowProvider` (cada 30 s) | RF-7, RF-10 (solo "Editar") |
| "Cancelar" y "Confirmar" | Al primer toque, sin diálogo ni aviso de error, **también en turnos pasados**. `AdminController.updateAppointmentStatus` → lote estado + borrado del turno ocupado | RF-11 a RF-18 (faltan casi todos), RF-8 |
| Cancelar desde los choques de un cierre (spec 008) | `admin_closure_form_view.dart`: diálogo propio (nombre y "La hora quedará libre."), aviso si falla, sin releer el turno | — (se unifica, D-3) |
| Marcas y WhatsApp en la agenda | `_AppointmentCard`: "Sin cuenta", "Cuenta eliminada", "Agendado por la admin", "Cancelado por la clienta"; `whatsAppLink` + `externalLinkLauncherProvider` | RF-37 |
| Lista de clientas | `AdminUsersView` sobre `adminUsersProvider` (`getAllUsers`, **todas las fichas, sin orden**, admins incluidas); error sin "Reintentar"; `Switch` que bloquea al momento (`toggleBlockUser`), sin confirmar ni aviso | RF-19 a RF-34 (faltan casi todos), RF-21 (ya) |
| Comparar nombres sin acentos | `foldText` (`booking/logic/recipient.dart`, spec 007) | RF-20 |
| Turno activo de una persona | `activeAppointment` (`booking_rules.dart`), `adminActiveAppointmentsProvider` (turnos sin terminar, en vivo) y `BookingRepository.fetchActiveAppointments` (del servidor) | RF-26 a RF-28 |
| Patrón "releer y cancelar" | `cancelByClient` (transacción) y `checkCancelBeforeSave` / `EditOriginal` (spec 009) | RF-14, RF-15 |
| Avisos anunciados | `showBookingMessage` (`booking_notices.dart`): `SnackBar` + `SemanticsService.sendAnnouncement` | RNF-4 |
| Reglas | La admin ya puede: cambiar solo `status` de un turno, borrar `busySlots`, actualizar `users` (incluido `isBlocked`); una clienta no puede tocar `role` ni `isBlocked` | RF-35 (ya; se comprueba a mano) |
| Contraste de la cabecera | "PANEL DE BEIDIS" (11 px, w300) y los nombres de los contadores (10 px, w300) en `onBrandMuted`: fallan `textContrastGuideline` (pendiente en MEMORY) | RNF-1 |
| Entrada al panel | Perfil → `push('/admin')` (móvil); `AccountButton` → `go('/admin')` (Web) | Plataformas |

## 2. Decisiones

- **D-1. El día de la agenda es un día del salón.** `adminSelectedDateProvider` guarda una fecha "de pared" del salón (`DateTime.utc(a, m, d)`), empieza en `salonDay(toSalon(clock()))` y la agenda pide los turnos de `fromSalon(día)` a `fromSalon(día + 1)`. Quien escriba una fecha local (los tests actuales, la edición de la 008) sigue funcionando porque todo pasa por `agendaDay` (año, mes y día). RF-1, RF-2. *Descartado:* dejar la fecha local y convertir al mostrar (el corte de medianoche seguiría siendo el del dispositivo).
- **D-2. La admin cancela en una transacción** (`cancelByAdmin`) que relee el turno y solo lo cancela si sigue activo, sin terminar y con el mismo inicio, fin y lo reservado; escribe solo `status: 'cancelled'` (sin `cancelledBy`: "cancelado por el salón", spec 009 D-1) y borra su turno ocupado. El estado no cuenta como cambio (si otro dispositivo solo lo confirmó, se cancela igual: caso límite). El margen no cuenta. RF-14, RF-15. *Descartado:* el lote actual sin releer (cancelaría un turno que la clienta acaba de mover).
- **D-3. Un solo diálogo de cancelar de la admin**, para la agenda y para los choques de un cierre (spec 008). El de los cierres no mostraba el turno ni releía; así los dos se comportan igual y desaparecen tres textos. *Descartado:* dejar dos diálogos (dos comportamientos para la misma acción).
- **D-4. Confirmar también relee** (`confirmByAdmin`, transacción): solo confirma si el turno sigue esperando confirmación y sin terminar. Sin diálogo (RF-11). Si ya no lo está, avisa "Este turno ya no está activo.". Motivo: la regla de la admin deja cambiar `status` de un turno cancelado, y confirmar a ciegas reactivaría un turno cancelado por la clienta sin su turno ocupado (dos personas en la misma hora). *Descartado:* el `update` actual.
- **D-5. Bloquear: comprobar en el servidor y guardar en una transacción.**
  1. Se lee del servidor el turno activo de la clienta (`fetchActiveAppointments` filtrado por `clientId`), se compara con el que mostró el diálogo (`checkBlockBeforeSave`: ninguno y ninguno, o el mismo id, inicio, fin y lo reservado). Si no coincide, no se bloquea (RF-28).
  2. La transacción relee ese turno (si hay) y, si sigue igual, escribe `isBlocked: true` en la ficha, `status: 'cancelled'` en el turno y borra su turno ocupado (RF-27).
  
  Riesgo aceptado: si la clienta reserva otro turno entre el paso 1 y el 2 (milisegundos), ese turno nuevo no se cancela; queda en la agenda y la admin lo cancela a mano. Una transacción de Firestore en el cliente no puede hacer consultas, solo leer documentos. *Descartado:* una Cloud Function (más infraestructura para un caso casi imposible).
- **D-6. Solo cuentan los turnos de su cuenta** (`clientId`), no los que llevan su WhatsApp: un turno de una persona sin cuenta con el mismo número no es suyo (caso límite de la spec). Por eso no se usa `activeAppointmentOfPerson` (que también mira el WhatsApp).
- **D-7. El interruptor de bloqueo se queda, controlado.** Su valor es siempre el de la ficha; tocarlo abre el diálogo y solo cambia cuando llega la ficha nueva. El progreso (RF-32) se muestra en el diálogo, que no se cierra hasta terminar, como el de cancelar de la spec 009. *Descartado:* botones "Bloquear"/"Desbloquear" (más espacio por fila sin ganar nada).
- **D-8. Contadores sin cancelados y texto "TURNOS DEL DÍA"** (se cambia el valor de `adminStatAppointmentsToday`, que mentía en otros días). RF-6.
- **D-9. La cabecera verde usa `onBrand`** (no `onBrandMuted`) para el subtítulo y los nombres de los contadores, a 11 px y w400. El tono más suave se pierde, pero `onBrandMuted` no llega a AA en esos tamaños y RNF-1 lo exige. *Descartado:* oscurecer el verde (cambia la marca en toda la app).
- **D-10. El calendario es el `showDatePicker` de Material**, con las traducciones de Flutter en ES/PT (RC-1), entre hoy − 365 y hoy + 365 días del salón. Si el día mostrado está fuera (se llegó con las flechas), abre en el límite más cercano. Sin dependencias nuevas.

## 3. Datos (Firestore)

- **Sin colecciones ni campos nuevos.** Se escriben los mismos campos que hoy (`status`, `isBlocked`, borrar `busySlots/{id}`), ahora en transacciones.
- **`firestore.rules`: sin cambios.** Ya permiten a la admin todo lo de esta spec y ya impiden a la clienta tocar `isBlocked` y los turnos ajenos (RF-35). Se comprueba a mano en `specs/010-admin/rules-check.md` (nuevo): la admin bloquea con turno activo en el simulador (ficha + turno + turno ocupado), una clienta no puede bloquearse ni desbloquearse, ni cancelar o confirmar un turno ajeno, ni borrar un turno ocupado ajeno; y el recorrido en la app.
- **Índices:** ninguno. Los turnos del día filtran un solo campo (`startTime`) y los activos, otro (`endTime`).
- **Compatibilidad:** los documentos existentes se leen igual; los turnos sin `booked` se comparan con `booked == null` (como en la 009).

## 4. Lógica pura (sin Flutter ni Firebase, "ahora" como parámetro)

Archivo nuevo `lib/features/admin/logic/admin_agenda.dart` (RF-1 a RF-10, RF-15):

```
agendaDay(fecha) = DateTime.utc(fecha.year, fecha.month, fecha.day)
agendaToday(ahoraSalon) = salonDay(ahoraSalon)
agendaRange(día) = (desde: fromSalon(día), hasta: fromSalon(día + 1 día))
agendaPickerBounds(hoy) = (primero: hoy − 365 días, último: hoy + 365 días)
agendaPickerInitial(día, límites) = día acotado a [primero, último]

agendaCounts(turnos) =
  sinCancelar = turnos donde status != 'cancelled'
  (total: sinCancelar.length, esperando: sinCancelar donde status == 'waiting_confirmation')

enum AgendaActions { none, active, pastUnconfirmed }
agendaActions(status, fin, ahoraSalon) =
  si status == 'cancelled' → none
  si toSalon(fin) <= ahoraSalon → (status == 'waiting_confirmation' ? pastUnconfirmed : none)
  si no → active            // "Editar", "Cancelar" y, si espera, "Confirmar"

enum AdminCancelCheck { ok, notActive, changed }
checkAdminCancelBeforeSave(mostrado: EditOriginal, actual: Turno?, ahoraSalon) =
  si actual == null, o su estado no es activo, o toSalon(actual.fin) <= ahoraSalon → notActive
  si inicio, fin o reservado de actual != mostrado → changed
  → ok                      // el estado no cuenta; el margen tampoco

checkAdminConfirmBeforeSave(actual, ahoraSalon) =
  actual != null && actual.status == 'waiting_confirmation' && toSalon(actual.fin) > ahoraSalon
```

Archivo nuevo `lib/features/admin/logic/admin_clients.dart` (RF-19, RF-20, RF-26, RF-28):

```
clientsForAdmin(fichas) =
  fichas donde role == 'cliente',
  ordenadas por foldText(nombre) y, si empatan, por nombre (y por uid, para un orden estable)

clientActiveAppointment(turnos, uid, ahora) =
  activeAppointment(turnos donde clientId == uid, ahora)     // D-6

enum BlockCheck { ok, changed }
checkBlockBeforeSave(mostrado: Turno?, actual: Turno?) =
  ambos null → ok
  uno null → changed
  distinto id, inicio, fin o reservado → changed
  → ok
```

## 5. Capa de datos (`lib/data/`)

`BookingRepository`:
- `watchAppointmentsBetween(desde, hasta)` **sustituye** a `getAppointmentsForDate(fecha)` (D-1): la misma consulta por `startTime` con instantes. RF-1.
- `cancelByAdmin({id, expected})`: transacción como `cancelByClient`, sin `cancelledBy`, con `saveTimeout`. RF-14, RF-15, RF-17.
- `confirmByAdmin({id, expected})`: transacción que solo cambia `status` a `confirmed`, con `saveTimeout`. RF-11, RF-17 (D-4).
- `updateAppointmentStatus` se elimina: ya no lo usa nadie.

`UserRepository`:
- `blockClient({uid, appointmentId?, expected})`: transacción; si hay `appointmentId`, relee el turno y aplica `expected`; escribe `isBlocked: true`, y si hay turno, `status: 'cancelled'` y borra `busySlots/{id}`. Devuelve si guardó. Con `saveTimeout`. RF-27, RF-28.
- `unblockClient(uid)`: `update({'isBlocked': false})` con `saveTimeout`. RF-30.
- `toggleBlockUser` se elimina.

## 6. Providers y controladores (`lib/features/admin/providers/`)

- `admin_provider.dart`:
  - `adminSelectedDateProvider` empieza en `agendaToday(...)` con `clockProvider` (D-1).
  - `adminTodayProvider`: el día de hoy del salón con `salonNowProvider.select(salonDay)`: cambia solo a medianoche. Decide "Hoy" (RF-3).
  - `adminAppointmentsProvider` usa `agendaRange(agendaDay(fecha))`.
  - `adminClientsProvider`: `adminUsersProvider` con `clientsForAdmin`; con error, el error manda (MEMORY).
  - `AdminController` se queda con `updateSettings` y `updateEditMargin`.
- `admin_appointment_actions_provider.dart` (nuevo): `AdminAppointmentActions` (`adminAppointmentActionsProvider`) con:
  - `cancel(mostrado) → AdminCancelOutcome { ok, notActive, changed, failed }` (RF-14, RF-15, RF-17);
  - `confirm(id) → AdminConfirmOutcome { ok, notActive, failed }` (RF-11, RF-17).
  
  Como el `AppointmentCanceller` de la 009: errores y tiempo de espera → `failed`, con el detalle en `debugPrint`.
- `admin_clients_provider.dart` (nuevo):
  - `clientActiveAppointmentProvider.family(uid)`: el turno activo de esa clienta con `adminActiveAppointmentsProvider` y `salonNowProvider` (RF-26; en vivo mientras el diálogo está abierto).
  - `ClientBlocker` (`clientBlockerProvider`): `block(uid, mostrado) → BlockOutcome { ok, changed, failed }` (D-5) y `unblock(uid) → UnblockOutcome { ok, failed }`. RF-27, RF-28, RF-30, RF-34.

## 7. Interfaz

Igual en Android/iOS y Web (spec, Plataformas): las mismas vistas en el panel (`push('/admin')` desde Perfil en móvil; `/admin` como página de cuenta en Web). **Sin rutas nuevas ni cambios de guardas**: los diálogos no tienen dirección.

### Cabecera de la agenda (RF-2 a RF-6, RNF-1 a RNF-3)
- La fecha se convierte en un botón (`Semantics` de botón con su nombre, ≥ 48 px) que abre `showDatePicker` con `agendaPickerBounds` y `agendaPickerInitial`. Al elegir, cambia `adminSelectedDateProvider`.
- Se añade un botón "Hoy" (contorno sobre el verde, ≥ 48 px), solo si el día mostrado no es hoy (`adminTodayProvider`).
- Se mantienen "<" y ">" sin límites (RF-5).
- Los contadores usan `agendaCounts` (D-8).
- El subtítulo y los nombres de los contadores pasan a `onBrand` (D-9).
- Con el texto al 200 % en 320 px, la fecha baja de línea y "Hoy" va en su propia fila si no cabe (`Wrap`).

### Tarjeta de turno (RF-7 a RF-11, RF-16 a RF-18, RF-37)
- `agendaActions` decide los botones, con "ahora" de `salonNowProvider` (cada 30 s: RF-10). `none` quita la fila de botones. `pastUnconfirmed` sustituye la etiqueta de estado por "SIN CONFIRMAR". El botón de WhatsApp sigue siempre.
- "Confirmar" pasa a ser un widget con estado: mientras guarda, muestra un indicador y queda desactivado (RF-16). Al terminar, se muestra un aviso con `showBookingMessage`: solo para `notActive` y `failed`. El éxito se ve en la propia tarjeta.
- "Cancelar" abre el diálogo de cancelar de la admin.

### Diálogo de cancelar de la admin (`admin_cancel_dialog.dart`, nuevo; RF-12 a RF-18, D-3)
- **Contenido:** título "¿Cancelar el turno de {name}?", con la fecha larga, las horas del salón y lo reservado (`bookedLabel`). Botones "No, mantener" y "Sí, cancelar".
- **Mientras guarda:** indicador, los dos botones desactivados y sin cerrar al tocar fuera.
- **Resultado:** se cierra y se avisa con `showBookingMessage`: "Turno cancelado." en éxito; "Este turno ya no está activo." / "El turno cambió. Revísalo antes de cancelarlo." / "No se pudo cancelar el turno. Inténtalo de nuevo." en error.
- **Textos:** se leen dentro del `builder`, así que cambian de idioma con el diálogo abierto (RC-1).
- **Desde el formulario de cierres:** lo usa en lugar de su diálogo propio y quita el turno de los choques en `ok` y en `notActive`.

### Lista de clientas (`AdminUsersView`; RF-19 a RF-24, RF-33)
- `adminClientsProvider`. Error: texto de la app y "Reintentar" (invalida `adminUsersProvider`). Vacía: el texto de siempre.
- **Cada fila:** avatar, nombre, WhatsApp (o correo si no tiene), estado "ACTIVA"/"BLOQUEADA", el botón de WhatsApp (solo si tiene, `adminAppointmentWhatsApp(name)` como nombre) y el interruptor controlado (D-7), con el nombre "Bloquear a {name}" y su estado activado o no.
- **Lector de pantalla:** la fila se lee como una frase, con `Semantics(container: true)` y nombre, WhatsApp y estado (RNF-2).
- **Al 200 % en 320 px:** el WhatsApp y el interruptor bajan bajo el texto si no caben.

### Diálogos de bloquear y desbloquear (`client_block_dialog.dart`, nuevo; RF-25 a RF-34)
- **Bloquear:**
  - título "¿Bloquear a {name}?";
  - "No podrá iniciar sesión ni reservar.";
  - si tiene un turno activo (`clientActiveAppointmentProvider`, en vivo): "Su turno se cancelará:", con la fecha, las horas del salón y lo reservado;
  - botones "No, volver" y "Sí, bloquear".
- **Desbloquear:** título "¿Desbloquear a {name}?", "Podrá volver a iniciar sesión y reservar.", botones "No, volver" y "Sí, desbloquear".
- **Mientras guarda y resultado:** como en el de cancelar. Avisos:
  - "{name} está bloqueada." / "{name} está desbloqueada.";
  - "Su turno cambió. Revísalo antes de bloquearla." (RF-28: el diálogo se cierra y, al volver a abrirlo, muestra el turno de ahora);
  - "No se pudo bloquear. Inténtalo de nuevo." / "No se pudo desbloquear. Inténtalo de nuevo.".

## 8. Textos nuevos (`app_es.arb` / `app_pt.arb`)

| Clave | ES | PT |
| --- | --- | --- |
| `adminAgendaToday` | Hoy | Hoje |
| `adminAgendaPickDate` | Elegir fecha | Escolher data |
| `adminAppointmentUnconfirmed` | Sin confirmar | Não confirmado |
| `adminCancelDone` | Turno cancelado. | Horário cancelado. |
| `adminCancelChanged` | El turno cambió. Revísalo antes de cancelarlo. | O horário mudou. Confira antes de cancelar. |
| `adminConfirmFailed` | No se pudo confirmar. Inténtalo de nuevo. | Não foi possível confirmar. Tente novamente. |
| `adminBlockTitle` | ¿Bloquear a {name}? | Bloquear {name}? |
| `adminBlockBody` | No podrá iniciar sesión ni reservar. | Não poderá entrar nem agendar. |
| `adminBlockCancelsAppointment` | Su turno se cancelará: | O horário dela será cancelado: |
| `adminBlockConfirm` | Sí, bloquear | Sim, bloquear |
| `adminUnblockTitle` | ¿Desbloquear a {name}? | Desbloquear {name}? |
| `adminUnblockBody` | Podrá volver a iniciar sesión y reservar. | Poderá voltar a entrar e agendar. |
| `adminUnblockConfirm` | Sí, desbloquear | Sim, desbloquear |
| `adminDialogBack` | No, volver | Não, voltar |
| `adminBlockDone` | {name} está bloqueada. | {name} está bloqueada. |
| `adminUnblockDone` | {name} está desbloqueada. | {name} está desbloqueada. |
| `adminBlockChanged` | Su turno cambió. Revísalo antes de bloquearla. | O horário dela mudou. Confira antes de bloquear. |
| `adminBlockFailed` | No se pudo bloquear. Inténtalo de nuevo. | Não foi possível bloquear. Tente novamente. |
| `adminUnblockFailed` | No se pudo desbloquear. Inténtalo de nuevo. | Não foi possível desbloquear. Tente novamente. |
| `adminBlockSwitch` | Bloquear a {name} | Bloquear {name} |

- **Cambian:** `adminStatAppointmentsToday` pasa a "TURNOS DEL DÍA" / "HORÁRIOS DO DIA" (D-8).
- **Se reutilizan:**
  - `adminCancelAppointmentTitle`, `adminCancelAppointmentError`;
  - `cancelConfirm`, `cancelKeep`, `cancelNotActive`;
  - `bookingRetry`, `adminClientsLoadError`, `adminAppointmentWhatsApp`, `bookingTimeRange`.
- **Se eliminan** (D-3): `adminCancelAppointmentBody`, `adminCancelAppointmentKeep`, `adminCancelAppointmentConfirm`.

## 9. Archivos

| Archivo | Cambio | RF |
| --- | --- | --- |
| `lib/features/admin/logic/admin_agenda.dart` | Nuevo: día, rango, límites del calendario, contadores, acciones, comprobaciones de cancelar y confirmar | RF-1 a RF-11, RF-15 |
| `lib/features/admin/logic/admin_clients.dart` | Nuevo: lista de clientas, su turno activo, comprobación del bloqueo | RF-19, RF-20, RF-26, RF-28 |
| `lib/data/repositories/booking_repository.dart` | `watchAppointmentsBetween`, `cancelByAdmin`, `confirmByAdmin`; fuera `getAppointmentsForDate` y `updateAppointmentStatus` | RF-1, RF-11, RF-14, RF-17 |
| `lib/data/repositories/user_repository.dart` | `blockClient`, `unblockClient`; fuera `toggleBlockUser` | RF-27, RF-30 |
| `lib/features/admin/providers/admin_provider.dart` | Día del salón, `adminTodayProvider`, `adminClientsProvider`; `AdminController` reducido | RF-1 a RF-3, RF-19 |
| `lib/features/admin/providers/admin_appointment_actions_provider.dart` | Nuevo: cancelar y confirmar | RF-11, RF-14 a RF-17 |
| `lib/features/admin/providers/admin_clients_provider.dart` | Nuevo: turno activo de una clienta, bloquear y desbloquear | RF-26 a RF-34 |
| `lib/features/admin/presentation/admin_dashboard_view.dart` | Cabecera ("Hoy", fecha, contadores, contraste) y tarjeta (acciones, "Sin confirmar", confirmar con estado) | RF-2 a RF-11, RF-16 |
| `lib/features/admin/presentation/admin_cancel_dialog.dart` | Nuevo: el diálogo de cancelar de la admin | RF-12 a RF-18 |
| `lib/features/admin/presentation/admin_closure_form_view.dart` | Usa el diálogo nuevo (D-3) | RF-12 a RF-17 |
| `lib/features/admin/presentation/admin_edit_view.dart` | Guarda el día como `DateTime.utc` (D-1) | RF-1 |
| `lib/features/admin/presentation/admin_users_view.dart` | Lista nueva, "Reintentar", WhatsApp, interruptor controlado, semántica | RF-19 a RF-24, RF-33 |
| `lib/features/admin/presentation/client_block_dialog.dart` | Nuevo: diálogos de bloquear y desbloquear | RF-25 a RF-34 |
| `lib/l10n/app_es.arb`, `app_pt.arb` (+ generados) | § 8 | RC-1 |
| `test/helpers/fake_booking.dart`, `fake_auth.dart` | Los métodos nuevos (ver § 10) | — |
| `specs/010-admin/rules-check.md` | Nuevo: comprobación manual de las reglas | RF-35 |
| `CLAUDE.md`, `docs/ESPECIFICACION.md`, `MEMORY.md` | Al cerrar: el panel de la 010 | — |

## 10. Tests (primero, en rojo)

**Fakes (sin Firebase):**
- `FakeBookingRepository`:
  - `watchAppointmentsBetween` (registra los rangos pedidos y emite con `emitDay`);
  - `cancelByAdmin` / `confirmByAdmin` como la transacción: aplican `expected` al turno de ese id, lanzan `adminCancelError` / `confirmError` y esperan `adminCancelGate`. Registran en `adminCancelled` / `confirmed`.
- `FakeUserRepository`: `blockClient` (aplica `expected`, registra en `blocks`, lanza `blockError`, espera `blockGate`, y actualiza la ficha en `users` y el turno en el fake de reservas que se le pase) y `unblockClient` (igual con `unblocks`/`unblockError`).

| Test | Qué cubre | RF |
| --- | --- | --- |
| `test/features/admin/admin_agenda_logic_test.dart` | `agendaDay`, `agendaRange` (con `TZ=Asia/Tokyo` y `Europe/Lisbon` también), hoy, límites e inicial del calendario, `agendaCounts`, `agendaActions` (activo, en curso, justo en el fin, pasado esperando/confirmado, cancelado), `checkAdminCancelBeforeSave` (ok, solo confirmado → ok, cancelado/terminado/borrado → notActive, otra hora/servicio → changed), `checkAdminConfirmBeforeSave` | RF-1 a RF-11, RF-15 |
| `test/features/admin/admin_clients_logic_test.dart` | Sin admins, orden sin mayúsculas ni acentos ("Álvarez" junto a "alvarez"), empates; turno activo solo por `clientId` (uno de invitada con su WhatsApp no cuenta); `checkBlockBeforeSave` en sus cinco casos | RF-19, RF-20, RF-26, RF-28 |
| `test/features/admin/admin_agenda_day_test.dart` | Abre en hoy del salón con el dispositivo en otra zona ("ahora" fijo); pide el rango del salón; "Hoy" solo fuera de hoy y vuelve; el calendario abre en el día (o en el límite), sus límites ±365 y elegir cambia el día; "<"/">" sin límite; contadores sin cancelados; textos ES/PT | RF-1 a RF-6 |
| `test/features/admin/admin_agenda_actions_test.dart` | Botones de activo / esperando / pasado / cancelado; "SIN CONFIRMAR"; al pasar el fin desaparecen (avanzando `salonNowProvider`); confirmar inmediato, en curso desactivado, `notActive` y fallo con aviso sin detalles; WhatsApp siempre | RF-7 a RF-11, RF-16, RF-17, RF-37 |
| `test/features/admin/admin_cancel_dialog_test.dart` | El diálogo muestra persona, fecha, horas del salón y servicio; "No, mantener" y cerrar no cambian nada; "Sí, cancelar" cancela y avisa; `notActive`, `changed`, fallo (sin detalles, se puede reintentar); en curso desactivado y un segundo toque no repite; cambio de idioma con el diálogo abierto; desde los choques de un cierre | RF-12 a RF-18, D-3 |
| `test/features/admin/admin_clients_view_test.dart` | Sin admins y en orden; WhatsApp solo con número y abre el enlace (`RecordingLinkLauncher`); correo si no hay número; error con "Reintentar"; la lista cambia en vivo (registro, bloqueo, borrado) | RF-19 a RF-24 |
| `test/features/admin/client_block_dialog_test.dart` | Bloquear sin turno (sin mención) y con turno (fecha, horas, servicio); el turno aparece o cambia en vivo con el diálogo abierto; confirmar bloquea y cancela a la vez; `changed` no bloquea; fallo; volver/cerrar sin cambios; desbloquear y su fallo; en curso desactivado; el interruptor no cambia hasta llegar la ficha; avisos | RF-25 a RF-34 |
| `test/features/admin/admin_accessibility_test.dart` | Claro y oscuro: `textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline` en la agenda (con la cabecera: cierra el pendiente), la lista y los tres diálogos (`expectDialogTextContrast`); semántica de "Hoy", la fecha, el interruptor y la fila; al 200 % en 320 px sin desbordes (ES y PT) | RNF-1 a RNF-4 |
| `test/core/firestore_rules_test.dart` | La cabecera de las reglas no cambia (sin reglas nuevas): ningún test nuevo | RF-35 |
| `test/features/admin/admin_texts_test.dart` | Las claves de § 8 en los dos `.arb`, no vacías, y las eliminadas fuera | RC-1 |

Se actualizan los tests que usan `getAppointmentsForDate`, `updateAppointmentStatus`, `toggleBlockUser` o el diálogo de cancelar de los cierres (`closure_conflict_edit_test`, `admin_closures_view_test`, `screens_theme_test`, `error_messages_test`, los de la agenda), sin cambiar lo que comprueban.

RF-35 se comprueba a mano (`rules-check.md`), como en las specs 005 a 009. RF-36 y RF-38: los tests existentes de las specs 004, 007 y 008 siguen en verde.

## 11. Tamaño

Unas 10 tareas: lógica de la agenda; lógica de clientas; repositorios y fakes; día del salón, "Hoy" y calendario; cabecera (contadores y contraste); acciones de la tarjeta y confirmar; diálogo de cancelar (agenda y cierres); lista de clientas; bloquear y desbloquear; y el cierre (accesibilidad, `rules-check.md` y documentos). Cabe en una spec.

## 12. Dependencias

Ninguna nueva.

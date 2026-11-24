# Plan 012 — Reglas del servidor para los turnos
Estado: aprobada

Spec: `specs/012-reglas/spec.md` (aprobada el 2026-11-23).

## 1. Qué existe ya

- **Las reglas de la agenda, en la app**, como funciones puras de Dart. La spec 012 no cambia ninguna; solo las lleva al servidor:
  - `freeSlots`/`fits` (`booking/logic/free_slots.dart`);
  - `dayGrid`, `bookingWindow` y `isSelectableDay` (`booking_window.dart`);
  - `checkBeforeSave`/`checkSlot`/`activeAppointment` (`booking_rules.dart`);
  - `editFreeSlots` y `checkEditBeforeSave` (`booking_edit.dart`, con el día y la hora originales siempre válidos);
  - `checkAdminBeforeSave` (`admin_booking.dart`) y `checkAdminEditBeforeSave` (`admin_edit.dart`);
  - `closureErrors`/`closureConflicts`/`overlaps` (`closures.dart`);
  - `findBookable`, `availableAddons` y `snapshotOf` (`bookable_catalog.dart`);
  - `whatsapp.dart` (la persona por su WhatsApp).
- **Los guardados, en la app.** Cada guardado lee del servidor, comprueba y escribe:
  - `BookingSubmitter.confirm` (005) escribe un lote con el turno y su turno ocupado;
  - `BookingEditor.save` (006) y `AdminEditController.save` (008) usan una transacción que exige que el turno siga como se abrió;
  - `AdminBookingSubmitter.confirm` (007) escribe un lote;
  - `ClosureController.save` (008) busca los turnos que chocan con el cierre y lo crea.
- **Las reglas de Firestore** (specs 005 a 011) protegen quién escribe qué:
  - la dueña, el estado, la marca de la admin y el margen de edición;
  - las mismas horas en el turno y en su turno ocupado.
  - No pueden buscar otros turnos, así que no impiden solapes, un segundo turno activo, un turno en un cierre, un horario o una ventana equivocados, ni lo reservado falso.
- **Cloud Functions** (`functions/`, TypeScript, `southamerica-east1`, plan Blaze):
  - `deleteAccount`, una función que la app llama (callable), con su adaptador `handler.ts` y el almacén `admin_store.ts` sobre `firebase-admin`;
  - el disparador de la 011;
  - lógica pura probada con `node --test` y sin Firebase real.
- **En la app**, `cloud_functions` ya está aprobado (spec 009). `AccountRepository` es el patrón de llamada: errores `FirebaseFunctionsException` con su motivo en `details.reason`, y tests con un `FirebaseFunctions` falso.
- **Los avisos al guardar** ya existen en los `.arb`: `bookingSlotTaken`, `bookingSlotNoLongerFits`, `bookingAlreadyActive`, `bookingItemUnavailable`, `bookingRecipientActive`, `bookingEditNotActive`, `bookingEditChangedMeanwhile` y el error genérico de cada formulario.

**Lo que falta:**
- un escritor del servidor que vuelva a comprobar todo de forma atómica (RF-1 a RF-13);
- que las reglas impidan escribir turnos, turnos ocupados y cierres sin pasar por él;
- un aviso para «lo reservado cambió» (RF-12);
- una forma de comprobar que la app y el servidor aplican las mismas reglas (RNF-2).

## 2. Enfoque (D-1, **decisión del autor: cambio de arquitectura**)

Los turnos y los cierres pasan a escribirse **solo desde funciones del servidor**, que la app llama con `httpsCallable`:

| Función callable | La llaman | Sustituye a |
| --- | --- | --- |
| `bookAppointment` | La clienta (005) y la admin para otra persona (007) | `createAppointment` (lote) |
| `editAppointment` | La clienta (006) y la admin (008) | `updateEditedAppointment`, `updateAppointmentByAdmin` |
| `saveClosure` | La admin (008) | `createClosure` |

Cada función, en una **transacción** de `firebase-admin`:
1. Lee el candado de la agenda (§ 5, D-3).
2. Lee la ficha de quien llama.
3. Lee el calendario y la lista de precios.
4. Lee los turnos que aún no terminaron, los cierres y, si es una edición, el turno.
5. Aplica las reglas puras.
6. Si todo se cumple, escribe el turno y su turno ocupado, o el cierre.

Si algo falla, responde `failed-precondition` con el motivo en `details.reason` (§ 6).

**No pasan por funciones**:
- confirmar y cancelar de la admin, cancelar de la clienta, bloquear, copiar el WhatsApp, borrar un cierre y borrar la cuenta;
- **motivo:** no pueden crear solapes ni turnos activos. Siguen como hoy, con sus transacciones y reglas (RF-14, RF-19).
- Las reglas se endurecen para que confirmar no pueda **reactivar** un turno cancelado (§ 5): es la única forma de que un turno vuelva a ocupar una hora sin pasar por las funciones.

**La app no cambia su flujo.** Cada formulario sigue comprobando antes de llamar, con los mismos datos y la misma lógica que hoy, para avisar al momento y quitar la hora elegida. Después, en lugar de escribir, llama a la función. Un rechazo del servidor se traduce al mismo resultado que daría la comprobación de la app (RF-16).

## 3. Archivos

### Servidor (`functions/`): lógica pura, sin Firebase

| Archivo | Responsabilidad | RF |
| --- | --- | --- |
| `src/agenda_rules.ts` (nuevo) | Las reglas de la agenda, traducción directa de las funciones de Dart: <br>• `salonDay`/`toSalon`, con Curitiba = −3 h fijo, como `salon_time.dart`; <br>• `weekdayKey`; <br>• `dayGrid`; `bookingWindow(nowSalon, days)`; <br>• `freeSlots` con su cobertura, y `fits`; <br>• `overlaps`; <br>• `activeAppointmentOfPerson`, por `clientId` y por WhatsApp normalizado (`normalizeWhatsApp`, como `whatsapp.dart`); <br>• `checkSlotRules`, que decide si un rango cumple horario, ventana, cierres, fechas bloqueadas, solapes y cobertura, con «ahora» como parámetro; <br>• `editTimesRules`, con el día y la hora originales permitidos (RF-15) | RF-1, RF-2, RF-4, RF-6, RF-7, RF-9 a RF-11, RF-15 |
| `src/booked_catalog.ts` (nuevo) | `findBookable`, `availableAddons` y `snapshotOf` sobre la lista de precios tal como se guarda (`categories[].items[]`, `combos[]`). `checkBooked(list, ref, addonIds, sentSnapshot)` devuelve el resumen construido por el servidor, o `item_unavailable` o `item_changed`. `bookedKey` es igual que el de la 011, para saber si una edición cambia lo reservado (RF-13). | RF-11 a RF-13 |
| `src/agenda_write.ts` (nuevo) | Los casos de uso, sobre un `AgendaStore` (interfaz como `NoticeStore`): <br>• `bookAppointment(store, caller, request, now)`; <br>• `editAppointment(store, caller, request, now)`; <br>• `saveClosure(store, caller, request, now)`. <br>Deciden quién es la persona, quién puede escribir y con qué estado y marca: la clienta crea a su nombre y esperando confirmación; la admin, confirmado, marcado y para otra persona. También comprueban la clienta bloqueada, el margen de edición, que el turno «siga como se abrió» y lo que escriben. Lanzan `AgendaError(reason)`. | RF-1 a RF-15 |
| `src/agenda_handler.ts` (nuevo) | Adaptador callable → caso de uso, como `handler.ts`: <br>• toma el uid de la sesión, nunca de los datos; <br>• valida la forma de los datos; <br>• traduce `AgendaError` a `HttpsError('failed-precondition', reason, {reason, …})`; <br>• cualquier otro fallo lo deja en el registro y lo devuelve como `internal`, sin detalles. | RF-16, RF-17, RNF-4 |
| `src/agenda_store.ts` (nuevo) | El `AgendaStore` sobre `firebase-admin`. La transacción lee el candado `locks/agenda`, la ficha, `settings/calendar`, `settings/priceList`, `appointments` con `endTime >= now`, `closures` con `end >= now` y, si es una edición, el turno. Escribe el turno con su turno ocupado y el candado, o el cierre y el candado. | RF-3, RF-5, RF-8 |
| `src/index.ts` | Las tres callables, en `southamerica-east1`. | — |

### Servidor: tests

| Archivo | Qué prueba |
| --- | --- |
| `test/agenda_rules.test.ts`, `test/booked_catalog.test.ts`, `test/agenda_write.test.ts`, `test/agenda_handler.test.ts` | La lógica, con un almacén en memoria |

### Compartido (RNF-2, D-4)

| Archivo | Responsabilidad |
| --- | --- |
| `test/fixtures/agenda_rules_cases.json` (nuevo) | Casos de entrada y salida de las reglas: calendario, turnos, cierres, «ahora», inicio, duración, modo clienta o admin, original de la edición y el veredicto esperado. Los leen un test de Dart y uno de TypeScript, así que una diferencia entre la app y el servidor rompe uno de los dos. |
| `test/features/booking/agenda_rules_cases_test.dart` (nuevo) | Pasa los casos por las funciones puras de Dart que ya existen. |
| `functions/test/agenda_rules_cases.test.ts` (nuevo) | Pasa los mismos casos por `agenda_rules.ts`. |

### App: capa `data`

| Archivo | Responsabilidad | RF |
| --- | --- | --- |
| `lib/data/repositories/agenda_functions.dart` (nuevo) | `AgendaFunctions`, con `FirebaseFunctions` inyectable como `AccountRepository`. <br>• `book(...)`, `edit(...)` y `saveClosure(...)` devuelven `AgendaWriteResult`: `ok`, o el motivo del rechazo (`AgendaRejection`), con `conflictIds` para el cierre. <br>• Sin conexión o con un error desconocido, `failed`. <br>• Si no responde a tiempo, `TimeoutException`, como hoy. <br>No toca Firestore. | RF-16, RF-17 |
| `lib/data/repositories/booking_repository.dart` | Pierde `createAppointment`, `updateEditedAppointment` y `updateAppointmentByAdmin`, porque las reglas ya no los permiten. Las lecturas, confirmar y cancelar siguen igual. | — |
| `lib/data/repositories/config_repository.dart` | Pierde `createClosure`. | — |

### App: capa `features`

| Archivo | Responsabilidad | RF |
| --- | --- | --- |
| `booking/providers/agenda_functions_provider.dart` (nuevo) | `agendaFunctionsProvider` (un `Provider`, como los repositorios). | — |
| `booking/providers/booking_provider.dart` | `BookingSubmitter.confirm` llama a `book`. <br>• `slot_taken` y los motivos de horario → `slotTaken`, quitando la hora; `does_not_fit` → `doesNotFit`; <br>• `already_active` → `alreadyActive`; `item_unavailable` → resultado nuevo `itemUnavailable`; `item_changed` → `itemChanged`; <br>• el resto → `failed`. | RF-16, RF-17 |
| `booking/providers/booking_edit_provider.dart` | `BookingEditor.save` llama a `edit`, con el original como «lo esperado». Los motivos se traducen a `EditSaveOutcome`: `changed`, `notActive`, `notEditable`, `slotTaken`, `doesNotFit`, `failed`, más `itemUnavailable` e `itemChanged`. | RF-16 |
| `booking/providers/admin_booking_provider.dart` | `AdminBookingSubmitter.confirm` llama a `book` con la persona: `personActive`, `recipientBlocked`, `slotTaken`, `doesNotFit`, `itemChanged`… | RF-16 |
| `booking/providers/admin_edit_provider.dart` | `AdminEditController.save` llama a `edit`, como el anterior. | RF-16 |
| `admin/providers/admin_closures_provider.dart` | `ClosureController.save` llama a `saveClosure`. Con `conflicts`, vuelve a leer los turnos activos y devuelve `ClosureSaveConflicts`, que ya pinta el formulario con «Editar» y «Cancelar». | RF-18 |
| Vistas de reserva, edición y agenda | Pintan los dos resultados nuevos con avisos que ya existen y uno nuevo (§ 7). Nada más cambia. | RF-16 |

### Reglas y documentos

| Archivo | Cambio |
| --- | --- |
| `firestore.rules` | § 5 |
| `test/core/firestore_rules_test.dart` | La estructura de § 5 |
| `specs/012-reglas/rules-check.md` (nuevo) | Casos del simulador y recorrido real |
| `CLAUDE.md`, `docs/ESPECIFICACION.md`, `functions/README.md` | Al día con este cambio |

## 4. Lógica y algoritmo

Todas las funciones puras reciben `now` (el instante del servidor en la función; el del reloj inyectado en la app). Ninguna lee Firebase.

```
bookAppointment(store, callerUid, req{id, start, item{kind,id}, addonIds, booked, recipient?}, now):
  tx(store):
    lock = store.readLock()                         # serializa (D-3)
    caller = store.user(callerUid)                  # sin ficha → permission-denied
    settings, list = store.calendar(), store.priceList()
    active = store.appointmentsEndingFrom(now)      # estado y horas de todos los que no terminaron
    closures = store.closuresEndingFrom(now) + blockedDates(settings)
    if caller.role == 'admin':
       person = req.recipient                       # {clientId} o {name, phone}
       if person.clientId:
          r = store.user(person.clientId)
          if r == null or r.role != 'cliente': invalid
          if r.isBlocked: recipient_blocked
       if activeAppointmentOfPerson(active, person, now): person_active      # RF-6
       window = 365; status = 'confirmed'; mark = true
    else:
       if caller.isBlocked: blocked
       if activeAppointmentOfPerson(active, {clientId: callerUid}, now): already_active  # RF-6
       person = {clientId: callerUid, name, phone, photo: de la ficha}
       window = 60; status = 'waiting_confirmation'; mark = false
    snapshot = checkBooked(list, req.item, req.addonIds, req.booked)          # RF-12
    end = req.start + snapshot.durationMinutes                                # RF-11
    v = checkSlotRules(settings, busy = activos sin cancelar, closures,
                       start, duration, nowSalon, window)                     # RF-1, RF-4, RF-9, RF-10
    if v != ok: v                                   # slot_taken | does_not_fit | closed | outside_window | past | outside_hours
    if exists(appointments/req.id): invalid
    write appointments/req.id = {persona, start, end, status, createdAt: now,
                                 booked: snapshot, createdByAdmin: mark}
    write busySlots/req.id = {start, end}
    write lock = {updatedAt: now}                   # el conflicto de escritura hace atómico RF-3 y RF-8
```

```
editAppointment(store, callerUid, req{id, start, item, addonIds, booked, expected, recipient?}, now):
  tx:
    lock, caller, settings, list, active, closures como arriba
    current = store.appointment(req.id)
    if current == null or not active(current, now): not_active
    if differs(current, req.expected): changed                  # como hoy (006 D-5, 008)
    if caller is client:
       current.clientId == callerUid, not blocked, starts after now + margin     # si no, not_editable
       status = 'waiting_confirmation'
    else (admin):
       person = req.recipient ?? persona actual
       if person changed: recipient_blocked / person_active (sin contar este turno)  # RF-7
       status = 'confirmed'; mark = current.mark or person changed
    if bookedKey(req.booked) == bookedKey(current.booked) and same item and addons:
       snapshot = current.booked                     # RF-13: la copia se respeta
    else:
       snapshot = checkBooked(list, ...)             # RF-12
    end = start + snapshot.duration
    v = editTimesRules(original = {current.start, current.end}, new = {start, end},
                       busy sin este turno, closures, settings, nowSalon, window)   # RF-2, RF-15
    if v != ok: v
    update appointment (solo los campos que cambian) + set busySlots/id + lock
```

`editTimesRules`, la traducción exacta de `isEditDaySelectable` + `editFreeSlots` (RF-15, precisado el 2026-11-23):
- **El día original** se puede elegir siempre, aunque esté cerrado, bloqueado o fuera de la ventana.
- **La hora original** vale aunque esté fuera de la rejilla o del horario, si no ha empezado (la admin: si no ha terminado) y **ningún cierre ni otro turno la cubre**. Su cobertura llega hasta el siguiente turno o cierre, sin pasar del cierre del día o del fin original, lo que sea más tarde.
- **Otro inicio:** se comprueban todas las reglas, como un turno nuevo, sin contar el propio turno (RF-2).

Es exactamente lo que hace hoy `editFreeSlots`; los casos compartidos lo fijan (§ 3, compartido).

```
saveClosure(store, callerUid, req{start, end}, now):
  tx: lock; caller.role == 'admin' o permission-denied
      errors = closureErrors(range, nowSalon)        # fin después del inicio, no en el pasado, ventana
      if errors: invalid
      conflicts = closureConflicts(active, range)    # RF-5
      if conflicts: conflicts(ids)
      write closures/{auto} = {start, end} + lock
```

`activeAppointmentOfPerson`:
- Un turno es **activo** si su estado es `waiting_confirmation` o `confirmed` y `end > now`.
- La **persona** es la misma si coincide el `clientId`, o si la persona no tiene cuenta y su WhatsApp normalizado coincide (spec 007).

## 5. Firestore

**Colecciones y campos:** no cambian. Se añade un documento interno `locks/agenda` con `{updatedAt}`, que solo escriben las funciones (D-3). Los turnos, los turnos ocupados y los cierres se escriben con la misma forma que hoy (`toMap`), así que todo lo que ya se lee sigue igual: la app, la 011 y `deleteAccount`. Los documentos existentes no se tocan (RF-14).

**`firestore.rules`.** Es el cambio de comportamiento del servidor; la cabecera lo cita y apunta a `specs/012-reglas/rules-check.md`.

`appointments`:
- **`create`:** `if false`. Solo las funciones crean turnos (RF-1, RF-4, RF-6, RF-9 a RF-12).
- **`update`:** solo quedan estas ramas:
  - la admin cambia solo `status`, desde `waiting_confirmation` o `confirmed` a `confirmed` o `cancelled`. Un turno cancelado ya no se puede reactivar: era el único camino para ocupar una hora sin pasar por las funciones (RF-1, RF-14);
  - la clienta cancela su turno activo (009), igual que hoy;
  - la clienta copia su WhatsApp a su turno activo (009), igual que hoy.
  - Se quitan las ramas de edición de la clienta (006) y de la admin (008): ahora editan las funciones (RF-2).
- **`delete`:** `if false`, como hoy.

`busySlots`:
- **`create` y `update`:** `if false`.
- **`delete`:** igual que hoy. La clienta y la admin lo borran al cancelar, en el mismo lote.
- **`get` y `list`:** igual que hoy.

`closures`:
- **`create`:** `if false`, solo la función (RF-5).
- **`delete`:** solo la admin, igual que hoy.

`locks/{id}`: sin reglas, así que queda denegado (solo `firebase-admin`).

**Índices:** no hacen falta. Las consultas de la función filtran un solo campo: `endTime >= now` en `appointments` y `end >= now` en `closures`. Ya se usan en la app (`_endingFrom`, `fetchClosures`).

**Antes de publicar las reglas** hay que desplegar las funciones y la app nueva. Una app vieja dejaría de poder reservar y editar, y vería su error genérico. Como la app aún no está publicada (013), el orden basta: primero las funciones, después la app y por último las reglas (`rules-check.md`).

## 6. Motivos de rechazo (`details.reason`) y cómo los pinta la app (RF-16, RF-17, RF-18)

| Motivo | Cuándo | Clienta: reserva y edición | Admin: reserva y edición | Aviso (ya existe salvo ⭐) |
| --- | --- | --- | --- | --- |
| `slot_taken` | Solapa con otro turno (RF-1 a RF-3) | `slotTaken` y quita la hora | igual | `bookingSlotTaken` |
| `closed`, `outside_hours`, `outside_window`, `past` | Cierre o fecha bloqueada, fuera de horario o de rejilla, fuera de la ventana, ya pasó (RF-4, RF-9, RF-10) | `slotTaken`, igual que su comprobación previa (`checkSlot`) | igual | `bookingSlotTaken` |
| `does_not_fit` | El servicio no cabe hasta el siguiente turno o el cierre (RF-9, RF-11) | `doesNotFit` | igual | `bookingSlotNoLongerFits` |
| `already_active` | La clienta ya tiene un turno activo (RF-6, RF-8) | `alreadyActive` (la reserva le muestra el que tiene) | — | `bookingAlreadyActive` |
| `person_active` | La persona ya tiene un turno activo (RF-6, RF-7) | — | `personActive` | `bookingRecipientActive` (vuelve a leer el turno para el texto) |
| `recipient_blocked` | La clienta destinataria está bloqueada | — | `recipientBlocked` | El que ya existe |
| `item_unavailable` | El servicio, el combo o un adicional ya no existe o no está disponible (RF-12) | `itemUnavailable` | igual | `bookingItemUnavailable` |
| `item_changed` | Cambió el nombre, el precio o la duración en la lista (RF-12) | `itemChanged` | igual | ⭐ `bookingItemChangedOnSave` |
| `not_active`, `changed`, `not_editable` | La edición encontró el turno cancelado, cambiado o dentro del margen | Como hoy | Como hoy | Los de la 006 y la 008 |
| `blocked` | La clienta está bloqueada | `failed` (la vista ya le muestra el bloqueo, en vivo) | — | Error genérico |
| `conflicts` (+ `ids`) | El cierre pisa turnos activos (RF-5) | — | `ClosureSaveConflicts`, con los turnos releídos | La lista del formulario (008) |
| `invalid`, `internal`, sin conexión, tiempo agotado | Datos con otra forma, fallo del servidor (RF-17) | `failed` | `failed` | El error genérico de cada formulario |

**RNF-4:** los motivos no llevan datos de otras personas. `person_active` lo usa solo la admin, que vuelve a leer el turno con sus propios permisos para el texto. `conflicts` lleva ids que solo la admin puede leer.

## 7. Interfaz y textos

**Pantallas.** No hay pantallas, rutas ni guardas nuevas: Web y Android/iOS igual. La reserva, la edición, la reserva de la admin, la edición de la admin y el formulario del cierre siguen como están. Solo cambia de dónde viene el resultado del guardado.

**Providers.** Se añade `agendaFunctionsProvider`; los controladores son los mismos (§ 3).

**Mientras guarda.** Cada formulario ya muestra su indicador de guardado. El tiempo máximo pasa a ser el de la llamada: 15 s, como `saveTimeout` hoy. RNF-1 se mide en el recorrido real.

**Textos nuevos** (ES/PT, con su descripción en `app_es.arb`; RNF-5):

| Clave | ES | PT |
| --- | --- | --- |
| `bookingItemChangedOnSave` | «El servicio cambió de nombre, precio o duración. Revisa el resumen y vuelve a confirmar.» | «O serviço mudou de nome, preço ou duração. Revise o resumo e confirme novamente.» |

`itemUnavailable` reutiliza `bookingItemUnavailable`. Con `itemChanged`, la vista ya muestra la lista de precios nueva en vivo, así que el resumen enseña el precio actual.

## 8. Decisiones

| # | Decisión | Por qué | Descartado |
| --- | --- | --- | --- |
| D-1 | **Escribir turnos y cierres solo desde callables con transacción** (decisión del autor: cambio de arquitectura) | Es la única forma de cumplir RF-1 a RF-12. Las reglas de Firestore no pueden consultar otros turnos ni recorrer la lista de precios. | **Solo reglas, con documentos de «hueco ocupado» por paso de la rejilla y de «turno activo» por persona.** Cubriría los solapes y el turno activo, pero no lo reservado (RF-12), la ventana ni el horario por día de la semana. Además, liberar el «turno activo» al pasar la hora exige escrituras que nadie hace. **Un disparador que deshace lo que no cumple:** el turno existiría un momento, y la clienta y la 011 lo verían. |
| D-2 | Confirmar, cancelar, bloquear, copiar el WhatsApp, borrar cierres y borrar la cuenta **no** pasan por funciones | No crean solapes ni turnos activos. Así no se tocan flujos ya validados, que siguen sin la espera de una función (RF-14, RF-19). | Todo por funciones: más cambio y más espera sin ganar seguridad. |
| D-3 | **Un único candado `locks/agenda`** que leen y escriben todas las transacciones | Dos escrituras simultáneas chocan en el candado y una se reintenta y ve la otra: RF-3, RF-5 y RF-8 sin depender de cómo bloquea Firestore las consultas. Un salón hace muy pocas reservas por minuto, lejos del límite de un documento (~1 escritura/s sostenida). | **Un candado por día:** no cubre el turno activo de la misma persona en días distintos (RF-8). **Fiarse del aislamiento de las consultas en la transacción:** correcto en teoría, pero más difícil de razonar y de probar. |
| D-4 | **Dos implementaciones (Dart y TypeScript) con un fichero de casos compartido** | La app debe seguir avisando al momento y quitar la hora sin llamar al servidor, y las funciones son TypeScript. Los casos compartidos hacen verificable RNF-2. | **Una sola implementación en el servidor**, con la app sin comprobar: la app ya no podría marcar horas libres ni coberturas (005). **Compartir código Dart en el servidor:** no hay entorno de funciones Dart en Firebase. |
| D-5 | El servidor **construye** la copia de lo reservado desde la lista y la **compara** con la que envía la app | La copia guardada siempre es la de la lista (RF-12). Si la que mostraba la app no coincide, el aviso es concreto (`item_changed`) en lugar de guardar un precio que la clienta no vio. | Guardar la copia de la app tras validarla: obliga a comparar igual y deja dos fuentes. Construirla sin comparar: guardaría un precio que la clienta no vio. |
| D-6 | La persona y sus datos (nombre, WhatsApp, foto) salen de la **ficha** en el servidor; para una persona sin cuenta, de los datos de la admin | Una app modificada no puede guardar un turno con el nombre de otra. Coincide con lo que escribe hoy la app. | Aceptarlos de la llamada. |
| D-7 | Las reglas niegan crear y editar turnos, turnos ocupados y cierres desde la app, y prohíben **reactivar** un turno cancelado | Sin esto, una app modificada se saltaría las funciones (RF-1, RF-4). Reactivar es la única escritura de estado que ocupa una hora. | Mantener las ramas de la 006 y la 008 como respaldo: serían una puerta trasera. |
| D-8 | Sin instancias mínimas al empezar; RNF-1 se mide en el recorrido | El arranque en frío de una función Node en São Paulo suele ser de 1 a 3 s, dentro de los 5 s. **Si el recorrido lo supera, decisión del autor:** `minInstances: 1` en `bookAppointment` y `editAppointment`, con coste mensual. | Instancias mínimas desde el principio: coste fijo sin saber si hace falta. |
| D-9 | La app comprueba antes de llamar, como hoy | Avisa al instante, quita la hora y evita llamadas que van a fallar. Además, la mayoría de los rechazos del servidor solo pasarán en carreras. | Llamar directamente: cada error esperaría a la función. |

Sin dependencias nuevas: `cloud_functions` (app), `firebase-admin` y `firebase-functions` (servidor) ya están aprobados.

## 9. Tests

Ningún test toca Firebase. El servidor usa un almacén en memoria con transacciones simuladas; la app, un `FirebaseFunctions` falso y la `AgendaFunctions` falsa en los helpers.

| RF | Test |
| --- | --- |
| RF-1, RF-2 | `agenda_rules.test.ts`: solapes (justo al terminar otro no cuenta; los cancelados y los terminados no cuentan; el propio turno no cuenta). `agenda_write.test.ts`: reserva y edición, de la clienta y de la admin. |
| RF-3, RF-5, RF-8 | `agenda_write.test.ts`: dos llamadas sobre el mismo almacén con el candado (el almacén en memoria aplica las transacciones de una en una y reintenta ante conflicto) → una guarda y la otra recibe `slot_taken`, `already_active` o `conflicts`. Se prueba de verdad en el recorrido con dos dispositivos. |
| RF-4 | Reglas y escritura: turno en un cierre, en una fecha bloqueada o en un día cerrado → `closed`. |
| RF-6, RF-7 | Por `clientId` y por WhatsApp normalizado; la admin que cambia la persona. |
| RF-9, RF-10 | Fuera de rejilla, después del cierre, antes de «ahora», día 61 para la clienta y día 366 para la admin, con «ahora» en otro día UTC. |
| RF-11, RF-12 | `booked_catalog.test.ts`: servicio y combo; adicional de otra categoría; combo con adicionales; precio, nombre o duración distintos → `item_changed`; no disponible → `item_unavailable`. |
| RF-13, RF-14, RF-15 | `agenda_write.test.ts`: <br>• editar sin cambiar lo reservado conserva la copia aunque la lista cambie; <br>• misma hora fuera del horario nuevo → `ok`; misma hora bajo un cierre nuevo → `slot_taken`; <br>• ampliar el fin sobre otro turno → `does_not_fit`. <br>Confirmar y cancelar no cambian (los tests de la 010 siguen verdes). |
| RNF-2 | `agenda_rules_cases.test.ts` y `agenda_rules_cases_test.dart` con `test/fixtures/agenda_rules_cases.json`. |
| RF-16, RF-17 | `agenda_functions_test.dart`: cada motivo de `details.reason` → su `AgendaRejection`; sin conexión, tiempo agotado o código desconocido → `failed`. Tests de cada submitter con la `AgendaFunctions` falsa: motivo → resultado → aviso de la vista, en ES y PT. |
| RF-18 | `ClosureController`: `conflicts` → relee y devuelve `ClosureSaveConflicts`; el formulario los muestra con «Editar» y «Cancelar». |
| RF-19 | Las suites de las specs 005 a 011 siguen en verde, con los helpers usando la `AgendaFunctions` falsa. |
| RNF-4 | `agenda_handler.test.ts`: los detalles de un rechazo no llevan nombres, WhatsApp ni lo reservado de otra persona. |
| RNF-5 | `bookingItemChangedOnSave` en los dos `.arb` (test de claves, como el de la 011). |
| Reglas (D-7) | `firestore_rules_test.dart` fija la estructura. `rules-check.md` tiene los casos del simulador: crear o editar un turno desde la app → denegado; confirmar uno cancelado → denegado; confirmar, cancelar y copiar el WhatsApp → permitidos; crear un cierre → denegado; borrarlo → permitido. Después, el recorrido real: dos dispositivos a la vez, cierre contra reserva, tiempos (RNF-1). |

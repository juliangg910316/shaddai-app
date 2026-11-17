# Plan 008 — Agenda de la admin
Estado: aprobada

Spec: `specs/008-agenda-admin/spec.md` (aprobada el 2026-11-17). Parte del código de las specs 005, 006 y 007, implementadas.

## 1. Qué existe ya en el código

| Pieza | Estado | Qué hace este plan |
| --- | --- | --- |
| `freeSlots` (`free_slots.dart`) | Horas libres y cobertura con una lista de `BusyRange`. Un rango que cruza días ya funciona (`start <= hora < end`). | Sin cambios en la función: los cierres entran como rangos más, junto a los turnos ocupados (RF-12, RF-14). |
| `isSelectableDay` / `initialDay` (`booking_window.dart`) | Ventana, fechas bloqueadas (`blockedDates`) y día abierto. | Recibe también los cierres: un día cuyo horario queda entero dentro de cierres no se puede elegir (RF-13). |
| `BookingContext` / `reconcile` (`booking_selection.dart`) | Quita la hora que deja de ser libre y avisa (`slotGone`). | Recibe los cierres. Un cierre nuevo que cubre la hora elegida la quita con el aviso de siempre (RF-15, RF-16). |
| `busySlotsProvider` / `busyRangesProvider` | Turnos ocupados de la ventana, en vivo, con error → aviso y "Reintentar" (005, RF-48). | Se añade `closuresProvider` y los rangos de la lógica suman los cierres. Si fallan los cierres, el mismo aviso que si fallan los turnos ocupados (RF-12). |
| `checkBeforeSave` / `checkSlot` / `checkEditBeforeSave` / `checkAdminBeforeSave` | Comprobación al guardar con los turnos ocupados leídos del servidor. | Las tres reservas leen también los cierres del servidor y los suman (RF-12). |
| `EditOriginal`, `editFreeSlots`, `selectionOf`, `draftOfOriginal`, `changedFields` (`booking_edit.dart`) | La edición de la clienta: el día y la hora originales valen, el propio turno no ocupa, antes y después. | Se reutilizan para la edición de la admin. `EditOriginal` guarda también la persona (RF-24, RF-30). `editFreeSlots` acepta una hora original que ya empezó, solo para la admin (RF-21). |
| `editTargetProvider` / `BookingSelectionController._checkEdit` | La edición de la clienta; termina si el turno deja de ser su turno activo. | Se usa también para la edición de la admin. `_checkEdit` no actúa con la sesión de la admin (no tiene turnos propios): su edición se vigila aparte (§ 5). |
| `RecipientPicker` / `bookingRecipientProvider` / `checkAdminBeforeSave` (007) | "Para quién", búsqueda, persona sin cuenta, bloqueo y turno activo de la persona. | Se reutilizan en la edición (RF-23 a RF-25). El turno activo de la persona no cuenta el turno en edición. |
| `BookingForm` / `BookButton` / `confirmEditChanges` | Modos `editing` y `admin` por separado. Usa siempre el controlador de desplazamiento de la pestaña Reservas. | Modo `editing` + `admin` a la vez (RF-19, RF-27). Recibe su controlador de desplazamiento: la edición vive en otra ruta mientras la pestaña Reservas sigue montada. El diálogo muestra la persona, "quedará confirmado" y el aviso del margen. |
| `AdminDashboardView` (`_AppointmentCard`) | Agenda por días con Confirmar y Cancelar. | Muestra los cierres del día (RF-9), "Editar" (RF-18) y un acceso a Cierres en la cabecera. |
| `AdminSettingsView` | Horario semanal; guarda con `merge: true` sin tocar el margen (006, plan D-4). | Añade el margen de edición, que se guarda al elegirlo (RF-36 a RF-39, RF-41). Deja de escribir `blockedDates` (§ 2). |
| `CalendarSettingsModel` | `blockedDates` y `editMarginMinutes` (se lee, 0 si no vale). | `toMap` deja de escribir `blockedDates` (D-6). El margen se escribe con su propio método (RF-38). |
| `ConfigRepository` | Lee y guarda `settings/calendar`. | Añade los cierres (`closures`), quitar una fecha bloqueada y guardar el margen. |
| `BookingRepository` | Lote turno + turno ocupado; edición de la clienta en transacción; lectura de turnos activos. | Añade leer un turno en vivo, leer del servidor los turnos activos y la edición de la admin en transacción (RF-5, RF-6, RF-19, RF-28). |
| Margen en vivo (006, RF-21) | `editAvailabilityProvider` ya escucha `calendarSettingsProvider` en vivo. | Nada: RF-40 ya se cumple al cambiar el documento; se añade su test. |
| `firestore.rules` | La admin solo cambia el estado de un turno; `settings/calendar` lo escribe la admin sin validar. | Colección `closures`; la admin edita turnos y su turno ocupado; el margen debe ser un entero ≥ 0 (RF-42 a RF-44). |

## 2. Datos en Firestore (RF-8, RF-42 a RF-44; RNF-4) — **decisión del autor**

### Colección nueva `closures/{uuid}`
```
closures/{uuid}         # id generado en la app (UUID v4), como los turnos
  start: timestamp      # instante de inicio
  end: timestamp        # instante de fin (excluido)
```
- **Solo inicio y fin** (RF-42): la clienta los lee para calcular las horas libres y no ve nada más (RF-17).
- **Franja o días enteros, sin campo de tipo:** son días enteros si inicio y fin caen a las 0:00 del salón (`closureKind`, § 4.1). Una franja nunca empieza y termina a las 0:00, porque sus horas van de 0:00 a 23:45 dentro de una fecha (D-3).
- **Los días enteros** se guardan desde las 0:00 del primer día hasta las 0:00 del día siguiente al último.
- **Lectura:** `closures` donde `end >= desde`, un solo campo, sin índice compuesto. Son pocos documentos.
- **Nunca se editan** (fuera de alcance): se crean y se borran.

### `settings/calendar`
- `editMarginMinutes`: lo escribe la app por primera vez, con `set({'editMarginMinutes': n}, merge: true)`, como `int` (RF-38). Con un valor guardado a mano que no es un entero o es negativo, la app sigue leyendo 0 (006).
- `blockedDates`: **la app deja de escribirlo** al guardar el horario. Solo lo cambia al quitar una fecha bloqueada existente, con `FieldValue.arrayRemove` (RF-8). Así guardar el horario no puede volver a poner una fecha recién quitada (D-6). Los documentos actuales se siguen leyendo igual (RNF-4).

### `appointments/{uuid}` y `busySlots/{uuid}`: sin campos nuevos
- La edición de la admin cambia en una transacción, solo si el turno sigue como al abrir la edición:
  - el inicio, el fin, `booked` y `status: 'confirmed'`;
  - si cambia la persona: `clientId`, `clientName`, `clientPhone`, `clientPhotoUrl` y `createdByAdmin: true`. Si no cambia, esos campos no se tocan (como en la 007, el turno conserva el WhatsApp con el que se agendó).
- El turno ocupado se escribe con `set` y no con `update`, por si un turno antiguo no lo tuviera. Se escribe con las mismas horas.

### Reglas (`firestore.rules`)
```
match /closures/{id} {
  allow get, list: if signedIn();                                     # RF-42
  allow create: if isAdmin()
    && request.resource.data.keys().hasOnly(['start', 'end'])
    && request.resource.data.start is timestamp
    && request.resource.data.end is timestamp
    && request.resource.data.end > request.resource.data.start;
  allow delete: if isAdmin();
  allow update: if false;
}

match /appointments/{id} {
  allow update: if
    (isAdmin() && solo cambia 'status')                               # 005, sin cambios
    // La admin edita un turno activo (RF-43).
    || (isAdmin()
      && resource.data.status in ['waiting_confirmation', 'confirmed']
      && resource.data.endTime > request.time
      && affectedKeys().hasOnly(['clientId', 'clientName', 'clientPhone',
           'clientPhotoUrl', 'startTime', 'endTime', 'booked', 'status',
           'createdByAdmin'])
      && request.resource.data.status == 'confirmed'
      && request.resource.data.endTime > request.resource.data.startTime
      // Nunca quita la marca (RF-31).
      && (request.resource.data.get('createdByAdmin', false) == true
          || !affectedKeys().hasAny(['createdByAdmin']))
      // Si cambia la persona, lo marca como suyo.
      && (!affectedKeys().hasAny(['clientId', 'clientName', 'clientPhone'])
          || request.resource.data.createdByAdmin == true)
      // La persona: igual que al crear (007, RF-2, RF-25).
      && (request.resource.data.clientId == null
          || (request.resource.data.clientId != request.auth.uid
              && users/<clientId>.role == 'cliente'
              && users/<clientId>.isBlocked != true))
      && getAfter(busySlots/id) con las mismas horas)
    || (la clienta edita su turno: 006, sin cambios);
}

match /busySlots/{id} {
  allow create: (sin cambios) || (isAdmin() && getAfter(appointments/id) con las mismas horas);
  allow update: (sin cambios, la clienta)
    || (isAdmin() && keys().hasOnly(['start', 'end'])
        && getAfter(appointments/id) con las mismas horas);
}

match /settings/calendar {
  allow read: if signedIn();
  allow write: if isAdmin()
    && (!('editMarginMinutes' in request.resource.data)
        || !affectedKeys().hasAny(['editMarginMinutes'])
        || (request.resource.data.editMarginMinutes is int
            && request.resource.data.editMarginMinutes >= 0));   # RF-44
}
```
- La validación del margen solo se aplica **cuando el margen cambia**. Si se aplicara siempre, un margen guardado a mano como `double` impediría guardar el horario (MEMORY, 006).
- Como en la 007, las reglas no impiden solapes con otros turnos ni con cierres (spec 012). La app lo comprueba antes de guardar (RF-6, RF-28).
- `rules-check.md` nuevo, con los casos de RF-42 a RF-44 y los de las specs 005 a 007 que tocan estas reglas (RNF-5).

## 3. Capa `lib/data/`

| Archivo | Cambio |
| --- | --- |
| `models/closure_model.dart` (nuevo) | `ClosureModel {id, start, end}` (instantes). `fromMap` devuelve `null` si falta un campo o el fin no es posterior al inicio, como `BusySlot`. `toMap` solo con `start` y `end`. |
| `models/calendar_settings_model.dart` | `toMap` sin `blockedDates` (D-6). |
| `repositories/config_repository.dart` | `watchClosures(from)` en vivo; `fetchClosures(from)` del servidor; `createClosure(ClosureModel)` y `deleteClosure(id)`, con el mismo tiempo máximo que los turnos; `removeBlockedDate(key)` (`arrayRemove`); `updateEditMargin(minutes)` (`set` con `merge`). |
| `repositories/booking_repository.dart` | `watchAppointment(id)` en vivo (la edición de la admin, también al recargar en Web); `fetchActiveAppointments(now)` del servidor (RF-5, RF-6); `fetchAdminEditCheck(id, from, to, now)`, que lee del servidor el turno, los turnos ocupados del día y los activos; `updateAppointmentByAdmin(id, expected, start, end, booked, person?)`, la transacción de § 2 (RF-28). |

Las tres comprobaciones al guardar que ya existen (`fetchBookingCheck`, `fetchEditCheck` y `fetchAdminBookingCheck`) no cambian. Sus submitters leen además `fetchClosures(inicio del día)` y suman los cierres a los turnos ocupados (RF-12).

## 4. Lógica pura (`lib/features/booking/logic/`, sin Flutter ni Firebase; RNF-1)

### 4.1 `closures.dart` (nuevo): cierres (RF-3 a RF-5, RF-8, RF-9, RF-13)
```
sealed ClosureDraft
  RangeDraft(day, fromMinutes, toMinutes)       # pasos de 15 min, 0..1425
  DaysDraft(firstDay, lastDay)

enum ClosureError { endNotAfterStart, daysReversed, past, tooFar }

closureRange(draft) → (start, end)              # hora de pared del salón
  RangeDraft: day + from, day + to
  DaysDraft:  firstDay 0:00, (lastDay + 1) 0:00

closureErrors(draft, nowSalon, {windowDays = 365}) → Set<ClosureError>
  RangeDraft y to <= from        → endNotAfterStart
  DaysDraft y lastDay < firstDay → daysReversed
  si no hay error de orden y end <= nowSalon → past
  alguna fecha > hoy + windowDays → tooFar

closureKind(start, end) → days | range          # días si los dos son las 0:00 del salón

overlaps(a, b) = a.start < b.end && b.start < a.end   # tocar el borde no choca

closureConflicts(range, appointments, nowSalon) → List<T> (por inicio)
  activo (activeStatuses), termina después de ahora y overlaps(turno, range)

closureEntries(closures, blockedDates, nowSalon) → List<ClosureEntry>
  ClosureEntry { source: closure(id) | blockedDate(key), start, end, kind }
  las fechas bloqueadas, como días enteros de 0:00 a 0:00 del día siguiente
  solo las que terminan después de ahora; ordenadas por inicio      # RF-1, RF-8

closuresOfDay(entries, day) → las que se cruzan con [day 0:00, day+1 0:00)   # RF-9

isClosedAllDay(day, settings, closures) → bool  # RF-13
  opening = openingOf(day); si null → false (ya es un día cerrado)
  t = opening.open
  repetir: buscar un cierre con start <= t < end; si no hay → false; t = su end
  hasta t >= opening.close → true                # unión de cierres que se cruzan
```

### 4.2 Cambios en `booking_window.dart` y `booking_selection.dart` (RF-12 a RF-16)
- `isSelectableDay(day, settings, window, {closures = const []})`: además, `!isClosedAllDay(...)`. `initialDay` e `isEditDaySelectable` lo pasan.
- `BookingContext` recibe `closures` (rangos en hora de pared). `freeSlotsOf` llama a `freeSlots` y a `editFreeSlots` con `busy + closures`. `reconcile` no cambia: una hora que deja de ser libre por un cierre se quita con `slotGone` (RF-16).
- `checkSlot`, `checkBeforeSave`, `checkEditBeforeSave` y `checkAdminBeforeSave` reciben los cierres y los suman a `busy`.

### 4.3 `booking_edit.dart`: la edición de la admin (RF-19 a RF-22, RF-24, RF-26, RF-30)
- `EditOriginal` añade la persona: `clientId`, `clientName`, `clientPhone`, `clientPhotoUrl` y `createdByAdmin`, copiados en `EditOriginal.of`. La edición de la clienta no los usa.
- `editFreeSlots(..., {allowStarted = false})`: con `allowStarted`, la hora original vale también si ya empezó, mientras el turno no haya terminado (RF-21, turno en curso). La clienta sigue con `false`.

### 4.4 `admin_edit.dart` (nuevo): persona, cambios y comprobación (RF-23 a RF-31)
```
recipientOf(original) → Recipient
  clientId != null → AccountRecipient(uid, clientName, clientPhone, photo)
  si no            → GuestRecipient(clientName, clientPhone, consent: true)   # RF-24

personChanged(original, recipient) → bool
  cuenta: otro uid, o pasa de cuenta a sin cuenta o al revés
  sin cuenta: nombre (sin espacios al principio ni al final) o WhatsApp distintos (sameWhatsApp)

adminEditChanges(original, recipient, selection, catalog) → Set<AdminEditField>
  changedFields(draftOfOriginal, draftOfSelection) + person si personChanged   # RF-26, RF-27

markAfterEdit(original, recipient) = personChanged || original.createdByAdmin   # RF-31

sealed AdminEditCheck: ok | notActive | changed | recipientBlocked
                     | personActive(turno) | slotTaken | doesNotFit
checkAdminEditBeforeSave({original, current, recipient, recipientUser, users,
    start, durationMinutes, settings, busy, closures, active, nowSalon})
  1. current null, no activo o ya terminado          → notActive    # RF-30
  2. current distinto de original (horas, estado, lo
     reservado, persona o marca)                     → changed      # RF-30
  3. persona bloqueada / ya no es clienta (igual que
     checkAdminBeforeSave)                           → recipientBlocked   # RF-29
  4. activeAppointmentOfPerson(active sin original.id) → personActive     # RF-25
  5. editFreeSlots(allowStarted: true) con busy (sin el propio) + closures:
     sin la hora → slotTaken; no cabe → doesNotFit                       # RF-20, RF-21
  sin margen de edición                                                   # RF-22
```

### 4.5 `edit_margin.dart` (nuevo): opciones del margen (RF-36, RF-37)
```
editMarginOptions = [0, 60, 120, 180, 360, 720, 1440, 2880, 4320]
marginChoices(current) → las opciones y, si current no está, también current, en orden
marginParts(minutes) → (hours, minutes)   # la vista lo pinta "N h M min"
```

## 5. Interfaz

### Providers
| Provider | Archivo | Qué hace | RF |
| --- | --- | --- | --- |
| `closuresProvider` | `booking_provider.dart` | `watchClosures(desde hoy 0:00 del salón)`, en vivo; vuelve a pedirlos solo al cambiar el día. | RF-12, RF-15 |
| `closureRangesProvider` | `booking_provider.dart` | Los cierres en hora de pared. Con error, `AsyncError`, comprobando `hasError` antes que `isLoading` (MEMORY). | RF-12 |
| `busyRangesProvider`, `freeSlotsOfDayProvider`, `BookingContext` | `booking_provider.dart` | Suman los cierres. El error de cualquiera de los dos da el aviso de la 005 (RF-48). | RF-12 a RF-16 |
| `adminDayClosuresProvider` | `admin_provider.dart` | Cierres y fechas bloqueadas del día de la agenda (`closuresOfDay`), con `watchClosures(día elegido)`. | RF-9, RF-10 |
| `adminClosureEntriesProvider` | `admin_provider.dart` | `closureEntries` de los cierres desde hoy y las fechas bloqueadas. | RF-1, RF-2, RF-8, RF-10 |
| `ClosureController` / `closureControllerProvider` | `admin_closures_provider.dart` (nuevo) | `save(draft)`: comprueba `closureErrors`, lee del servidor los turnos activos (`fetchActiveAppointments`), devuelve los que chocan o guarda. `delete(entry)`: borra el cierre o quita la fecha bloqueada. | RF-3 a RF-8, RF-11 |
| `adminEditAppointmentProvider(id)` | `admin_edit_provider.dart` (nuevo) | `watchAppointment(id)` en vivo. | RF-19, RF-30 |
| `AdminEditController` / `adminEditProvider` | `admin_edit_provider.dart` | Ver más abajo. | RF-19 a RF-35 |
| `recipientActiveAppointmentProvider` | `admin_booking_provider.dart` | No cuenta el turno en edición. | RF-25 |
| `editMarginSaverProvider` | `admin_provider.dart` | `AdminController.updateEditMargin(minutes)`. | RF-38, RF-39 |

**`AdminEditController`** (un `Notifier` que guarda el id en edición, o `null`):
- `start(appointment)`:
  1. guarda aparte lo que la admin tenía elegido para agendar: la selección y "Para quién" (RF-33, D-2);
  2. pone `recipientOf(original)` en `bookingRecipientProvider`;
  3. abre `editTargetProvider.start(appointment)`; `selectionOf` carga el día, la hora y lo reservado.
- `end()`: cierra `editTargetProvider` y devuelve la selección y "Para quién" guardados aparte; `reconcile` los ajusta a los datos de ahora (RF-33, RF-35).
- `save()`:
  1. comprueba lo que falta (`missingParts(admin: true)`, RF-34) y si hay cambios (RF-26);
  2. lee `fetchAdminEditCheck`, `fetchClosures` y `fetchUser` del servidor;
  3. aplica `checkAdminEditBeforeSave` y llama a `updateAppointmentByAdmin`, con `expected` igual al paso 2 de § 4.4.

  Devuelve `AdminEditResult(outcome, {active, name, day})`. Con `slotTaken` o `doesNotFit` quita la hora, como al agendar. Con `recipientBlocked` quita a la clienta con cuenta (007).
- **Vigilancia:** escucha `adminEditAppointmentProvider(id)`. Si el turno deja de estar activo o cambia mientras la admin lo edita, la vista lo avisa y vuelve a la agenda (RF-30). `BookingSelectionController._checkEdit` no actúa con la sesión de la admin.

### Agenda (`AdminDashboardView`; igual en Web y en Android/iOS)
- **Cabecera:** un `IconButton` "Cierres" (`Icons.event_busy_outlined`, 48 px, con tooltip) → `/admin/closures` (RF-1).
- **Lista:** los turnos y los cierres del día (`_ClosureCard`: "CERRADO", sus horas o "Todo el día"), ordenados por inicio (RF-9). Si fallan los cierres, un aviso con "Reintentar" sobre la lista (RF-10).
- **`_AppointmentCard`:** "Editar" (`OutlinePillButton`, 48 px) si el turno está esperando confirmación o confirmado y termina después de "ahora" (RF-18).

### Cierres (`AdminClosuresView`, nueva)
- **Lista** de `adminClosureEntriesProvider`: fechas, horas o "Todo el día", y un botón "Quitar" (48 px) en cada una, que pide confirmación (RF-1, RF-7, RF-8).
- Sin cierres: el texto y "Nuevo cierre" (RF-2). Con error: aviso y "Reintentar", sin "Nuevo cierre" (RF-10).
- **"Nuevo cierre"** → `/admin/closures/new` → `AdminClosureFormView`:
  - `SegmentedButton` "Unas horas" / "Días enteros";
  - las fechas con `showDatePicker` (desde hoy hasta 365 días);
  - las horas con un desplegable en pasos de 15 minutos;
  - los errores debajo de cada campo, en `brand.danger` (RF-3, RF-4).
- **"Guardar":**
  - si hay turnos que chocan, salen debajo (`AppNotice` y una tarjeta por turno con fecha, hora, persona y lo reservado) con "Editar" y "Cancelar". Cancelar pide confirmación, porque el turno de la clienta se pierde (constitución, principio 5). Al volver, la admin vuelve a tocar "Guardar" y se comprueba otra vez (RF-5, RF-6);
  - si no hay choques: aviso "Cierre guardado" y vuelta a la lista (RF-6);
  - si falla: aviso, y conserva lo elegido (RF-11).

### Edición de la admin (`AdminAppointmentEditView`, nueva)
- **Al abrirse**, espera `adminEditAppointmentProvider(id)`:
  - turno activo: `adminEditProvider.start(appointment)`, en el fotograma siguiente;
  - no existe o ya no está activo: un aviso y "Volver a la agenda".
- **Formulario:** `BookingForm(editing: true, admin: true, scrollController: propio)`:
  - "Para quién" con la persona del turno, el calendario de 365 días, las horas, los servicios y el resumen;
  - "Guardar cambios" y "Cancelar" (RF-19 a RF-24, RF-34, RF-35).
- **`BookButton` en este modo:**
  - pide `confirmEditChanges(admin: true)`, con el antes y el después de la persona (`bookingSummaryFor`), del día, de la hora y de lo reservado;
  - el aviso "El turno quedará confirmado" (`bookingAdminConfirmNote`);
  - el aviso del margen si la persona tiene cuenta (`_MarginWarning(admin: true)`, RF-27).

  Sin cambios, no abre el diálogo y avisa (RF-26).
- **Al guardar con éxito:** `adminSelectedDateProvider` pasa al día del turno y la vista vuelve a la agenda con "Turno de {nombre} guardado" (RF-28).
- **Con otro resultado:** el aviso que corresponda (RF-29, RF-30).
- **Al salir de la vista por cualquier camino** (botón atrás, "Cancelar", atrás del navegador o guardar): `adminEditProvider.end()` en `dispose`, creado en `initState` (MEMORY) (RF-33, RF-35).
- **`BookingForm`** recibe `scrollController` opcional, que por defecto es el de la pestaña Reservas. En Android/iOS la pestaña sigue montada debajo (`indexedStack`) y un controlador no puede estar en dos listas.

### Margen (`AdminSettingsView`)
- Una sección "Margen de edición" con un `DropdownButtonFormField` de `marginChoices(actual)` y la explicación (RF-36, RF-37).
- **Al elegir**, guarda solo el margen (RF-38, RF-41) y avisa "Margen guardado".
- **Si falla**, vuelve al valor guardado y avisa (RF-39). El valor que se muestra viene de `calendarSettingsProvider`, más el elegido mientras se guarda.
- El horario semanal sigue con su botón "Guardar", que no toca el margen ni `blockedDates` (RF-41, D-6).

### Rutas y guardas (`app_router.dart`, `redirect_logic.dart`)
- **Android/iOS:** `GoRoute` de primer nivel `/admin/closures`, `/admin/closures/new` y `/admin/appointments/:id/edit`, con `push`/`pop`, como las demás páginas del panel.
- **Web:**
  - las mismas rutas en `WebAccountPage`;
  - la edición se abre con `go`, para que tenga su dirección (spec, Plataformas), y "atrás" del navegador sale sin guardar (RF-35);
  - los cierres, con `push`, como las demás páginas del panel;
  - un helper decide entre `push` y `go` según `isWebProvider`.
- **Guardas:** las nuevas direcciones empiezan por `/admin/`, así que `resolveRedirect` ya las protege (cosmético). La seguridad está en las reglas. Se añaden a la lista de rutas conocidas de `safeNext`.

## 6. Textos nuevos en los `.arb` (ES / PT; RNF-3, RC-1)

| Clave | ES | PT |
| --- | --- | --- |
| `adminClosuresTitle` | Cierres | Fechamentos |
| `adminClosuresEmpty` | No hay cierres próximos. | Não há fechamentos próximos. |
| `adminClosuresNew` | Nuevo cierre | Novo fechamento |
| `adminClosuresLoadError` | No se pudieron cargar los cierres. | Não foi possível carregar os fechamentos. |
| `closureKindRange` | Unas horas | Algumas horas |
| `closureKindDays` | Días enteros | Dias inteiros |
| `closureDateLabel` | Fecha | Data |
| `closureFromLabel` / `closureToLabel` | Desde / Hasta | Das / Até |
| `closureFirstDayLabel` / `closureLastDayLabel` | Primer día / Último día | Primeiro dia / Último dia |
| `closureErrorEndNotAfterStart` | La hora de fin debe ser posterior a la de inicio. | O horário final deve ser depois do inicial. |
| `closureErrorDaysReversed` | El último día no puede ser anterior al primero. | O último dia não pode ser anterior ao primeiro. |
| `closureErrorPast` | Ese tiempo ya pasó. | Esse período já passou. |
| `closureErrorTooFar` | Solo se puede cerrar hasta el {date}. | Só é possível fechar até {date}. |
| `closureConflictsTitle` | Hay turnos en ese tiempo | Há horários marcados nesse período |
| `closureConflictsBody` | Muévelos o cancélalos y vuelve a guardar el cierre. | Mova-os ou cancele-os e salve o fechamento de novo. |
| `closureSaved` | Cierre guardado. | Fechamento salvo. |
| `closureSaveError` | No se pudo guardar el cierre. Inténtalo de nuevo. | Não foi possível salvar o fechamento. Tente de novo. |
| `closureDeleteTitle` | ¿Quitar este cierre? | Remover este fechamento? |
| `closureDeleteBody` | Esas horas volverán a estar libres para reservar. | Esses horários voltarão a ficar livres para reserva. |
| `closureDeleteAction` | Quitar | Remover |
| `closureDeleted` | Cierre quitado. | Fechamento removido. |
| `closureDeleteError` | No se pudo quitar el cierre. Inténtalo de nuevo. | Não foi possível remover o fechamento. Tente de novo. |
| `closureAllDay` | Todo el día | Dia inteiro |
| `closureDaysRange` | Del {first} al {last} | De {first} a {last} |
| `adminAgendaClosed` | Cerrado | Fechado |
| `adminAppointmentEdit` | Editar | Editar |
| `adminCancelAppointmentTitle` | ¿Cancelar el turno de {name}? | Cancelar o horário de {name}? |
| `adminCancelAppointmentBody` | La hora quedará libre. | O horário ficará livre. |
| `adminEditNoChanges` | No cambiaste nada. | Você não mudou nada. |
| `adminEditSaved` | Turno de {name} guardado. | Horário de {name} salvo. |
| `adminEditNotActive` | Ese turno ya no está activo: se canceló o terminó. | Esse horário não está mais ativo: foi cancelado ou terminou. |
| `adminEditChanged` | Alguien cambió ese turno mientras lo editabas. Revisa cómo está ahora. | Alguém mudou esse horário enquanto você editava. Veja como está agora. |
| `adminEditNotFound` | No se encontró ese turno. | Não foi possível encontrar esse horário. |
| `adminEditBackToAgenda` | Volver a la agenda | Voltar para a agenda |
| `settingsEditMarginTitle` | Margen de edición | Prazo para alterações |
| `settingsEditMarginHelp` | Hasta cuánto antes del turno puede cambiarlo la clienta. | Até quanto tempo antes do horário a cliente pode alterá-lo. |
| `settingsEditMarginNone` | Sin margen | Sem prazo |
| `settingsEditMarginHours` | {hours, plural, =1{1 hora} other{{hours} horas}} | {hours, plural, =1{1 hora} other{{hours} horas}} |
| `settingsEditMarginCustom` | {hours} h {minutes} min | {hours} h {minutes} min |
| `settingsEditMarginSaved` | Margen guardado. | Prazo salvo. |
| `settingsEditMarginError` | No se pudo guardar el margen. | Não foi possível salvar o prazo. |

Se reutilizan:
- de la 006: `bookingEditTitle`, `bookingSaveChangesAction`, `bookingEditConfirmTitle`, `bookingEditBefore`/`After` y los avisos de hora ocupada o sin sitio;
- de la 007: `bookingSummaryFor`, `bookingAdminConfirmNote`, `bookingAdminMarginWarning`, `bookingRecipientBlocked` y `activeAppointmentMessage`.

Todas las claves nuevas se añaden a `booking_texts_test` (o a un `admin_texts_test` nuevo) y se ejecuta `flutter gen-l10n`.

## 7. Decisiones técnicas

| # | Decisión | Alternativa descartada |
| --- | --- | --- |
| D-1 | Cierres en una **colección propia** `closures`, que se lee con `end >= desde`. | Guardarlos como `busySlots` sin turno. La consulta de `busySlots` filtra por `start` dentro de la ventana, así que no vería un cierre de varios días que empezó antes. Además mezclaría reglas que dependen del turno. |
| D-2 | La edición de la admin **guarda aparte y devuelve** lo que tenía elegido para agendar, sobre los mismos providers de selección y "Para quién" (RF-33). | Providers de selección por modo (`family`) o con `ProviderScope` anidado. Habría que cambiar todos los widgets y providers que leen la selección (calendario, horas, servicios, resumen y botón), o declarar las dependencias de todos los que dependen de ella. |
| D-3 | El tipo del cierre se deduce de las horas (0:00 → días enteros). | Un campo `kind`. La spec pide que un cierre solo guarde inicio y fin (RF-42). |
| D-4 | Los turnos que chocan se buscan **al guardar**, con una lectura del servidor que sirve a la vez para RF-5 y RF-6. | Buscarlos en vivo mientras elige. Haría falta escuchar todos los turnos activos desde el formulario, y al guardar habría que volver a leerlos igualmente. |
| D-5 | La edición de la admin es una **ruta propia** que reutiliza `BookingForm`. | Abrirla en la pestaña Reservas de la admin. Mezclaría su reserva a medias con la edición, y en Web perdería la dirección propia. |
| D-6 | `CalendarSettingsModel.toMap` deja de escribir `blockedDates`; solo se quitan fechas con `arrayRemove`. | Seguir escribiendo la lista entera al guardar el horario. Con la pantalla abierta, podría volver a poner una fecha bloqueada que se acaba de quitar. |
| D-7 | El margen se valida en las reglas **solo cuando cambia**. | Validarlo siempre. Un valor guardado a mano como `double` impediría guardar el horario. |
| D-8 | El turno ocupado se escribe con `set` en la edición de la admin. | `update`, que falla si un turno antiguo no tiene turno ocupado. |
| D-9 | Los cierres van en `ConfigRepository` (son parte del calendario del salón). | Un `ClosureRepository` nuevo. CLAUDE.md fija cuatro repositorios, y crear uno más multiplica los providers. |

## 8. Decisiones del autor
- **Colección nueva `closures`** y los cambios de `firestore.rules` de § 2 (CLAUDE.md: preguntar antes de cambiar colecciones, campos o reglas).
- Sin dependencias nuevas.

## 9. Estrategia de tests

Sin Firebase: `FakeBookingRepository` y un `FakeConfigRepository` nuevo (o ampliado) en `test/helpers/`. Este último lleva cierres en vivo (`emitClosures`), `fetchClosures`, `created`/`deleted`, `removedBlockedDates`, `margin`, `saveError`. Al de turnos se añaden `watchAppointment` (`emitAppointment`), `fetchActiveAppointments`, `adminEditCheckData` y `updateAppointmentByAdmin` (registra lo que se guarda y respeta `expected`).

| Test | Qué cubre |
| --- | --- |
| `test/features/booking/closures_test.dart` (tabla) | `closureRange`, `closureErrors`, `closureKind`, `closureConflicts` (borde, en curso, cancelado, terminado), `closureEntries` (fechas bloqueadas, pasados, orden), `closuresOfDay`, `isClosedAllDay` (franja que cubre todo, unión de dos, hueco). RNF-1, RF-3 a RF-5, RF-8, RF-9, RF-13. |
| `free_slots_test.dart` y `booking_window_test.dart` (ampliados) | Horas libres y cobertura con cierres al principio, en medio y al final, cierre pegado a un turno, varios días y cierre que cruza el día; día no seleccionable. RF-12 a RF-14. |
| `booking_selection_test.dart` (ampliado) | Un cierre nuevo quita la hora elegida con `slotGone`. RF-16. |
| `admin_edit_test.dart` (tabla, nuevo) | `recipientOf`, `personChanged`, `adminEditChanges`, `markAfterEdit` y `checkAdminEditBeforeSave` en cada caso; `editFreeSlots(allowStarted)`. RF-20 a RF-26, RF-29 a RF-31. |
| `edit_margin_test.dart` (tabla, nuevo) | `marginChoices` y `marginParts`. RF-36, RF-37. |
| `closure_model_test.dart`, `calendar_settings_model_test.dart` | `fromMap`/`toMap`; `toMap` sin `blockedDates`. RNF-4. |
| `admin_closures_provider_test.dart` | Guardar con errores, con choques (no guarda), sin choques (guarda), fallo; quitar un cierre y una fecha bloqueada. RF-3 a RF-8, RF-11. |
| `admin_closures_view_test.dart` | Lista, vacía, error con "Reintentar", formulario, choques con Editar y Cancelar, quitar con confirmación. RF-1 a RF-11. |
| `booking_closures_test.dart` | La reserva de la clienta, su edición y la de la admin no ofrecen las horas del cierre; un día cerrado no se elige; un cierre que llega en vivo; error de los cierres → aviso; los submitters leen los cierres. RF-12 a RF-17. |
| `admin_edit_provider_test.dart` | `start`/`end` guardan y devuelven la reserva a medias; `save` en cada resultado; lo que se escribe (persona solo si cambia, marca, confirmado); la vigilancia del turno. RF-19 a RF-35. |
| `admin_edit_view_test.dart` | Abrir desde la agenda, persona y selección cargadas, diálogo de antes y después con persona y margen, guardar → agenda en el día del turno, salir sin guardar, no encontrado. RF-18, RF-19, RF-27, RF-28, RF-33 a RF-35. |
| `admin_edit_flow_test.dart` (`pumpMobileApp` y `pumpWebApp`) | Rutas, dirección propia en Web y atrás del navegador, la pestaña Reservas sigue con lo suyo. RF-33, RF-35; Plataformas. |
| `admin_edited_client_test.dart` | La clienta ve el cambio sin recargar; al cambiar la persona, deja de verlo. RF-32. |
| `admin_appointments_booked_test.dart` (ampliado) | "Editar" solo en turnos activos; cierres en la agenda del día. RF-9, RF-18. |
| `admin_settings_margin_test.dart` | Opciones, valor que no está en la lista, guardar al elegir, error → vuelve al anterior, el horario no toca el margen. RF-36 a RF-39, RF-41. |
| `booking_edit_margin_live_test.dart` | La clienta ve aparecer y desaparecer "Editar turno" al cambiar el margen. RF-40. |
| `firestore_rules_test.dart` (ampliado) | Estructura de `closures`, la edición de la admin, `busySlots` y el margen. RF-42 a RF-44. |
| `admin_agenda_accessibility_test.dart` | Contraste en los dos temas, 48 px, semántica y 200 % en 320 px en Cierres, el formulario, la edición y el margen. RNF-2. |
| `booking_texts_test` | Las claves nuevas en ES y PT. RNF-3. |
| `rules-check.md` | Simulador (lo hace el autor). RNF-5. |

## 10. Cobertura

| RF | Dónde | Test |
| --- | --- | --- |
| RF-1, RF-2 | `AdminClosuresView`, `closureEntries` | `admin_closures_view_test`, `closures_test` |
| RF-3, RF-4 | `AdminClosureFormView`, `closureErrors` | `closures_test`, `admin_closures_view_test` |
| RF-5, RF-6 | `ClosureController.save`, `closureConflicts`, `fetchActiveAppointments` | `closures_test`, `admin_closures_provider_test`, view |
| RF-7, RF-8 | `ClosureController.delete`, `removeBlockedDate`, `closureEntries` | provider, view, `closures_test` |
| RF-9 | `adminDayClosuresProvider`, `_ClosureCard` | `admin_appointments_booked_test`, `closures_test` |
| RF-10, RF-11 | vistas de cierres y agenda | `admin_closures_view_test`, provider |
| RF-12 a RF-14 | `closuresProvider`, `BookingContext`, `isSelectableDay`, submitters | `free_slots_test`, `booking_window_test`, `booking_closures_test` |
| RF-15, RF-16 | `closuresProvider` en vivo, `reconcile` | `booking_selection_test`, `booking_closures_test` |
| RF-17 | la reserva solo recibe rangos | `booking_closures_test` |
| RF-18 | `_AppointmentCard` | `admin_appointments_booked_test` |
| RF-19 a RF-26 | `AdminEditController`, `admin_edit.dart`, `editFreeSlots(allowStarted)` | `admin_edit_test`, `admin_edit_provider_test`, `admin_edit_view_test` |
| RF-27 | `BookButton` y `confirmEditChanges(admin)` | `admin_edit_view_test` |
| RF-28 a RF-31 | `save`, `updateAppointmentByAdmin`, `checkAdminEditBeforeSave` | `admin_edit_test`, `admin_edit_provider_test` |
| RF-32 | `myAppointmentsProvider` (sin cambios) | `admin_edited_client_test` |
| RF-33 a RF-35 | `AdminEditController.start`/`end`, `AdminAppointmentEditView` | provider, view, `admin_edit_flow_test` |
| RF-36 a RF-39, RF-41 | `AdminSettingsView`, `edit_margin.dart`, `updateEditMargin`, `toMap` | `edit_margin_test`, `admin_settings_margin_test`, model test |
| RF-40 | `editAvailabilityProvider` (sin cambios) | `booking_edit_margin_live_test` |
| RF-42 a RF-44 | `firestore.rules` | `firestore_rules_test` (estructura); simulador del autor |
| RNF-1 | `closures.dart`, `admin_edit.dart`, `edit_margin.dart`, `free_slots`, `booking_window` | tests de tabla |
| RNF-2 | vistas nuevas | `admin_agenda_accessibility_test` |
| RNF-3 | `.arb` | `booking_texts_test` |
| RNF-4 | modelos, `toMap`, lectura de `blockedDates` y del margen | tests de modelo, `closures_test` |
| RNF-5 | `rules-check.md` | autor |
| RC-1 a RC-4 | textos en `.arb`, `context.brand`, las mismas pantallas en las tres plataformas | `booking_texts_test`, `no_hardcoded_style_test`, `admin_edit_flow_test` |

Tareas previstas: unas 16, en cuatro bloques: cierres y reserva, edición de la admin, margen, y reglas y cierre. Como decidió el autor, todo va en esta spec.

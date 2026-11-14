# Plan 006 — Editar el turno
Estado: aprobada

Spec: `specs/006-editar-turno/spec.md` (aprobada el 2026-11-13). Parte del código de la spec 005 (implementada el 2026-11-05).

## 1. Qué existe ya en el código

| Pieza | Estado | Qué hace este plan |
| --- | --- | --- |
| `ActiveAppointmentView` | Muestra el turno activo: lo reservado, el día, la franja, el total, el estado y "solo uno" (005, RF-33). Si está bloqueada, también su aviso (RF-37). | Añade "Editar turno", o el aviso de que ya no se puede cambiar, o el error del margen (RF-1 a RF-3, RF-22). |
| `bookingScreen` / `bookingScreenProvider` (`booking_rules.dart`) | Decide qué muestra la pestaña: cargando, sin sesión, error, admin, turno activo, bloqueada o la vista de reserva. | Añade el estado **edición** (`BookingScreenEditing`) cuando hay un turno en edición que sigue siendo el activo y la clienta no está bloqueada. |
| `BookingSelectionController` / `booking_selection.dart` | Lo elegido (día, hora, servicio, adicionales), sus acciones (`selectDay`, `selectSlot`, `selectItem`, `toggleAddon`, `requestItem`) y `reconcile`. Avisos como datos (`BookingNotice`). | Se reutiliza para la edición, con un **contexto de edición** que deja válidos el día y la hora originales y no cuenta el propio turno (RF-5, RF-7 a RF-9). `requestItem` tiene una variante para la edición (RF-27 a RF-30). |
| `BookingForm`, `BookingCalendar`, `SlotGrid`, `ServicePicker`, `AddonPicker`, `BookingSummary`, `BookButton` | La vista de reserva de la 005. | La misma vista en modo edición: título "Editar turno", "Guardar cambios", "Cancelar" y diálogo de antes y después (RF-4, RF-10, RF-11, RF-18). |
| `free_slots.dart` (`freeSlots`, `fits`) | Horas libres y cobertura de un día. | Sin cambios. La edición la envuelve (`editFreeSlots`, § 4). |
| `busySlotsProvider` / `busyRangesProvider` | Turnos ocupados de la ventana, en vivo. Los `BusySlot` llevan el id de su turno. | Durante la edición se quita el del propio turno (RF-7). |
| `BookingSubmitter` / `checkBeforeSave` | Comprueba en el servidor y guarda el turno nuevo (005, RF-26). | Se añade `BookingEditor` con su propia comprobación (`checkEditBeforeSave`) y una transacción (RF-12 a RF-16). El diálogo de confirmación de la 005 gana el aviso del margen (RF-23). |
| `BookingRepository` | `createAppointment` (lote turno + turno ocupado), `fetchBookingCheck`, `watchBusySlots`, `getClientAppointments`, `updateAppointmentStatus`. | Añade `fetchEditCheck` y `updateEditedAppointment` (transacción que cambia el turno y su turno ocupado). |
| `CalendarSettingsModel` / `ConfigRepository` / `calendarSettingsProvider` | Horario, fechas bloqueadas, duración global; en vivo; por defecto si no existe. | Añade el margen de edición, que se lee con tolerancia y vale 0 si falta (RF-21). |
| `AdminSettingsView._saveSettings` | Crea un `CalendarSettingsModel` nuevo y lo guarda con `merge: true`. | Sin cambios: como `toMap` no escribe el margen, guardar el horario no lo pisa (D-4). |
| `bookingRequestOf` / `/booking?service|combo=<id>` / `_ReserveButton` del detalle | "Reservar cita" en el detalle abre la reserva con ese servicio (005, RF-40 a RF-44). | Sin cambios en las rutas. Con la edición abierta, `BookingView` aplica la petición a la edición (RF-27). |
| `BookingNotice`, `showBookingNotice`, `BookingLoadErrorNotice`, `BookingBlockedNotice`, `formatPrice`, `formatDuration`, `BilingualText.of` | Avisos y formatos de la 005 y la 004. | Se reutilizan. `BookingNotice` gana los avisos de la edición (§ 4.5). |
| `firestore.rules` | `appointments`: la clienta crea y no cambia; la admin cambia solo `status`. `busySlots`: se crea con su turno, la admin lo borra, nadie lo cambia. `settings/calendar`: provisional, cualquiera con sesión escribe. | La clienta puede editar su turno activo y su turno ocupado (RF-24). `settings/calendar` solo lo escribe la admin (RF-25). |
| `WebShell` (`ShellRoute` de Web) | Barra superior y páginas de cuenta. | Escucha la navegación del navegador para cerrar la edición al ir atrás (RF-20, D-8). |

## 2. Datos en Firestore (RF-13, RF-21, RF-24 a RF-26)

### `settings/calendar`: nuevo campo `editMarginMinutes`
```
settings/calendar
  openingHours, globalSlotDurationMinutes, blockedDates   # sin cambios
  editMarginMinutes: int                                   # NUEVO, opcional: margen de edición en minutos
```
- **Compatibilidad:** el documento actual no lo tiene. Si falta, no es un entero o es negativo, vale 0 (RF-21; constitución, principio 5).
- Hasta la spec 008 nadie lo escribe desde la app: el autor lo pone a mano para el recorrido manual. `toMap` **no** lo escribe, y el guardado de la admin usa `merge: true`, así que guardar el horario no lo borra (D-4).

### `appointments/{uuid}` y `busySlots/{uuid}`: sin campos nuevos
- Al editar se cambian `startTime`, `endTime`, `booked` y `status` (vuelve a `'waiting_confirmation'`, RF-13). Los demás campos (`clientId`, `clientName`, `clientPhone`, `clientPhotoUrl`, `createdAt`) no se tocan.
- En la misma transacción, `busySlots/{id}` pasa a tener el nuevo `start` y `end` (RF-26). Las demás clientas lo reciben en vivo por `watchBusySlots`: la hora antigua queda libre y la nueva, ocupada, sin recargar.
- No hay índices nuevos: la transacción lee el turno por su id y la comprobación previa usa las mismas consultas que la 005.

### Reglas (`firestore.rules`)
```
// Margen de edición del salón (RF-21): 0 si no hay documento o campo.
function editMarginMinutes() {
  let path = /databases/$(database)/documents/settings/calendar;
  return exists(path) ? get(path).data.get('editMarginMinutes', 0) : 0;
}

match /appointments/{id} {
  // get, list, create y delete: sin cambios (spec 005).
  allow update: if
    // La admin: solo el estado (005, RF-56).
    (isAdmin() && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status']))
    // La clienta: su turno activo y editable (RF-24).
    || (signedIn() && !isBlocked()
      && resource.data.clientId == request.auth.uid
      && resource.data.status in ['waiting_confirmation', 'confirmed']
      && resource.data.startTime > request.time + duration.value(editMarginMinutes(), 'm')
      && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['startTime', 'endTime', 'booked', 'status'])
      && request.resource.data.status == 'waiting_confirmation'
      && request.resource.data.startTime > request.time
      && request.resource.data.endTime > request.resource.data.startTime
      && getAfter(/databases/$(database)/documents/busySlots/$(id)).data.start == request.resource.data.startTime
      && getAfter(/databases/$(database)/documents/busySlots/$(id)).data.end == request.resource.data.endTime);
}

match /busySlots/{id} {
  // get, list, create y delete: sin cambios (spec 005).
  // Se cambia junto a la edición de su turno, con las mismas horas (RF-24, RF-26).
  allow update: if signedIn()
    && request.resource.data.keys().hasOnly(['start', 'end'])
    && get(/databases/$(database)/documents/appointments/$(id)).data.clientId == request.auth.uid
    && getAfter(/databases/$(database)/documents/appointments/$(id)).data.startTime == request.resource.data.start
    && getAfter(/databases/$(database)/documents/appointments/$(id)).data.endTime == request.resource.data.end;
}

match /settings/calendar {                                   // RF-25: deja de ser provisional
  allow read: if signedIn();
  allow write: if isAdmin();
}
```
- "Editable" en el servidor usa `request.time`, que es la hora del servidor. Que el turno esté **activo** (no ha terminado) queda cubierto: si empieza después de ahora más el margen, aún no ha terminado.
- El turno ocupado solo se puede cambiar si el turno es de la clienta y, tras la escritura, tiene sus mismas horas. Como la regla de `appointments` exige a su vez que el turno ocupado coincida, solo pasan las dos escrituras juntas.
- Lo que sigue fuera de las reglas (spec 012): que la nueva hora no choque con otro turno. La app lo comprueba antes de guardar (RF-12, como en la 005).
- Se comprueban a mano en el simulador: `specs/006-editar-turno/rules-check.md` (RNF-4, § 9).

## 3. Capa `lib/data/`

| Archivo | Cambio | RF |
| --- | --- | --- |
| `models/calendar_settings_model.dart` | Añade `editMarginMinutes` (por defecto 0). `fromMap` lo lee con tolerancia (falta, no entero o negativo → 0). `toMap` no lo escribe (D-4). | RF-21 |
| `models/booked_service_model.dart` | `==` y `hashCode` por valor en `BookedServiceModel` y `BookedAddonModel`, para saber si el turno cambió (RF-12). No cambia lo que se lee ni lo que se escribe. | RF-12 |
| `repositories/booking_repository.dart` | `fetchEditCheck({appointmentId, from, to})`: lee **del servidor** el turno y los turnos ocupados del día nuevo (como `fetchBookingCheck`, D-4 de la 005). `updateEditedAppointment({id, expected, start, end, booked})`: transacción que vuelve a leer el turno, comprueba `expected(actual)` y, si sigue igual, cambia el turno (`startTime`, `endTime`, `booked`, `status: 'waiting_confirmation'`) y su turno ocupado (`start`, `end`). Devuelve `false` si el turno ya no es el esperado. Tiene el mismo tiempo límite que `createAppointment`. | RF-12, RF-13, RF-15, RF-16, RF-26 |

## 4. Lógica pura (`lib/features/booking/logic/`, sin Flutter ni Firebase; RNF-1)

Todas las funciones reciben "ahora" como parámetro. Las horas son horas de pared del salón (`salon_time.dart`), salvo donde se dice "instante".

### 4.1 `booking_edit.dart` (nuevo): si un turno es editable (RF-1 a RF-3, RF-23)
```
isEditable(start: instante, now: instante, marginMinutes, isBlocked)
  = !isBlocked && now < start − marginMinutes            // margen 30, turno 10:00 → editable hasta antes de las 9:30
startsWithinEditMargin(start, now, marginMinutes)
  = now >= start − marginMinutes                          // RF-23, al reservar
```
- Se calcula con instantes, así que no depende de la zona del dispositivo (caso de RNF-1).

Lo que ve la clienta bajo su turno activo (`EditAvailability`):
```
editAvailability(isBlocked, settings: AsyncValue, start, now)
  isBlocked                  → blocked      // solo el aviso de RF-37, sin el de RF-2 (D-6)
  settings con error         → error        // RF-22: sin botón, aviso con "Reintentar"
  settings cargando          → loading      // sin botón todavía
  isEditable(...)            → editable     // RF-1
  si no                      → closed       // RF-2
```

### 4.2 `booking_edit.dart`: el turno original y sus horas (RF-5, RF-7 a RF-9)
`EditOriginal` guarda lo que había al abrir la edición: el id, el inicio y el fin (pared), el estado y lo reservado (`BookedServiceModel`). Sirve para tres cosas: como excepción a las reglas actuales (RF-5, RF-8), como "antes" del diálogo (RF-11) y para saber si alguien cambió el turno (RF-12).

```
isEditDaySelectable(day, settings, window, original)
  = isSelectableDay(day, settings, window) || day == salonDay(original.start)       // RF-5, RF-9

editFreeSlots(day, settings, busy, nowSalon, original)                               // busy: sin el propio turno (RF-7)
  slots = freeSlots(day, settings, busy, nowSalon)
  si day != salonDay(original.start): return slots
  si original.start <= nowSalon o cae dentro de un turno de busy: return slots
  si slots ya tiene original.start: return slots
  // Su hora, aunque esté fuera de la rejilla o el día ya no abra (RF-8):
  límite = min(inicio del siguiente turno ocupado del día,
               max(cierre del día si abre, original.end))                              // D-3
  return slots + FreeSlot(original.start, límite − original.start), en orden
```
- Las demás horas del día original y las de los demás días cumplen las reglas de siempre (RF-9).

### 4.3 `booking_selection.dart`: la selección en la edición (RF-4 a RF-9, RF-27 a RF-30)
- `BookingContext` añade `EditOriginal? original`. Con él:
  - `freeSlotsOf(day)` usa `editFreeSlots`;
  - en `reconcile`, el día es válido si cumple `isEditDaySelectable`. Así no salta del día original aunque esté cerrado o fuera de la ventana.
- `selectionOf(original, catalog)`: el día, la hora, el servicio y los adicionales del turno (RF-4). Si el catálogo ya está, quita lo que no esté disponible y avisa (RF-6). Si aún carga, lo hace `reconcile` cuando llega (`pendingOriginalCheck`): `itemUnavailable` si falta el servicio y `editAddonsUnavailable` si falta algún adicional.
- `requestItemInEdit(selection, context, ref)`, para "Reservar cita" con la edición abierta:
```
si ref == selection.item: sin cambios                                  // caso límite: mismo servicio
bookable = findBookable(catálogo, ref)
si catálogo cargado y bookable == null: sin cambios + itemUnavailable  // RF-30
si catálogo cargando: se guarda como petición pendiente; se aplica al llegar (005, RF-43)
si hay hora:
  slot = context.slotAt(hora)                                          // sin el propio turno
  si slot == null o !fits(bookable.duración, slot):
    sin cambios + editItemDoesNotFit(nombre, duración, slot?.cobertura ?? 0)   // RF-29
nueva = selection con item = ref y sin adicionales                     // RF-28
aviso editItemChanged(antes: draft(selection), después: draft(nueva))
```
- "Cabe" es `fits(duración, slot)` con la cobertura calculada sin el propio turno. Si dura lo mismo o menos que el anterior, cabe siempre, porque la hora original ya tenía su sitio. Si dura más, cabe solo si el tiempo de después está libre y no pasa del cierre (RF-28, RF-29).

### 4.4 `booking_edit.dart`: antes y después (RF-11, RF-17, RF-28)
```
BookingDraft { day, start, end, name: BilingualText, addons: List<BilingualText>,
               durationMinutes, totalCents, totalFrom }
draftOfOriginal(original)                  // lo guardado en el turno
draftOfSelection(selection, catalog)       // lo elegido, con los precios y la duración actuales
changedFields(antes, después) → Set<EditField>
  EditField = date | start | end | item | addons | duration | total
```
- Los nombres van en los dos idiomas (`BilingualText`): la vista los traduce al pintarlos (RF-50 de la 005, D-7 de la 005).

### 4.5 `booking_selection.dart`: avisos nuevos
`BookingNoticeKind` añade:
- `editItemChanged`, con `before` y `after` (`BookingDraft`) (RF-28);
- `editItemDoesNotFit`, con el nombre, `minutes` (duración) y `freeMinutes` (RF-29);
- `editAddonsUnavailable` (RF-6).

Cuando el servicio no está disponible se reutiliza `itemUnavailable` (RF-6, RF-30).

### 4.6 `booking_edit.dart`: comprobación al guardar (RF-12, RF-14, RF-15)
```
checkEditBeforeSave(original, current: turno leído del servidor o null, start, durationMinutes,
                    settings, busy (sin el propio), nowSalon, marginMinutes)
  current == null, cancelado, o current.end <= ahora    → notActive     // RF-15
  current difiere de original (horas, estado o booked)   → changed       // RF-15
  !isEditable(current.start, ahora, margin, false)       → notEditable   // RF-15
  slot = editFreeSlots(día de start, …).at(start)
  slot == null                                           → slotTaken     // RF-14 (005, RF-29)
  !fits(durationMinutes, slot)                           → doesNotFit    // RF-14 (005, RF-30)
  si no                                                  → ok
```
- El orden da a la clienta el motivo más útil: si la admin canceló el turno, "ya no está activo" explica más que "cambió".
- El bloqueo no está aquí. Si la bloquean, la edición se cierra en vivo (§ 5), y si llega a guardar, el servidor lo rechaza (error genérico, RF-16).

## 5. Interfaz

### Providers (`lib/features/booking/providers/`)
| Provider | Qué hace | RF |
| --- | --- | --- |
| `editTargetProvider` (`Notifier<EditOriginal?>`, nuevo) | El turno en edición, o `null`. `start(appointment)` / `end()`. Está separado de la selección para no crear un ciclo (D-2). | RF-4, RF-18 |
| `busyRangesProvider` | Quita el turno ocupado cuyo id es el del turno en edición. | RF-7 |
| `editAvailabilityProvider` (nuevo) | `editAvailability` del turno activo con la ficha, el calendario y "ahora" en vivo (cada 30 s, como la 005). | RF-1 a RF-3, RF-22 |
| `bookingScreenProvider` | Pasa el turno en edición a `bookingScreen`, que devuelve `BookingScreenEditing(active)` si el turno en edición es el activo y no está bloqueada. | RF-4, RF-18 |
| `BookingSelectionController` | Escucha `editTargetProvider`: al empezar, carga `selectionOf(original)`; al terminar, vuelve a la selección vacía (y `reconcile` elige el día de la 005, RF-1). Escucha la ficha y los turnos: si la bloquean o el turno deja de ser el activo, termina la edición; en este segundo caso avisa `editNotActive`. `requestItem` usa `requestItemInEdit` mientras hay edición. | RF-4 a RF-9, RF-27 a RF-30; casos límite |
| `freeSlotsOfDayProvider` (`Provider.family`, nuevo) | Las horas libres de un día con el contexto actual (edición o no). Lo usan `SlotGrid` y `selectedFreeSlotProvider`, para que la vista y la lógica calculen lo mismo. | RF-5, RF-7, RF-8 |
| `BookingEditor` / `bookingEditSaveProvider` (nuevo) | `save()`: `fetchEditCheck`, después `checkEditBeforeSave` y, si sale `ok`, `updateEditedAppointment` con la copia nueva (`snapshotOf`, 005). Devuelve `EditSaveResult` (`ok` con los campos cambiados, `slotTaken`, `doesNotFit`, `notEditable`, `notActive`, `changed`, `failed`). Con `slotTaken`/`doesNotFit` quita la hora y conserva lo demás. Con `notEditable`/`notActive`/`changed`/`ok` termina la edición. Con `failed` no toca nada. | RF-12 a RF-17, RF-26 |

### Turno activo (`ActiveAppointmentView`)
- Con `editable`: botón "Editar turno" (48 px como mínimo, nombre para el lector de pantalla) bajo la tarjeta. Al tocarlo, `editTargetProvider.start(appointment)` y la pestaña sube al principio (RF-1, RF-4).
- Con `closed`: el texto "ya no se puede cambiar" con el botón de WhatsApp (el mismo de `BookingBlockedNotice`) (RF-2).
- Con `error`: `BookingLoadErrorNotice(schedule: true)`, con "Reintentar" (RF-22).
- Con `blocked`: solo el aviso de bloqueo que ya existe (RF-37 de la 005; D-6).
- Todo cambia en vivo, porque `editAvailabilityProvider` depende de la ficha, el calendario y "ahora" (RF-3).

### Edición (la misma vista en Web y en Android/iOS)
`BookingView` muestra `BookingForm(editing: true)` con `BookingScreenEditing`:
- título "Editar turno" en lugar de "Reservar cita";
- calendario: deja elegir el día original aunque no cumpla las reglas, y su rango llega hasta él si está más allá de la ventana (RF-5);
- horas: las de `editFreeSlots`, sin el propio turno (RF-5, RF-7, RF-8);
- servicios, adicionales y resumen sin cambios (las reglas de la 005, RF-7);
- "Guardar cambios" (siempre activo, RF-10, como RF-24 de la 005) y, debajo, "Cancelar" (RF-18).

El diálogo de confirmación (RF-11) muestra:
- la tabla de antes y después (`EditChangesTable`): una fila por campo (fecha, inicio, fin, servicio, adicionales, duración y total);
  - en las que cambian, el valor de antes, una flecha y el de después, en negrita y con "cambia" para el lector de pantalla;
  - en las que no cambian, un solo valor;
- "El turno volverá a esperar la confirmación de Beidis";
- "Cancelar" y "Confirmar".

Al guardar (RF-17) aparece un diálogo, en Web y en Android/iOS (D-7):
- título "Cambios guardados";
- la lista de lo que cambió, o "No cambiaste nada…";
- "Tu turno vuelve a esperar la confirmación de Beidis".

La vista pasa sola al turno activo, que llega en vivo con su nuevo estado.

Los demás resultados se avisan con un `SnackBar` que también se anuncia, como en la 005:
- `slotTaken` y `doesNotFit`: los textos de la 005 (RF-14);
- `notEditable`, `notActive` y `changed`: un texto distinto para cada uno (RF-15);
- `failed`: el error sobre el color de peligro, sin detalles (RF-16).

### Desde el detalle con la edición abierta (RF-27 a RF-30)
- "Reservar cita" va a `/booking?service=<id>` como hasta ahora. `BookingView._applyRequest` llama a `requestItem`, que en la edición usa `requestItemInEdit`.
- El aviso `editItemChanged` es un `SnackBar` con las líneas "Servicio: A → B · Fin: … · Duración: … · Total: …", traducido en su `build` (RF-50).
- `editItemDoesNotFit` dice "{servicio} dura {N} y a esa hora solo hay {M} libres. Elige otra hora u otro servicio."
- Sin edición, el detalle con turno activo sigue mostrando el turno (005, RF-46).

### Salir de la edición (RF-18 a RF-20)
- **"Cancelar"**: `editTargetProvider.end()`. Se vuelve a ver el turno sin cambios.
- **Android/iOS, cambio de pestaña:** la edición vive en providers que no se descartan, así que se conserva (RF-19).
- **Web, enlace de la app:** los enlaces de la app (`context.go`) no tocan la edición (RF-19).
- **Web, atrás o adelante del navegador:** `WebShell` escucha `GoRouter.routeInformationProvider`. Si la ruta cambia por el navegador y no por la app, y sale de `/booking`, termina la edición (RF-20, D-8). Las navegaciones del navegador son las que no llevan el estado que go_router pone en las suyas.
- **Web, recargar:** se pierde el estado de la app, y la reserva vuelve a mostrar el turno (RF-20).

### Aviso del margen al reservar (RF-23)
El diálogo de confirmación de la 005 (`BookButton._confirm`, sin edición) añade una línea si `startsWithinEditMargin(start, now, margin)`: "No podrás cambiar este turno: falta menos de {margen} para que empiece." Con margen 0 nunca sale, porque una hora libre siempre es futura.

### Rutas y guardas
- **Sin rutas nuevas.** La edición no tiene dirección propia (Plataformas, RF-20).
- `resolveRedirect` no cambia.

## 6. Textos nuevos en los `.arb` (ES / PT; RNF-3, RC-1)

| Clave | ES | PT | RF |
| --- | --- | --- | --- |
| `bookingEditAction` | Editar turno | Editar horário | RF-1 |
| `bookingEditClosed` | Ya no puedes cambiar este turno porque falta poco para que empiece. Si necesitas cambiarlo, escríbenos por WhatsApp. | Você já não pode alterar este horário porque falta pouco para começar. Se precisar alterá-lo, escreva-nos pelo WhatsApp. | RF-2 |
| `bookingEditTitle` | Editar turno | Editar horário | RF-4 |
| `bookingSaveChangesAction` | Guardar cambios | Salvar alterações | RF-10 |
| `bookingEditConfirmTitle` | Confirmar cambios | Confirmar alterações | RF-11 |
| `bookingEditBefore` / `bookingEditAfter` | Antes / Después | Antes / Depois | RF-11 |
| `bookingEditChangedLabel` | cambia | muda | RF-11 (lector de pantalla) |
| `bookingEditStart` / `bookingEditEnd` | Inicio / Fin | Início / Fim | RF-11, RF-28 |
| `bookingEditNoAddons` | Ninguno | Nenhum | RF-11 |
| `bookingEditChangeLine` | {label}: {before} → {after} | {label}: {before} → {after} | RF-17, RF-28 |
| `bookingEditConfirmPending` | El turno volverá a esperar la confirmación de Beidis. | O horário voltará a aguardar a confirmação de Beidis. | RF-11 |
| `bookingEditSavedTitle` | Cambios guardados | Alterações salvas | RF-17 |
| `bookingEditSavedPending` | Tu turno vuelve a esperar la confirmación de Beidis. | Seu horário volta a aguardar a confirmação de Beidis. | RF-17 |
| `bookingEditNoChanges` | No cambiaste nada: el turno sigue igual. | Você não alterou nada: o horário continua igual. | RF-17 (caso límite) |
| `bookingEditNotEditable` | Ya no se puede cambiar el turno: falta poco para que empiece. | Já não é possível alterar o horário: falta pouco para começar. | RF-15 |
| `bookingEditNotActive` | Tu turno ya no está activo: se canceló o terminó. | Seu horário já não está ativo: foi cancelado ou terminou. | RF-15 |
| `bookingEditChangedMeanwhile` | Tu turno cambió mientras lo editabas. Revisa cómo está ahora. | Seu horário mudou enquanto você o editava. Confira como está agora. | RF-15 |
| `bookingEditSaveError` | No pudimos guardar los cambios. Inténtalo de nuevo. | Não conseguimos salvar as alterações. Tente novamente. | RF-16 |
| `bookingEditItemChanged` | Cambiaste el servicio: | Você trocou o serviço: | RF-28 |
| `bookingEditItemDoesNotFit` | {service} dura {duration} y a esa hora solo hay {free} libres. Elige otra hora u otro servicio. | {service} dura {duration} e nesse horário só há {free} livres. Escolha outro horário ou outro serviço. | RF-29 |
| `bookingEditAddonsUnavailable` | Algunos adicionales de tu turno ya no están disponibles y se quitaron. | Alguns adicionais do seu horário já não estão disponíveis e foram removidos. | RF-6 |
| `bookingEditMarginWarning` | No podrás cambiar este turno: falta menos de {margin} para que empiece. | Você não poderá alterar este horário: falta menos de {margin} para começar. | RF-23 |

Se reutilizan:
- `bookingStepDate`, `bookingStepService`, `bookingStepAddons`, `bookingDuration` y `bookingTotal`, como etiquetas de la tabla;
- `cancelAction` y `confirmAction`;
- `bookingSlotTaken` y `bookingSlotNoLongerFits` (RF-14);
- `bookingItemUnavailable` (RF-6, RF-30);
- `bookingLoadError` y `bookingRetry` (RF-22).

Las duraciones se escriben con `formatDuration` y los precios con `formatPrice`. Después se ejecuta `flutter gen-l10n`.

## 7. Decisiones técnicas

| # | Decisión | Por qué | Alternativa descartada |
| --- | --- | --- | --- |
| D-1 | La edición reutiliza `bookingSelectionProvider` y los widgets de la 005, con un contexto de edición. | Las mismas reglas (RF-7) sin duplicar la vista. Mientras hay turno activo no se puede reservar otro, así que la selección de una reserva nueva no se pierde. | Un segundo provider de selección y widgets que reciben el provider por parámetro: duplica estado y casi todos los widgets. |
| D-2 | El turno en edición vive en su propio provider (`editTargetProvider`). | `busyRangesProvider` necesita saber qué turno quitar, y el controlador de la selección escucha `busyRangesProvider`. Si el turno en edición estuviera dentro del controlador, habría un ciclo de dependencias. | Guardarlo en `BookingSelectionState`: Riverpod rechaza el ciclo. |
| D-3 | Si el día original ya no abre o la hora está fuera de la rejilla, el límite de la hora original es el cierre o el fin original, lo que sea más tarde, y nunca pasa del siguiente turno ocupado. Aclarado con el autor el 2026-11-14: en un día cerrado con otro turno más tarde, el límite es el fin original, no ese turno. | RF-8 pide que "el servicio quepa desde esa hora", pero un día cerrado no tiene cierre. Así el turno original siempre cabe, y un servicio más largo solo cabe si el salón seguía abierto. | Exigir el horario actual: el turno original dejaría de caber en su propia hora, contra RF-5 y RF-8. |
| D-4 | `editMarginMinutes` va en `settings/calendar`, y `toMap` no lo escribe. | Es "un ajuste del salón" (spec, Definiciones). El guardado de la admin con `merge: true` no lo pisa hasta que la 008 lo edite. | Un documento propio (`settings/booking`): otra lectura y otra regla para un solo número. |
| D-5 | Al guardar: comprobación previa en el servidor (como la 005) y, después, una **transacción** que vuelve a leer el turno y lo cambia solo si sigue como se abrió. | La transacción hace atómico RF-12 para el propio turno: dos dispositivos de la clienta, o la admin confirmando a la vez. Los choques con otros turnos siguen como en la 005, porque una transacción del cliente no puede leer consultas (012). | Un lote sin transacción: dos guardados casi a la vez se pisarían. |
| D-6 | Una clienta bloqueada ve solo el aviso de bloqueo, sin el de RF-2. | Los dos dicen lo mismo con dos botones de WhatsApp. El aviso de bloqueo ya explica que no puede reservar. | Mostrar los dos avisos. |
| D-7 | "Cambios guardados" es un diálogo en las dos plataformas. | Una lista de cambios no cabe bien en un `SnackBar` que se va solo, y no es fiable con lector de pantalla (el mismo motivo que el diálogo de Web de la 005). | El `SnackBar` de Android/iOS de la 005. |
| D-8 | "Atrás" del navegador se detecta en `WebShell` por la información de ruta de go_router: las navegaciones de la app llevan su estado y las del navegador no. | RF-20 distingue "atrás" (sale de la edición) de "enlace de la app" (la conserva, RF-19), y las dos sacan de `/booking`. **A comprobar en su tarea:** si go_router 18 no deja distinguirlas de forma fiable, se para y se pregunta al autor. | Dar a la edición su propia dirección (`/booking?edit`): contradice "sin dirección propia" y RF-20 al recargar. |
| D-9 | Los cambios de servicio desde el detalle no esperan a confirmarse: se aplican en la edición y se avisan con el antes y el después. | La spec pide avisar del cambio (RF-28), no confirmarlo, y la clienta aún tiene "Guardar cambios" y "Cancelar". | Un diálogo de confirmación por cada cambio: un paso más sin que la spec lo pida. |

## 8. Decisiones del autor

- **Dependencias nuevas:** ninguna.
- **Reglas (RF-24, RF-25):** se cambian `appointments` (la clienta edita su turno), `busySlots` (se cambia con su turno) y `settings/calendar` (solo la admin escribe). Ya están decididas en la spec (RF-25, decisión del 2026-11-13). Se publican y se comprueban a mano antes de dar la spec por implementada.
- **Campo nuevo `settings/calendar.editMarginMinutes`**, opcional y con 0 por defecto (§ 2).
- **Para que el autor lo revise:**
  - D-3 (el límite de la hora original);
  - D-6 (bloqueada: un solo aviso);
  - D-7 (diálogo al guardar en Android/iOS, que cambia el estilo de la 005).

## 9. Estrategia de tests

Sin Firebase real:
- `FakeBookingRepository` añade `fetchEditCheck` (turno y turnos ocupados programables, o error) y `updateEditedAppointment` (registra lo guardado; resultado `false` o error programables).
- `bookingDataOverrides` acepta un `CalendarSettingsModel` con margen.
- `clockProvider`, `salonNowProvider` y `deviceUtcOffsetProvider` se fijan como en la 005.

| Test | Cubre |
| --- | --- |
| `test/features/booking/logic/booking_edit_test.dart` (tablas) | `isEditable`: margen 0, margen 30 justo en el límite y un minuto antes, bloqueada, dispositivo en Lisboa. `startsWithinEditMargin`. `editAvailability`. `isEditDaySelectable` (día original más allá de 60 días, cerrado o bloqueado). `editFreeSlots`: el propio turno no ocupa, hora fuera de la rejilla, día cerrado con el límite de D-3, original ya pasado. `changedFields`: sin cambios, cada campo y varios a la vez. `checkEditBeforeSave`: cada resultado y su orden. RF-1 a RF-3, RF-5, RF-7 a RF-9, RF-11, RF-12, RF-14, RF-15, RF-17, RF-23, RNF-1. |
| `test/features/booking/logic/booking_selection_test.dart` (casos nuevos) | `selectionOf` (RF-4, RF-6, con el catálogo listo y cargando); `reconcile` con `original` (no salta del día original; al cambiar de día se aplican las reglas); `requestItemInEdit`: más corto, igual, más largo con hueco, más largo sin hueco, pasado el cierre, sin hora, el mismo servicio, no disponible, catálogo cargando. RF-4 a RF-9, RF-27 a RF-30. |
| `test/data/models/calendar_settings_model_test.dart` | Margen leído con tolerancia (falta, texto, negativo) y no escrito en `toMap`. RF-21. |
| `test/data/models/booked_service_model_test.dart` (casos nuevos) | Igualdad por valor. RF-12. |
| `test/features/booking/booking_edit_screen_test.dart` (`pumpApp`) | "Editar turno" visible, oculto con margen, aparece o desaparece al pasar el tiempo, al cambiar el margen y al bloquearla; texto y WhatsApp de RF-2; error del calendario con "Reintentar"; abrir la edición con todo elegido; servicio y adicional no disponibles con su aviso; "Cancelar"; bloqueo y cancelación mientras edita. RF-1 a RF-6, RF-18, RF-22; casos límite. |
| `test/features/booking/booking_edit_form_test.dart` (`pumpApp`) | Día original fuera de la ventana y cerrado elegible; su hora libre aunque esté fuera de la rejilla; otra fecha con reglas normales; la hora del propio turno no sale ocupada; "Guardar cambios" con algo sin elegir; diálogo de antes y después con lo que cambia marcado, en ES y PT, y cambio de idioma con el diálogo abierto; aviso del margen en el diálogo de una reserva nueva. RF-5, RF-7 a RF-11, RF-23. |
| `test/features/booking/booking_edit_save_test.dart` | Guardado con las horas, la copia nueva y `waiting_confirmation` (también desde confirmado); se cambia también el turno ocupado; diálogo con lo cambiado y "sin cambios"; `slotTaken`/`doesNotFit` conservan lo elegido; `notEditable`, `notActive` y `changed`, cada uno con su texto y de vuelta al turno; error y tiempo agotado conservan la edición. RF-12 a RF-17, RF-26. |
| `test/features/booking/booking_edit_detail_test.dart` (`pumpMobileApp` / `pumpWebApp`) | Desde el detalle con la edición abierta: cambia y avisa con el antes y el después; no cabe y avisa con N y M; no disponible; el mismo servicio; la pestaña o la página se conservan. RF-19, RF-27 a RF-30. |
| `test/features/booking/booking_edit_web_test.dart` (`pumpWebApp`) | Un enlace de la app y la vuelta conservan la edición; "atrás" del navegador (mensaje de plataforma `pushRouteInformation`) la cierra. RF-19, RF-20. |
| `test/features/booking/booking_edit_accessibility_test.dart` | Contraste, 48 px y nombres en los dos temas (botón, "Guardar cambios", "Cancelar", diálogo de antes y después); "cambia" anunciado; avisos anunciados; texto al 200 % y 320 px en ES y PT. RNF-2. |
| `test/features/booking/booking_texts_test.dart` (casos nuevos) | Las claves nuevas existen en ES y en PT. RNF-3. |
| `test/core/firestore_rules_test.dart` (casos nuevos) | Estructura: `editMarginMinutes()`; `update` de `appointments` con la rama de la clienta (`!isBlocked()`, propia, activa, margen, `hasOnly` de los cuatro campos, `waiting_confirmation`, `getAfter` del turno ocupado); `update` de `busySlots`; `settings/calendar` con lectura con sesión y escritura de la admin, sin "PROVISIONAL". RF-24, RF-25, RNF-4. |
| `specs/006-editar-turno/rules-check.md` | Casos del simulador. Clienta: edita su turno activo → permitido; edita uno ajeno, cancelado, dentro del margen o estando bloqueada → denegado; cambia `clientName` o deja `confirmed` → denegado; turno sin su turno ocupado → denegado. Turno ocupado cambiado solo, o ajeno → denegado. Calendario: clienta escribe → denegado; admin escribe → permitido; clienta lee → permitido. Después, recorrido de lo que ya existía (005, RF-58). RF-24, RF-25. |
| Tests de la 005 que cambian | `firestore_rules_test` (el calendario deja de ser provisional), `booking_screen_states_test` (el turno activo tiene el botón) y `booking_accessibility_test`, si el botón entra en sus pantallas. |

## 10. Cobertura

| RF / RNF | Dónde |
| --- | --- |
| RF-1 a RF-3 | `isEditable`, `editAvailabilityProvider`, `ActiveAppointmentView` |
| RF-4 a RF-6 | `editTargetProvider`, `selectionOf`, `BookingScreenEditing` |
| RF-7 a RF-9 | `editFreeSlots`, `isEditDaySelectable`, `BookingContext.original`, `busyRangesProvider` sin el propio turno |
| RF-10, RF-11 | `BookButton` en edición, `missingParts`, `EditChangesTable`, `changedFields` |
| RF-12 a RF-17, RF-26 | `checkEditBeforeSave`, `BookingEditor`, `fetchEditCheck`, `updateEditedAppointment` (transacción), diálogo y avisos |
| RF-18 a RF-20 | "Cancelar", providers que no se descartan, escucha del navegador en `WebShell` (D-8) |
| RF-21, RF-22 | `CalendarSettingsModel.editMarginMinutes`, `editAvailability` con error |
| RF-23 | `startsWithinEditMargin` en el diálogo de la 005 |
| RF-24, RF-25 | `firestore.rules`, `rules-check.md` |
| RF-27 a RF-30 | `requestItemInEdit`, avisos `editItemChanged`, `editItemDoesNotFit` e `itemUnavailable` |
| RNF-1 | Tablas de `booking_edit_test.dart` y `booking_selection_test.dart` |
| RNF-2 | `booking_edit_accessibility_test.dart` |
| RNF-3 | `.arb` ES/PT y `flutter gen-l10n` |
| RNF-4 | `rules-check.md` y `firestore_rules_test.dart` |
| RC-1 a RC-4 | Textos en los `.arb` y fechas con `intl` (RC-1); `context.brand` en los dos temas (RC-2); idioma de la app (RC-3); la misma edición en Web y en Android/iOS, dentro de la página de reserva y de la pestaña Reservas (RC-4) |

Al terminar, `CLAUDE.md` debe recoger:
- que `settings/calendar` ya no es provisional;
- que la clienta puede editar su turno;
- el margen de edición.

# Plan 005 — Reservas
Estado: aprobada

Spec: `specs/005-reservas/spec.md` (aprobada el 2026-11-02).

## 1. Qué existe ya en el código

| Pieza | Estado | Qué hace este plan |
| --- | --- | --- |
| `BookingView` (`lib/features/booking/presentation/booking_view.dart`) | Paso "Servicio" con 3 chips fijos (`_serviceOptions`), `TableCalendar` de 90 días, rejilla de horas, botón "Confirmar a las…" desactivado sin hora, diálogo de confirmación, diálogo de Web "Volver al inicio" (spec 002, RF-22) y aviso en Android/iOS | Se rehace como **vista de reserva** (RF-1 a RF-32). Se conservan el diálogo de Web, el calendario (`table_calendar`) con su estilo e idioma, y el aviso sin sesión. |
| `BookingSignInPrompt` | Aviso sin sesión en la pestaña (spec 003) | Sin cambios. |
| `availableSlotsProvider`, `selectedDateProvider`, `appointmentsForDateProvider` (`booking_provider.dart`) | Huecos de duración global, hora del dispositivo, `DateTime.now()` dentro | Se **borran**. Los sustituyen la lógica pura de § 4 y los providers de § 5. |
| `BookingRepository` | `createAppointment` (un `set`), `getActiveAppointmentsForDate` (lee turnos ajenos completos), `getAppointmentsForDate` (admin), `getClientAppointments`, `updateAppointmentStatus` | Escritura en lote con el turno ocupado, lecturas de turnos ocupados, comprobación previa desde el servidor y cancelación que libera la hora (§ 3). `getActiveAppointmentsForDate` se borra. |
| `AppointmentModel` | Sin lo reservado; importa `cloud_firestore` por `Timestamp` | Añade `booked` (lo reservado) y deja de importar Firebase (D-6). |
| `CalendarSettingsModel` / `ConfigRepository` | Horario por día (`'HH:mm'`), fechas bloqueadas `yyyy-MM-dd`, duración global | Sin cambios. La duración global deja de usarse en la reserva (la spec 010 decide qué hacer con ella). |
| `weekdayKey()` | Clave del día en inglés | Se reutiliza con la fecha del salón. |
| `currentUserProvider` | `FutureProvider`: lee la ficha una vez por sesión | Pasa a `StreamProvider` sobre la ficha (RF-38, D-5). |
| `priceListStateProvider` / `currentPriceListProvider`, `formatPrice`, `formatDuration`, `BilingualText.of` (spec 004) | Existen | La reserva los reutiliza (RF-10, RF-22, RF-47, RF-50). |
| `PriceListUnavailableNotice` (con "Reintentar" y WhatsApp) | Existe | Se reutiliza para RF-47. Su estructura (`_Notice`, `_WhatsappButton`) se extrae para los avisos de RF-48 y RF-49 (§ 5). |
| "Reservar cita" en el hero, contacto, Servicios, detalle, barra superior y Perfil | Todos hacen `context.go('/booking')` | El detalle pasa a `/booking?service=<id>` o `?combo=<id>` (RF-40). Los demás no cambian (RF-45). |
| `resolveRedirect` / `safeNext` | `next` es solo la ruta, sin query | Conserva la query de la reserva (RF-41, RF-42). |
| `AdminDashboardView._AppointmentCard` | Nombre, WhatsApp, horas y estado | Añade lo reservado y los adicionales (RF-52). |
| `firestore.rules` | Usuarias y turnos: provisional "con sesión" | Reglas de turnos, turnos ocupados y usuarias (RF-53 a RF-57). |
| `firestore.indexes.json` | No existe | Se crea con el índice de "mis turnos" (§ 2). |
| Tests de reserva (`test/features/booking/*`, `error_messages_test`, `fake_session.bookingOverrides`) | Sobreescriben `availableSlotsProvider` y `selectedDateProvider` | Se adaptan a los providers nuevos. |

## 2. Datos en Firestore (RF-27, RF-28, RF-51, RF-53 a RF-57)

La base de datos se borra antes de publicar las reglas (RF-51), así que no hay migración. La lectura sigue siendo tolerante (constitución, principio 5): un turno sin `booked` se lee igual, con `booked == null`.

### `appointments/{uuid}`: se añade `booked`
```
appointments/{uuid}
  clientId, clientName, clientPhone, clientPhotoUrl   # sin cambios
  startTime, endTime: timestamp                     # instantes; fin = inicio + duración del servicio
  status: 'waiting_confirmation' | 'confirmed' | 'cancelled'
  createdAt: timestamp
  booked: {                                         # NUEVO: copia de lo reservado (RF-27, RF-28)
    kind: 'service' | 'combo',
    id: string,                                     # id en la lista de precios, solo como referencia
    name: { es, pt },
    priceCents: int,
    priceFrom: bool,                                # false en combos
    durationMinutes: int,
    addons: [ { id, name: { es, pt }, priceCents: int } ]   # vacío en combos
  }
```
- Es una copia y no una referencia, para que no cambie aunque la admin edite o borre el servicio (RF-28).

### `busySlots/{uuid}`: nueva colección (RF-53, D-1)
```
busySlots/{uuid}          # el mismo id que su turno
  start: timestamp
  end: timestamp
```
- Contiene solo el inicio y el fin de cada turno que está esperando confirmación o confirmado. Las clientas calculan las horas libres con ella, sin leer los turnos ajenos.
- Se crea en el mismo lote que el turno. Cuando la admin cancela un turno, se borra en el mismo lote que el cambio de estado. Confirmar no la toca.
- Los turnos pasados se quedan; la consulta solo pide la ventana de reserva.

### Consultas
- **Turnos ocupados de la ventana:** `busySlots` con `start` entre el inicio de hoy y el final del día 60, en hora del salón. Es un rango sobre un solo campo, con índice automático.
- **Mis turnos:** `appointments` con `clientId == uid`, ordenados por `startTime` descendente. Ya existe (Perfil). Necesita un índice compuesto, que hoy solo está en la consola: se declara en `firestore.indexes.json`, y `firebase.json` añade `"indexes": "firestore.indexes.json"`.
- **Turnos del día para la admin:** sin cambios.

### Reglas (`firestore.rules`)
```
function signedIn() { return request.auth != null; }
function myProfile() { return get(/databases/$(database)/documents/users/$(request.auth.uid)).data; }
function isAdmin()  { return signedIn() && myProfile().role == 'admin'; }      // ya existe
function isBlocked() { return myProfile().get('isBlocked', false) == true; }

match /users/{userId} {                                        // RF-57
  allow get, list: if isAdmin() || (signedIn() && request.auth.uid == userId);
  allow create: if signedIn() && request.auth.uid == userId
    && request.resource.data.get('role', 'cliente') == 'cliente'
    && request.resource.data.get('isBlocked', false) == false;
  allow update: if isAdmin() || (signedIn() && request.auth.uid == userId
    && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role', 'isBlocked']));
  allow delete: if false;
}

match /appointments/{id} {
  allow get, list: if isAdmin()                                 // RF-56
    || (signedIn() && resource.data.clientId == request.auth.uid);  // RF-53
  allow create: if signedIn() && !isBlocked()                   // RF-54
    && request.resource.data.clientId == request.auth.uid
    && request.resource.data.status == 'waiting_confirmation'
    && request.resource.data.endTime > request.resource.data.startTime
    && getAfter(/databases/$(database)/documents/busySlots/$(id)).data.start == request.resource.data.startTime
    && getAfter(/databases/$(database)/documents/busySlots/$(id)).data.end == request.resource.data.endTime;
  allow update: if isAdmin()                                    // RF-56; RF-55: la clienta no
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status']);
  allow delete: if false;                                       // RF-55
}

match /busySlots/{id} {
  allow get, list: if signedIn();                               // solo inicio y fin (RF-53)
  allow create: if signedIn()
    && request.resource.data.keys().hasOnly(['start', 'end'])
    && getAfter(/databases/$(database)/documents/appointments/$(id)).data.clientId == request.auth.uid
    && getAfter(/databases/$(database)/documents/appointments/$(id)).data.startTime == request.resource.data.start
    && getAfter(/databases/$(database)/documents/appointments/$(id)).data.endTime == request.resource.data.end;
  allow delete: if isAdmin();                                   // al cancelar
  allow update: if false;
}
```
- `getAfter` obliga a crear el turno y su turno ocupado juntos y con las mismas horas. Así nadie puede ocupar horas sin un turno a su nombre, ni crear un turno sin ocupar su hora.
- `users`: la app ya crea la ficha con `role: 'cliente'` e `isBlocked: false` (`AuthController`), y la clienta solo cambia `phoneNumber` (y `fcmToken` en la 011). Inicio de sesión, captura de WhatsApp y bloqueo siguen funcionando (RF-58).
- **`settings/calendar` sigue con la regla provisional "con sesión":** sus reglas no son de esta spec (010/012). El comentario de cabecera pasa a decir "hasta la spec 012" (pendiente de `MEMORY.md`).
- **Fuera de las reglas (spec 012):** solapes y un segundo turno activo. La app los comprueba antes de guardar (§ 4.6).
- Se comprueban a mano en el simulador, caso por caso: `specs/005-reservas/rules-check.md` (§ 9, RNF-5).

## 3. Capa `lib/data/`

| Archivo | Cambio | RF |
| --- | --- | --- |
| `models/booked_service_model.dart` (nuevo) | `BookedServiceModel` (`kind`, `id`, `name: BilingualText`, `priceCents`, `priceFrom`, `durationMinutes`, `addons: List<BookedAddonModel>`) y `BookedAddonModel`, con `fromMap`/`toMap` tolerantes como los de la 004. Sin Firebase. | RF-27, RF-28 |
| `models/busy_slot_model.dart` (nuevo) | `BusySlot(id, start, end)`, sin Firebase. | RF-4, RF-6 |
| `models/appointment_model.dart` | Añade `BookedServiceModel? booked`. Las fechas pasan a ser `DateTime` en `fromMap`/`toMap`: la conversión de `Timestamp` la hace el repositorio (D-6). | RF-27, RF-51 |
| `repositories/booking_repository.dart` | `watchBusySlots(from, to)` (stream). `createAppointment(appointment)`: lote con `appointments/{id}` y `busySlots/{id}`. `fetchBookingCheck(uid, dayStart, dayEnd)`: lee **del servidor** (`Source.server`) los turnos ocupados del día y los turnos de la clienta, para la comprobación previa (RF-26); sin conexión, falla (RF-31). `updateAppointmentStatus`: con `'cancelled'`, lote que cambia el estado y borra el turno ocupado. Se borra `getActiveAppointmentsForDate`. | RF-6, RF-26, RF-27, RF-31, RF-56 |
| `repositories/user_repository.dart` | `watchUser(uid)` (stream de la ficha). | RF-38 |

- Todas las fechas se guardan como instantes (`Timestamp`). La hora del salón solo existe en la lógica y en la interfaz (§ 4.1).
- `createAppointment` tiene un tiempo límite (15 s). Si se agota, el error es el de RF-31, en lugar de dejar la escritura sin respuesta. El caso de una escritura que llega después se trata en § 7 (D-8).

## 4. Lógica pura (`lib/features/booking/logic/`, sin Flutter ni Firebase; RNF-1)

Todas las funciones reciben "ahora" como parámetro.

### 4.1 `salon_time.dart`: hora del salón
```
salonOffset = −3 h                       // Curitiba, sin horario de verano
toSalon(instante)  → DateTime.utc(campos de la hora de Curitiba)   // "hora de pared"
fromSalon(pared)   → instante = pared(utc) + 3 h
salonDay(pared)    → DateTime.utc(año, mes, día)
deviceIsInSalonZone(offsetDelDispositivo) → offset == −3 h          // RF-5
```
- La "hora de pared" es un `DateTime` UTC cuyos campos son la hora de Curitiba. No depende de la zona del dispositivo, y `DateFormat` la muestra tal cual.

### 4.2 `booking_window.dart`: ventana y días
```
bookingWindow(ahoraSalón) → (primero: salonDay(ahora), último: primero + 60 días)
isSelectableDay(día, ajustes, ventana) =
    día dentro de la ventana
  ∧ no está en ajustes.blockedDates (yyyy-MM-dd del salón)
  ∧ dayGrid(día, ajustes) != null                      // RF-3; cierre ≤ apertura = cerrado
dayGrid(día, ajustes) → lista de inicios cada 30 min desde la apertura y antes del cierre,
                        o null si el día está cerrado o cierre ≤ apertura
initialDay(ahora, ajustes, ocupados) →                 // RF-1, RF-2
    primer día seleccionable con alguna hora libre;
    si no hay, el primer día seleccionable;
    si no hay ninguno, null (RF-2)
```

### 4.3 `free_slots.dart`: horas libres y cobertura (RF-4, RF-12, RF-15)
```
freeSlots(día, ajustes, ocupados, ahoraSalón) → List<FreeSlot(inicio, coberturaMin)>
  rejilla = dayGrid(día) ?? []
  turnos = ocupados del día (en hora del salón), ordenados por inicio
  para cada h en rejilla:
    si h ≤ ahora: siguiente                            // "igual a ahora" no es libre
    si ∃ t: t.inicio ≤ h < t.fin: siguiente            // cae dentro de un turno ocupado
    límite = min(inicio del primer turno con inicio > h, cierre)
    añadir FreeSlot(h, minutos(límite − h))
fits(duraciónMin, slot) = duraciónMin ≤ slot.coberturaMin
```
- Ejemplo de la spec: turno de 8:00 a 9:10 → 8:00, 8:30 y 9:00 quedan dentro; 9:30 es libre.

### 4.4 `bookable_catalog.dart`: qué se puede reservar (RF-10, RF-11, RF-17 a RF-21)
```
bookableCatalog(lista) → BookableCatalog(
    categorías: [ (categoría, servicios visibles, adicionales visibles) ]   // solo categorías visibles con ≥ 1 servicio visible
    combos: combos visibles)
findBookable(catálogo, ref(kind, id)) → servicio | combo | null
availableAddons(catálogo, ref) → adicionales visibles de su categoría; [] si es un combo
totalPrice(elegido, adicionales) → (céntimos, desde: elegido.priceFrom)     // RF-22
snapshotOf(elegido, adicionales) → BookedServiceModel                       // RF-27
```

### 4.5 `booking_selection.dart`: lo elegido y su conciliación
```
BookingSelection(día?, inicio?, item: BookableRef?(kind, id), addonIds: Set)

reconcile(selección, contexto) → (selección', avisos)       // contexto: catálogo, ajustes, ocupados, ahora
  si día == null o !isSelectableDay(día) o día fuera de la ventana:
     día = initialDay(…); inicio = null
     aviso dateMoved si antes había día                        // casos límite: bloqueo, medianoche
  si item != null y findBookable == null: item = null; addons = ∅; aviso itemUnavailable   // RF-17
  addons = addons ∩ availableAddons(item)                     // RF-21 (sin aviso)
  si inicio != null:
     slot = freeSlots(día).buscar(inicio)
     si slot == null: inicio = null; aviso slotGone           // RF-9
     si no, si item != null y !fits(item.duración, slot): inicio = null; aviso slotTooShort   // RF-16

selectDay(día)       → día; inicio = null                     // RF-8
selectSlot(slot)     → rechaza con aviso slotTooShortFor si hay item y no cabe            // RF-15
selectItem(ref)      → rechaza con aviso needsLongerSlot(duración) si no cabe en el inicio // RF-13
                       si se acepta: addons = ∅                                           // RF-20
requestItem(ref)     → item = ref, addons = ∅; inicio se conserva solo si cabe            // RF-40
                       (si no, inicio = null y aviso slotTooShort)
missingParts(sel)    → {slot, item}                                                       // RF-24
```
- Los avisos son datos (`BookingNotice` + parámetros), no textos: la vista los traduce al mostrarlos (RF-50).

### 4.6 `booking_rules.dart`: turno activo y comprobación al confirmar
```
activeAppointment(misTurnos, ahora) → el primero con fin > ahora y estado activo, o null   // definición; RF-33, RF-35
checkBeforeSave(inicio, duraciónMin, ocupadosDelDía, misTurnos, ahora) →
    alreadyActive    si activeAppointment(misTurnos, ahora) != null      // RF-36
    slotTaken        si inicio ≤ ahora o cae dentro de un ocupado        // RF-29
    doesNotFit       si la cobertura de inicio < duración                // RF-30
    ok
bookingScreen(sesión, ficha, misTurnos, ahora) →                          // RF-33, RF-37, RF-39, RF-49
    loading | signedOut | error | admin | active(turno, bloqueada?) | blocked | booking
```
- Orden de `bookingScreen`: cargando → sin sesión → error (ficha o mis turnos) → admin → turno activo (con el aviso de bloqueo si lo está, RF-37) → bloqueada → vista de reserva.

## 5. Interfaz

### Providers (`lib/features/booking/providers/booking_provider.dart`)
| Provider | Tipo | Qué hace | RF |
| --- | --- | --- | --- |
| `bookingRepositoryProvider`, `configRepositoryProvider`, `calendarSettingsProvider` | existen | Sin cambios. | |
| `clockProvider` | `Provider<DateTime Function()>` | `DateTime.now` (los tests lo sustituyen). | RNF-1 |
| `salonNowProvider` | `StreamProvider<DateTime>` | "Ahora" del salón, cada 30 s: así se actualiza cuando una hora pasa, cuando termina el turno activo y a medianoche. | RF-9, RF-35 |
| `deviceUtcOffsetProvider` | `Provider<Duration>` | Diferencia del dispositivo con UTC. | RF-5 |
| `busySlotsProvider` | `StreamProvider<List<BusySlot>>` | Turnos ocupados de la ventana, en vivo. | RF-6, RF-48 |
| `bookableCatalogProvider` | `Provider<PriceView<BookableCatalog>>` | Sobre `currentPriceListProvider` (cargando / no disponible / listo). | RF-10, RF-11, RF-43, RF-47 |
| `myAppointmentsProvider` | `StreamProvider` | Mis turnos. Sustituye a `clientAppointmentsProvider` (Perfil lo usa, con el mismo contenido). | RF-33, RF-49 |
| `bookingScreenProvider` | `Provider` | `bookingScreen(…)` de § 4.6. | RF-33 a RF-39, RF-49 |
| `bookingSelectionProvider` | `NotifierProvider<BookingSelectionController, BookingSelectionState>` | Lo elegido y los avisos pendientes. Escucha catálogo, ajustes, ocupados y ahora, y aplica `reconcile`. No es `autoDispose`: lo elegido se conserva al cambiar de pestaña o de página (RF-45). | RF-1, RF-8, RF-9, RF-12 a RF-21, RF-40, RF-45 |
| `bookingSubmitProvider` | controlador | `confirm()`: `fetchBookingCheck` → `checkBeforeSave` → `createAppointment`. Devuelve `ok`, `slotTaken`, `doesNotFit`, `alreadyActive` o `failed`. | RF-26 a RF-31, RF-36 |

- `currentUserProvider` (`auth_provider.dart`) pasa a `StreamProvider` sobre `watchUser`. Las redirecciones siguen esperando con `isLoading` (CLAUDE.md). La invalidación tras `saveUser` y tras guardar el WhatsApp deja de hacer falta, pero se mantiene: es inofensiva.
- Los controladores nuevos usan `Notifier` de Riverpod 3, sin `legacy.dart`.

### Vista de reserva (la misma en Web y en Android/iOS)
`BookingView` se queda con el cambio de estado de pantalla, y cada estado es su propio widget, bajo `lib/features/booking/presentation/`:

| Widget | Contenido | RF |
| --- | --- | --- |
| `BookingView` | `switch (bookingScreen)`: progreso, `BookingSignInPrompt`, `BookingLoadErrorNotice`, `BookingAdminNotice`, `ActiveAppointmentView`, `BookingBlockedNotice`, `BookingForm`. Escucha los avisos de la selección y los muestra en un `SnackBar`, que también se anuncia al lector de pantalla. | RF-33, RF-37 a RF-39, RF-49, RNF-2 |
| `BookingForm` | `ListView` (con `tabScrollControllerProvider(MobileTab.booking)`) con calendario, horas, servicios, adicionales, resumen y "Agendar turno". | RF-1, RF-23 |
| `BookingCalendar` | El `TableCalendar` actual con `firstDay`/`lastDay` de la ventana y `enabledDayPredicate = isSelectableDay`. Sin días seleccionables, texto y WhatsApp en su lugar. | RF-2, RF-3 |
| `SlotGrid` | Horas libres (`Hm` de la hora de pared), "Hora de Curitiba" si el dispositivo está en otra zona, texto si no hay horas, y horas sin tiempo suficiente desactivadas (se pueden tocar y avisan). Con error de calendario o de turnos ocupados, `BookingLoadErrorNotice` en su lugar. | RF-4 a RF-7, RF-15, RF-48 |
| `ServicePicker` | Categorías con sus servicios y, después, los combos, con nombre, precio y duración. Los que no caben se ven desactivados, se pueden tocar y avisan. Con la lista no disponible, `PriceListUnavailableNotice`. | RF-10 a RF-14, RF-47 |
| `AddonPicker` | Casillas con los adicionales del servicio elegido. No aparece con un combo. | RF-18 a RF-20 |
| `BookingSummary` | Fecha, inicio y fin, lo reservado, adicionales, duración y total. Solo aparece con una hora o un servicio elegidos. | RF-22 |
| `BookButton` | "Agendar turno", siempre activo. Si falta algo, avisa y marca cada sección que falta (borde y texto de error). Si está todo, abre el diálogo de confirmación con el resumen y el texto de "esperando confirmación". | RF-23 a RF-25 |
| `ActiveAppointmentView` | Lo reservado con sus adicionales, fecha, inicio y fin, total, estado, y el texto "solo un turno pendiente a la vez". Para una bloqueada, también el aviso de RF-37. | RF-33, RF-34, RF-37, RF-46 |
| `BookingLoadErrorNotice`, `BookingBlockedNotice`, `BookingAdminNotice` | Avisos con "Reintentar" (invalida los providers que fallaron) y/o WhatsApp. Usan el `_Notice` de `price_list_notices.dart`, que pasa a ser público como `AppNotice` (refactor sin cambio de comportamiento). | RF-37, RF-39, RF-48, RF-49 |

- Tras confirmar: con `ok`, en Android/iOS el `SnackBar` de hoy, y en Web el diálogo de hoy (RF-32). La vista pasa sola a `ActiveAppointmentView`, porque `myAppointmentsProvider` está en vivo. Con `slotTaken` o `doesNotFit`, se quita la hora, se conservan lo reservado y la fecha, y se avisa (RF-29, RF-30). Con `alreadyActive`, se avisa, y la vista ya muestra el turno que tiene (RF-36). Con `failed`, se avisa sin detalles técnicos (al log, `debugPrint`) y se conserva todo (RF-31).
- **Idioma (RF-50):** nombres con `BilingualText.of(l10n.localeName)` en `build`. Los diálogos leen sus textos dentro del `builder`, y el contenido de los `SnackBar` es un widget que traduce el aviso en su `build`, así que también cambia de idioma con el aviso abierto.
- **Accesibilidad (RNF-2):**
  - horas, servicios y adicionales miden al menos 48 px y tienen `Semantics` con nombre, estado elegido, y "no disponible" en los desactivados;
  - los desactivados usan `inkMuted`, que cumple el contraste en los dos temas, y no `Opacity`;
  - los avisos se anuncian con `SemanticsService.announce` además del `SnackBar`.
- **Texto grande y 320 px (RNF-3):** las horas van en un `Wrap`, que pasa a otra fila, en lugar de la rejilla fija de 3 columnas con 46 px de alto. Los servicios son filas que crecen. Nada se reduce por debajo de 48 px.

### Hora del salón en la vista
- `TableCalendar` trabaja con fechas locales: se le pasan `DateTime(año, mes, día)` construidas con los campos del día del salón, y se convierten de vuelta con `DateTime.utc(…)`. Así el día elegido no depende de la zona del dispositivo.

### Rutas y guardas (RF-40 a RF-42, RF-45)
- **Dirección:** `/booking?service=<id>` o `/booking?combo=<id>`, en las dos plataformas. Las rutas `/booking` (Web y la rama de Android/iOS) pasan `BookableRef?` a `BookingView`. Cuando la referencia cambia, la vista llama a `requestItem` una vez, en el fotograma siguiente. Con la lista de precios cargando, la petición queda pendiente y se aplica al llegar (RF-43). Si el servicio no existe, no está disponible o el id no es válido, no se elige nada y se avisa (RF-44).
- **"Reservar cita" del detalle** (`_ReserveButton` de `price_detail_view.dart`): `context.go('/booking?service=<id>')` o `?combo=<id>`. En Android/iOS, `go` a `/booking` cambia a la pestaña Reservas. Los demás botones siguen con `/booking`, que conserva lo elegido (RF-45).
- **`redirect_logic.dart`:**
  - `_withNext` usa la ruta **con su query**;
  - `safeNext` acepta `/booking` con una sola clave `service` o `combo` cuyo id cumpla `^[A-Za-z0-9_-]{1,64}$`, y descarta cualquier otra query. Así un enlace manipulado sigue sin poder sacar a la persona de la app (spec 002, D-4).
  - En Web: sin sesión → `/login?next=/booking?service=x` → `/capture_phone?next=…` → `/booking?service=x` (RF-41, RF-42). En Android/iOS, la pestaña muestra el aviso de sesión con la petición ya registrada, y la captura del WhatsApp vuelve a `/booking?service=x`.
- **Web, "atrás":** `go` desde el detalle sustituye la página. "Atrás" del navegador vuelve a la dirección anterior (el detalle), como pide la spec.
- **Recargar en Web:** la dirección vuelve a aplicar su servicio; lo demás se pierde, porque el estado está en memoria (spec, Plataformas).

### Lista de la admin (RF-52)
- `AdminDashboardView._AppointmentCard` añade una línea con lo reservado (nombre en el idioma activo) y los adicionales. Sin `booked`, no añade nada.
- Cancelar libera la hora (§ 3).

### Limpieza
- Se borran `_ServiceOption`, `_serviceOptions`, `_ServiceChip`, `availableSlotsProvider`, `selectedDateProvider`, `appointmentsForDateProvider` y `getActiveAppointmentsForDate`, y las claves `.arb` que solo usaban ellos: `serviceOption*`, `stepServiceLabel`, `chooseTimeSlotAction`, `confirmAtTimeAction`, `confirmBookingDialogBody` (se sustituye) y `slotsLoadError` (se sustituye por el aviso de RF-48). Se comprueba antes con `grep -w` que no tienen otros usos.
- `legacy_cleanup_test.dart` comprueba que ya no están.

## 6. Textos nuevos en los `.arb` (ES / PT; RNF-4, RC-1)

| Clave | ES | PT |
| --- | --- | --- |
| `bookingStepDate` | Fecha | Data |
| `bookingStepTime` | Hora | Horário |
| `bookingStepService` | Servicio | Serviço |
| `bookingStepAddons` | Adicionales | Adicionais |
| `bookingStepSummary` | Resumen | Resumo |
| `bookingSalonTimeNote` | Horas de Curitiba | Horários de Curitiba |
| `bookingNoDaysAvailable` | No hay fechas disponibles para reservar. Escríbenos por WhatsApp. | Não há datas disponíveis para agendar. Fale conosco pelo WhatsApp. |
| `bookingNoFreeSlots` | No quedan horas libres este día. Prueba otra fecha. | Não há horários livres neste dia. Tente outra data. |
| `bookingServiceNeedsLongerSlot(duration)` | Este servicio dura {duration}: elige una hora con más tiempo libre. | Este serviço dura {duration}: escolha um horário com mais tempo livre. |
| `bookingSlotTooShortFor(duration)` | No hay tiempo suficiente a esta hora para un servicio de {duration}. | Não há tempo suficiente neste horário para um serviço de {duration}. |
| `bookingSlotGone` | La hora elegida ya no está disponible. Elige otra. | O horário escolhido não está mais disponível. Escolha outro. |
| `bookingSlotNoLongerFits` | La hora elegida ya no tiene tiempo suficiente para el servicio. Elige otra. | O horário escolhido não tem mais tempo suficiente para o serviço. Escolha outro. |
| `bookingItemUnavailable` | El servicio elegido ya no está disponible. | O serviço escolhido não está mais disponível. |
| `bookingDateMoved` | La fecha elegida ya no se puede reservar: te mostramos la siguiente disponible. | A data escolhida não pode mais ser agendada: mostramos a próxima disponível. |
| `bookingUnavailableLabel` | no disponible | indisponível |
| `bookingMissingSlot` | Elige una hora | Escolha um horário |
| `bookingMissingService` | Elige un servicio | Escolha um serviço |
| `bookingMissingBoth` | Elige una hora y un servicio para agendar. | Escolha um horário e um serviço para agendar. |
| `bookingAction` | Agendar turno | Agendar horário |
| `bookingConfirmTitle` | Confirmar turno | Confirmar horário |
| `bookingConfirmPending` | El turno quedará esperando la confirmación de Beidis. | O horário ficará aguardando a confirmação da Beidis. |
| `bookingSlotTaken` | Esa hora acaba de ocuparse. Elige otra. | Esse horário acabou de ser ocupado. Escolha outro. |
| `bookingAlreadyActive` | Ya tienes un turno pendiente. | Você já tem um horário pendente. |
| `bookingActiveTitle` | Tu turno | Seu horário |
| `bookingOnlyOneActive` | Solo puedes tener un turno pendiente a la vez. Puedes ver todos tus turnos en tu perfil. | Você só pode ter um horário pendente por vez. Veja todos os seus horários no seu perfil. |
| `bookingBlocked` | Tu cuenta no puede reservar turnos. Si crees que es un error, escríbenos por WhatsApp. | Sua conta não pode agendar horários. Se acha que é um erro, fale conosco pelo WhatsApp. |
| `bookingAdminNotice` | Con la cuenta de administración no se reservan turnos a tu nombre. | Com a conta de administração não se agendam horários em seu nome. |
| `bookingLoadError` | No se pudo cargar la agenda. | Não foi possível carregar a agenda. |
| `bookingRetry` | Reintentar | Tentar novamente |
| `bookingDuration` | Duración | Duração |
| `bookingTotal` | Total | Total |
| `bookingTimeRange(start, end)` | {start} – {end} | {start} – {end} |

- Se reutilizan `priceFrom`, `pricesLoadError`/`pricesRetry` (RF-47), `bookingCreatedSuccess`, `bookingCreateError` (RF-31), `bookingCreatedWebTitle`, `bookingBackToLanding` (RF-32), los estados `statusWaitingConfirmationClient`/`statusConfirmedClient` y `cancelAction`/`confirmAction`.
- Términos decididos por el autor (§ 8): "horário" en portugués y "la confirmación de Beidis". El resto de la redacción se puede retocar en la tarea de los `.arb`.

## 7. Decisiones técnicas

| # | Decisión | Alternativa descartada |
| --- | --- | --- |
| D-1 | **Colección `busySlots`** con solo inicio y fin, un documento por turno y el mismo id, escrita en lote con el turno y validada con `getAfter`. | Un documento por día con la lista de horas: permite una transacción que evita solapes, pero las reglas no pueden comprobar que una clienta solo añade su propia entrada, así que podría borrar las de las demás. Leer `appointments` recortando campos: las reglas no pueden ocultar campos de un documento. |
| D-2 | **Una escucha de toda la ventana** (60 días) de `busySlots`. | Una escucha por día elegido: RF-1 necesita saber qué días tienen horas libres antes de elegir uno. Son pocos documentos, solo con dos fechas. |
| D-3 | **Hora del salón con desfase fijo de −3 h** ("hora de pared" en `DateTime` UTC). | Paquete `timezone`: dependencia nueva para una zona sin horario de verano (Brasil lo eliminó en 2019). Si volviera, se cambia en `salon_time.dart`. |
| D-4 | **Comprobación previa leída del servidor** (`Source.server`) antes del lote. | Comprobar con los datos en caché: sin conexión parecería libre, y la escritura quedaría en cola sin respuesta. |
| D-5 | **`currentUserProvider` pasa a `StreamProvider`** sobre la ficha (adelantado de la 009, decidido en la revisión de la spec). | Un segundo provider en vivo solo para la reserva: dos fuentes de la misma ficha que pueden no coincidir (router y reserva). |
| D-6 | **Modelos sin Firebase:** el repositorio convierte `Timestamp` ↔ `DateTime`. | Que la lógica pura importe `AppointmentModel` con `cloud_firestore`: incumple el principio 3 de la constitución. |
| D-7 | **Avisos como datos** (`BookingNotice`), traducidos al pintarse. | Textos ya traducidos en el controlador: no cambiarían de idioma con el aviso abierto (RF-50) y el controlador dependería de Flutter. |
| D-8 | **Tiempo límite de 15 s al guardar.** Si se agota, se avisa como en RF-31. Si después la escritura llega al servidor, la clienta verá su turno activo, porque `myAppointmentsProvider` está en vivo. | Esperar sin límite: con una conexión que se corta durante la escritura, la vista se quedaría cargando sin fin. |
| D-9 | La **dirección de Web lleva solo el servicio pedido** desde el detalle. Cambiar de servicio en la vista no la cambia. | Actualizar la dirección con cada cambio: la spec solo pide conservar el servicio de la dirección al recargar, y cada `go` añadiría entradas al historial. |
| D-10 | `requestItem` con una hora en la que el servicio no cabe: **quita la hora y avisa** con el texto de RF-16. | Quitarla sin avisar: la clienta no sabría por qué desaparece su hora. |
| D-11 | Las horas desactivadas y los servicios que no caben **se pueden tocar** (avisan) y se anuncian como "no disponible" en su etiqueta. | `enabled: false`: el lector de pantalla no los dejaría activar, y no oiría el porqué (RF-13, RF-15). |

## 8. Decisiones del autor
Tomadas el 2026-11-02:
1. **Modelo de datos aprobado** (CLAUDE.md pide preguntar antes de cambiar colecciones o reglas):
   - nueva colección `busySlots` (D-1);
   - campo `booked` en `appointments`;
   - `firestore.indexes.json` con el índice de "mis turnos";
   - las reglas de § 2.
2. **`currentUserProvider` pasa a `StreamProvider`** (D-5), adelantado de la 009.
3. **Sin dependencias nuevas:** desfase fijo de −3 h (D-3). `table_calendar`, `intl` y `uuid` ya están.
4. **Textos de § 6:** en portugués, el turno es "horário"; el turno espera "la confirmación de Beidis".

## 9. Estrategia de tests

Sin Firebase real:
- Los repositorios se sustituyen por fakes escritos a mano en `test/helpers/fake_booking.dart`: `FakeBookingRepository` con turnos ocupados y mis turnos en `StreamController`, resultados de la comprobación previa y errores programables, y lo guardado. La ficha usa un `FakeUserRepository.watchUser`.
- `clockProvider`, `salonNowProvider` y `deviceUtcOffsetProvider` se sustituyen con valores fijos.
- `fake_session.dart` adapta `sessionOverrides` (ficha como `Stream`) y `bookingOverrides` a los providers nuevos.

| Test | Cubre |
| --- | --- |
| `test/features/booking/logic/salon_time_test.dart` | Conversión de ida y vuelta, cambio de día (23:30 en Curitiba = 02:30 UTC del día siguiente), dispositivo en Lisboa, en Buenos Aires y en Curitiba. RF-5, RNF-1. |
| `…/logic/booking_window_test.dart` (tabla) | Ventana de 61 días, día bloqueado, cerrado, cierre ≤ apertura, apertura 8:15, `initialDay` con hoy sin horas → mañana, ninguno seleccionable → `null`. RF-1 a RF-3, RNF-1. |
| `…/logic/free_slots_test.dart` (tabla) | 8:00–9:10 → 9:30, turno 8:00–9:00 → 9:00 libre, hora = ahora, cobertura hasta el cierre, servicio que cabe justo, rejilla que no coincide con el fin del turno, apertura 8:15. RF-4, RF-12, RF-15, RNF-1. |
| `…/logic/bookable_catalog_test.dart` | Ocultos, categorías solo con adicionales, adicionales por categoría, combo sin adicionales, total con "desde", copia de lo reservado. RF-10, RF-11, RF-18, RF-19, RF-22, RF-27. |
| `…/logic/booking_selection_test.dart` (tabla) | `reconcile` y cada acción: RF-8, RF-9, RF-13, RF-15 a RF-17, RF-20, RF-21, RF-24, RF-40; fecha que deja de poderse elegir y medianoche (casos límite). |
| `…/logic/booking_rules_test.dart` (tabla) | Turno activo (en curso, pasado esperando confirmación, cancelado), `checkBeforeSave` y `bookingScreen` en su orden. RF-26, RF-29, RF-30, RF-33 a RF-37, RF-39, RF-49, RNF-1. |
| `test/data/models/booked_service_model_test.dart`, `appointment_model_test.dart` | `fromMap`/`toMap` de ida y vuelta, campos que faltan, turno sin `booked`. RF-27, RF-28, RF-51. |
| `test/features/booking/booking_form_test.dart` (`pumpApp`) | Calendario con el día inicial, horas en vivo al cambiar los turnos ocupados, indicación de Curitiba, sin horas, servicios agrupados, desactivados con su aviso, adicionales, resumen, "Agendar turno" con lo que falta marcado, diálogo de confirmación. RF-1 a RF-25. |
| `test/features/booking/booking_submit_test.dart` | Guardado con la copia correcta, `slotTaken`, `doesNotFit`, `alreadyActive`, error y tiempo agotado; aviso en Android/iOS y diálogo en Web. RF-26 a RF-32, RF-36. |
| `test/features/booking/booking_screen_states_test.dart` | Turno activo, que desaparece al terminar o cancelarse; bloqueada con y sin turno activo; bloqueo con la sesión abierta; admin; errores con "Reintentar". RF-33 a RF-39, RF-46, RF-47 a RF-49. |
| `test/features/booking/booking_from_detail_test.dart` (`pumpWebApp` / `pumpMobileApp`) | Desde el detalle con sesión, sin sesión y sin WhatsApp (Web y Android/iOS), con la lista cargando, con un id no válido o inexistente; otros "Reservar cita" conservan lo elegido; recargar en Web. RF-40 a RF-46. |
| `test/core/router/redirect_logic_test.dart` | Casos nuevos de `next` con `service`/`combo`, ids no válidos y queries extra descartadas. RF-41, RF-42. |
| `test/features/booking/booking_locale_test.dart` | Cambio de idioma con un aviso y con el diálogo abiertos. RF-50. |
| `test/features/admin/admin_appointments_booked_test.dart` | Lo reservado y los adicionales en la tarjeta, y un turno sin `booked`. RF-52. |
| `test/features/booking/booking_accessibility_test.dart` | `textContrastGuideline`, `androidTapTargetGuideline` y `labeledTapTargetGuideline` en los dos temas; semántica de elegido y de "no disponible"; avisos anunciados; texto al 200 % y 320 px en ES y PT sin desbordes. RNF-2, RNF-3. |
| `test/core/firestore_rules_test.dart` | Estructura de los `match` de `users`, `appointments` y `busySlots` (como en la 004). RNF-5. |
| `specs/005-reservas/rules-check.md` | Casos manuales del simulador. RF-53 a RF-57: leer un turno ajeno → denegado; crear sin `busySlots` o con horas distintas → denegado; bloqueada → denegado; clienta que cambia el estado o borra → denegado; admin que cancela y borra el turno ocupado → permitido; clienta que cambia su `role` o `isBlocked` → denegado. Después, el recorrido de RF-58. |
| Tests existentes adaptados | `web_booking_flow_test`, `mobile_booking_sign_in_test`, `state_preserved_test`, `localized_dates_test`, `error_messages_test`, `new_user_profile_test`, `screens_theme_test`, `legacy_cleanup_test`. RF-58. |

## 10. Cobertura

| RF / RNF | Dónde |
| --- | --- |
| RF-1 a RF-3 | `booking_window.dart`, `BookingCalendar`, `reconcile` |
| RF-4 a RF-7 | `free_slots.dart`, `salon_time.dart`, `busySlotsProvider`, `SlotGrid` |
| RF-8, RF-9 | `booking_selection.dart`, `salonNowProvider` |
| RF-10 a RF-21 | `bookable_catalog.dart`, `booking_selection.dart`, `ServicePicker`, `AddonPicker`, `SlotGrid` |
| RF-22 a RF-25 | `BookingSummary`, `BookButton`, `missingParts` |
| RF-26 a RF-32, RF-36 | `checkBeforeSave`, `bookingSubmitProvider`, `BookingRepository.fetchBookingCheck/createAppointment` |
| RF-33 a RF-35, RF-46 | `activeAppointment`, `bookingScreen`, `ActiveAppointmentView`, `myAppointmentsProvider` |
| RF-37 a RF-39 | `bookingScreen`, `currentUserProvider` en vivo, avisos de bloqueo y admin |
| RF-40 a RF-45 | `requestItem`, rutas `/booking?service|combo`, `redirect_logic.dart`, `_ReserveButton` |
| RF-47 a RF-49 | `PriceListUnavailableNotice`, `BookingLoadErrorNotice` |
| RF-50 | `BilingualText.of`, avisos como datos (D-7) |
| RF-51 | `fromMap` tolerante; borrado de la base de datos antes de publicar las reglas |
| RF-52 | `AdminDashboardView._AppointmentCard` |
| RF-53 a RF-57 | `firestore.rules`, `busySlots`, `rules-check.md` |
| RF-58 | Tests existentes adaptados y recorrido manual tras publicar las reglas |
| RNF-1 | Tests de tabla de `lib/features/booking/logic/` |
| RNF-2, RNF-3 | `booking_accessibility_test.dart` |
| RNF-4 | `.arb` ES/PT y `flutter gen-l10n` |
| RNF-5 | `rules-check.md` y `firestore_rules_test.dart` |

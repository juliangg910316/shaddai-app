# Plan 007 — Reserva de la admin
Estado: aprobada

Spec: `specs/007-reserva-admin/spec.md` (aprobada el 2026-11-16). Parte del código de las specs 005 (implementada el 2026-11-05) y 006 (implementada el 2026-11-15).

## 1. Qué existe ya en el código

| Pieza | Estado | Qué hace este plan |
| --- | --- | --- |
| `bookingScreen` / `bookingScreenProvider` (`booking_rules.dart`) | Con sesión de admin devuelve `BookingScreenAdmin` antes de mirar sus turnos, y la vista muestra `BookingAdminNotice` (005, RF-39). | `BookingScreenAdmin` pasa a mostrar el formulario de reserva en modo admin (RF-1, RF-28). Se borra `BookingAdminNotice` y su texto. La admin nunca llega a `BookingScreenActive` ni a `BookingScreenEditing`. |
| `BookingSelectionController` / `booking_selection.dart` | Día, hora, servicio y adicionales, `reconcile`, avisos como datos, `missingParts`. `BookingContext` calcula la ventana con `bookingWindow(nowSalon)`. | `BookingContext` recibe los días de la ventana: 60 para la clienta y 365 para la admin (RF-12). `missingParts` añade "para quién" en modo admin (RF-17). Al guardar, la admin vuelve a la selección vacía (RF-20). |
| `booking_window.dart` (`bookingWindowDays = 60`, `bookingWindow`) | Ventana fija de 60 días. | `bookingWindow(nowSalon, {days})` y la constante `adminBookingWindowDays = 365` (RF-12, RNF-1). Los días cerrados y bloqueados siguen fuera (RF-13). |
| `busySlotsProvider` | Turnos ocupados de la ventana de 60 días. | Pide la ventana de la sesión: 365 días para la admin (RF-12). |
| `BookingCalendar` | Usa `bookingWindow(today)`. | Usa la ventana de la sesión (RF-12). |
| `SlotGrid` | Las horas libres del día elegido (`freeSlotsOfDayProvider`), desactivadas si el servicio no cabe, y el aviso de error con "Reintentar". | Sin cambios. No conoce la ventana: muestra el día que le da la selección, y `busySlotsProvider` ya trae los turnos ocupados de los 365 días de la admin. Las horas libres, la cobertura y "no cabe" son las de la 005 (RF-12, RF-13); los turnos de personas sin cuenta ocupan su hora como los demás, porque también tienen su turno ocupado (RF-24). |
| `BookingSubmitter` / `checkBeforeSave` | Comprueba y guarda el turno de la clienta, esperando confirmación. | Se añade `AdminBookingSubmitter` con su propia comprobación (`checkAdminBeforeSave`, § 4.4) y guarda el turno confirmado (RF-18, RF-19). |
| `BookButton` (diálogo de confirmación, `_MarginWarning`) | Resumen, "quedará esperando confirmación" y aviso del margen (006, RF-23). | En modo admin: para quién primero, "quedará confirmado" y el aviso del margen dirigido a la clienta, solo si tiene cuenta (RF-16, RF-29). |
| `BookingSummary` | Fecha, horas, lo reservado y el total. | En modo admin, primero para quién (RF-16). |
| `AppointmentModel` | `clientId` obligatorio, sin marca de quién lo creó. | `clientId` pasa a `String?` (`null` = persona sin cuenta) y se añade `createdByAdmin` (RF-19). |
| `BookingRepository` | `createAppointment` (lote turno + turno ocupado), `fetchBookingCheck`, `getAppointmentsForDate`. | Añade `watchActiveAppointments` y `fetchAdminBookingCheck` (RF-14, RF-18). `createAppointment` sirve tal cual para la admin. |
| `UserRepository.getAllUsers` / `adminUsersProvider` | Todas las fichas, en vivo; las usa la lista de usuarias de la admin. | Se reutiliza para la búsqueda de "Para quién" (RF-3 a RF-6, RF-10, RF-11, RF-15). Se añade `fetchUser`, que lee del servidor, para la comprobación al guardar (RF-15, RF-18). |
| `AdminDashboardView` (`_AppointmentCard`) | Hora, estado, avatar, nombre, teléfono, lo reservado, Cancelar y Confirmar. El icono de WhatsApp es decorativo, no un enlace. | Marca "Sin cuenta" y "Agendado por la admin", y el icono pasa a ser un enlace a WhatsApp (RF-22, RF-23, D-6). |
| `firestore.rules` | La clienta crea turnos a su nombre, esperando confirmación. La admin solo cambia `status`. El turno ocupado solo se crea junto a un turno de la clienta. | La admin crea turnos confirmados para otra persona y su turno ocupado. La clienta no puede crear ni cambiar `createdByAdmin` (RF-25, RF-26, RF-30). |
| `externalLinkLauncherProvider` | Abre enlaces externos. | Abre el WhatsApp de la lista de la admin (RF-22). |

## 2. Datos en Firestore (RF-19, RF-24 a RF-26, RF-30; RNF-4)

### `appointments/{uuid}`: un campo nuevo y `clientId` que puede ser nulo
```
appointments/{uuid}
  clientId: string | null      # null = persona sin cuenta (RF-19)
  clientName, clientPhone      # de la clienta, o los que escribe la admin
  clientPhotoUrl               # null en una persona sin cuenta
  startTime, endTime, status, createdAt, booked   # sin cambios
  createdByAdmin: bool         # NUEVO: true si lo agendó la admin (RF-19, RF-23)
```
- Persona sin cuenta: `clientId: null`, escrito de forma explícita (las reglas comprueban `== null`), con el nombre y el WhatsApp tal como los escribe la admin, sin espacios al principio ni al final. No se crea ninguna ficha aparte (RNF-4).
- Clienta con cuenta: su `uid`, su `displayName`, su `phoneNumber` y su `photoUrl` en el momento de agendar (casos límite: un cambio posterior de WhatsApp no cambia el turno).
- Estado `'confirmed'` (RF-19). `createdByAdmin: true`. La clienta guarda `createdByAdmin: false` desde la 005; un turno sin el campo se lee como `false`.
- **Compatibilidad:** los turnos actuales no tienen `createdByAdmin` y siempre tienen `clientId`; se leen igual. `fromMap` lee `clientId` vacío o que falta como `null`.
- `busySlots/{uuid}`: sin cambios. Solo tiene inicio y fin, así que nunca expone el nombre ni el WhatsApp (RF-26).
- **Índices:** ninguno nuevo. `watchActiveAppointments` y `fetchAdminBookingCheck` filtran un solo campo (`endTime >= ahora`), que Firestore indexa solo.

### Reglas (`firestore.rules`)
```
match /appointments/{id} {
  allow get, list: (sin cambios: admin, o clientId == uid)            # RF-26
  allow create: if
    // La clienta (005, RF-54), que ahora no puede marcarlo como de la admin.
    (signedIn() && !isBlocked()
      && request.resource.data.clientId == request.auth.uid
      && request.resource.data.status == 'waiting_confirmation'
      && request.resource.data.get('createdByAdmin', false) == false
      && fin > inicio && turno ocupado con las mismas horas)
    // La admin (RF-25): confirmado, marcado, para otra persona.
    || (isAdmin()
      && request.resource.data.status == 'confirmed'
      && request.resource.data.createdByAdmin == true
      && fin > inicio && turno ocupado con las mismas horas
      && (request.resource.data.clientId == null
          || (request.resource.data.clientId != request.auth.uid
              && get(users/clientId).data.role == 'cliente'
              && get(users/clientId).data.get('isBlocked', false) == false)));
  allow update: (sin cambios)  # la clienta ya no puede tocar createdByAdmin (hasOnly); RF-30
}
match /busySlots/{id} {
  allow create: if signedIn() && keys hasOnly [start, end] && mismas horas que su turno
    && (getAfter(turno).clientId == request.auth.uid
        || (isAdmin() && getAfter(turno).createdByAdmin == true));       # RF-25
}
```
- RF-2 y "dos admins" también se cumplen en el servidor: la admin no puede usar su propio `uid` ni el de otra admin (`role == 'cliente'`).
- RF-26 ya se cumple: un turno con `clientId: null` no coincide con el `uid` de nadie, así que solo lo lee la admin. Se comprueba en el simulador.
- RF-30 ya se cumple: la edición de la clienta solo puede cambiar `startTime`, `endTime`, `booked` y `status` (006). Se comprueba en el simulador.
- Los casos se apuntan en `specs/007-reserva-admin/rules-check.md`, que también repite los casos de la 006 que tocan estas reglas (RNF-5).

## 3. Capa `lib/data/`
- `AppointmentModel`: `String? clientId`, `bool createdByAdmin` (por defecto `false`), getter `hasAccount` (`clientId != null`). `toMap` escribe los dos campos siempre.
- `BookingRepository`:
  - `watchActiveAppointments(DateTime now)`: turnos con `endTime >= now`, en vivo. Solo lo usa la admin (RF-14, RF-15). La lógica vuelve a filtrar con "ahora" (§ 4.3), así que la consulta no tiene que repetirse cuando pasa el tiempo.
  - `fetchAdminBookingCheck({from, to, now})`: lee **del servidor** los turnos ocupados del día y los turnos con `endTime >= now` (RF-18). Sin conexión falla, como `fetchBookingCheck` (005, D-4).
- `UserRepository.fetchUser(uid)`: lee la ficha **del servidor**, para saber si la clienta elegida sigue sin bloquear justo antes de guardar (RF-15, RF-18).
- `fetchBookingCheck` y `getClientAppointments` no cambian.

## 4. Lógica pura (`lib/features/booking/logic/`, sin Flutter ni Firebase; RNF-1)

### 4.1 `whatsapp.dart` (nuevo): normalizar, validar y enlazar (RF-7, RF-9, RF-10; RNF-1)
```
normalizeWhatsApp(raw):
  digits = solo los dígitos de raw
  si digits empieza por "55" y tiene 12 dígitos o más: quita el "55"   # D-1
  devuelve digits
isValidWhatsApp(raw) = 8 <= normalizeWhatsApp(raw).length <= 15
sameWhatsApp(a, b) = las dos normalizadas no vacías y iguales
whatsAppLink(raw):   # D-6
  digits = solo los dígitos de raw
  si raw empieza por "+" o digits empieza por "55" y tiene 12 o más: https://wa.me/<digits>
  si no: https://wa.me/55<digits>
```
Tabla: espacios, guiones, paréntesis, `+55`, `55` delante, `55` como DDD (Rio Grande do Sul) en un número de 10 u 11 dígitos, 7 y 8 dígitos, 15 y 16 dígitos, texto sin dígitos.

### 4.2 `recipient.dart` (nuevo): para quién y la búsqueda (RF-2 a RF-5, RF-7 a RF-11, RF-15)
```
sealed Recipient
  AccountRecipient(uid, name, phone, photoUrl)
  GuestRecipient(name, phone, consent)        # lo que escribe la admin

foldText(s): minúsculas y sin acentos (á à â ã ä é ê í ó ô õ ö ú ü ç ñ…)

isBookableClient(user) = role == 'cliente' && !isBlocked && phone normalizado no vacío     # RF-4

searchClients(users, query, limit = 20):                                   # RF-3, RF-4
  q = query.trim(); si q.length < 2 → []
  qDigits = solo los dígitos de q
  candidatas = users.where(isBookableClient)
    .where(foldText(name).contains(foldText(q))
           || (qDigits no vacío && normalizeWhatsApp(phone).contains(qDigits)))
  ordena por foldText(name) y luego por name; toma limit

accountWithPhone(users, phone):                                             # RF-10, RF-11
  la primera ficha con role 'cliente' y sameWhatsApp(phone); null si ninguna
  (incluye las bloqueadas, para avisar de RF-11)

guestErrors(guest) → Set<GuestField>                                          # RF-7 a RF-9
  name vacío tras trim o > 80 caracteres → name
  !isValidWhatsApp(phone) → phone
  !consent → consent

reconcileRecipient(recipient, users):                                        # RF-15
  AccountRecipient cuya ficha ya no existe, ya no es clienta o está bloqueada
    → (null, aviso recipientBlocked)
  si no → (recipient, sin aviso)
```

### 4.3 `admin_booking.dart` (nuevo): turno activo de una persona y comprobación (RF-14, RF-18)
```
activeAppointmentOfPerson<T>(appointments, {uid?, phone, times, idOf, phoneOf, now}):
  los turnos con clientId == uid (si hay uid) o sameWhatsApp(phoneOf(t), phone)
  → activeAppointment(...) de la 005 (termina después de ahora, esperando o confirmado)

AdminBookingCheck: ok | slotTaken | doesNotFit | personActive(appointment) | recipientBlocked

checkAdminBeforeSave<T>({start, durationMinutes, settings, busy, active, recipient,
                         recipientUser, users, nowSalon, ...}):
  AccountRecipient y su ficha (del servidor) bloqueada, no clienta o inexistente → recipientBlocked
  GuestRecipient y accountWithPhone(users, phone) bloqueada → recipientBlocked     # RF-11
  activeAppointmentOfPerson(...) != null → personActive
  hora y cobertura como checkBeforeSave de la 005 → slotTaken / doesNotFit
  → ok
```
`checkBeforeSave` (005) no cambia: la clienta sigue mirando solo sus turnos por `clientId` (casos límite: no ve los turnos que se le agendaron sin cuenta).

### 4.4 Cambios en `booking_window.dart` y `booking_selection.dart` (RF-12, RF-17, RF-20)
- `bookingWindow(nowSalon, {int days = bookingWindowDays})` y `initialDay(..., windowDays)`. Constante `adminBookingWindowDays = 365`.
- `BookingContext.windowDays` (60 por defecto), usado por `isDaySelectable` y `reconcile`.
- `BookingPart.recipient`. `missingParts(selection, {Recipient? recipient, bool admin})` lo añade en modo admin si no hay para quién, o si es una persona sin cuenta con errores (RF-9, RF-17).
- La edición de la 006 no cambia: siempre usa la ventana de la clienta (60 días).

## 5. Interfaz

### Providers (`lib/features/booking/providers/`)
- `isAdminSessionProvider` (`bool`): rol de `currentUserProvider`.
- `bookingWindowDaysProvider`: 365 en sesión de admin, 60 si no. Lo leen `busySlotsProvider`, `BookingCalendar` y `BookingSelectionController._context` (RF-12).
- `admin_booking_provider.dart` (nuevo):
  - `bookingRecipientProvider` (`Notifier<RecipientState>`): para quién, el borrador de la persona sin cuenta (nombre, WhatsApp, casilla) y el texto de la búsqueda. No se destruye al cambiar de pestaña o de página (RF-27). Escucha `adminUsersProvider` y aplica `reconcileRecipient` (RF-15). Se vacía al cambiar de cuenta y tras agendar (RF-20).
  - `recipientSearchProvider`: `searchClients` sobre `adminUsersProvider` y la búsqueda (RF-3 a RF-6).
  - `adminActiveAppointmentsProvider`: `watchActiveAppointments` desde el "ahora" del primer valor (RF-14).
  - `recipientActiveAppointmentProvider`: el turno activo de la persona elegida, o `null` (RF-14).
  - `AdminBookingSubmitter` / `adminBookingSubmitProvider`: lee del servidor (`fetchAdminBookingCheck`, `fetchUser`), aplica `checkAdminBeforeSave` y guarda con `createAppointment` (confirmado, `createdByAdmin: true`). Resultado: `ok`, `slotTaken`, `doesNotFit`, `personActive`, `recipientBlocked` o `failed`. Con `ok`, vacía la selección (sin conservar el día) y para quién (RF-18 a RF-20).
- `adminUsersProvider` sigue en `features/admin/providers/admin_provider.dart`. La reserva lo importa, como la admin importa los providers de reserva (CLAUDE.md).

### Vista de reserva de la admin (la misma en Web y en Android/iOS)
- `BookingView`: `BookingScreenAdmin` → `_buildForm(admin: true)`, con `onConfirmed` = guardar como admin (RF-1, RF-28).
- `BookingForm(admin: true)`: encima del calendario, la sección **"Para quién"** (`RecipientPicker`, nuevo widget) dentro de su `_MissingFrame` (RF-17). Título "Agendar turno para una clienta".
- `RecipientPicker`:
  - Sin nada elegido: campo de búsqueda con etiqueta ("Nombre o WhatsApp") y, desde 2 caracteres, los resultados como filas de al menos 48 px: avatar, nombre y WhatsApp (RF-3). Debajo, siempre, el botón "Persona sin cuenta" (RF-5, RF-6).
  - Sin resultados: "No hay clientas con ese nombre o WhatsApp" (RF-5).
  - Error de `adminUsersProvider`: aviso con "Reintentar" (`ref.invalidate`), y "Persona sin cuenta" sigue disponible (RF-6). Se comprueba `hasError` antes de `isLoading` (MEMORY).
  - Clienta elegida: una tarjeta con su nombre y su WhatsApp, y "Cambiar". Si tiene un turno activo, debajo el aviso con su fecha, su hora y lo reservado (RF-14), con el color de peligro y su propio color de texto (MEMORY).
  - Persona sin cuenta: campos de nombre (máximo 80, contador) y WhatsApp (teclado de teléfono), la casilla de consentimiento y "Buscar clienta" para volver a la búsqueda (RF-7, RF-8). Cada campo con error lleva su texto bajo el campo (RF-9).
  - Al salir del campo de WhatsApp (`Focus.onFocusChange`): si `accountWithPhone` da una clienta sin bloquear, un aviso con "Elegir a <nombre>" y "Seguir sin cuenta" (RF-10); si da una bloqueada, un error en el campo, "Esa clienta está bloqueada" (RF-11). El aviso se anuncia al lector de pantalla.
  - Turno activo de una persona sin cuenta: igual que con cuenta, en cuanto el WhatsApp es válido (RF-14).
- `BookingSummary`: con modo admin y para quién elegido, primero la fila "Para: <nombre> · <WhatsApp>" y, si es sin cuenta, "(sin cuenta)" (RF-16).
- `BookButton` en modo admin:
  - Si falta algo, como en la 005, con el texto de lo que falta (RF-17, § 6).
  - Con la persona con turno activo: no abre la confirmación; avisa como RF-14 y marca "Para quién".
  - Diálogo: para quién, el resumen, "El turno quedará confirmado." y, si es una clienta con cuenta y empieza dentro del margen, "<Nombre> no podrá cambiar este turno: falta menos de N para que empiece." (RF-16, RF-29).
- Tras guardar (`ok`): `SnackBar` "Turno agendado para <nombre>", anunciado, en Web y en Android/iOS; sin el diálogo de volver a la landing. La vista sube al principio y queda vacía (RF-20).
- Otros resultados: los avisos de la 005 para `slotTaken`, `doesNotFit` y `failed` (conserva lo elegido); `personActive` y `recipientBlocked` con su propio texto. Con `recipientBlocked`, quita para quién (RF-15, RF-18).
- Cambio de idioma con la confirmación abierta: los textos se leen dentro del `builder` (casos límite).

### Lista de turnos de la admin (`AdminDashboardView`, RF-22 a RF-24)
- Persona sin cuenta: `InitialsAvatar` sin foto, y la etiqueta "Sin cuenta" junto al nombre.
- `createdByAdmin`: la etiqueta "Agendado por la admin".
- El icono de WhatsApp pasa a ser un botón de 48 px con nombre para el lector de pantalla ("Escribir a <nombre> por WhatsApp"), que abre `whatsAppLink(clientPhone)` con `externalLinkLauncherProvider`. Vale para todos los turnos (D-6).

### Rutas y guardas
- Sin rutas nuevas. La admin ya llega a `/booking` y a la pestaña Reservas. `resolveRedirect` no cambia.
- "Reservar cita" en el detalle (`/booking?service=…`) aplica `requestItem` como en la 005: el servicio queda elegido y para quién, sin elegir (Navegación).

## 6. Textos nuevos en los `.arb` (ES / PT; RNF-3)
Se borra `bookingAdminNotice`. Nuevos (nombres orientativos):

| Clave | ES |
| --- | --- |
| `bookingAdminTitle` | Agendar un turno |
| `bookingStepRecipient` | Para quién |
| `bookingRecipientSearchLabel` | Nombre o WhatsApp de la clienta |
| `bookingRecipientSearchHint` | Escribe al menos 2 caracteres |
| `bookingRecipientNoResults` | No hay clientas con ese nombre o WhatsApp. |
| `bookingRecipientLoadError` | No se pudieron cargar las clientas. |
| `bookingRecipientGuestAction` | Persona sin cuenta |
| `bookingRecipientSearchAction` | Buscar clienta |
| `bookingRecipientChange` | Cambiar |
| `bookingGuestNameLabel` | Nombre |
| `bookingGuestPhoneLabel` | WhatsApp |
| `bookingGuestConsent` | La persona acepta dar su nombre y su WhatsApp para este turno. |
| `bookingGuestNameError` | Escribe un nombre de hasta 80 caracteres. |
| `bookingGuestPhoneError` | Escribe un WhatsApp válido (de 8 a 15 dígitos). |
| `bookingGuestConsentError` | Marca la casilla para continuar. |
| `bookingGuestPhoneHasAccount` | Este WhatsApp es de {name}, que tiene cuenta. |
| `bookingGuestChooseAccount` | Elegir a {name} |
| `bookingGuestKeepGuest` | Seguir sin cuenta |
| `bookingGuestPhoneBlocked` | Este WhatsApp es de una clienta bloqueada: no se le puede agendar. |
| `bookingRecipientActive` | Ya tiene un turno el {date} a las {time}: {service}. No se le puede agendar otro. |
| `bookingRecipientBlocked` | Esa clienta está bloqueada: ya no se le puede agendar. |
| `bookingMissingRecipient` | Elige para quién es el turno |
| `bookingMissingSeveral` | Faltan datos para agendar: revisa lo marcado. |
| `bookingSummaryFor` | Para: {name} |
| `bookingSummaryGuest` | sin cuenta |
| `bookingAdminConfirmNote` | El turno quedará confirmado. |
| `bookingAdminMarginWarning` | {name} no podrá cambiar este turno: falta menos de {margin} para que empiece. |
| `bookingAdminCreated` | Turno agendado para {name}. |
| `adminAppointmentGuest` | Sin cuenta |
| `adminAppointmentByAdmin` | Agendado por la admin |
| `adminAppointmentWhatsApp` | Escribir a {name} por WhatsApp |

`bookingMissingBoth`, `bookingMissingSlot` y `bookingMissingService` se siguen usando. Con dos o más partes que faltan en modo admin, `bookingMissingSeveral`.

## 7. Decisiones técnicas
- **D-1. El `55` solo se quita en números de 12 dígitos o más.** En Brasil, `55` también es un DDD (Rio Grande do Sul): "55 99123-4567" tiene 11 dígitos y no lleva el código del país. Con 12 o 13 dígitos (55 + DDD + 8 o 9), el `55` es el del país. *Descartado:* quitar siempre el `55` inicial, que confundiría esos números.
- **D-2. El turno activo de una persona se busca entre los turnos que aún no terminaron, filtrando en la app.** Son pocos, y así un turno de una clienta con cuenta también se encuentra por su WhatsApp, sin guardar un campo nuevo con el WhatsApp normalizado. *Descartado:* el campo `clientPhoneKey` con su consulta, que obliga a escribirlo también desde la reserva de la clienta y no sirve para los turnos que ya existen.
- **D-3. `clientId: null` para la persona sin cuenta, escrito de forma explícita.** Las reglas pueden comprobar `== null`, y un campo que falta las haría fallar. Así "sin cuenta" no necesita un campo propio. *Descartado:* `clientId: ''` y un `hasAccount` aparte, que pueden contradecirse.
- **D-4. La búsqueda usa la lista de fichas que ya lee la admin (`adminUsersProvider`) y filtra en la app.** Firestore no busca por subcadena ni sin acentos, y las clientas de un salón son pocas. *Descartado:* guardar en cada ficha un nombre sin acentos para consultarlo, que obliga a cambiar todas las fichas.
- **D-5. Para quién va en su propio provider, no en `BookingSelection`.** La selección es la misma para la clienta, la edición y la admin; para quién solo existe en modo admin y tiene su propio borrador (nombre, WhatsApp, casilla). *Descartado:* añadirlo a `BookingSelection`, que tocaría toda la lógica de la 005 y la 006.
- **D-6. El enlace a WhatsApp de la lista es para todos los turnos, no solo los de personas sin cuenta.** Hoy el icono es decorativo, y lo natural es que todos se comporten igual. `whatsAppLink` añade el `55` si el número no lo lleva.
- **D-7. La comprobación al guardar lee la ficha de la clienta del servidor.** Así una clienta bloqueada en otro dispositivo justo antes de confirmar no recibe el turno (RF-15), aunque la lista en vivo aún no lo sepa. Las reglas lo impiden también.
- **D-8. Tras agendar, la selección queda vacía del todo, también el día**, y `reconcile` vuelve a elegir el primer día con horas libres, como al abrir (RF-20). *Descartado:* conservar el día como hace la clienta (005), porque la siguiente reserva suele ser para otra persona y otro día.

## 8. Decisiones del autor
- Las de la spec (2026-10-24 y 2026-11-16).
- Este plan cambia el modelo de datos de `appointments` (`clientId` nulo, `createdByAdmin`) y `firestore.rules` (§ 2). Según CLAUDE.md, el autor los aprueba al aprobar el plan.
- Para revisar: D-1 (el `55` como DDD), D-6 (enlace para todos) y D-8 (vaciar también el día).

## 9. Estrategia de tests
Tests primero, en cada tarea. Sin Firebase: repositorios falsos inyectados.
- **Lógica pura, con tablas (RNF-1):** `whatsapp_test.dart` (normalizar, validar, D-1, enlace), `recipient_test.dart` (`foldText`, `searchClients`: acentos, mayúsculas, dígitos, menos de 2 caracteres, límite de 20 y orden; `accountWithPhone`; `guestErrors`; `reconcileRecipient`), `admin_booking_test.dart` (turno activo por `uid` y por WhatsApp, en curso, cancelado, terminado; `checkAdminBeforeSave` en cada caso), `booking_window_test.dart` (365 días, días cerrados y bloqueados).
- **Datos:** `appointment_model_test.dart` (`clientId` nulo, `createdByAdmin`, documentos sin el campo). Los métodos nuevos de los repositorios no se prueban contra Firestore, como en la 005 y la 006: los providers y las vistas usan repositorios falsos escritos a mano (`test/helpers/`), que ganan `watchActiveAppointments`, `fetchAdminBookingCheck` y `fetchUser`. Sus consultas se comprueban en el recorrido manual.
- **Providers:** `admin_booking_provider_test.dart`: búsqueda, conservar para quién (RF-27), quitar a la bloqueada (RF-15), guardar confirmado y marcado (RF-19), vaciar tras agendar (RF-20), cada resultado de la comprobación (RF-18).
- **Vista (`pumpApp`, `pumpMobileApp`, `pumpWebApp`):** `admin_booking_view_test.dart`: "Para quién" sin nada elegido (RF-1, RF-28), búsqueda y sin resultados (RF-3 a RF-5), error con Reintentar (RF-6), persona sin cuenta y sus errores (RF-7 a RF-9), aviso al salir del WhatsApp (RF-10, RF-11), turno activo (RF-14), lo que falta (RF-17), resumen y confirmación (RF-16, RF-29), ventana de 365 días en el calendario (RF-12), tras agendar en Web y en móvil (RF-20), conservar al cambiar de pestaña (RF-27), cambio de idioma con el diálogo abierto. `booking_screen_states_test.dart` se actualiza: la admin ve el formulario, no el aviso.
- **Clienta:** un test de que el turno agendado por la admin aparece como su turno activo y en Perfil, sin recargar (RF-21), y de que se edita (casos límite de la 006).
- **Lista de la admin:** `admin_dashboard_test.dart`: sin cuenta, sin foto, etiquetas y enlace a WhatsApp con `RecordingLinkLauncher` (RF-22, RF-23); horas libres con turnos sin cuenta (RF-24).
- **Accesibilidad (RNF-2):** contraste en tema claro y oscuro, 48 px, semántica de los resultados y del aviso, texto al 200 % y 320 px en "Para quién", en el diálogo y en la tarjeta de la lista.
- **Reglas (RF-25, RF-26, RF-30; RNF-5):** a mano en el simulador, con `rules-check.md`.

## 10. Cobertura
| RF | Dónde | Test |
| --- | --- | --- |
| RF-1, RF-28 | `bookingScreen`, `BookingView`, `BookingForm(admin)` | estados de pantalla, vista |
| RF-2 | `isBookableClient`, reglas | `recipient_test`, simulador |
| RF-3, RF-4 | `searchClients` | `recipient_test`, vista |
| RF-5, RF-6 | `RecipientPicker` | vista |
| RF-7 a RF-9 | `guestErrors`, `RecipientPicker`, `missingParts` | `recipient_test`, vista |
| RF-10, RF-11 | `accountWithPhone`, `checkAdminBeforeSave` | `recipient_test`, `admin_booking_test`, vista |
| RF-12, RF-13 | `bookingWindow`, `bookingWindowDaysProvider` | `booking_window_test`, vista |
| RF-14 | `activeAppointmentOfPerson`, `recipientActiveAppointmentProvider` | `admin_booking_test`, vista |
| RF-15 | `reconcileRecipient`, `AdminBookingSubmitter` | `recipient_test`, providers |
| RF-16, RF-29 | `BookingSummary`, `BookButton` | vista |
| RF-17 | `missingParts`, `BookButton` | `booking_selection_test`, vista |
| RF-18, RF-19 | `checkAdminBeforeSave`, `AdminBookingSubmitter`, `AppointmentModel` | `admin_booking_test`, providers, modelo |
| RF-20 | `AdminBookingSubmitter`, `BookingView` | providers, vista (Web y móvil) |
| RF-21 | `myAppointmentsProvider` (sin cambios) | vista de la clienta |
| RF-22 a RF-24 | `AdminDashboardView`, `whatsAppLink` | lista de la admin, `whatsapp_test` |
| RF-25, RF-26, RF-30 | `firestore.rules` | simulador (`rules-check.md`) |
| RF-27 | `bookingRecipientProvider` | providers, vista |

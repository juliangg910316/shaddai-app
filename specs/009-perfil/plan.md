# Plan 009 — Perfil y mis turnos
Estado: aprobada

Spec: `specs/009-perfil/spec.md` (aprobada el 2026-11-18).

## 1. Qué existe ya

| Parte | Estado en el código | RF |
| --- | --- | --- |
| Perfil con foto, nombre, WhatsApp, acceso al panel, lista de turnos, "Reservar otro turno", preferencias (solo móvil) y salir | `ProfileView` (`lib/features/profile/presentation/profile_view.dart`). La lista es plana, va en un `Expanded` (si falla la carga, las preferencias desaparecen) y "Reservar otro turno" sale siempre | RF-43 (parcial), RF-24 (sin "Reintentar") |
| Turnos de la clienta en vivo | `myAppointmentsProvider` → `BookingRepository.getClientAppointments` (por `startTime` descendente) | RF-6 |
| Hora del salón | `toSalon`/`fromSalon` (`logic/salon_time.dart`). **El perfil no la usa**: formatea `startTime` en la zona del dispositivo (pendiente anotado) | RF-2 |
| Turno activo | `activeAppointment` y `activeStatuses` (`logic/booking_rules.dart`) | RF-1 |
| Margen de edición y "se puede editar" | `isEditable`, `editAvailability` (`logic/booking_edit.dart`), `editAvailabilityProvider`, `calendarSettingsProvider.editMarginMinutes`; "ahora" cada 30 s con `salonNowProvider` | RF-3, RF-4, RF-7 |
| Turno activo en Reservas con "Editar turno" o el aviso con WhatsApp | `ActiveAppointmentView`, `WhatsappNoticeButton` | RF-8 (falta cancelar) |
| Edición del turno | `editTargetProvider`, `BookingEditor` (spec 006) | RF-3, RF-17 |
| Cancelar | Solo la admin: `BookingRepository.updateAppointmentStatus` (estado y borrado del turno ocupado en un lote). Las reglas no dejan cancelar a la clienta | RF-11, RF-19 (faltan) |
| Agenda de la admin con marcas "Sin cuenta" y "Agendado por la admin" | `_AppointmentCard` en `admin_dashboard_view.dart` | RF-18, RF-35 (faltan las marcas nuevas) |
| Captura del WhatsApp | `PhoneCaptureView` (acepta 8 caracteres o más, sin `isValidWhatsApp`; el "consentimiento" es el texto `whatsappDisclaimer`, sin casilla). `UserRepository.updatePhoneNumber` | RF-26 a RF-30 (base) |
| Validar WhatsApp | `isValidWhatsApp`, `normalizeWhatsApp` (`logic/whatsapp.dart`, spec 007) | RF-27 |
| Borrar la cuenta | Nada: no hay `functions/`, ni `cloud_functions`, y las reglas impiden borrar fichas | RF-31 a RF-42 |
| Nueva cuenta tras iniciar sesión | `AuthController._syncFirestoreUser` crea la ficha si no existe y el router pide el WhatsApp | RF-41 (ya funciona: una cuenta borrada vuelve con otro uid) |

## 2. Decisiones

- **D-1. Quién canceló: campo `cancelledBy` en el turno** (`'client'`; ausente = el salón). RF-18, RF-20. Los turnos cancelados que ya existen no lo tienen y los canceló la admin (la clienta no podía): se leen como "Cancelado por el salón" sin migrar nada. La admin sigue escribiendo solo `status`, así que su regla no cambia. *Descartado:* escribir también `'admin'` (habría que tocar la regla de la admin y migrar los antiguos para nada); deducirlo de otro dato (no existe ninguno fiable).
- **D-2. Cuenta borrada: campo `accountDeleted: true` en sus turnos**, que conservan `clientId`, nombre y WhatsApp y pierden la foto (`clientPhotoUrl: null`). RF-35. Conservar `clientId` hace que nadie más los vea (un uid de Firebase no se reutiliza) y que las reglas de lectura no cambien. *Descartado:* `clientId: null` (los confundiría con los de una persona sin cuenta de la spec 007, con su marca y su lógica de WhatsApp).
- **D-3. La clienta cancela en una transacción** que vuelve a leer el turno y solo lo cancela si sigue activo, cancelable y con el mismo inicio, fin y lo reservado que vio (RF-11, RF-14): cambia `status` a `cancelled`, escribe `cancelledBy: 'client'` y borra su turno ocupado. El estado no cuenta como cambio: si la admin solo lo confirmó, se cancela igual (caso límite de la spec). *Descartado:* un lote sin releer (cancelaría un turno que la admin acaba de mover).
- **D-4. El margen se comprueba dos veces:** en la app con el valor en vivo del calendario (para el mensaje de RF-14) y en las reglas con `editMarginMinutes()`, que ya existe (RF-19). Si la regla deniega por un margen recién cambiado, la app lo trata como fallo (RF-15) y, como el calendario llega en vivo, el siguiente intento ya da el mensaje correcto.
- **D-5. Cancelar no exige estar sin bloquear.** Una clienta bloqueada sigue viendo "Cancelar turno" (no "Editar turno") bajo su aviso de bloqueo (caso límite de la spec). La regla de cancelar no mira `isBlocked`.
- **D-6. Cambiar el WhatsApp va en un lote:** la ficha y, si tiene turno activo, el `clientPhone` de ese turno (RF-28). La regla del turno exige que el número nuevo sea el de la ficha después del lote (`getAfter`), así la clienta no puede escribir cualquier cosa en el turno. *Descartado:* que lo copie una Cloud Function al cambiar la ficha (más piezas en el servidor para un caso sencillo).
- **D-7. Validación del WhatsApp: `isValidWhatsApp` (spec 007) en el cambio y también en la captura.** RF-26 pide "las mismas reglas que al registrarlo"; hoy la captura solo mira 8 caracteres. Se usa un único campo compartido (`WhatsAppField`) con la misma validación y el mismo texto `whatsappDisclaimer` en los dos sitios. **Aceptado por el autor (§ 12):** (a) esto endurece la captura del registro (hoy acepta, por ejemplo, letras), y (b) el registro no tiene casilla de consentimiento, solo el texto: el cambio mostrará el mismo texto y la parte "falta el consentimiento" de RF-27 no se aplica. Si quieres una casilla, irá en los dos sitios.
- **D-8. Borrar la cuenta: Cloud Function invocable `deleteAccount`** (RF-34 a RF-42), en `functions/` con TypeScript, Node 22, región `southamerica-east1` (São Paulo). La app la llama con la sesión iniciada; la función toma el uid de la sesión (nunca de los datos enviados), así que solo borra la propia cuenta (RF-42), y como usa el SDK de administración no hace falta una sesión reciente (RF-37). Pasos, todos repetibles sin romper nada (RF-39):
  1. Sin sesión → `unauthenticated`.
  2. Lee `users/{uid}`. Si es admin → `permission-denied`; si está bloqueada → `failed-precondition` con motivo `blocked` (RF-40, RF-42). Si la ficha ya no existe (un intento anterior llegó más lejos), sigue.
  3. Lee los turnos con `clientId == uid`. Para cada uno, en lotes de 400: el activo (`waiting_confirmation`/`confirmed` y `endTime` > ahora) pasa a `cancelled` con `cancelledBy: 'client'` y se borra su turno ocupado (RF-34, sin mirar el margen); a todos, `clientPhotoUrl: null` y `accountDeleted: true` (RF-35).
  4. Borra `users/{uid}` (incluye correo, foto, WhatsApp y token).
  5. Borra la cuenta de Auth; si ya no existe (`auth/user-not-found`), no es error.
  Devuelve `{ ok: true }`.
  *Descartado:* borrar desde la app (exige sesión reciente con Google, que en Web y móvil es otro flujo, y daría permisos de borrado a las clientas en las reglas); una función disparada al borrar la cuenta de Auth (no puede rechazar a una bloqueada ni a la admin).
- **D-9. Dependencias nuevas (aprobadas por el autor, § 12):**
  - **App:** `cloud_functions` (paquete oficial de FlutterFire, de la misma familia que `firebase_core`) para llamar a la función. *Alternativa:* llamar por HTTP con el token a mano (necesitaría `http`, otra dependencia, y reimplementar lo que da el paquete).
  - **`functions/` (npm):** `firebase-admin` y `firebase-functions`; de desarrollo, `typescript`. Los tests usan el ejecutor que trae Node (`node --test`), sin Jest ni el emulador.
  - **Proyecto de Firebase:** las funciones exigen el plan **Blaze**. `firebase.json` gana la entrada `functions`.
- **D-10. La lógica de la función no toca Firebase:** `functions/src/delete_account.ts` recibe un "almacén" (interfaz con leer ficha, leer turnos, escribir lote, borrar ficha, borrar de Auth) y "ahora". `functions/src/index.ts` lo conecta con `firebase-admin`. Los tests pasan un almacén en memoria (constitución, principio 4).
- **D-11. Palabra de confirmación:** `ELIMINAR` en español y `EXCLUIR` en portugués, desde el `.arb`. Se compara sin espacios a los lados y sin distinguir mayúsculas (RF-32).
- **D-12. Perfil en un solo scroll:** cabecera, identidad, turno activo, historial, cuenta (WhatsApp y "Eliminar mi cuenta") y preferencias en una sola lista con `tabScrollControllerProvider(MobileTab.profile)`. Así el error de carga no oculta nada (RF-24) y con el texto al 200 % todo se alcanza (RNF-3). "Cerrar sesión" pasa de `GestureDetector` a `IconButton` con `tooltip` (RNF-2).
- **D-13. "Cancelar turno" y su diálogo son piezas compartidas** del feature `booking` (`CancelAppointmentButton`), usadas por `ActiveAppointmentView` y por la tarjeta del perfil, con un único controlador (RF-8). La vista de perfil importa de `booking`, como ya hace.
- **D-14. Tras borrar la cuenta**, la app cierra la sesión de Google y de Firebase (la sesión local sigue viva hasta que caduca el token), muestra el aviso y va a `/` en Web (antes de cerrar la sesión, como ya hace "salir") o a `/home` en Android/iOS (RF-36).

## 3. Datos (Firestore)

### Campos nuevos en `appointments/{id}`
| Campo | Tipo | Quién lo escribe | Ausente |
| --- | --- | --- | --- |
| `cancelledBy` | `'client'` | la clienta al cancelar; la función al borrar la cuenta | cancelado por el salón (D-1) |
| `accountDeleted` | `true` | solo la función | cuenta viva |

`AppointmentModel` los lee (`cancelledByClient`, `accountDeleted`, `false` si faltan). `toMap` no los escribe: los turnos nuevos nacen sin ellos. Los documentos existentes se siguen leyendo sin cambios (constitución, principio 5).

`users/{uid}`: sin campos nuevos. Las fichas siguen sin poder borrarse desde la app; solo las borra la función.

Índices: la consulta de la función (`clientId ==`) es de un solo campo; la de la app no cambia. Sin índices nuevos.

### `firestore.rules`
- **`appointments` update, rama nueva "la clienta cancela" (RF-19):** `resource.data.clientId == request.auth.uid`, `resource.data.status in ['waiting_confirmation', 'confirmed']`, `resource.data.startTime > request.time + duration.value(editMarginMinutes(), 'm')`, cambian solo `status` y `cancelledBy`, `request.resource.data.status == 'cancelled'`, `request.resource.data.cancelledBy == 'client'`, y `!existsAfter(busySlots/{id})` (la hora queda libre en el mismo lote).
- **`appointments` update, rama nueva "la clienta copia su WhatsApp" (RF-28):** turno propio, activo (`status` activo y `endTime > request.time`), cambia solo `clientPhone`, y es igual a `getAfter(users/{uid}).data.phoneNumber`.
- **`busySlots` delete:** además de la admin, la dueña del turno si `getAfter(appointments/{id}).data.status == 'cancelled'` (RF-11, RF-19).
- `users`: sin cambios (la clienta ya puede cambiar su `phoneNumber`; el borrado sigue denegado).
- La cabecera del archivo cita la spec 009, y `specs/009-perfil/rules-check.md` lista los casos para el simulador (permitidos y denegados: cancelar lo ajeno, dentro del margen, con otros campos, sin borrar el turno ocupado; borrar el turno ocupado de otra o de un turno no cancelado; copiar un WhatsApp distinto del de la ficha; tocar un turno del historial).

## 4. Lógica pura (sin Flutter ni Firebase, "ahora" como parámetro)

### 4.1 `lib/features/booking/logic/cancel_appointment.dart` (RF-3, RF-4, RF-7, RF-14)
```
enum CancelAvailability { loading, error, cancellable, closed }

cancelAvailability({settingsError, marginMinutes?, start, now}):
  si settingsError → error
  si marginMinutes == null → loading
  isEditable(start, now, marginMinutes, isBlocked: false) ? cancellable : closed

enum CancelCheck { ok, notActive, changed, notCancellable }

checkCancelBeforeSave({shown, current?, nowSalon, marginMinutes}):
  si current == null o estado no activo o toSalon(current.end) <= nowSalon → notActive
  si inicio, fin o lo reservado de current != los de shown → changed   // el estado no cuenta (D-3)
  si !isEditable(current.start, fromSalon(nowSalon), margin, false) → notCancellable
  → ok
```
`shown` es un `EditOriginal` (ya tiene inicio, fin, estado y lo reservado en hora de pared).

### 4.2 `lib/features/profile/logic/profile_appointments.dart` (RF-1, RF-5, RF-20 a RF-22)
```
typedef ProfileAppointments<T> = ({T? active, List<T> history})

profileAppointments<T>(mine, times, now):
  active = activeAppointment(mine, times, now)
  history = mine sin active, ordenados por inicio descendente
  // Con datos antiguos de dos activos, el segundo va al historial con su estado (upcoming).
  → (active, history)

enum HistoryLabel { cancelledByYou, cancelledBySalon, done, notConfirmed, upcoming }

historyLabel(status, cancelledByClient, end, now):
  status == cancelled → cancelledByClient ? cancelledByYou : cancelledBySalon
  end <= now → status == confirmed ? done : notConfirmed
  → upcoming   // solo con datos antiguos de dos activos: se muestra con su estado normal
```

### 4.3 `lib/features/profile/logic/account_deletion.dart` (RF-31, RF-32, RF-40)
```
enum AccountDeletionAccess { hidden, blocked, allowed }
accountDeletionAccess(role, isBlocked): admin → hidden; isBlocked → blocked; si no → allowed
deletionWordMatches(typed, word): typed.trim().toUpperCase() == word.toUpperCase()
```

### 4.4 WhatsApp
Se reutiliza `isValidWhatsApp` (D-7). Sin funciones nuevas.

### 4.5 `functions/src/delete_account.ts` (RF-34, RF-35, RF-39, RF-40, RF-42)
```
interface AccountStore {
  getUser(uid): Promise<{role, isBlocked} | null>
  appointmentsOf(uid): Promise<{id, status, endTime}[]>
  commit(writes: Write[]): Promise<void>        // Write = update turno | delete busySlot
  deleteUser(uid): Promise<void>
  deleteAuthUser(uid): Promise<void>           // ignora user-not-found
}

deleteAccount(store, uid?, now):
  si !uid → throw unauthenticated
  user = getUser(uid)
  si user?.role == 'admin' → throw permission-denied
  si user?.isBlocked → throw failed-precondition('blocked')
  writes = []
  para cada a en appointmentsOf(uid):
    si a.status activo y a.endTime > now:
      writes += update(a.id, {status: cancelled, cancelledBy: client, clientPhotoUrl: null, accountDeleted: true})
      writes += deleteBusySlot(a.id)
    si no:
      writes += update(a.id, {clientPhotoUrl: null, accountDeleted: true})
  commit en trozos de 400
  deleteUser(uid); deleteAuthUser(uid)
```
Repetirlo tras un fallo vuelve a escribir los mismos valores y borra lo que falte: el resultado es el mismo (RF-39).

## 5. Capa de datos (`lib/data/`)

- **`models/appointment_model.dart`:** lee `cancelledBy` (`cancelledByClient`) y `accountDeleted`. RF-18, RF-20, RF-35.
- **`repositories/booking_repository.dart`:**
  - `cancelByClient({id, expected})`: transacción de D-3 (relee, aplica `expected`, cambia el estado, escribe `cancelledBy` y borra el turno ocupado); devuelve `false` si `expected` no lo da por bueno; tiempo máximo `saveTimeout`. RF-11, RF-14, RF-15.
- **`repositories/user_repository.dart`:**
  - `updateWhatsApp({uid, phone, activeAppointmentId?})`: lote con la ficha y, si hay turno activo, su `clientPhone` (D-6). RF-28, RF-30.
- **`repositories/account_repository.dart` (nuevo):** `deleteAccount()` llama a la función `deleteAccount` con `FirebaseFunctions` inyectable (por defecto `FirebaseFunctions.instanceFor(region: 'southamerica-east1')`). Traduce los errores a `AccountDeletionFailure.blocked`, `.notAllowed` o `.failed` (RF-39, RF-40); el detalle va a `debugPrint`.

## 6. Providers y controladores

- **`booking/providers/booking_cancel_provider.dart` (nuevo):**
  - `cancelAvailabilityProvider.family(AppointmentModel)` → `CancelAvailability`, en vivo con `calendarSettingsProvider` y `salonNowProvider` (RF-3, RF-4, RF-7).
  - `AppointmentCanceller` (`appointmentCancelProvider`): `cancel(AppointmentModel shown)` → `CancelOutcome { ok, notCancellable, notActive, changed, failed }`. Lee el margen en vivo, llama a `cancelByClient` con `expected` = `checkCancelBeforeSave(...) == ok` y, en la misma transacción, distingue el motivo con la comprobación pura sobre el turno releído. Si el turno estaba en edición (`editTargetProvider.id == shown.id`), vacía la selección y cierra la edición (RF-17; orden de MEMORY). RF-11 a RF-17.
  - Mientras guarda, el diálogo bloquea sus botones (RF-16): estado local del diálogo, no un provider.
- **`profile/providers/profile_provider.dart` (nuevo):**
  - `profileAppointmentsProvider` → `AsyncValue<ProfileAppointments<AppointmentModel>>` a partir de `myAppointmentsProvider` y `salonNowProvider` (RF-1, RF-5, RF-6, RF-20). Mantiene el error aunque Riverpod reintente (MEMORY).
  - `WhatsAppChanger` (`whatsAppChangeProvider`): `save(String raw)` → `ok | invalid | failed`; valida con `isValidWhatsApp`, busca el turno activo en `myAppointmentsProvider` y llama a `updateWhatsApp` (RF-27, RF-28, RF-30).
  - `AccountDeleter` (`accountDeletionProvider`, `AsyncNotifier`): `delete()` llama a `AccountRepository.deleteAccount()`, después `AuthController.signOut()`; expone cargando/éxito/error para RF-36, RF-38, RF-39, RF-40.
  - `accountRepositoryProvider` (nuevo, en este archivo; es el único que lo usa).

Repositorios: se reutilizan `bookingRepositoryProvider` y `userRepositoryProvider` (no se duplican).

## 7. Interfaz

### Perfil (las tres plataformas; RF-1 a RF-7, RF-20 a RF-25, RF-31, RF-43)
Una sola lista (D-12):
1. **Cabecera:** título y "Cerrar sesión" (`IconButton` con `tooltip`).
2. **Identidad:** foto, nombre, correo.
3. **Panel** (solo la admin).
4. **"Tu próximo turno"** (`ProfileActiveCard`, nuevo): día de la semana y fecha, `HH:mm – HH:mm` en hora del salón, servicio y adicionales (sin servicio si es antiguo, RF-44), estado. Debajo, según `cancelAvailability`: "Editar turno" + "Cancelar turno"; o el aviso "falta poco" con `WhatsappNoticeButton`; o el error del calendario con "Reintentar". Bloqueada: el aviso de bloqueo y "Cancelar turno" si es cancelable (D-5). "Editar turno" en Android/iOS cambia a la pestaña Reservas (`goBranch`) y abre la edición; en Web, `context.go('/booking')` y la edición. Sin turno activo: "No tienes turnos próximos" y "Reservar" (RF-5).
5. **"Historial"** (si no está vacío, RF-22): tarjetas sin acciones (`ProfileHistoryCard`, sustituye a `_AppointmentCard`) con fecha y hora del salón, servicio y etiqueta (`HistoryLabel`). Se distinguen por etiqueta y tono, sin opacidad (RNF-1). Cada tarjeta es un nodo semántico con una frase (RNF-2).
6. **Error al cargar los turnos:** en el lugar de 4 y 5, el texto y "Reintentar" (`ref.invalidate(myAppointmentsProvider)`) (RF-24).
7. **"Tu cuenta":** WhatsApp con "Cambiar" (RF-25); "Eliminar mi cuenta" (solo `allowed`) o, si está bloqueada, el aviso de hablar con el salón con WhatsApp (RF-40). La admin no ve ninguno de los dos para borrar (RF-31).
8. **Preferencias** (solo Android/iOS, como hoy).

### Reservas (RF-8, RF-12)
`ActiveAppointmentView` añade `CancelAppointmentButton` junto a "Editar turno" (y bajo el aviso de bloqueo, D-5). Tras cancelar, `bookingScreenProvider` pasa sola a la vista de reservar (el turno deja de ser activo en el stream).

### Diálogos y hojas
- **Cancelar** (`CancelAppointmentDialog`): día, hora del salón y servicio; "Sí, cancelar" / "No, mantener"; mientras guarda, indicador y botones desactivados. El resultado se muestra con un `SnackBar` (éxito) o un aviso con el texto de cada caso (RF-14, RF-15), anunciado al lector de pantalla (RNF-4). Textos leídos dentro del `builder` (cambio de idioma con el diálogo abierto).
- **Cambiar WhatsApp** (`ChangeWhatsAppDialog`): `WhatsAppField` con el número actual, el texto del consentimiento, error junto al campo (`errorStyle` con `brand.danger`), "Guardar" / "Cancelar" (RF-26 a RF-30).
- **Eliminar mi cuenta** (`DeleteAccountDialog`, dos pasos): (1) qué se borra y qué se conserva, "Continuar" / "Cancelar"; (2) "Escribe ELIMINAR para confirmar", campo y "Eliminar mi cuenta" activo solo si `deletionWordMatches`; mientras borra, indicador y botones desactivados (RF-32, RF-33, RF-38). Al terminar: aviso y navegación de D-14 (RF-36). Error: texto y "Reintentar" en el mismo diálogo (RF-39); bloqueada: el texto de RF-40.

### Agenda de la admin (RF-18, RF-35)
`_AppointmentCard` añade a sus marcas "Cancelado por la clienta" (`cancelledByClient`) y "Cuenta eliminada" (`accountDeleted`). Un turno de una cuenta eliminada no se busca como clienta con cuenta en `RecipientPicker` (su ficha ya no existe).

### Captura del WhatsApp (D-7)
`PhoneCaptureView` usa el mismo `WhatsAppField` y `isValidWhatsApp`, y muestra el error junto al campo en lugar de no hacer nada.

### Rutas
Sin rutas nuevas. `/profile` (Web) y la pestaña Perfil (móvil) siguen igual; las guardas de `resolveRedirect` no cambian. Tras borrar la cuenta: `/` o `/home` (D-14).

## 8. Textos nuevos (`app_es.arb` / `app_pt.arb`)

| Clave | ES | PT |
| --- | --- | --- |
| `profileNextAppointmentTitle` | Tu próximo turno | Seu próximo horário |
| `profileNoUpcoming` | No tienes turnos próximos | Você não tem horários marcados |
| `profileBookAction` | Reservar | Agendar |
| `profileHistoryTitle` | Historial | Histórico |
| `historyCancelledByYou` | Cancelado por ti | Cancelado por você |
| `historyCancelledBySalon` | Cancelado por el salón | Cancelado pelo salão |
| `historyDone` | Realizado | Realizado |
| `historyNotConfirmed` | No confirmado | Não confirmado |
| `profileAppointmentsRetry` | Reintentar | Tentar novamente |
| `cancelAppointmentAction` | Cancelar turno | Cancelar horário |
| `cancelDialogTitle` | ¿Cancelar tu turno? | Cancelar seu horário? |
| `cancelDialogBody(date, time, service)` | {date} a las {time} · {service} | {date} às {time} · {service} |
| `cancelConfirm` | Sí, cancelar | Sim, cancelar |
| `cancelKeep` | No, mantener | Não, manter |
| `cancelDone` | Tu turno se canceló | Seu horário foi cancelado |
| `cancelNotCancellable` | Ya no puedes cancelarlo: falta poco para tu turno. Escríbenos por WhatsApp. | Não é mais possível cancelar: falta pouco para o seu horário. Fale conosco pelo WhatsApp. |
| `cancelNotActive` | Este turno ya no está activo. | Este horário não está mais ativo. |
| `cancelChanged` | Tu turno cambió. Revísalo antes de cancelarlo. | Seu horário mudou. Confira antes de cancelar. |
| `cancelFailed` | No se pudo cancelar. Inténtalo de nuevo. | Não foi possível cancelar. Tente novamente. |
| `profileAccountTitle` | Tu cuenta | Sua conta |
| `profileWhatsAppLabel` | WhatsApp | WhatsApp |
| `changeAction` | Cambiar | Alterar |
| `changeWhatsAppTitle` | Cambiar WhatsApp | Alterar WhatsApp |
| `whatsAppInvalid` | Escribe un número de WhatsApp válido | Digite um número de WhatsApp válido |
| `whatsAppSaved` | Tu WhatsApp se actualizó | Seu WhatsApp foi atualizado |
| `whatsAppSaveFailed` | No se pudo guardar. Inténtalo de nuevo. | Não foi possível salvar. Tente novamente. |
| `deleteAccountAction` | Eliminar mi cuenta | Excluir minha conta |
| `deleteAccountExplain` | Se cancelará tu turno activo y se borrarán tu cuenta, tu nombre, tu correo, tu foto y tu WhatsApp. El salón conservará tus turnos, con tu nombre y tu WhatsApp, para su agenda. | Seu horário ativo será cancelado e sua conta, nome, e-mail, foto e WhatsApp serão apagados. O salão manterá seus horários, com seu nome e WhatsApp, na agenda. |
| `deleteAccountContinue` | Continuar | Continuar |
| `deleteAccountWord` | ELIMINAR | EXCLUIR |
| `deleteAccountTypeWord(word)` | Escribe {word} para confirmar | Digite {word} para confirmar |
| `deleteAccountDone` | Tu cuenta se eliminó | Sua conta foi excluída |
| `deleteAccountFailed` | No se pudo eliminar la cuenta. Inténtalo de nuevo. | Não foi possível excluir a conta. Tente novamente. |
| `deleteAccountBlocked` | Para eliminar tu cuenta, habla con el salón. | Para excluir sua conta, fale com o salão. |
| `adminAppointmentCancelledByClient` | Cancelado por la clienta | Cancelado pela cliente |
| `adminAppointmentAccountDeleted` | Cuenta eliminada | Conta excluída |

Se reutilizan: `bookingEditAction`, `cancelAction`, `whatsappDisclaimer`, `phoneHintExample`, `bookingEditClosed`, `bookingBlocked`, `myProfileTitle`, los estados `statusConfirmedClient`/`statusWaitingConfirmationClient`. `myAppointmentsTitle`, `noAppointmentsYet` y `bookAnotherAppointmentAction` dejan de usarse: se borran. Tras editar los `.arb`, `flutter gen-l10n`.

## 9. Archivos

| Archivo | Cambio | RF |
| --- | --- | --- |
| `lib/data/models/appointment_model.dart` | `cancelledByClient`, `accountDeleted` | 18, 20, 35 |
| `lib/data/repositories/booking_repository.dart` | `cancelByClient` | 11, 14, 15 |
| `lib/data/repositories/user_repository.dart` | `updateWhatsApp` | 28, 30 |
| `lib/data/repositories/account_repository.dart` (nuevo) | llamada a la función | 34, 37, 39, 40 |
| `lib/features/booking/logic/cancel_appointment.dart` (nuevo) | 4.1 | 3, 4, 7, 14 |
| `lib/features/booking/providers/booking_cancel_provider.dart` (nuevo) | disponibilidad y `AppointmentCanceller` | 3–17 |
| `lib/features/booking/presentation/cancel_appointment.dart` (nuevo) | botón y diálogo de cancelar | 8–10, 12, 14–16 |
| `lib/features/booking/presentation/active_appointment_view.dart` | botón de cancelar | 8 |
| `lib/features/profile/logic/profile_appointments.dart` (nuevo) | 4.2 | 1, 5, 20–22 |
| `lib/features/profile/logic/account_deletion.dart` (nuevo) | 4.3 | 31, 32, 40 |
| `lib/features/profile/providers/profile_provider.dart` (nuevo) | providers de § 6 | 1, 5, 6, 20, 24, 27–30, 34–40 |
| `lib/features/profile/presentation/profile_view.dart` | nueva estructura (§ 7) | 1–7, 20–25, 31, 43, 44 |
| `lib/features/profile/presentation/profile_cards.dart` (nuevo) | tarjeta activa e historial | 1–5, 20, 21, 44 |
| `lib/features/profile/presentation/change_whatsapp_dialog.dart` (nuevo) | diálogo | 26–30 |
| `lib/features/profile/presentation/delete_account_dialog.dart` (nuevo) | diálogo en dos pasos | 32, 33, 36, 38–40 |
| `lib/core/widgets/whatsapp_field.dart` (nuevo) | campo compartido | 26, 27 |
| `lib/features/auth/presentation/phone_capture_view.dart` | usa `WhatsAppField` e `isValidWhatsApp` | D-7 |
| `lib/features/admin/presentation/admin_dashboard_view.dart` | dos marcas nuevas | 18, 35 |
| `lib/l10n/app_es.arb`, `app_pt.arb` (+ generados) | § 8 | RC-1 |
| `firestore.rules`, `test/core/firestore_rules_test.dart`, `specs/009-perfil/rules-check.md` | § 3 | 19, 28, 42 |
| `functions/` (nuevo: `package.json`, `tsconfig.json`, `src/index.ts`, `src/delete_account.ts`, `test/delete_account.test.ts`) | función | 34, 35, 37, 39, 40, 42 |
| `firebase.json` | entrada `functions` | 37 |
| `pubspec.yaml` | `cloud_functions` (D-9) | 37 |
| `CLAUDE.md`, `MEMORY.md`, `docs/ESPECIFICACION.md` | campos nuevos, `functions/`, estado | — |

## 10. Tests (primero, en rojo)

Fakes: `FakeBookingRepository` gana `cancelByClient` (aplica `expected` como la transacción, cambia el turno en `mine`/`active`, quita el turno ocupado de `busy`, registra en `cancelled`, o lanza `cancelError`); `FakeUserRepository` gana `updateWhatsApp` (registra y emite la ficha, o lanza); `FakeAccountRepository` (nuevo, en `fake_auth.dart`) devuelve ok o una `AccountDeletionFailure`. Ningún test usa Firebase real. La función se prueba con un `AccountStore` en memoria.

| Test | Cubre |
| --- | --- |
| `test/features/booking/logic/cancel_appointment_test.dart`: disponibilidad (margen, borde exacto, margen 0, carga, error) y `checkCancelBeforeSave` (no activo, terminado, cambiado en hora o servicio, solo confirmado → ok, dentro del margen) | 3, 4, 7, 14 |
| `test/features/profile/logic/profile_appointments_test.dart`: activo e historial, orden, etiquetas (cancelado por ti/por el salón, sin `cancelledBy`, realizado, no confirmado), historial vacío | 1, 5, 20–22, D-1 |
| `test/features/profile/logic/account_deletion_test.dart`: acceso (admin, bloqueada, clienta) y palabra (mayúsculas, espacios, otra palabra) | 31, 32, 40 |
| `test/data/models/appointment_model_test.dart` (ampliar): campos nuevos, ausentes y `toMap` sin ellos | 18, 35, 44 |
| `test/features/booking/booking_cancel_test.dart`: `AppointmentCanceller` con el fake: ok, cada motivo, fallo/tiempo agotado, cierra la edición abierta | 11, 12, 14–17 |
| `test/features/booking/active_appointment_cancel_test.dart` (pantalla): botón en Reservas, diálogo, "No, mantener", éxito y vuelta a reservar, bloqueada con botón, botones desactivados mientras guarda | 8–10, 12, 16, D-5 |
| `test/features/profile/profile_view_test.dart` (pantalla): activo con hora del salón (`TZ=Europe/Lisbon` para verlo en rojo), servicio, sin servicio antiguo, editar/cancelar o aviso "falta poco" que cambia al pasar el minuto, sin activo con "Reservar", historial, error con "Reintentar" sin ocultar preferencias, admin sin "Eliminar" | 1–7, 20–25, 31, 43, 44 |
| `test/features/profile/change_whatsapp_test.dart` (pantalla): número actual escrito, inválido con error, guardado con turno activo (registra el id), cancelar, fallo | 25–30 |
| `test/features/profile/delete_account_test.dart` (pantalla): dos pasos, cancelar en cada uno, palabra en ES y PT, en curso sin doble envío, éxito → sesión cerrada y `/home` (móvil) o `/` (Web), fallo con "Reintentar", bloqueada | 32, 33, 36, 38–40 |
| `test/features/admin/…` (ampliar el de la agenda): marcas "Cancelado por la clienta" y "Cuenta eliminada" | 18, 35 |
| `test/features/auth/phone_capture_test.dart` (ampliar): captura con `isValidWhatsApp` y error junto al campo | D-7 |
| `test/core/firestore_rules_test.dart` (ampliar): las ramas nuevas de `appointments` y `busySlots`, `users` sigue sin `delete` | 19, 28, 42 |
| `functions/test/delete_account.test.ts` (`node --test`): sin sesión, admin, bloqueada, cancela solo el activo (también dentro del margen) y borra su turno ocupado, marca todos sin foto con nombre y WhatsApp intactos, borra ficha y Auth, repetir tras un fallo a mitad, ficha ya borrada, más de 400 turnos | 34, 35, 37, 39, 40, 42 |
| Contraste y accesibilidad: perfil, diálogos e historial en claro y oscuro con `textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`; 320 px con texto al 200 % | RNF-1 a RNF-4 |
| Idiomas: textos nuevos en ES y PT, también al cambiar el idioma con un diálogo abierto | RC-1 |
| Comprobación manual de las reglas en el simulador (`rules-check.md`) | 19, 28, 42 |

Puerta de cada tarea: `dart format lib test` sin cambios, `flutter analyze` limpio, `flutter test` en verde y, en las tareas de `functions/`, `npm test` y `npm run build` en verde.

RF-41 queda cubierto por lo que ya existe (ficha nueva y captura del WhatsApp al iniciar sesión con un uid nuevo); se comprueba en el recorrido manual.

## 11. Tamaño

Salen unas 14 tareas (lógica, modelo y repositorios, cancelar ×3, perfil ×3, WhatsApp, función ×2, app del borrado, reglas, cierre). La skill pide proponer dividir la spec si pasan de 10. Propuesta: **mantener una sola spec** (las partes comparten la tarjeta y los providers del perfil) y agrupar las tareas en tres bloques que se pueden fusionar por separado: (A) cancelar e historial, (B) WhatsApp, (C) borrar la cuenta. Si prefieres dividir, (C) pasa a ser la spec 009b.

## 12. Decisiones del autor (2026-11-18)
1. Aprobadas las dependencias de D-9: `cloud_functions` en la app; `firebase-admin`, `firebase-functions` y `typescript` en `functions/`. El proyecto pasa al plan Blaze para desplegar la función.
2. D-7 aceptada: `isValidWhatsApp` en el registro y en el cambio, con el mismo texto de consentimiento y sin casilla.
3. § 11: una sola spec, con las tareas en tres bloques: (A) cancelar e historial, (B) WhatsApp, (C) borrar la cuenta.

# Plan 011 — Avisos push a la admin
Estado: aprobada

Spec: `specs/011-push/spec.md` (aprobada el 2026-11-20).

## 1. Qué existe ya
- **`firebase_messaging` 17.0.1** está en `pubspec.yaml`, pero nada lo usa. Su manifiesto de Android ya declara `POST_NOTIFICATIONS`. Ninguna dependencia nueva hace falta, ni en la app ni en `functions/` (`firebase-admin` 14.5.1 trae `messaging`).
- **`UserModel.fcmToken`** y **`UserRepository.updateFcmToken`** existen sin uso. Un solo token por ficha no sirve para varios dispositivos (RF-19), y la ficha la leen la propia usuaria y la admin, lo que va contra RF-23.
- **`functions/`**: TypeScript ESM, Node 22, región `southamerica-east1`, con la lógica sin Firebase y probada con `node --test` (`deleteAccount`, spec 009). Esta spec sigue el mismo patrón: lógica pura, almacén sobre `firebase-admin` y adaptador.
- **El borrado de la cuenta** (009) cancela el turno activo con `status: 'cancelled'`, `cancelledBy: 'client'` y `accountDeleted: true` en una sola escritura. Para RF-3 se ve como cualquier cancelación de la clienta.
- **La agenda** (010): `adminSelectedDateProvider` guarda un día del salón (`agendaDay`). En Android/iOS, `/admin` es una ruta de nivel superior que Perfil abre con `push`. `rootNavigatorKey` y `goRouterProvider` dan acceso al navegador sin un `BuildContext` de pantalla.
- **Cierre de sesión**: `AuthController.signOut` → `AuthRepository.signOut`. Lo llaman Perfil, el botón de cuenta de Web y el borrado de la cuenta.
- **Las reglas** dejan a cada usuaria cambiar su ficha salvo `role` e `isBlocked`. No hay subcolecciones bajo `users`.
- **Android**: sin icono de notificación ni nombre de canal propios. **iOS**: sin `Runner.entitlements` ni `UIBackgroundModes`.

## 2. Decisiones

**D-1. Los dispositivos van en `users/{uid}/pushDevices/{token}`, que nadie lee desde la app.** (RF-19, RF-20, RF-23)
- Cada dispositivo es un documento: el id es el token, y los campos son `token`, `platform` (`'android'` | `'ios'`) y `updatedAt`.
- Las reglas dejan crear o cambiar solo a una admin dentro de su propia ficha, y borrar solo a su dueña. La lectura queda denegada a todos; el servidor lee con el SDK de administración.
- *Descartado:* un array `fcmTokens` en la ficha. Lo leerían la admin (que lista todas las fichas) y la propia usuaria, y dos dispositivos que escriben a la vez se pisan sin transacción.
- *Descartado también:* reutilizar `fcmToken`, que solo admite un dispositivo.

**D-2. El servidor decide el tipo de aviso por los datos del turno, no por quién escribió.** (RF-1 a RF-4)
Las reglas ya garantizan que cada cambio solo lo puede hacer una persona:

| Cambio en el turno | Quién puede hacerlo | Aviso |
|---|---|---|
| Se crea con `createdByAdmin == false` (y por tanto `clientId` propio) | Solo la clienta | Turno nuevo |
| Antes activo; después `waiting_confirmation` con otro inicio, fin o `booked` | Solo la clienta (la edición de la admin queda siempre `confirmed`) | Turno modificado |
| Antes activo; después `cancelled` con `cancelledBy == 'client'` | Solo la clienta o `deleteAccount` (la admin solo puede cambiar `status`) | Turno cancelado |
| Cualquier otro (confirmar, cancelar o bloquear la admin, copiar el WhatsApp, marcar `accountDeleted` en turnos pasados, borrar) | — | Ninguno |

- Que la clienta edite o cancele un turno que agendó la admin genera aviso (casos límite de la spec).
- *Descartado:* `onDocumentWrittenWithAuthContext`, que dice quién escribió. `deleteAccount` escribe con el SDK de administración, así que su cancelación no parecería de la clienta (RF-3). Además, la regla de datos ya es exacta.

**D-3. Una función `onDocumentWritten('appointments/{id}')` en la región de la base de datos.** (RF-6, RF-24)
- La función no reintenta, para no duplicar avisos (RF-5). Si el envío falla, solo se registra en el log: la reserva ya está guardada (RF-24).
- **Región:** la de Firestore. Hay que mirar en la consola la ubicación de la base de datos de `shaddai-68df1`. Si es `southamerica-east1`, la función va allí, como `deleteAccount`. Si es multirregión (`nam5`), va en `us-central1`. Es una tarea de despliegue, no del código.

**D-4. Un aviso por evento y dispositivo.** (RF-5)
- El servidor junta los tokens de todas las admins y quita los repetidos (la misma admin dos veces, o dos admins en un mismo teléfono).
- Cada mensaje lleva una etiqueta sacada del id del evento: `android.notification.tag` y `apns-collapse-id`, como hash de 32 caracteres. Si la plataforma entregara el evento dos veces, el segundo aviso sustituye al primero en vez de apilarse.

**D-5. Los tokens inválidos se borran al enviar.** (RF-21, RF-22)
- Si FCM responde `messaging/registration-token-not-registered` o `messaging/invalid-registration-token`, el servidor borra ese `pushDevices`. Otros errores no borran nada.
- Una usuaria que deja de ser admin no recibe avisos, porque el servidor solo lee los dispositivos de las fichas con `role == 'admin'`.

**D-6. El texto del aviso lo escribe el servidor, en español, con la hora del salón (UTC−3 fijo, como en la app).** (RF-7 a RF-11)
- Los nombres de los días y los meses están escritos a mano en la lógica, sin depender de `Intl`, para que los tests den siempre lo mismo.
- El servicio es `booked.name.es`, o `pt` si falta. Sin `booked`, el aviso va sin servicio.
- El aviso nunca lleva el WhatsApp, la foto ni el correo (RNF-4).

**D-7. Cerrar sesión borra el registro y anula el token, y si no puede, lo reintenta.** (RF-20, RF-25, casos límite)
- En `AuthController.signOut`, antes de cerrar la sesión de Firebase, el registrador:
  1. borra `users/{uid}/pushDevices/{token}`;
  2. llama a `deleteToken()`, que invalida el token en FCM aunque el documento quedara.
- Si algo falla (por ejemplo, sin conexión), la sesión se cierra igual y queda en el dispositivo una marca **"token pendiente de anular"**.
- Al abrir la app, si hay marca y la sesión no es de admin, se vuelve a llamar a `deleteToken()`. El servidor borra el documento que quedara la próxima vez que falle al enviar (D-5).
- *Descartado:* confiar solo en borrar el documento. Sin conexión, la escritura queda en la cola de Firestore de la usuaria anterior y no se envía al cambiar de cuenta.

**D-8. El permiso se pide tras una explicación, una sola vez por dispositivo.** (RF-15 a RF-18)
- `firebase_messaging` no distingue en Android "nunca preguntado" de "denegado". Por eso el repositorio guarda en el dispositivo (`shared_preferences`, nunca Firestore, spec 001 RNF-3) que ya se preguntó.
- Junta esa marca con el estado del sistema en un `PushPermission`: `notAsked` | `granted` | `denied`.
- La explicación es un diálogo con un solo botón, "Continuar", y no se cierra tocando fuera. Al pulsarlo se pide el permiso del sistema.
- Si se deniega, el panel muestra un aviso fijo (RF-17) y no se vuelve a pedir.
- Al volver la app a primer plano, se lee otra vez el estado: si lo activó en los ajustes, se registra el dispositivo (RF-18).
- *Descartado:* "Ahora no" en la explicación. Dejaría un tercer estado que la spec no contempla.

**D-9. Con la app abierta, el aviso es un `SnackBar` con "Ver", no una notificación del sistema.** (RF-14)
- Android no muestra los avisos en primer plano, y iOS tampoco con las opciones por defecto. Así no hace falta `flutter_local_notifications`.
- Se usa el `ScaffoldMessenger` de la app (`scaffoldMessengerKey` en `MaterialApp.router`) para que aparezca sobre cualquier pantalla, también el panel. Es flotante, dura 8 s y lo anuncia el lector de pantalla.
- Si la sesión no es de admin, el aviso se ignora.

**D-10. Tocar el aviso o "Ver" abre la agenda del día del turno.** (RF-12, RF-13)
- El aviso lleva en `data` el campo `day` (`'YYYY-MM-DD'`, día del salón), además de `kind` y `appointmentId`.
- La app espera a que `currentUserProvider` deje de cargar, con un máximo de 10 s.
  - Si es admin: pone `adminSelectedDateProvider` en ese día. Si la ruta de arriba no es `/admin`, hace `push('/admin')`, de modo que "atrás" vuelve a donde estaba (con la app cerrada, a Inicio).
  - Si no es admin: no hace nada (RF-13).
- Funciona igual con la app cerrada (`getInitialMessage`), en segundo plano (`onMessageOpenedApp`) y con "Ver".

**D-11. Todo lo de push pasa por un `PushRepository` en `lib/data/`, y nada se ejecuta en Web.** (Plataformas, constitución 3)
- Las vistas y los providers reciben `PushNotice` (título, texto y `data`), nunca un `RemoteMessage`.
- Con `isWebProvider` a `true`, el controlador no hace nada y no toca `FirebaseMessaging`.
- Los tests usan `FakePushRepository`, que los helpers (`pumpApp`, `pumpWebApp`, `pumpMobileApp`) ponen por defecto con el permiso `granted`. Así ningún test existente ve el diálogo ni toca Firebase.

**D-12. Nombre del canal y pequeño icono en Android.** (Criterios: que se vea bien en Android)
- **Canal:** FCM crea su canal de respaldo con el nombre del recurso `fcm_fallback_notification_channel_label`. Se sobrescribe en `android/app/src/main/res/values/strings.xml` ("Avisos de turnos") y `values-pt/strings.xml` ("Avisos de horários"). Es la única excepción a "textos en `.arb`", porque Android lo lee antes de que exista Flutter.
- **Icono:** `ic_notification`, un vector monocromo del sello (`BrandLogo`), declarado como `default_notification_icon`, con `default_notification_color` en el verde de la marca. Sin él, Android pinta el icono de la app como un cuadrado blanco.
- *Descartado:* crear canales propios, que obliga a usar `flutter_local_notifications` (dependencia nueva).

**D-13. `fcmToken` queda obsoleto.** Se deja de escribir y se borra `UserRepository.updateFcmToken`, que nadie usa. `UserModel` lo sigue leyendo, para no romper fichas antiguas (constitución 5), y `toMap` deja de escribirlo. No se migra nada.

**D-14. iOS queda configurado pero sin probar avisos reales.**
- Se añaden `Runner.entitlements` con `aps-environment` y `UIBackgroundModes: remote-notification`.
- La clave APNs en Firebase y la prueba real necesitan la cuenta de Apple (spec 013). Queda anotado en `MEMORY.md` y en `functions/README.md`.

## 3. Datos y reglas

**Firestore.**
- **Nuevo:** `users/{uid}/pushDevices/{token}`, con `{ token: string, platform: 'android' | 'ios', updatedAt: timestamp }`.
- **Sin cambios:** `appointments`, `busySlots`, `closures` y `settings`.
- **Índices:** ninguno. `users where role == 'admin'` usa el índice automático, y cada subcolección se lee entera.

**`firestore.rules`** (RF-23, RNF-5). Un `match` nuevo dentro de `/users/{userId}`:
```
match /pushDevices/{token} {
  allow read: if false;
  allow create, update: if signedIn() && request.auth.uid == userId && isAdmin()
    && request.resource.data.keys().hasOnly(['token', 'platform', 'updatedAt'])
    && request.resource.data.token == token
    && request.resource.data.platform in ['android', 'ios']
    && request.resource.data.updatedAt == request.time;
  allow delete: if signedIn() && request.auth.uid == userId;
}
```
- Borrar el registro no exige ser admin, para que una usuaria que dejó de serlo pueda limpiar el suyo.
- Las reglas de `users`, `appointments` y el resto no cambian.
- Se comprueban a mano en `specs/011-push/rules-check.md`. Casos del simulador:
  - la admin crea su dispositivo: permitido;
  - una clienta crea uno: denegado;
  - la admin crea uno en la ficha de otra: denegado;
  - un `token` distinto del id: denegado;
  - un campo de más: denegado;
  - `platform: 'web'`: denegado;
  - la admin lee uno suyo: denegado;
  - la admin lista los de otra: denegado;
  - la dueña lo borra: permitido;
  - otra persona lo borra: denegado;
  - una exadmin borra el suyo: permitido.

## 4. Lógica pura

### Servidor (`functions/src/appointment_notice.ts`, sin Firebase)
```ts
type NoticeKind = 'created' | 'edited' | 'cancelled';
interface NoticeAppointment {                        // lo que importa del turno
  clientId: string | null; clientName: string; status: string;
  start: Date; end: Date; bookedKey: string;         // booked serializado, para comparar
  serviceName: string | null; createdByAdmin: boolean;
  cancelledByClient: boolean; accountDeleted: boolean;
}
noticeKind(before: NoticeAppointment | null, after: NoticeAppointment | null): NoticeKind | null   // D-2
salonDay(start: Date): string                        // 'YYYY-MM-DD' en UTC−3
noticeText(kind, appointment): { title: string; body: string }  // D-6
uniqueTokens(devices: { uid; token }[]): string[]    // D-4, orden estable
noticeTag(eventId: string): string                   // D-4, 32 caracteres
```

Pseudocódigo de `noticeKind`:
```
si after == null → null                                  // se borró
activo(a) = a.status in {waiting_confirmation, confirmed}
si before == null:
  devuelve 'created' si !after.createdByAdmin y after.clientId != null y after.status == waiting_confirmation
  si no, null
si activo(before) y after.status == cancelled y after.cancelledByClient → 'cancelled'
si activo(before) y after.status == waiting_confirmation
   y (start, end o bookedKey cambiaron) → 'edited'
null
```

Textos (`noticeText`). La fecha es "viernes 21 de noviembre, 10:00", con la hora en "H:mm", como `DateFormat.Hm('es')`. El servicio va precedido de " · ", solo si existe.

| Tipo | Título | Texto |
|---|---|---|
| created | Turno nuevo | `{nombre} · {fecha}{ · servicio}. Espera tu confirmación.` |
| edited | Turno modificado | `{nombre} lo cambió a {fecha}{ · servicio}. Espera tu confirmación.` |
| cancelled | Turno cancelado | `{nombre} canceló su turno del {fecha}. La hora queda libre.` |
| cancelled con `accountDeleted` | Turno cancelado | `{nombre} eliminó su cuenta y se canceló su turno del {fecha}. La hora queda libre.` |

Si el nombre está vacío, el texto dice "Una clienta".

### Envío (`functions/src/notify_admins.ts`, sin Firebase)
```ts
interface NoticeStore {
  adminDevices(): Promise<{ uid: string; token: string }[]>;  // dispositivos de role == 'admin'
  send(tokens: string[], message: NoticeMessage): Promise<SendResult[]>; // uno por token, en orden
  removeDevice(uid: string, token: string): Promise<void>;
}
notifyAdmins(store, eventId, appointmentId, before, after): Promise<{ sent: number; removed: number }>
```

Pseudocódigo:
```
kind = noticeKind(before, after); si null → {0, 0}
devices = store.adminDevices(); tokens = uniqueTokens(devices); si vacío → {0, 0}   // RF-24
message = { notification: noticeText(kind, after),
            data: { kind, appointmentId, day: salonDay(after.start) },
            tag: noticeTag(eventId) }
results = store.send(tokens, message)
por cada token con error "no registrado" o "inválido": removeDevice de cada uid que lo tenía   // D-5
```

`index.ts` exporta `notifyAdminsOnAppointmentWrite`:
- envuelve la llamada en `try/catch` con `logger.error` y nunca la relanza (RF-24, D-3);
- no reintenta;
- `admin_store.ts` gana `noticeStore(db, messaging)`, que usa `sendEach` con `android.priority: 'high'`, `android.notification.tag` y `apns.headers['apns-collapse-id']`.

### App (`lib/features/admin/logic/push_notices.dart`, sin Flutter ni Firebase)
```dart
// PushPermission { notAsked, granted, denied } vive en data/models/push_notice.dart (lo devuelve el repositorio, T3)
bool shouldExplainPush({required bool isWeb, required UserModel? user, required PushPermission permission});
  // !isWeb && user?.role == 'admin' && permission == notAsked              (RF-15, RF-16)
bool shouldRegisterDevice({required bool isWeb, required UserModel? user, required PushPermission permission});
  // !isWeb && user?.role == 'admin' && permission == granted               (RF-18, RF-16)
bool showPushDisabled({required bool isWeb, required UserModel? user, required PushPermission permission});
  // !isWeb && user?.role == 'admin' && permission == denied                (RF-17)
bool shouldRevokeToken({required bool pendingRevoke, required UserModel? user});
  // pendingRevoke && user?.role != 'admin'                                 (D-7)
DateTime? noticeDay(Map<String, String> data);
  // 'YYYY-MM-DD' válido → agendaDay(DateTime.utc(y, m, d)); si no, null   (RF-12)
```

## 5. Archivos

**`functions/`**

| Archivo | Responsabilidad | RF |
|---|---|---|
| `src/appointment_notice.ts` (nuevo) | Tipo, día, texto, tokens únicos y etiqueta | RF-1 a RF-11 |
| `src/notify_admins.ts` (nuevo) | Orquesta el envío y la limpieza | RF-5, RF-19, RF-21, RF-22, RF-24 |
| `src/notice_store.ts` (nuevo) | Almacén sobre `firebase-admin` (Firestore y Messaging); convierte el documento en `NoticeAppointment` (lectura tolerante, como la app) | RF-6, RF-19, RF-21 |
| `src/index.ts` | Exporta el disparador (D-3) | RF-6, RF-24 |
| `test/appointment_notice.test.ts` y `test/notify_admins.test.ts` (nuevos) | Tests sin Firebase | — |
| `README.md` y `package.json` (`description`) | La función nueva, la región y la clave APNs pendiente | — |

**`lib/data/`**

| Archivo | Responsabilidad | RF |
|---|---|---|
| `repositories/push_repository.dart` (nuevo) | Envuelve `FirebaseMessaging` y escribe `pushDevices` (ver detalle abajo) | RF-12 a RF-21, RF-25 |
| `models/push_notice.dart` (nuevo) | `PushNotice { title, body, data }`, sin Firebase | RF-12, RF-14 |
| `repositories/user_repository.dart` | Se borra `updateFcmToken` (D-13) | — |
| `models/user_model.dart` | `toMap` deja de escribir `fcmToken` y se documenta como obsoleto (D-13) | — |

`PushRepository` recibe `FirebaseMessaging?`, `FirebaseFirestore?` y `SharedPreferences?` por constructor. Sus métodos:
- `permission()`, `requestPermission()`;
- `token()`, `onTokenRefresh`, `deleteToken()`;
- `registerDevice(uid, token, platform)` (`set` con `updatedAt: serverTimestamp`), `unregisterDevice(uid, token)`;
- `initialNotice()`, `onNoticeOpened`, `onForegroundNotice`;
- `pendingRevoke` / `setPendingRevoke(bool)`;
- la marca "ya preguntado" (D-8).

**`lib/features/admin/`**

| Archivo | Responsabilidad | RF |
|---|---|---|
| `logic/push_notices.dart` (nuevo) | Lógica pura (§ 4) | RF-12, RF-15 a RF-18 |
| `providers/admin_push_provider.dart` (nuevo) | `pushRepositoryProvider`, `pushPermissionProvider` y `AdminPushController` (§ 6) | RF-12 a RF-21, RF-25 |
| `presentation/admin_push_gate.dart` (nuevo) | Widget sin interfaz propia que envuelve la app en Android/iOS: arranca el controlador, muestra la explicación, el `SnackBar` y navega al tocar | RF-12 a RF-15 |
| `presentation/admin_push_dialog.dart` (nuevo) | La explicación del permiso | RF-15, RNF-1 a RNF-3 |
| `presentation/admin_dashboard_view.dart` | El aviso de permiso denegado, arriba de la agenda | RF-17 |

**Resto de la app**

| Archivo | Responsabilidad | RF |
|---|---|---|
| `features/auth/providers/auth_provider.dart` | `AuthController.signOut` llama antes a `AdminPushController.unregister()` sin esperar más de 5 s ni lanzar (D-7) | RF-20, RF-25 |
| `main.dart` | `scaffoldMessengerKey` y `AdminPushGate` en el `builder` de `MaterialApp.router` | RF-14 |
| `core/router/app_router.dart` | `appScaffoldMessengerKey`, junto a `rootNavigatorKey` | RF-14 |
| `l10n/app_es.arb` y `app_pt.arb` (+ `flutter gen-l10n`) | Los textos del § 8 | RNF-1 |

**Plataformas, reglas y documentos**

| Archivo | Responsabilidad | RF |
|---|---|---|
| `android/app/src/main/AndroidManifest.xml` | `default_notification_icon` y `default_notification_color` (D-12) | — |
| `android/app/src/main/res/drawable/ic_notification.xml` (nuevo) | Icono monocromo | — |
| `android/app/src/main/res/values{,-pt}/strings.xml` y `values/colors.xml` | Nombre del canal y color (D-12) | — |
| `ios/Runner/Runner.entitlements` (nuevo), `Info.plist` y `project.pbxproj` | `aps-environment` y `remote-notification` (D-14) | — |
| `firestore.rules` | `pushDevices` (§ 3) | RF-23 |
| `specs/011-push/rules-check.md` (nuevo) | Simulador y recorrido real | RF-23 |
| `test/helpers/fake_push.dart` (nuevo) | `FakePushRepository` | — |
| `test/helpers/pump_app.dart` y `pump_web_app.dart` | Lo ponen por defecto (D-11) | — |
| `CLAUDE.md`, `docs/ESPECIFICACION.md` y `MEMORY.md` | Push implementado; el modelo de datos pasa de "token de notificaciones" a "dispositivos de la admin" | — |

## 6. Interfaz y estado

**Providers.**
- `pushRepositoryProvider`: `Provider<PushRepository>`.
- `pushPermissionProvider`: `StateProvider<PushPermission?>`, que se lee al arrancar y al volver a primer plano.
- `adminPushControllerProvider`: `Provider<AdminPushController>`, con `ref.onDispose` para cancelar las suscripciones.

**`AdminPushController`.** Recibe el repositorio, `isWeb`, una forma de leer el usuario actual y la de abrir la agenda. No hace nada en Web.
- **`start()`** se llama una vez desde `AdminPushGate`:
  1. lee el permiso;
  2. aplica D-7 (`shouldRevokeToken` → `deleteToken`, y quita la marca si sale bien);
  3. se suscribe a `currentUserProvider`, `onTokenRefresh`, `onNoticeOpened` y `onForegroundNotice`;
  4. procesa `initialNotice()`.
- **`sync()`** se ejecuta al cambiar el usuario o el permiso, al volver a primer plano y al refrescarse el token. Si `shouldRegisterDevice`, hace `token()` y `registerDevice`, y guarda en el dispositivo el uid registrado. Los errores van a `debugPrint` y se reintenta la próxima vez (RF-25).
- **`requestPermission()`**, tras la explicación: marca que se preguntó, pide el permiso y llama a `sync()`.
- **`unregister()`**, al cerrar sesión (D-7): borra el documento, llama a `deleteToken()` y, si algo falla, pone la marca "pendiente de anular". Nunca lanza.
- **`open(PushNotice)`** (D-10): espera al usuario. Si es admin y `noticeDay` no es nulo, cambia el día y abre `/admin` si no está arriba.

**`AdminPushGate`.** Es un `ConsumerStatefulWidget` en el `builder` de la app, solo para Android/iOS: en Web devuelve el hijo sin más.
- Escucha `AppLifecycleState.resumed` para RF-18.
- Cuando `shouldExplainPush` se cumple, muestra `AdminPushDialog` con el contexto de `rootNavigatorKey` (RF-15), una sola vez por sesión de la app.
- Muestra el `SnackBar` de los avisos en primer plano (RF-14): título en negrita, texto y la acción "Ver" → `open`.

**`AdminDashboardView`.** Si `showPushDisabled`, muestra arriba de la agenda una tarjeta con el icono `notifications_off`, el título y el texto del § 8 (RF-17).
- Usa los tokens de `context.brand` para el contraste.
- Es una sola frase para el lector de pantalla (`Semantics(container: true)`).
- Crece con el texto, sin alto fijo (RNF-3).
- En Web no sale nunca.

**Rutas.** No cambian. Se reutiliza `/admin` de Android/iOS. Las guardas tampoco cambian: el controlador comprueba el rol (RF-13).

**Web.** Nada nuevo: ni la puerta, ni el aviso de permiso, ni llamadas a `FirebaseMessaging`.

## 7. Flujo completo
1. Una clienta reserva, edita o cancela (desde Web, Android o iOS). Se guarda el turno.
2. Firestore dispara `notifyAdminsOnAppointmentWrite`, que aplica `noticeKind`. Si hay aviso, lee los dispositivos de las admins, envía un mensaje por token y borra los inválidos.
3. En el teléfono de la admin:
   - con la app cerrada o en segundo plano, el sistema muestra la notificación, y al tocarla `getInitialMessage`/`onMessageOpenedApp` llevan a `open`;
   - en primer plano, `onMessage` lleva al `SnackBar` y "Ver" a `open`.
4. `open` pone el día y abre la agenda, que ya muestra el turno en vivo (spec 010).

## 8. Textos nuevos (`.arb`, ES / PT)

| Clave | ES | PT |
|---|---|---|
| `adminPushExplainTitle` | Avisos de turnos | Avisos de horários |
| `adminPushExplainBody` | Te avisaremos en este teléfono cuando una clienta reserve, cambie o cancele un turno. A continuación, el teléfono te pedirá permiso para mostrar notificaciones. | Vamos avisar neste celular quando uma cliente agendar, alterar ou cancelar um horário. Em seguida, o celular vai pedir permissão para mostrar notificações. |
| `adminPushExplainContinue` | Continuar | Continuar |
| `adminPushDisabledTitle` | Avisos desactivados | Avisos desativados |
| `adminPushDisabledBody` | Este teléfono no muestra los avisos de turnos. Para recibirlos, activa las notificaciones de la app en los ajustes del teléfono. | Este celular não mostra os avisos de horários. Para recebê-los, ative as notificações do app nos ajustes do celular. |
| `adminPushView` | Ver | Ver |
| `adminPushViewLabel` | Ver la agenda de ese día | Ver a agenda desse dia |

Los avisos push en sí van en español y viven en `functions/` (RF-7, D-6). El nombre del canal de Android va en los recursos de Android (D-12).

## 9. Tests

**`functions/` (`npm test`, sin Firebase)**
- **`appointment_notice.test.ts`:**
  - `noticeKind` en cada fila de la tabla de D-2: crea la clienta; crea la admin; persona sin cuenta; la clienta edita la hora, el servicio o solo los adicionales; la admin edita; la admin confirma; la admin cancela; bloqueo; la clienta cancela; borrado de cuenta con turno activo; turno pasado marcado `accountDeleted`; WhatsApp copiado; turno borrado; la clienta cancela uno agendado por la admin → aviso. (RF-1 a RF-4)
  - `noticeText` en los tres tipos, sin servicio, con la cuenta borrada y sin nombre, con un turno a las 22:30 de Curitiba (otro día en UTC), en español, y sin WhatsApp ni foto. (RF-7 a RF-11, RNF-4)
  - `salonDay`, `uniqueTokens` y `noticeTag` (estable y de 32 caracteres). (RF-5)
- **`notify_admins.test.ts`**, con un almacén en memoria:
  - sin tipo no envía;
  - sin dispositivos no envía ni falla (RF-24);
  - un token repetido se envía una vez (RF-5);
  - dos admins, varios dispositivos (RF-19);
  - los no registrados o inválidos se borran de cada dueña y los demás errores no (RF-21);
  - el mensaje lleva `day`, `kind`, `appointmentId` y la etiqueta (RF-12);
  - si `send` lanza, `notifyAdmins` lo propaga y el adaptador lo registra sin relanzar (RF-24).
- **RF-22:** lo garantiza la consulta por `role == 'admin'` del almacén real. Se prueba en `rules-check.md` (una exadmin no recibe avisos).

**Flutter (sin Firebase, con `FakePushRepository`)**
- **`test/features/admin/push_notices_logic_test.dart`:** las cinco funciones del § 4 (Web, clienta, visitante, admin con cada permiso; `noticeDay` válido, inválido o ausente). (RF-12, RF-15 a RF-18)
- **`test/features/admin/admin_push_controller_test.dart`**, con un `ProviderContainer`:
  - registra con admin y `granted`;
  - no registra a una clienta ni en Web, ni toca el repositorio (RF-16);
  - vuelve a registrar al refrescarse el token y al volver a primer plano (RF-18, RF-21);
  - los errores de registro no salen (RF-25);
  - `unregister` borra y anula; si falla, deja la marca y la siguiente apertura sin admin anula (RF-20, D-7).
- **`test/features/auth/sign_out_push_test.dart`:**
  - cerrar sesión llama a `unregister` antes que a `AuthRepository.signOut`;
  - si `unregister` falla o tarda, la sesión se cierra igual. (RF-20, RF-25)
- **`test/features/admin/admin_push_gate_test.dart`**, con `pumpMobileApp`:
  - admin con `notAsked`: sale la explicación; "Continuar" pide el permiso y no se repite (RF-15);
  - una clienta o con `granted`: no sale (RF-16);
  - un aviso en primer plano muestra el título, el texto y "Ver", y lo anuncia; "Ver" abre `/admin` en el día del aviso (RF-14, RF-12);
  - `initialNotice` con la app cerrada abre la agenda de ese día; un aviso con la sesión de una clienta no navega (RF-12, RF-13);
  - con la agenda ya arriba, solo cambia el día;
  - en ES y PT.
- **`test/features/admin/admin_push_disabled_test.dart`:**
  - con `denied`, el aviso sale en el panel, y no sale en Web ni con `granted` (RF-17);
  - al volver a primer plano con `granted`, desaparece y se registra (RF-18).
- **`test/features/admin/admin_push_accessibility_test.dart`**, en claro y oscuro (RNF-1 a RNF-3):
  - contraste de la explicación (`expectDialogTextContrast`), del aviso de permiso y del `SnackBar`;
  - "Continuar" y "Ver" de 48 px, con su nombre;
  - con el texto al 200 % en 320 px, en ES y PT, sin desbordes;
  - el `SnackBar` se anuncia al lector de pantalla (RNF-2).
- **`test/features/admin/admin_push_texts_test.dart`:** las claves del § 8 están en los dos `.arb` (RC-1).
- **Los tests existentes** siguen en verde con el fake por defecto (D-11).

**A mano** (`specs/011-push/rules-check.md`):
- el simulador de reglas (§ 3);
- el recorrido real en Android: reserva, edición y cancelación desde otra cuenta, y una cancelación al borrar la cuenta, con la app cerrada, en segundo plano y en primer plano;
- dos dispositivos;
- cerrar sesión con y sin conexión;
- permiso denegado y activado después;
- lo que hace la admin no avisa;
- el icono y el nombre del canal.

`RF-6` (≤ 1 minuto) solo se puede comprobar en este recorrido. iOS queda pendiente de la cuenta de Apple.

**Cobertura:**

| RF | Dónde |
|---|---|
| RF-1 a RF-4 | `appointment_notice` |
| RF-5 | `appointment_notice`, `notify_admins` |
| RF-6 | Recorrido |
| RF-7 a RF-11 | `appointment_notice` |
| RF-12 a RF-14 | Puerta y lógica |
| RF-15 a RF-18 | Lógica, controlador, puerta y aviso de permiso |
| RF-19 a RF-21 | `notify_admins`, controlador |
| RF-22 | Recorrido |
| RF-23 | `rules-check` |
| RF-24 | `notify_admins` |
| RF-25 | Controlador, cierre de sesión |
| RNF-1 a RNF-3 | Accesibilidad y textos |
| RNF-4 | `appointment_notice` |
| RNF-5 | `rules-check` y D-3 |
| RC-1 | Textos |

## 10. Lo que necesita tu aprobación
- **Cambio en Firestore y en las reglas:** la subcolección `users/{uid}/pushDevices` (D-1, § 3) y dejar de escribir `fcmToken` (D-13).
- **Una Cloud Function nueva** (D-3): hay que desplegarla con `firebase deploy --only functions`, en la región de la base de datos.
- **Ninguna dependencia nueva.**
- **Una excepción a "textos en `.arb`":** el nombre del canal de Android, en recursos nativos (D-12).

# Cloud Functions de Studio Shaddai

## `deleteAccount` (spec 009)

Función invocable que borra la cuenta de la clienta con la sesión iniciada:
cancela su turno activo, marca sus turnos como de una cuenta borrada (sin
foto, con nombre y WhatsApp), y borra su ficha y su cuenta de Auth. Región
`southamerica-east1` (São Paulo), Node 22.

- `src/delete_account.ts`: la lógica, sin Firebase.
- `src/handler.ts`: toma el uid de la sesión y traduce los errores a
  `HttpsError` (`unauthenticated`, `permission-denied`,
  `failed-precondition` con `details.reason = 'blocked'`, `internal`).
- `src/admin_store.ts`: el almacén sobre `firebase-admin`.
- `src/index.ts`: exporta `deleteAccount`, `notifyAdminsOnAppointmentWrite`
  y las funciones de la agenda.

## `notifyAdminsOnAppointmentWrite` (spec 011)

Disparador de Firestore (`onDocumentWritten` en `appointments/{id}`) que
avisa por push a las admins cuando una clienta reserva, edita o cancela un
turno. Lo que hace la admin no avisa. El aviso va en español, con la hora del
salón, a todos los dispositivos registrados en `users/{uid}/pushDevices` de
las fichas con `role == 'admin'`. Cada dispositivo es su FID (Firebase
Installation ID), no un token de FCM: se envía con `fid`. Los FID que FCM da
por no registrados o inválidos se borran. Sin reintentos: si el envío falla, queda en el registro
y el turno sigue guardado.

- `src/appointment_notice.ts`: qué aviso genera cada cambio y qué dice, sin
  Firebase.
- `src/notify_admins.ts`: el envío y la limpieza, la versión que nunca lanza
  y la lectura tolerante del documento, sin Firebase.
- `src/notice_store.ts`: el almacén sobre `firebase-admin` (Firestore y
  Messaging, `sendEach`).

**Región.** Tiene que ser la de la base de datos de Firestore. Está puesta en
`southamerica-east1` (`FIRESTORE_REGION` en `src/index.ts`). Antes del primer
despliegue, comprobarla en la consola (Firestore → Base de datos →
ubicación); si es la multirregión `nam5`, cambiarla a `us-central1`.

**iOS.** Para que los avisos lleguen a iOS hace falta subir la clave APNs
(`.p8`) en la consola (Configuración del proyecto → Cloud Messaging), que
requiere la cuenta de desarrollador de Apple (spec 013). Android no necesita
nada más.

## `bookAppointment`, `editAppointment` y `saveClosure` (spec 012)

Funciones invocables que escriben en la agenda. Son el **único** camino para
crear o editar un turno y para crear un cierre: las reglas de Firestore ya no
lo permiten desde la app. Región `southamerica-east1`.

- `bookAppointment`: la clienta reserva para sí misma (esperando
  confirmación, con los datos de su ficha); la admin, para otra persona
  (confirmado y marcado).
- `editAppointment`: la clienta edita su turno activo fuera del margen; la
  admin, cualquier turno activo, también en curso.
- `saveClosure`: la admin guarda un cierre si no pisa turnos activos.

Cada una corre en una transacción que lee el candado `locks/agenda` y lo
escribe al final, así dos escrituras a la vez se ordenan y la segunda ve lo
que guardó la primera: no se solapan turnos ni cierres, ni una persona tiene
dos turnos activos. Comprueban horario, ventana, cierres, fechas bloqueadas,
que el servicio quepa y lo reservado contra la lista de precios vigente.

**Respuestas.** El uid sale de la sesión (`unauthenticated` sin ella). Datos
con otra forma: `invalid-argument`. Un rechazo: `failed-precondition` (o
`permission-denied` sin ficha o sin ser admin) con el motivo en
`details.reason` (`slot_taken`, `closed`, `outside_hours`, `outside_window`,
`past`, `does_not_fit`, `already_active`, `person_active`,
`recipient_blocked`, `item_unavailable`, `item_changed`, `not_active`,
`changed`, `not_editable`, `blocked`, `invalid`) y, en `conflicts`, los ids
en `details.ids`. Nunca llevan datos de otras personas. Cualquier otro fallo
queda en el registro y llega como `internal`.

- `src/agenda_rules.ts`: las reglas de horas y de la persona, traducidas de
  la app. `test/fixtures/agenda_rules_cases.json` (en la raíz del
  repositorio) lo pasan la app y el servidor: si cambia una regla, cambia en
  los dos y se añade su caso.
- `src/booked_catalog.ts`: lo reservado contra `settings/priceList`.
- `src/agenda_write.ts`: los tres casos de uso, sin Firebase.
- `src/agenda_handler.ts`: la sesión, la forma de los datos y los errores.
- `src/agenda_store.ts`: el almacén sobre `firebase-admin`. Sin índices
  nuevos (`endTime >= now` y `end >= now` filtran un solo campo).

**Orden de despliegue** (la app vieja no podría reservar con las reglas
nuevas): primero las funciones, después la app que las llama y por último
las reglas (`specs/012-reglas/rules-check.md`).

## Comandos

```bash
cd functions
npm install
npm test        # node --test, sin Firebase
npm run build   # tsc → lib/
```

## Desplegar (lo hace el autor)

1. Pasar el proyecto `shaddai-68df1` al plan **Blaze** (consola de Firebase →
   Uso y facturación). Las funciones no se despliegan en el plan gratuito.
   Conviene poner una alerta de presupuesto.
2. Con la CLI de Firebase y la sesión iniciada (`firebase login`), desde la
   raíz del repositorio:

   ```bash
   firebase deploy --only functions
   ```

   `firebase.json` compila antes de desplegar (`predeploy`). La primera vez
   la CLI activa las APIs que falten (Cloud Functions, Cloud Build, Artifact
   Registry, Cloud Run).
3. Comprobar en la consola (Functions) que `deleteAccount`,
   `bookAppointment`, `editAppointment` y `saveClosure` aparecen en
   `southamerica-east1`, y `notifyAdminsOnAppointmentWrite` en la región
   de la base de datos.

La app llama a `deleteAccount` con `cloud_functions` (spec 009, T13).
La reserva, la edición y los cierres llaman a las funciones de la agenda
(spec 012). `notifyAdminsOnAppointmentWrite` no se llama: salta sola con
cada escritura en `appointments`. Todas usan el SDK de administración, así que no dependen
de las reglas de Firestore.

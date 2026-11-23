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
- `src/index.ts`: exporta `deleteAccount` y `notifyAdminsOnAppointmentWrite`.

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
3. Comprobar en la consola (Functions) que `deleteAccount` aparece en
   `southamerica-east1`, y `notifyAdminsOnAppointmentWrite` en la región
   de la base de datos.

La app llama a `deleteAccount` con `cloud_functions` (spec 009, T13).
`notifyAdminsOnAppointmentWrite` no se llama: salta sola con cada escritura
en `appointments`. Las dos usan el SDK de administración, así que no dependen
de las reglas de Firestore.

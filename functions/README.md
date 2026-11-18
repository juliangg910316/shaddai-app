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
- `src/index.ts`: exporta `deleteAccount`.

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
   `southamerica-east1`.

La app la llama desde T13 (`cloud_functions`). Las reglas de Firestore no
cambian por la función: usa el SDK de administración.

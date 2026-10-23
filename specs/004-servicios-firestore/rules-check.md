# Comprobación manual de las reglas de Firestore (spec 004)

Las reglas no tienen tests automáticos: el autor las comprueba a mano (plan, A-1). Cubren RNF-2 y el criterio de finalización de la spec.

## 1. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Copia las reglas que hay ahora en un archivo aparte, para poder volver a ellas.
3. Apunta dos UID reales de la pestaña **Authentication → Usuarios**:
   - el de la **admin**, cuya ficha en `users/<uid>` tiene `role: 'admin'`;
   - el de una **clienta**, con `role: 'cliente'`.

## 2. Publicar

Elige una de estas dos formas:

- **Desde la consola** (no hace falta instalar nada): pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**.
- **Desde la terminal** (requiere instalar la CLI): `npm install -g firebase-tools`, luego `firebase login` y, en la raíz del repositorio, `firebase deploy --only firestore:rules --project shaddai-68df1`.

## 3. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador usa los datos reales para `get()`, así que `isAdmin()` lee la ficha de verdad de cada UID.

| # | Tipo | Ubicación | Autenticación | Resultado esperado |
| --- | --- | --- | --- | --- |
| 1 | `get` | `settings/priceList` | sin autenticar | **Permitido** |
| 2 | `update` | `settings/priceList` | sin autenticar | **Denegado** |
| 3 | `update` | `settings/priceList` | UID de la clienta | **Denegado** |
| 4 | `create` y `update` | `settings/priceList` | UID de la admin | **Permitido** |
| 5 | `delete` | `settings/priceList` | UID de la admin | **Denegado** |
| 6 | `get` | `users/<UID de la clienta>` | UID de la clienta → sin autenticar | **Permitido** → **Denegado** |

Si el documento `settings/priceList` aún no existe, el caso 4 se prueba como `create`. Una vez hecha la carga inicial, se prueba como `update`.

## 4. La app sigue funcionando

Con las reglas publicadas, en la app real (Android/iOS o Web):

1. Sin sesión, la lista de precios y el detalle se ven.
2. Inicia sesión con Google como clienta: se carga tu ficha y puedes hacer una reserva.
3. Inicia sesión como admin:
   - el panel muestra la agenda, Usuarias y Ajustes;
   - en **Servicios**, la carga inicial funciona si aún no se ha hecho.

Si algo falla, vuelve a publicar la copia del paso 1.2 y avisa.

## Resultado

Comprobado por el autor el 2026-10-22.


- [x] Copia de las reglas anteriores guardada.
- [x] Reglas publicadas.
- [x] Casos 1 a 6 del simulador correctos.
- [x] La app sigue funcionando (paso 4).

# Comprobación manual de las reglas de Firestore (spec 005)

Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en la spec 004 (RNF-5). `test/core/firestore_rules_test.dart` solo fija su estructura. Cubre RF-51, RF-53 a RF-58 y los criterios de finalización de la spec.

## 1. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Copia las reglas que hay ahora en un archivo aparte, para poder volver a ellas.
3. **Borra los turnos de prueba (RF-51).** En **Firestore Database → Datos**, borra las colecciones `appointments` y, si existe, `busySlots` enteras. Las reglas nuevas exigen que cada turno tenga su `busySlots` con las mismas horas, y los turnos antiguos no lo tienen.
   - No borres `users` ni `settings`: perderías la ficha de la admin, con su `role: 'admin'`, y la lista de precios. Si prefieres borrar la base de datos entera, vuelve a poner después `role: 'admin'` en la ficha de la admin y haz otra vez la carga inicial de la lista de precios.
4. Apunta tres UID reales de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta** (`role: 'cliente'`, `isBlocked: false`), que llamaremos A;
   - otra **clienta**, B. Para los casos 7 y 8, bloquéala desde el panel de la admin o pon `isBlocked: true` en su ficha, y desbloquéala al terminar.
5. Con la app y las reglas **anteriores**, haz una reserva como clienta A. Así habrá un `appointments/<id>` y su `busySlots/<id>` de verdad para los casos de lectura, cambio y borrado. Apunta ese `<id>`.

## 2. Publicar

Elige una de estas dos formas:

- **Desde la consola:** pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**. El índice se crea aparte, en **Firestore Database → Índices → Compuestos**: colección `appointments`, campos `clientId` ascendente y `startTime` descendente, ámbito colección. Si ya está creado, no hay que hacer nada.
- **Desde la terminal (requiere la CLI):** `firebase deploy --only firestore:rules,firestore:indexes --project shaddai-68df1`, en la raíz del repositorio. Publica `firestore.rules` y `firestore.indexes.json` juntos.

## 3. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador usa los datos reales para `get()`.

El simulador prueba una sola escritura cada vez, sin lote, y `getAfter()` solo ve esa escritura. Por eso un `create` de un turno sin su `busySlots` sale **Denegado**, y así se comprueba RF-54. El caso permitido, con el lote completo, se prueba en la app (paso 4).

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado | RF |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `get` | `appointments/<id>` | clienta A | — | **Permitido** | RF-53 |
| 2 | `get` | `appointments/<id>` | clienta B | — | **Denegado** | RF-53 |
| 3 | `get` | `busySlots/<id>` | clienta B → sin autenticar | — | **Permitido** → **Denegado** | RF-53 |
| 4 | `create` | `appointments/nuevo1` | clienta A | `clientId` de A, `status: 'waiting_confirmation'`, `startTime` < `endTime` (sin `busySlots/nuevo1`) | **Denegado** | RF-54 |
| 5 | `create` | `appointments/nuevo2` | clienta A | `clientId` de **B** | **Denegado** | RF-54 |
| 6 | `create` | `busySlots/nuevo3` | clienta A | `start`, `end` (sin `appointments/nuevo3`) | **Denegado** | RF-53, RF-54 |
| 7 | `create` | `appointments/nuevo4` | clienta B bloqueada | `clientId` de B | **Denegado** | RF-54 |
| 8 | `get` | `users/<UID de B>` | clienta B bloqueada | — | **Permitido** (la app le muestra el aviso de bloqueo) | RF-57 |
| 9 | `update` | `appointments/<id>` | clienta A | `status: 'cancelled'` | **Denegado** | RF-55 |
| 10 | `delete` | `appointments/<id>` | clienta A → admin | — | **Denegado** → **Denegado** | RF-55 |
| 11 | `update` | `appointments/<id>` | admin | `status: 'confirmed'` | **Permitido** | RF-56 |
| 12 | `update` | `appointments/<id>` | admin | `status: 'confirmed'` y `clientName` cambiado | **Denegado** | RF-56 |
| 13 | `delete` | `busySlots/<id>` | clienta A → admin | — | **Denegado** → **Permitido** | RF-56 |
| 14 | `get` | `users/<UID de A>` | clienta A → clienta B → admin | — | **Permitido** → **Denegado** → **Permitido** | RF-57 |
| 15 | `update` | `users/<UID de A>` | clienta A | `phoneNumber` cambiado | **Permitido** | RF-57, RF-58 |
| 16 | `update` | `users/<UID de A>` | clienta A | `role: 'admin'` | **Denegado** | RF-57 |
| 17 | `update` | `users/<UID de A>` | clienta A | `isBlocked: true` | **Denegado** | RF-57 |
| 18 | `update` | `users/<UID de A>` | admin | `isBlocked: true` | **Permitido** (vuelve a `false` al terminar) | RF-57 |
| 19 | `create` | `users/<UID nuevo>` | ese UID | `role: 'admin'` | **Denegado** | RF-57 |
| 20 | `get` | `settings/priceList` | sin autenticar | — | **Permitido** (spec 004, sin cambios) | — |

Los casos 11 y 18 son escrituras reales solo si las ejecutas en la app. En el simulador no cambian nada.

## 4. La app sigue funcionando (RF-58)

Con las reglas publicadas, en la app real (Android/iOS y Web):

1. **Alta de cuenta:** inicia sesión con Google con una cuenta nueva. Se crea su ficha y te pide el WhatsApp. Guárdalo y llegas a donde ibas.
2. **Inicio de sesión** con la clienta A: se carga su ficha.
3. **Reserva:** reserva un servicio con adicionales. Se guarda (el turno y su `busySlots`, en el mismo lote) y se ve el turno activo. En la consola, `busySlots/<id>` tiene solo `start` y `end`.
4. **Perfil:** el turno aparece en "mis turnos". Esta consulta usa el índice compuesto: si falla, el índice aún se está creando.
5. **Otra clienta:** con la clienta B (sin bloquear), la hora de A sale ocupada en el mismo día.
6. **Panel de la admin:**
   - la agenda del día muestra el turno con lo reservado, en hora de Curitiba;
   - "Confirmar" lo confirma;
   - "Cancelar" lo cancela y la hora vuelve a quedar libre para las clientas;
   - Usuarias lista a todas, y bloquear o desbloquear funciona;
   - Ajustes guarda el calendario.
7. **Bloqueo con la sesión abierta:** bloquea a la clienta B mientras tiene Reservas abierto. Ve el aviso de bloqueo y no puede reservar.

Si algo falla, vuelve a publicar la copia del paso 1.2 y avisa.

## Resultado

Comprobado por el autor el 2026-11-05.

- [x] Copia de las reglas anteriores guardada.
- [x] Turnos de prueba borrados (RF-51).
- [x] Reglas e índice publicados.
- [x] Casos 1 a 20 del simulador correctos.
- [x] La app sigue funcionando (paso 4).

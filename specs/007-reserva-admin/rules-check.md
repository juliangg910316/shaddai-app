# Comprobación manual de las reglas de Firestore (spec 007)

Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en las specs 004 a 006 (RNF-5). `test/core/firestore_rules_test.dart` solo fija su estructura. Cubre RF-2, RF-25, RF-26 y RF-30, y que lo de las specs 005 y 006 sigue igual.

## 1. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Copia las reglas que hay ahora en un archivo aparte, para poder volver a ellas.
3. Apunta estos UID de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta A** (`role: 'cliente'`, `isBlocked: false`), sin turno activo;
   - una **clienta B** (`role: 'cliente'`). Para los casos 5 y 13, bloquéala desde el panel de la admin o pon `isBlocked: true` en su ficha, y desbloquéala al terminar;
   - si hay **otra cuenta admin**, también su UID (caso 4). Si no la hay, sáltate ese caso.
4. Elige dos instantes de un día futuro, por ejemplo el próximo lunes a las 10:00 y a las 10:45 de Curitiba: **T1** y **T2**. Usa exactamente los mismos en todos los documentos y casos (tipo `timestamp`).
5. Crea a mano en la consola estos documentos de prueba. Las escrituras de la consola no pasan por las reglas:
   - `busySlots/prueba1`: `start: T1`, `end: T2`. Así el simulador ve el turno ocupado de `appointments/prueba1` y cada caso prueba **su** condición (ver § 3);
   - `appointments/prueba2`: `clientId: null`, `clientName: 'Prueba sin cuenta'`, `clientPhone: '41 90000-0000'`, `clientPhotoUrl: null`, `startTime: T1`, `endTime: T2`, `status: 'confirmed'`, `createdAt: T1`, `createdByAdmin: true`. Sin su `busySlots`;
   - `appointments/prueba3`: como `prueba2`, pero con `clientId: <A>`, `clientName` de A y `createdByAdmin: false`. Sin su `busySlots`.

## 2. Publicar

Elige una de estas dos formas:

- **Desde la consola:** pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**. No hay índices nuevos.
- **Desde la terminal (requiere la CLI):** `firebase deploy --only firestore:rules --project shaddai-68df1`, en la raíz del repositorio.

## 3. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador usa los datos reales para `get()`.

El simulador prueba una sola escritura cada vez, sin lote, y `getAfter()` solo ve esa escritura y lo que ya está guardado. Por eso los casos 1 a 11 crean `appointments/prueba1`, cuyo turno ocupado ya existe (paso 1.5) con las mismas horas: el resultado depende solo de la condición de cada caso. El caso 12 comprueba que, sin turno ocupado, no se crea.

**Datos base** de los casos 1 a 12 (cambia solo lo que dice la columna "Datos"): `clientName: 'Prueba'`, `clientPhone: '41 90000-0000'`, `clientPhotoUrl: null`, `startTime: T1`, `endTime: T2`, `createdAt: T1`, y además:
- casos de la admin: `status: 'confirmed'`, `createdByAdmin: true`;
- casos de la clienta: `clientId: <A>`, `status: 'waiting_confirmation'`, `createdByAdmin: false`.

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado | RF |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `create` | `appointments/prueba1` | admin | `clientId: <A>` | **Permitido** | RF-25 |
| 2 | `create` | `appointments/prueba1` | admin | `clientId: null` | **Permitido** (persona sin cuenta) | RF-25 |
| 3 | `create` | `appointments/prueba1` | admin | `clientId: <admin>` (el suyo) | **Denegado** | RF-2 |
| 4 | `create` | `appointments/prueba1` | admin | `clientId: <otra admin>` | **Denegado** (no es clienta) | RF-2 |
| 5 | `create` | `appointments/prueba1` | admin | `clientId: <B>`, con B bloqueada | **Denegado** | RF-25 |
| 6 | `create` | `appointments/prueba1` | admin | `clientId: <A>`, `status: 'waiting_confirmation'` | **Denegado** (debe ser confirmado) | RF-25 |
| 7 | `create` | `appointments/prueba1` | admin | `clientId: <A>`, `createdByAdmin: false` | **Denegado** | RF-25 |
| 8 | `create` | `appointments/prueba1` | admin | `clientId: <A>`, sin el campo `createdByAdmin` | **Denegado** | RF-25 |
| 9 | `create` | `appointments/prueba1` | clienta A | `createdByAdmin: true` | **Denegado** | RF-25 |
| 10 | `create` | `appointments/prueba1` | clienta A | (datos base de la clienta) | **Permitido** (spec 005, sin cambios) | — |
| 11 | `create` | `appointments/prueba1` | clienta A | `clientId: null`, `status: 'confirmed'`, `createdByAdmin: true` | **Denegado** | RF-25 |
| 12 | `create` | `appointments/prueba4` | admin | `clientId: null` (no existe `busySlots/prueba4`) | **Denegado** (sin turno ocupado) | RF-25 |
| 13 | `create` | `appointments/prueba1` | clienta B bloqueada | `clientId: <B>` (datos base de la clienta) | **Denegado** (spec 005, sin cambios) | — |
| 14 | `create` | `busySlots/prueba2` | admin | `start: T1`, `end: T2` | **Permitido** (su turno lo marcó la admin) | RF-25 |
| 15 | `create` | `busySlots/prueba3` | admin | `start: T1`, `end: T2` | **Denegado** (su turno no es de la admin) | RF-25 |
| 16 | `create` | `busySlots/prueba2` | clienta A | `start: T1`, `end: T2` | **Denegado** (turno ajeno) | RF-25 |
| 17 | `create` | `busySlots/prueba3` | clienta A | `start: T1`, `end: T2` | **Permitido** (su propio turno, spec 005) | — |
| 18 | `get` | `appointments/prueba2` | clienta A | — | **Denegado** (sin cuenta: solo la admin) | RF-26 |
| 19 | `get` | `appointments/prueba2` | admin | — | **Permitido** | RF-26 |
| 20 | `get` | `appointments/prueba3` | clienta A | — | **Permitido** (el suyo, spec 005) | — |

### Edición de un turno que agendó la admin (RF-30)

Para estos casos, primero agenda desde la app, como admin, un turno para la clienta A **para dentro de unos días** (paso 4.1): `<idA>`. "Datos" es el documento entero tal como queda: copia el turno, deja `startTime` y `endTime` como están y cambia solo lo que se indica.

| # | Tipo | Ubicación | Autenticación | Datos (sobre el turno actual) | Resultado esperado | RF |
| --- | --- | --- | --- | --- | --- | --- |
| 21 | `update` | `appointments/<idA>` | clienta A | `status: 'waiting_confirmation'` | **Permitido** (spec 006) | RF-30 |
| 22 | `update` | `appointments/<idA>` | clienta A | `status: 'waiting_confirmation'`, `createdByAdmin: false` | **Denegado** (no toca la marca) | RF-30 |
| 23 | `update` | `appointments/<idA>` | admin | `status: 'cancelled'` | **Permitido** (spec 005, solo el estado) | — |
| 24 | `update` | `appointments/<idA>` | admin | `createdByAdmin: false` | **Denegado** (la admin solo cambia el estado) | — |

Las escrituras del simulador no se guardan: el caso 23 no cancela el turno de verdad.

### Lo de la spec 006

Repite los casos 1 a 13 de `specs/006-editar-turno/rules-check.md` sobre un turno que pidió la clienta A: deben dar lo mismo que entonces.

## 4. En la app

Con las reglas publicadas, en la app real (Android/iOS y Web):

1. **Para una clienta (RF-19, RF-21, RF-25):** la admin agenda un turno para la clienta A. Se guarda y sale "Turno agendado para …". En la consola, `appointments/<idA>` tiene `status: 'confirmed'`, `createdByAdmin: true` y el `clientId` de A, y `busySlots/<idA>` las mismas horas. Con la clienta A en Reservas, el turno aparece como su turno activo sin recargar, y en su Perfil.
2. **Para una persona sin cuenta (RF-19, RF-24, RF-26):** la admin agenda otro turno para una persona sin cuenta. En la consola, `clientId` es `null`. La clienta A no lo ve en su Perfil, pero su hora sale ocupada en Reservas. En la lista de la admin sale con "Sin cuenta", "Agendado por la admin" y el botón de WhatsApp, que abre el chat.
3. **La clienta lo edita (RF-30):** la clienta A edita el turno del paso 1 y guarda. Vuelve a esperar confirmación y, en la consola, `createdByAdmin` sigue en `true`.
4. **Bloqueada (RF-15):** la admin elige a la clienta B en "Para quién"; bloquéala desde otro dispositivo. Sale el aviso y se quita. Desbloquéala al terminar.
5. **Lo que ya existía:** repite el paso 4 de `specs/005-reservas/rules-check.md` (reserva de una clienta, "mis turnos", la hora ocupada para otra clienta, el panel de la admin y el bloqueo) y el paso 4.1 de la 006 (editar).

Al terminar, borra `busySlots/prueba1`, `appointments/prueba2` y `appointments/prueba3`, y cancela desde el panel los turnos de prueba que agendaste.

Si algo falla, vuelve a publicar la copia del paso 1.2 y avisa.

## Resultado

Comprobado por el autor el 2026-11-17.

- [x] Copia de las reglas anteriores guardada.
- [x] Reglas publicadas.
- [x] Casos 1 a 24 del simulador correctos.
- [x] Casos de la 006 correctos.
- [x] La reserva de la admin funciona en la app (paso 4).
- [x] Lo que ya existía sigue funcionando.

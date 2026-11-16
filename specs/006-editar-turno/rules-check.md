# Comprobación manual de las reglas de Firestore (spec 006)

Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en las specs 004 y 005 (RNF-4). `test/core/firestore_rules_test.dart` solo fija su estructura. Cubre RF-24, RF-25 y RF-26, y el recorrido de lo que ya existía (spec 005, RF-58).

## 1. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Copia las reglas que hay ahora en un archivo aparte, para poder volver a ellas.
3. Apunta tres UID reales de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta** A (`role: 'cliente'`, `isBlocked: false`);
   - otra **clienta** B (`role: 'cliente'`). Para el caso 6, bloquéala desde el panel de la admin o pon `isBlocked: true` en su ficha, y desbloquéala al terminar.
4. Prepara los turnos con la app y las reglas **anteriores**:
   - la clienta A reserva un turno **para dentro de unos días**: `<idA>`. Es su turno activo;
   - la clienta B reserva otro turno: `<idB>`.
5. Comprueba que `settings/calendar` existe. No hace falta que tenga `editMarginMinutes`: si falta, vale 0.

## 2. Publicar

Elige una de estas dos formas:

- **Desde la consola:** pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**. No hay índices nuevos.
- **Desde la terminal (requiere la CLI):** `firebase deploy --only firestore:rules --project shaddai-68df1`, en la raíz del repositorio.

## 3. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador usa los datos reales para `get()`.

El simulador prueba una sola escritura cada vez, sin lote ni transacción, y `getAfter()` solo ve esa escritura. Por eso:
- un `update` del turno sin cambiar a la vez su `busySlots` con las mismas horas sale **Denegado** (caso 9). El caso permitido, con el turno y su `busySlots` juntos, se prueba en la app (paso 4.1);
- en los casos 1 a 8, si cambias `startTime`/`endTime`, el resultado ya es **Denegado** por el `busySlots`. Para que cada caso pruebe **su** condición, deja `startTime` y `endTime` como están y cambia solo lo que dice la columna "Datos". Así `getAfter()` del `busySlots` coincide y el resultado depende de esa condición.

Para los casos de turnos, "Datos" es el documento entero tal como queda: copia el turno y cambia lo que se indica.

| # | Tipo | Ubicación | Autenticación | Datos (sobre el turno actual) | Resultado esperado | RF |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `update` | `appointments/<idA>` | clienta A | `status: 'waiting_confirmation'` (horas iguales) | **Permitido** | RF-24 |
| 2 | `update` | `appointments/<idA>` | clienta A | `status: 'waiting_confirmation'` y `booked` con otro `durationMinutes` | **Permitido** | RF-24 |
| 3 | `update` | `appointments/<idB>` | clienta A | `status: 'waiting_confirmation'` | **Denegado** (turno ajeno) | RF-24 |
| 4 | `update` | `appointments/<idA>` | clienta A | `status: 'confirmed'` | **Denegado** (debe quedar esperando confirmación) | RF-24 |
| 5 | `update` | `appointments/<idA>` | clienta A | `status: 'waiting_confirmation'` y `clientName` cambiado | **Denegado** (solo inicio, fin, lo reservado y el estado) | RF-24 |
| 6 | `update` | `appointments/<idB>` | clienta B bloqueada | `status: 'waiting_confirmation'` | **Denegado** (bloqueada) | RF-24 |
| 7 | `update` | `appointments/<idA>` | clienta A | `status: 'waiting_confirmation'`, con `settings/calendar.editMarginMinutes` puesto a más minutos de los que faltan para el turno (quítalo al terminar) | **Denegado** (dentro del margen) | RF-24 |
| 8 | `update` | `appointments/<idA>`, con `status: 'cancelled'` puesto a mano en la consola (no desde el panel, que borra su `busySlots`); vuelve a ponerlo como estaba al terminar | clienta A | `status: 'waiting_confirmation'` | **Denegado** (no está activo) | RF-24 |
| 9 | `update` | `appointments/<idA>` | clienta A | `startTime` y `endTime` una hora más tarde, `status: 'waiting_confirmation'` (sin cambiar `busySlots`) | **Denegado** (su turno ocupado no coincide) | RF-24, RF-26 |
| 10 | `update` | `busySlots/<idA>` | clienta A | `start` y `end` una hora más tarde (sin cambiar el turno) | **Denegado** (no coincide con su turno) | RF-24, RF-26 |
| 11 | `update` | `busySlots/<idB>` | clienta A | `start` y `end` iguales a los del turno de B | **Denegado** (turno ajeno) | RF-24 |
| 12 | `update` | `busySlots/<idA>` | clienta A | `start`, `end` iguales y un campo `clientId` añadido | **Denegado** (solo inicio y fin) | RF-24 |
| 13 | `update` | `appointments/<idA>` | admin | `status: 'confirmed'` | **Permitido** (spec 005, sin cambios) | — |
| 14 | `get` | `settings/calendar` | clienta A | — | **Permitido** | RF-25 |
| 15 | `update` | `settings/calendar` | clienta A | `editMarginMinutes: 0` | **Denegado** | RF-25 |
| 16 | `update` | `settings/calendar` | admin | `editMarginMinutes: 30` | **Permitido** (en el simulador no cambia nada) | RF-25 |
| 17 | `get` | `settings/calendar` | sin autenticar | — | **Denegado** | RF-25 |

## 4. En la app

Con las reglas publicadas, en la app real (Android/iOS y Web):

1. **Editar (RF-24, RF-26):** la clienta A edita su turno: cambia la hora y el servicio y guarda. Se guarda, vuelve a esperar confirmación y, en la consola, `appointments/<idA>` y `busySlots/<idA>` tienen el mismo inicio y fin nuevos.
2. **La otra clienta lo ve (RF-26):** con la clienta B en Reservas, en el mismo día, la hora antigua de A vuelve a estar libre y la nueva sale ocupada, sin recargar.
3. **Margen (RF-1 a RF-3, RF-15):** pon a mano en `settings/calendar` un `editMarginMinutes` mayor que lo que falta para el turno de A. "Editar turno" desaparece y sale el aviso con WhatsApp. Quítalo al terminar.
4. **Dos dispositivos (RF-15):** abre la edición del turno de A en dos dispositivos; guarda en uno y después en el otro. El segundo avisa de que el turno cambió y no guarda.
5. **Ajustes de la admin (RF-25):** la admin guarda el calendario desde el panel y se guarda. `editMarginMinutes`, si lo pusiste, sigue ahí.

### Lo que ya existía (spec 005, RF-58)

Repite el paso 4 de `specs/005-reservas/rules-check.md`: alta de cuenta, inicio de sesión, reserva nueva, "mis turnos" en Perfil, la hora ocupada para otra clienta, el panel de la admin (confirmar, cancelar, usuarias, bloqueo y ajustes) y el bloqueo con la sesión abierta.

Si algo falla, vuelve a publicar la copia del paso 1.2 y avisa.

## Resultado

Pendiente de la comprobación del autor.

- [ ] Copia de las reglas anteriores guardada.
- [ ] Reglas publicadas.
- [ ] Casos 1 a 17 del simulador correctos.
- [ ] La edición funciona en la app (paso 4).
- [ ] Lo que ya existía sigue funcionando.

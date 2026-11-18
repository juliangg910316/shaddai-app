# Comprobación manual de las reglas de Firestore (spec 008)

Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en las specs 004 a 007 (RNF-5). `test/core/firestore_rules_test.dart` solo fija su estructura. Cubre RF-42 (cierres), RF-43 (la admin edita un turno) y RF-44 (el margen), y que lo de las specs 005 a 007 sigue igual, con un cambio deliberado (§ 3.6).

Las reglas no se pudieron compilar en local: el emulador de Firestore necesita Java 21 y la máquina tiene 17. Las reglas tienen comentarios dentro de las condiciones; si la consola marca un error de sintaxis al publicar, avisa.

## 1. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Copia las reglas que hay ahora en un archivo aparte, para poder volver a ellas.
3. Apunta estos UID de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta A** (`role: 'cliente'`, `isBlocked: false`);
   - una **clienta B** (`role: 'cliente'`). Para el caso 7, bloquéala desde el panel de la admin o pon `isBlocked: true` en su ficha, y desbloquéala al terminar.
4. Elige cuatro instantes de un día futuro, en hora de Curitiba (tipo `timestamp`), y usa exactamente los mismos en todo:
   - **T1** = el próximo lunes a las 10:00 y **T2** = a las 10:45 (las horas de ahora del turno);
   - **T3** = ese lunes a las 11:00 y **T4** = a las 11:45 (las horas nuevas).
5. Crea a mano en la consola estos documentos de prueba. Las escrituras de la consola no pasan por las reglas. "Turno base" es: `clientId: <A>`, `clientName` y `clientPhone` de A, `clientPhotoUrl: null`, `startTime: T1`, `endTime: T2`, `status: 'waiting_confirmation'`, `createdAt: T1`, `createdByAdmin: false` y `booked` (un mapa: `kind: 'service'`, `id: 'prueba'`, `name: {es: 'Prueba', pt: 'Prueba'}`, `priceCents: 1000`, `durationMinutes: 45`, `addons: []`).
   - `appointments/edicion1`: el turno base. `busySlots/edicion1`: `start: T3`, `end: T4`. Así el simulador ve el turno ocupado con las horas nuevas y cada caso prueba **su** condición (ver § 3);
   - `appointments/edicion2`: el turno base, **sin** `busySlots`;
   - `appointments/edicion5`: el turno base con `status: 'cancelled'`. `busySlots/edicion5`: `start: T3`, `end: T4`;
   - `appointments/edicion6`: el turno base con `status: 'confirmed'` y `createdByAdmin: true`. `busySlots/edicion6`: `start: T3`, `end: T4`;
   - `closures/prueba`: `start: T1`, `end: T2`.
6. Abre `settings/calendar` y apunta su `editMarginMinutes` actual (o que no lo tiene), para dejarlo igual al terminar.

## 2. Publicar

Elige una de estas dos formas:

- **Desde la consola:** pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**. No hay índices nuevos.
- **Desde la terminal (requiere la CLI):** `firebase deploy --only firestore:rules --project shaddai-68df1`, en la raíz del repositorio.

## 3. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador usa los datos reales para `get()`, prueba una sola escritura cada vez, sin lote, y `getAfter()` solo ve esa escritura y lo que ya está guardado. Las escrituras del simulador no se guardan.

En los `update`, "Datos" es el documento entero tal como queda: copia el turno de la consola y cambia solo lo que se indica.

### 3.1 La admin edita un turno (RF-43)

| # | Tipo | Ubicación | Autenticación | Datos (sobre el turno) | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 1 | `update` | `appointments/edicion1` | admin | `startTime: T3`, `endTime: T4`, `status: 'confirmed'` | **Permitido** |
| 2 | `update` | `appointments/edicion1` | admin | `startTime: T3`, `endTime: T4`, `status: 'waiting_confirmation'` | **Denegado** (queda confirmado) |
| 3 | `update` | `appointments/edicion1` | admin | como el 1, y `clientId: <B>`, `clientName` y `clientPhone` de B, `createdByAdmin: true` | **Permitido** (otra persona, marcado) |
| 4 | `update` | `appointments/edicion1` | admin | como el 3, pero `createdByAdmin: false` | **Denegado** (cambia la persona sin marcarlo) |
| 5 | `update` | `appointments/edicion1` | admin | como el 1, y `clientId: null`, `clientName: 'Prueba sin cuenta'`, `createdByAdmin: true` | **Permitido** (persona sin cuenta) |
| 6 | `update` | `appointments/edicion1` | admin | como el 3, pero `clientId: <admin>` | **Denegado** (no es para ella) |
| 7 | `update` | `appointments/edicion1` | admin | como el 3, con B bloqueada | **Denegado** |
| 8 | `update` | `appointments/edicion6` | admin | `startTime: T3`, `endTime: T4`, `createdByAdmin: false` | **Denegado** (quita la marca) |
| 9 | `update` | `appointments/edicion6` | admin | `startTime: T3`, `endTime: T4` | **Permitido** (conserva la marca) |
| 10 | `update` | `appointments/edicion5` | admin | `startTime: T3`, `endTime: T4`, `status: 'confirmed'` | **Denegado** (cancelado: no está activo) |
| 11 | `update` | `appointments/edicion1` | admin | `status: 'confirmed'` y `booked.priceCents: 2000` (horas T1 y T2) | **Denegado** (su turno ocupado no tiene esas horas) |
| 12 | `update` | `appointments/edicion1` | admin | como el 1, y un campo nuevo `notes: 'x'` | **Denegado** |
| 13 | `update` | `appointments/edicion1` | clienta A | como el 3 (cambia la persona) | **Denegado** (la clienta no cambia la persona) |
| 14 | `update` | `appointments/edicion1` | clienta B | como el 1 | **Denegado** (turno ajeno) |

### 3.2 Su turno ocupado (RF-43)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 15 | `create` | `busySlots/edicion2` | admin | `start: T1`, `end: T2` | **Permitido** (con `set`, el que le faltaba) |
| 16 | `create` | `busySlots/edicion2` | admin | `start: T3`, `end: T4` | **Denegado** (otras horas que su turno) |
| 17 | `create` | `busySlots/edicion2` | clienta B | `start: T1`, `end: T2` | **Denegado** (turno ajeno) |
| 18 | `update` | `busySlots/edicion1` | admin | `start: T1`, `end: T2` | **Permitido** (las horas de su turno) |
| 19 | `update` | `busySlots/edicion1` | admin | `start: T1`, `end: T4` | **Denegado** |
| 20 | `update` | `busySlots/edicion1` | admin | `start: T1`, `end: T2`, `turno: 'x'` | **Denegado** (solo inicio y fin) |

### 3.3 Cierres (RF-42)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 21 | `create` | `closures/nuevo` | admin | `start: T1`, `end: T2` | **Permitido** |
| 22 | `create` | `closures/nuevo` | admin | `start: T2`, `end: T1` | **Denegado** (el fin antes del inicio) |
| 23 | `create` | `closures/nuevo` | admin | `start: T1`, `end: T1` | **Denegado** |
| 24 | `create` | `closures/nuevo` | admin | `start: T1`, `end: T2`, `reason: 'médico'` | **Denegado** (solo inicio y fin) |
| 25 | `create` | `closures/nuevo` | admin | `start: '2026-12-01'` (texto), `end: T2` | **Denegado** |
| 26 | `create` | `closures/nuevo` | clienta A | `start: T1`, `end: T2` | **Denegado** |
| 27 | `get` | `closures/prueba` | clienta A | — | **Permitido** |
| 28 | `get` | `closures/prueba` | sin autenticar | — | **Denegado** |
| 29 | `update` | `closures/prueba` | admin | `start: T1`, `end: T4` | **Denegado** (no se cambian) |
| 30 | `delete` | `closures/prueba` | clienta A | — | **Denegado** |
| 31 | `delete` | `closures/prueba` | admin | — | **Permitido** |

### 3.4 El margen (RF-44)

Sobre `settings/calendar` tal como está; cambia solo lo que se indica.

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 32 | `update` | `settings/calendar` | admin | `editMarginMinutes: 120` | **Permitido** |
| 33 | `update` | `settings/calendar` | admin | `editMarginMinutes: 0` | **Permitido** |
| 34 | `update` | `settings/calendar` | admin | `editMarginMinutes: -30` | **Denegado** |
| 35 | `update` | `settings/calendar` | admin | `editMarginMinutes: 1.5` | **Denegado** (no es entero) |
| 36 | `update` | `settings/calendar` | admin | `editMarginMinutes: '60'` (texto) | **Denegado** |
| 37 | `update` | `settings/calendar` | clienta A | `editMarginMinutes: 120` | **Denegado** |
| 38 | `update` | `settings/calendar` | admin | el horario: `openingHours.monday.open: '09:30'`, sin tocar el margen | **Permitido** |
| 39 | `get` | `settings/calendar` | clienta A | — | **Permitido** (spec 006, sin cambios) |

### 3.5 Un margen `double` guardado a mano (D-7)

1. En la consola, cambia `settings/calendar.editMarginMinutes` a `90.5` (tipo número).
2. En el simulador, como admin, `update` de `settings/calendar` con el documento tal como está y `openingHours.monday.open: '09:30'`: **Permitido** (el horario se guarda aunque el margen guardado no sea entero).
3. Como admin, `update` con `editMarginMinutes: 90.5` → `100.5`: **Denegado**.
4. Vuelve a dejar el margen como estaba (paso 1.6).

### 3.6 Lo de las specs 005 a 007

- Repite los casos 1 a 13 de `specs/006-editar-turno/rules-check.md` (la clienta edita su turno): deben dar lo mismo que entonces.
- Repite los casos 1 a 24 de `specs/007-reserva-admin/rules-check.md`. Todos deben dar lo mismo **salvo el 15**: la admin crea `busySlots/prueba3`, cuyo turno no marcó, con sus mismas horas. Antes era **Denegado**; ahora es **Permitido**, a propósito: la edición de la admin escribe el turno ocupado con `set`, y en un turno antiguo que no lo tuviera eso es crearlo (plan § 2, D-8). Sigue haciendo falta que tenga las mismas horas que su turno (caso 16 de arriba).

## 4. En la app

Con las reglas publicadas, en la app real (Android/iOS y Web):

1. **Cierres (RF-42):** la admin crea un cierre de unas horas para un día sin turnos. Se guarda y sale en la lista. En la consola, `closures/<id>` solo tiene `start` y `end`. Con la clienta A en Reservas, esas horas no salen libres sin recargar. La admin lo quita y vuelven a salir.
2. **Cierre con un turno (RF-5):** con un turno de prueba ese día, crear un cierre que lo pise muestra el turno, con "Editar" y "Cancelar".
3. **La admin edita un turno (RF-43):** la admin edita el turno de la clienta A: cambia la hora y guarda. Vuelve a la agenda en su día, con el aviso. En la consola, el turno tiene las horas nuevas y `status: 'confirmed'`, y `busySlots/<id>` las mismas horas. La clienta A lo ve cambiado sin recargar.
4. **Cambiar la persona (RF-31, RF-43):** la admin edita el mismo turno y pone a la clienta B. En la consola, `clientId` es el de B y `createdByAdmin: true`. La clienta A deja de verlo y B lo ve como su turno activo.
5. **El margen (RF-44):** la admin cambia el margen en los ajustes del horario y sale "Margen guardado". En la consola, `editMarginMinutes` es el entero elegido. Con la clienta A en Reservas, "Editar turno" aparece o desaparece según el margen. Guardar el horario no lo cambia.
6. **Lo que ya existía:** repite el paso 4 de `specs/007-reserva-admin/rules-check.md` (la reserva de la admin) y el 4.1 de la 006 (la clienta edita su turno).

Al terminar:
- borra `appointments/edicion1`, `edicion2`, `edicion5` y `edicion6`, sus `busySlots`, y `closures/prueba` si sigue;
- cancela desde el panel los turnos de prueba y quita los cierres de prueba;
- deja el margen como estaba (paso 1.6) y desbloquea a la clienta B.

Si algo falla, vuelve a publicar la copia del paso 1.2 y avisa.

## Resultado

Pendiente de comprobar por el autor.

- [ ] Copia de las reglas anteriores guardada.
- [ ] Reglas publicadas, sin errores de sintaxis.
- [ ] Casos 1 a 39 del simulador correctos.
- [ ] Margen `double` guardado a mano (§ 3.5) correcto.
- [ ] Casos de las specs 006 y 007 correctos (con el 15 de la 007 ahora permitido).
- [ ] Todo funciona en la app (paso 4).

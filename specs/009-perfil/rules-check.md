# Comprobación manual de las reglas de Firestore (spec 009)

Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en las specs 004 a 008. `test/core/firestore_rules_test.dart` solo fija su estructura. Cubre RF-19 (la clienta cancela su turno), RF-28 (copia su WhatsApp nuevo a su turno activo) y RF-42 (las fichas no se borran desde la app), y que lo de las specs 005 a 008 sigue igual.

Las reglas no se pudieron compilar en local: el emulador de Firestore necesita Java 21 y la máquina tiene 17. Si la consola marca un error de sintaxis al publicar, avisa.

## 1. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Copia las reglas que hay ahora en un archivo aparte, para poder volver a ellas.
3. Apunta estos UID de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta A** (`role: 'cliente'`, `isBlocked: false`), y el `phoneNumber` de su ficha (lo llamamos **WA**);
   - una **clienta B** (`role: 'cliente'`).
4. Abre `settings/calendar` y apunta su `editMarginMinutes` actual (o que no lo tiene). Para estas pruebas ponlo en `60`, y déjalo como estaba al terminar.
5. Elige estos instantes, en hora de Curitiba (tipo `timestamp`):
   - **T1** = el próximo lunes a las 10:00 y **T2** = a las 10:45 (lejos del margen);
   - **C1** = dentro de 30 minutos y **C2** = 45 minutos después de C1 (dentro del margen de 60);
   - **P1** = ayer a las 10:00 y **P2** = a las 10:45 (ya pasado).
6. Crea a mano en la consola estos documentos de prueba (las escrituras de la consola no pasan por las reglas). "Turno base" es: `clientId: <A>`, `clientName` de A, `clientPhone: '+55 41 90000-0000'` (distinto de WA), `clientPhotoUrl: null`, `startTime: T1`, `endTime: T2`, `status: 'waiting_confirmation'`, `createdAt: T1`, `createdByAdmin: false` y `booked` (un mapa: `kind: 'service'`, `id: 'prueba'`, `name: {es: 'Prueba', pt: 'Prueba'}`, `priceCents: 1000`, `durationMinutes: 45`, `addons: []`).
   - `appointments/cancela1`: el turno base, **sin** `busySlots` (el simulador prueba una sola escritura: así ve el turno ocupado ya borrado, como tras el lote);
   - `appointments/cancela2`: el turno base, **con** `busySlots/cancela2` (`start: T1`, `end: T2`);
   - `appointments/cancela3`: el turno base con `status: 'confirmed'`, sin `busySlots`;
   - `appointments/cancela4`: el turno base con `startTime: C1`, `endTime: C2`, sin `busySlots`;
   - `appointments/cancelado1`: el turno base con `status: 'cancelled'`, `cancelledBy: 'client'`, y `busySlots/cancelado1` (`start: T1`, `end: T2`);
   - `appointments/activo1`: el turno base con `busySlots/activo1` (`start: T1`, `end: T2`);
   - `appointments/pasado1`: el turno base con `startTime: P1`, `endTime: P2` y `status: 'confirmed'`.

## 2. Publicar

Elige una de estas dos formas:

- **Desde la consola:** pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**. No hay índices nuevos.
- **Desde la terminal (requiere la CLI):** `firebase deploy --only firestore:rules --project shaddai-68df1`, en la raíz del repositorio.

## 3. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador usa los datos reales para `get()`, prueba una sola escritura cada vez, sin lote, y `getAfter()`/`existsAfter()` solo ven esa escritura y lo que ya está guardado. Las escrituras del simulador no se guardan.

En los `update`, "Datos" es el documento entero tal como queda: copia el turno de la consola y cambia solo lo que se indica.

### 3.1 La clienta cancela su turno (RF-19)

| # | Tipo | Ubicación | Autenticación | Datos (sobre el turno) | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 1 | `update` | `appointments/cancela1` | clienta A | `status: 'cancelled'`, `cancelledBy: 'client'` | **Permitido** |
| 2 | `update` | `appointments/cancela3` | clienta A | `status: 'cancelled'`, `cancelledBy: 'client'` | **Permitido** (confirmado también) |
| 3 | `update` | `appointments/cancela1` | clienta B | como el 1 | **Denegado** (turno ajeno) |
| 4 | `update` | `appointments/cancela4` | clienta A | como el 1 | **Denegado** (dentro del margen) |
| 5 | `update` | `appointments/cancela1` | clienta A | como el 1, y `booked.priceCents: 0` | **Denegado** (otros campos) |
| 6 | `update` | `appointments/cancela1` | clienta A | `status: 'cancelled'`, sin `cancelledBy` | **Denegado** |
| 7 | `update` | `appointments/cancela1` | clienta A | `status: 'cancelled'`, `cancelledBy: 'admin'` | **Denegado** |
| 8 | `update` | `appointments/cancela1` | clienta A | `status: 'confirmed'`, `cancelledBy: 'client'` | **Denegado** (solo a cancelado) |
| 9 | `update` | `appointments/cancela2` | clienta A | como el 1 | **Denegado** (su turno ocupado sigue: no se borra en el mismo lote) |
| 10 | `update` | `appointments/cancelado1` | clienta A | tal como está (`status: 'cancelled'`, `cancelledBy: 'client'`) | **Denegado** (turno del historial) |
| 11 | `update` | `appointments/pasado1` | clienta A | `status: 'cancelled'`, `cancelledBy: 'client'` | **Denegado** (ya pasó) |
| 12 | `update` | `appointments/cancela1` | clienta A, **bloqueada** (pon `isBlocked: true` en su ficha y quítalo después) | como el 1 | **Permitido** (la bloqueada también cancela, D-5) |
| 13 | `update` | `appointments/cancela1` | admin | `status: 'cancelled'` | **Permitido** (sin cambios: la admin cambia el estado) |

### 3.2 El turno ocupado al cancelar (RF-11, RF-19)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 14 | `delete` | `busySlots/cancelado1` | clienta A | — | **Permitido** (su turno está cancelado) |
| 15 | `delete` | `busySlots/cancelado1` | clienta B | — | **Denegado** (turno ajeno) |
| 16 | `delete` | `busySlots/activo1` | clienta A | — | **Denegado** (su turno sigue activo) |
| 17 | `delete` | `busySlots/activo1` | admin | — | **Permitido** (sin cambios) |
| 18 | `delete` | `busySlots/activo1` | sin autenticar | — | **Denegado** |

### 3.3 La clienta copia su WhatsApp (RF-28)

| # | Tipo | Ubicación | Autenticación | Datos (sobre el turno) | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 19 | `update` | `appointments/activo1` | clienta A | `clientPhone: WA` | **Permitido** (el de su ficha) |
| 20 | `update` | `appointments/activo1` | clienta A | `clientPhone: '+55 41 91111-1111'` | **Denegado** (distinto del de su ficha) |
| 21 | `update` | `appointments/activo1` | clienta A | `clientPhone: WA`, `clientName: 'Otra'` | **Denegado** (otros campos) |
| 22 | `update` | `appointments/activo1` | clienta B | `clientPhone:` el de la ficha de B | **Denegado** (turno ajeno) |
| 23 | `update` | `appointments/pasado1` | clienta A | `clientPhone: WA` | **Denegado** (turno del historial) |
| 24 | `update` | `appointments/cancelado1` | clienta A | `clientPhone: WA` | **Denegado** (cancelado) |

### 3.4 Las fichas no se borran (RF-42)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 25 | `delete` | `users/<A>` | clienta A | — | **Denegado** (solo la función `deleteAccount`, con el SDK de administración) |
| 26 | `delete` | `users/<A>` | admin | — | **Denegado** |
| 27 | `update` | `users/<A>` | clienta A | `phoneNumber: '+55 41 92222-2222'` | **Permitido** (sin cambios) |
| 28 | `delete` | `appointments/activo1` | clienta A | — | **Denegado** |

### 3.5 Lo de las specs 005 a 008

- Repite los casos 1 a 13 de `specs/006-editar-turno/rules-check.md` (la clienta edita su turno) y los 1 a 20 de `specs/008-agenda-admin/rules-check.md` (la admin edita un turno y su turno ocupado): deben dar lo mismo que entonces.

## 4. En la app

Con las reglas publicadas, en la app real (Android/iOS y Web), con la clienta A:

1. **Cancelar (RF-11, RF-19):** reserva un turno fuera del margen y cancélalo desde Reservas. Sale "Tu turno se canceló.". En la consola, el turno tiene `status: 'cancelled'` y `cancelledBy: 'client'`, y `busySlots/<id>` ya no existe. La hora vuelve a salir libre.
2. **Cambiar el WhatsApp (RF-28):** con un turno activo, cambia el WhatsApp desde Perfil → Tu cuenta. Sale "WhatsApp guardado.". En la consola, `users/<A>.phoneNumber` y el `clientPhone` del turno activo son el número nuevo; los turnos del historial conservan el anterior.
3. **Sin turno activo:** repite el paso 2 sin turno activo: se guarda solo la ficha.

Al terminar:
- borra `appointments/cancela1` a `cancela4`, `cancelado1`, `activo1` y `pasado1`, y sus `busySlots`;
- devuelve a la clienta A su WhatsApp y quita su bloqueo si lo pusiste;
- deja el margen como estaba (paso 1.4).

Si algo falla, vuelve a publicar la copia del paso 1.2 y avisa.

## Resultado

- [ ] Copia de las reglas anteriores guardada.
- [ ] Reglas publicadas, sin errores de sintaxis.
- [ ] Casos 1 a 28 del simulador correctos.
- [ ] Casos de las specs 006 y 008 correctos.
- [ ] Todo funciona en la app (paso 4).

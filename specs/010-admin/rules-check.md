# Comprobación manual de las reglas de Firestore (spec 010)

La spec 010 **no cambia `firestore.rules`**: las reglas de las specs 005 a 009 ya permiten a la admin todo lo que hace el panel y ya impiden a una clienta tocar `isBlocked` o los turnos ajenos. Este documento comprueba que es así (RF-35). Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en las specs 004 a 009. `test/core/firestore_rules_test.dart` solo fija su estructura.

Qué escribe el panel:
- **Cancelar** un turno (agenda y choques de un cierre): una transacción que relee el turno, pone `status: 'cancelled'` (sin `cancelledBy`: lo canceló el salón) y borra `busySlots/<id>`.
- **Confirmar**: una transacción que relee el turno y pone `status: 'confirmed'`.
- **Bloquear**: una transacción que relee el turno activo de la clienta (si tiene) y escribe a la vez `users/<uid>.isBlocked: true`, `status: 'cancelled'` en el turno y el borrado de su `busySlots`.
- **Desbloquear**: `users/<uid>.isBlocked: false`.

## 1. Antes de probar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Comprueba que las reglas publicadas son las de `firestore.rules` (las de la spec 009). Si no, publícalas antes (paso 2 de `specs/009-perfil/rules-check.md`) y guarda una copia de las anteriores.
3. Apunta estos UID de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta A** (`role: 'cliente'`, `isBlocked: false`);
   - una **clienta B** (`role: 'cliente'`, `isBlocked: false`).
4. Elige **T1** = el próximo lunes a las 10:00 y **T2** = a las 10:45, en hora de Curitiba (tipo `timestamp`).
5. Crea a mano en la consola estos documentos de prueba (las escrituras de la consola no pasan por las reglas). "Turno base" es: `clientId: <A>`, `clientName` de A, `clientPhone: '+55 41 90000-0000'`, `clientPhotoUrl: null`, `startTime: T1`, `endTime: T2`, `status: 'waiting_confirmation'`, `createdAt: T1`, `createdByAdmin: false` y `booked` (un mapa: `kind: 'service'`, `id: 'prueba'`, `name: {es: 'Prueba', pt: 'Prueba'}`, `priceCents: 1000`, `durationMinutes: 45`, `addons: []`).
   - `appointments/admin1`: el turno base, con `busySlots/admin1` (`start: T1`, `end: T2`).

## 2. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador prueba una sola escritura cada vez, sin lote ni transacción. Las escrituras del simulador no se guardan.

En los `update`, "Datos" es el documento entero tal como queda: copia el documento de la consola y cambia solo lo que se indica.

### 2.1 La admin cancela y confirma (RF-12 a RF-18, RF-9)

| # | Tipo | Ubicación | Autenticación | Datos (sobre el turno) | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 1 | `update` | `appointments/admin1` | admin | `status: 'confirmed'` | **Permitido** (confirmar) |
| 2 | `update` | `appointments/admin1` | admin | `status: 'cancelled'` | **Permitido** (cancelar) |
| 3 | `delete` | `busySlots/admin1` | admin | — | **Permitido** (libera la hora) |
| 4 | `update` | `appointments/admin1` | clienta B | `status: 'confirmed'` | **Denegado** (turno ajeno) |
| 5 | `update` | `appointments/admin1` | clienta B | `status: 'cancelled'`, `cancelledBy: 'client'` | **Denegado** (turno ajeno) |
| 6 | `update` | `appointments/admin1` | clienta A | `status: 'confirmed'` | **Denegado** (no se confirma a sí misma) |
| 7 | `delete` | `busySlots/admin1` | clienta B | — | **Denegado** (turno ajeno) |
| 8 | `delete` | `busySlots/admin1` | clienta A | — | **Denegado** (su turno sigue activo) |

### 2.2 Bloquear y desbloquear (RF-25 a RF-30, RF-35)

| # | Tipo | Ubicación | Autenticación | Datos (sobre la ficha) | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 9 | `update` | `users/<A>` | admin | `isBlocked: true` | **Permitido** (bloquear) |
| 10 | `update` | `users/<A>` | admin | `isBlocked: false` | **Permitido** (desbloquear) |
| 11 | `update` | `users/<A>` | clienta A | `isBlocked: true` | **Denegado** (no se bloquea ella) |
| 12 | `update` | `users/<A>` (con `isBlocked: true` puesto en la consola; quítalo después) | clienta A | `isBlocked: false` | **Denegado** (no se desbloquea ella) |
| 13 | `update` | `users/<B>` | clienta A | `isBlocked: true` | **Denegado** (ficha ajena) |
| 14 | `update` | `users/<A>` | clienta A | `role: 'admin'` | **Denegado** (sin cambios: no cambia su rol) |

## 3. En la app

Con las reglas publicadas, en la app real (Android/iOS y Web), con la admin:

1. **Confirmar (RF-9):** con un turno de la clienta A por confirmar, pulsa "Confirmar" en la agenda. El botón desaparece y el turno sale confirmado; en la consola, `status: 'confirmed'`.
2. **Cancelar (RF-12 a RF-18):** pulsa "Cancelar" en ese turno. Sale el diálogo con el nombre, el día, la hora y el servicio. "No, mantener" no cambia nada. "Sí, cancelar" muestra "Turno cancelado."; en la consola, `status: 'cancelled'` sin `cancelledBy`, y `busySlots/<id>` ya no existe. La hora vuelve a salir libre al reservar.
3. **Cancelar desde un cierre:** crea un cierre que choque con un turno activo y pulsa "Cancelar" en la lista de choques. Sale el mismo diálogo; al cancelar, el turno sale de la lista.
4. **Bloquear con turno (RF-25 a RF-27):** con un turno activo de la clienta A, en **Clientas** pulsa su interruptor. El diálogo dice que su turno se cancelará y lo muestra. "Sí, bloquear" muestra "<A> está bloqueada."; en la consola, `users/<A>.isBlocked: true`, el turno `status: 'cancelled'` y su `busySlots` borrado. A no puede iniciar sesión.
5. **Desbloquear (RF-29, RF-30):** pulsa otra vez el interruptor de A y confirma. Sale "<A> está desbloqueada."; A vuelve a iniciar sesión y reservar. El turno cancelado sigue cancelado.
6. **Bloquear sin turno:** repite el paso 4 con la clienta B sin turnos: el diálogo no menciona turnos y solo cambia su ficha.

Al terminar:
- borra `appointments/admin1` y su `busySlots`, y los turnos de los pasos 1 a 4;
- desbloquea a las clientas A y B si siguen bloqueadas.

Si algo falla, avisa: las reglas no cambian en esta spec, así que un fallo es un error del código o de las reglas de una spec anterior.

## Resultado

Comprobado por el autor en el recorrido de `/sdd-validate` (2026-11-20).

- [x] Reglas publicadas iguales a `firestore.rules`.
- [x] Casos 1 a 14 del simulador correctos.
- [x] Todo funciona en la app (paso 3).

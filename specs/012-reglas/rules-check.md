# Comprobación manual de las reglas de Firestore (spec 012)

Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en las specs 004 a 011 (RNF-3). `test/core/firestore_rules_test.dart` solo fija su estructura, y las reglas de la agenda que aplican las funciones tienen sus tests en `functions/test/` (`npm test`).

Cubre la decisión D-7 del plan:
- desde la app ya no se crean ni se editan turnos, turnos ocupados ni cierres; solo lo hacen las funciones `bookAppointment`, `editAppointment` y `saveClosure` (RF-1, RF-2, RF-4, RF-5);
- la admin ya no reactiva un turno cancelado (RF-1, RF-14);
- confirmar, cancelar, copiar el WhatsApp y borrar un cierre siguen como antes (RF-14, RF-19).

La sintaxis se comprobó con el validador de reglas de Firebase (sin errores ni avisos); lo que permiten se comprueba aquí.

## 1. Orden de despliegue

Una app sin la spec 012 dejaría de poder reservar y editar con estas reglas: vería su aviso de error genérico. Como la app aún no está publicada (spec 013), basta con este orden:

1. **Las funciones**: `firebase deploy --only functions` en la raíz del repositorio (ver `functions/README.md`). Comprueba en **Functions** que `bookAppointment`, `editAppointment` y `saveClosure` aparecen en `southamerica-east1`.
2. **La app nueva**: la de esta rama, en los dispositivos y en Web.
3. **Las reglas**: § 3.

Si hay que volver atrás, se hace en el orden contrario: primero las reglas guardadas en el paso 2.2, después la app.

## 2. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Copia las reglas que hay ahora en un archivo aparte, para poder volver a ellas.
3. Apunta estos UID de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta A** (`role: 'cliente'`, `isBlocked: false`) con `phoneNumber` en su ficha;
   - una **clienta B** (`role: 'cliente'`).
4. Elige cuatro instantes de un día futuro, en hora de Curitiba (tipo `timestamp`), y usa exactamente los mismos en todo:
   - **T1** = el próximo lunes a las 10:00 y **T2** = a las 10:45;
   - **T3** = ese lunes a las 11:00 y **T4** = a las 11:45.

   Comprueba que T1 queda más allá del margen de edición de `settings/calendar`.
5. Crea a mano en la consola estos documentos de prueba. Las escrituras de la consola no pasan por las reglas. «Turno base» es:
   - `clientId: <A>`, `clientName` y `clientPhone` de A, `clientPhotoUrl: null`;
   - `startTime: T1`, `endTime: T2`, `status: 'waiting_confirmation'`, `createdAt: T1`, `createdByAdmin: false`;
   - `booked` (un mapa): `kind: 'service'`, `id: 'prueba'`, `name: {es: 'Prueba', pt: 'Prueba'}`, `priceCents: 1000`, `durationMinutes: 45`, `addons: []`.

   Documentos:
   - `appointments/regla1`: el turno base. `busySlots/regla1`: `start: T1`, `end: T2`.
   - `appointments/regla2`: el turno base con `status: 'cancelled'`, **sin** `busySlots`.
   - `appointments/regla3`: el turno base con `status: 'confirmed'`. `busySlots/regla3`: `start: T1`, `end: T2`.
   - `closures/regla`: `start: T3`, `end: T4`.

## 3. Publicar

Elige una de estas dos formas:

- **Desde la consola:** pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**. No hay índices nuevos.
- **Desde la terminal (requiere la CLI):** `firebase deploy --only firestore:rules --project shaddai-68df1`, en la raíz del repositorio.

## 4. Simulador de reglas

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador:
- usa los datos reales para `get()`;
- prueba una sola escritura cada vez, sin lote;
- con `getAfter()`, solo ve esa escritura y lo que ya está guardado;
- no guarda nada.

En los `update`, «Datos» es el documento entero tal como queda: copia el documento de la consola y cambia solo lo que se indica.

### 4.1 Crear y editar desde la app: denegado (RF-1, RF-2, RF-4, RF-5)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 1 | `create` | `appointments/nuevo` | clienta A | el turno base | **Denegado** |
| 2 | `create` | `appointments/nuevo` | admin | el turno base con `status: 'confirmed'`, `createdByAdmin: true` | **Denegado** |
| 3 | `update` | `appointments/regla1` | clienta A | `startTime: T3`, `endTime: T4` | **Denegado** (antes, la edición de la spec 006) |
| 4 | `update` | `appointments/regla1` | admin | `startTime: T3`, `endTime: T4`, `status: 'confirmed'` | **Denegado** (antes, la edición de la spec 008) |
| 5 | `update` | `appointments/regla1` | admin | `clientId: <B>`, `clientName` y `clientPhone` de B, `createdByAdmin: true` | **Denegado** |
| 6 | `update` | `appointments/regla1` | admin | `booked.priceCents: 2000` | **Denegado** |
| 7 | `create` | `busySlots/nuevo` | clienta A | `start: T1`, `end: T2` | **Denegado** |
| 8 | `create` | `busySlots/regla2` | admin | `start: T1`, `end: T2` | **Denegado** |
| 9 | `update` | `busySlots/regla1` | admin | `start: T3`, `end: T4` | **Denegado** |
| 10 | `update` | `busySlots/regla1` | clienta A | `start: T3`, `end: T4` | **Denegado** |
| 11 | `create` | `closures/nuevo` | admin | `start: T1`, `end: T2` | **Denegado** |
| 12 | `create` | `closures/nuevo` | clienta A | `start: T1`, `end: T2` | **Denegado** |
| 13 | `get` | `locks/agenda` | admin | — | **Denegado** |
| 14 | `create` | `locks/agenda` | admin | `updatedAt: T1` | **Denegado** |

### 4.2 Confirmar y cancelar (RF-1, RF-14)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 15 | `update` | `appointments/regla1` | admin | `status: 'confirmed'` | **Permitido** (confirmar) |
| 16 | `update` | `appointments/regla1` | admin | `status: 'cancelled'` | **Permitido** (cancelar) |
| 17 | `update` | `appointments/regla3` | admin | `status: 'cancelled'` | **Permitido** (cancelar uno confirmado) |
| 18 | `update` | `appointments/regla2` | admin | `status: 'confirmed'` | **Denegado** (no reactiva un cancelado) |
| 19 | `update` | `appointments/regla2` | admin | `status: 'waiting_confirmation'` | **Denegado** |
| 20 | `update` | `appointments/regla1` | admin | `status: 'expired'` | **Denegado** (estado desconocido) |
| 21 | `update` | `appointments/regla1` | clienta A | `status: 'confirmed'` | **Denegado** (solo la admin confirma) |

### 4.3 Lo de la clienta (spec 009, sin cambios: RF-19)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 22 | `update` | `appointments/regla3` | clienta A | `status: 'cancelled'`, `cancelledBy: 'client'` | **Denegado** (su turno ocupado sigue: la app lo borra en el mismo lote) |
| 22b | `update` | `appointments/regla3` | clienta A | como el 22, tras borrar `busySlots/regla3` en la consola | **Permitido** (cancelar) |
| 23 | `update` | `appointments/regla1` | clienta B | `status: 'cancelled'`, `cancelledBy: 'client'` | **Denegado** (turno ajeno) |
| 24 | `update` | `appointments/regla1` | clienta A | `clientPhone` = el `phoneNumber` de la ficha de A | **Permitido** (copiar el WhatsApp) |
| 25 | `update` | `appointments/regla1` | clienta A | `clientPhone: '000'` (distinto del de su ficha) | **Denegado** |

### 4.4 Borrar (sin cambios: RF-14, RF-19)

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 26 | `delete` | `busySlots/regla1` | admin | — | **Permitido** (al cancelar) |
| 27 | `delete` | `busySlots/regla1` | clienta B | — | **Denegado** |
| 28 | `delete` | `closures/regla` | admin | — | **Permitido** |
| 29 | `delete` | `closures/regla` | clienta A | — | **Denegado** |
| 30 | `get` | `closures/regla` | clienta A | — | **Permitido** |
| 31 | `delete` | `appointments/regla1` | admin | — | **Denegado** |

### 4.5 Limpieza

Borra en la consola `appointments/regla1` a `regla3`, sus `busySlots` y `closures/regla`.

## 5. Recorrido real

Con las funciones, la app nueva y las reglas publicadas. Hazlo en Android, iOS (simulador) y Web (`flutter run -d chrome --web-port 5050`), con tema claro y oscuro y en español y portugués, repartidos entre los pasos.

1. **Dos dispositivos con la misma hora (RF-1, RF-3, RF-16):** la clienta A en un dispositivo y la clienta B en otro eligen el mismo día, la misma hora y un servicio, y pulsan «Confirmar» casi a la vez. Se guarda uno solo. La otra ve «Esa hora acaba de ocuparse», conserva el servicio y elige otra hora. En la consola hay un solo turno activo a esa hora, con su `busySlots`.
2. **Cierre contra reserva (RF-5, RF-18):** la admin abre el formulario de un cierre que cubre una hora libre; antes de guardarlo, la clienta A reserva esa hora. Al guardar el cierre, el formulario muestra el turno de A con «Editar» y «Cancelar», y el cierre no se guarda. Al revés: con el cierre guardado, la clienta que tenía esa hora abierta recibe «Esa hora acaba de ocuparse».
3. **La misma clienta en dos dispositivos (RF-6, RF-8):** la clienta A, sin turno activo, prepara un turno en el móvil y otro en la Web, y confirma los dos casi a la vez. Se guarda uno; el otro muestra el aviso de que ya tiene un turno activo, con su día y su hora.
4. **La admin agenda (RF-6, RF-7):** la admin agenda para la clienta A, que ya tiene un turno activo: sale el aviso con el turno de A. Agenda para una persona sin cuenta con el WhatsApp de A: el mismo aviso. Para una clienta sin turno activo: se guarda confirmado y marcado.
5. **El turno de un horario anterior (RF-14, RF-15):** con un turno de A guardado, la admin cambia el horario para que esa hora quede fuera.
   - La admin lo confirma y la clienta lo cancela; los dos se guardan.
   - En otro turno igual, la clienta (o la admin) edita solo el servicio, sin moverlo, y se guarda.
   - Moverlo a una hora fuera del horario nuevo no se ofrece.
6. **Lo reservado (RF-12, RF-13):** con la reserva abierta, la admin desactiva el servicio elegido en la lista de precios. Al confirmar, sale el aviso de que el servicio ya no está disponible. Si en su lugar le cambia el precio, sale el aviso de que el servicio cambió. Un turno ya guardado con el precio anterior se confirma y se cancela sin problema.
7. **Tiempos (RNF-1, D-8):** mide con un reloj, con conexión normal, desde que se pulsa hasta el aviso:
   - la primera reserva tras unos 15 minutos sin uso (arranque en frío);
   - una segunda reserva enseguida;
   - una edición;
   - un cierre.

   Cada una debe tardar 5 s como mucho. Si la primera los supera, es una decisión del autor: `minInstances: 1` en `bookAppointment` y `editAppointment`, con coste mensual (plan D-8).
8. **Lo demás sigue igual (RF-19):** confirmar y cancelar desde la agenda, bloquear a una clienta con turno activo (se cancela), cancelar desde Perfil, cambiar el WhatsApp (se copia al turno activo), borrar un cierre, y el aviso push a la admin de una reserva nueva (Android).

## Resultado

Para el autor: marca cada caso y apunta lo que no salió como se esperaba.

- [ ] Despliegue en orden: funciones, app, reglas.
- [ ] Simulador: casos 1 a 31 (con el 22b).
- [ ] Recorrido: pasos 1 a 8.
- [ ] Tiempos (RNF-1): primera reserva ___ s, segunda ___ s, edición ___ s, cierre ___ s.
- Notas:

# Comprobación manual de las reglas y de los avisos push (spec 011)

La spec 011 añade a `firestore.rules` la subcolección `users/{uid}/pushDevices/{fid}`: los dispositivos donde la admin recibe los avisos, uno por FID (plan § 3, D-1, D-15). El resto de las reglas no cambia. Las reglas no tienen tests automáticos de lo que permiten: el autor las comprueba a mano en el simulador, como en las specs 004 a 010. `test/core/firestore_rules_test.dart` solo fija su estructura.

Este documento también recoge el recorrido real de los avisos en Android (plan § 9), porque varias cosas solo se pueden comprobar con Firebase de verdad: el tiempo de llegada (RF-6), que una exadmin deje de recibirlos (RF-22), el icono y el nombre del canal.

Qué escribe la app:
- **Registrar el dispositivo** (admin, Android/iOS, con el permiso concedido): `users/<admin>/pushDevices/<fid>` con `fid`, `platform` (`'android'` o `'ios'`) y `updatedAt` (hora del servidor).
- **Cerrar sesión:** borra ese documento y da de baja el dispositivo en FCM.

Qué escribe la función `notifyAdminsOnAppointmentWrite`, con el SDK de administración (no pasa por las reglas): borra los `pushDevices` cuyo FID FCM da por no registrado o inválido.

## 1. Antes de publicar

1. Abre la [consola de Firebase](https://console.firebase.google.com/project/shaddai-68df1/firestore/rules), proyecto `shaddai-68df1`, en **Firestore Database → Reglas**.
2. Guarda una copia de las reglas publicadas (las de la spec 009; la 010 no las cambió).
3. Apunta estos UID de **Authentication → Usuarios**, con su ficha en `users/<uid>`:
   - la **admin** (`role: 'admin'`);
   - una **clienta A** (`role: 'cliente'`);
   - una **exadmin**: una cuenta de prueba con `role: 'cliente'` (para el caso 11, ponle `role: 'cliente'` a una ficha que antes fuera admin, o usa la clienta B).
4. Crea a mano en la consola (las escrituras de la consola no pasan por las reglas):
   - `users/<admin>/pushDevices/fid-admin`: `fid: 'fid-admin'`, `platform: 'android'`, `updatedAt` (timestamp);
   - `users/<exadmin>/pushDevices/fid-ex`: `fid: 'fid-ex'`, `platform: 'android'`, `updatedAt` (timestamp).

## 2. Publicar

Elige una de estas dos formas:

- **Desde la consola:** pega el contenido de `firestore.rules` en el editor de Reglas y pulsa **Publicar**. No hay índices nuevos.
- **Desde la terminal (requiere la CLI):** `firebase deploy --only firestore:rules --project shaddai-68df1`, en la raíz del repositorio.

## 3. Simulador de reglas (RF-23)

En **Reglas → Área de pruebas de reglas** (Rules Playground), ejecuta cada caso. El simulador usa los datos reales para `get()` (el rol de la ficha) y prueba una sola operación cada vez. Las escrituras del simulador no se guardan.

En `updatedAt`, el simulador no deja escribir `request.time`: en los casos que deben permitirse, usa el tipo **timestamp** con la hora del servidor si la opción existe; si no, el caso 1 sale **Denegado** solo por esa condición, y se comprueba en la app (paso 4.1).

"Datos válidos" es `fid: <el id del documento>`, `platform: 'android'`, `updatedAt: <hora del servidor>`.

| # | Tipo | Ubicación | Autenticación | Datos | Resultado esperado |
| --- | --- | --- | --- | --- | --- |
| 1 | `create` | `users/<admin>/pushDevices/fid-nuevo` | admin | datos válidos | **Permitido** |
| 2 | `create` | `users/<A>/pushDevices/fid-nuevo` | clienta A | datos válidos | **Denegado** (no es admin) |
| 3 | `create` | `users/<A>/pushDevices/fid-nuevo` | admin | datos válidos | **Denegado** (ficha de otra) |
| 4 | `create` | `users/<admin>/pushDevices/fid-nuevo` | admin | `fid: 'otro'`, el resto válido | **Denegado** (el FID no es el id) |
| 5 | `create` | `users/<admin>/pushDevices/fid-nuevo` | admin | datos válidos y `email: 'x@example.com'` | **Denegado** (campo de más) |
| 6 | `create` | `users/<admin>/pushDevices/fid-nuevo` | admin | datos válidos con `platform: 'web'` | **Denegado** (plataforma) |
| 7 | `get` | `users/<admin>/pushDevices/fid-admin` | admin | — | **Denegado** (nadie los lee desde la app) |
| 8 | `list` | `users/<exadmin>/pushDevices` | admin | — | **Denegado** |
| 9 | `delete` | `users/<admin>/pushDevices/fid-admin` | admin | — | **Permitido** (la dueña) |
| 10 | `delete` | `users/<admin>/pushDevices/fid-admin` | clienta A | — | **Denegado** (otra persona) |
| 11 | `delete` | `users/<exadmin>/pushDevices/fid-ex` | exadmin | — | **Permitido** (la dueña, aunque ya no sea admin) |

Comprueba también que lo de las specs anteriores sigue igual: repite los casos 1, 3 y 13 de `specs/009-perfil/rules-check.md` (§ 3.1).

## 4. En la app (Android)

Hace falta la función desplegada (`functions/README.md`, "Desplegar") y la región de Firestore comprobada. Usa un teléfono Android real o un emulador **con Google Play** (sin Google Play no hay FCM), con la app instalada desde `flutter run` o un APK.

Cuentas: la **admin** en el teléfono 1; la **clienta A** en otro dispositivo o en la Web (`flutter run -d chrome --web-port 5050`).

1. **Permiso y registro (RF-15, RF-18, RF-19):** inicia sesión como admin. Sale la explicación «Avisos de turnos»; pulsa «Continuar» y concede el permiso. En la consola aparece `users/<admin>/pushDevices/<fid>` con `platform: 'android'` y `updatedAt`. Cierra y abre la app: la explicación no vuelve a salir.
2. **Turno nuevo, con la app cerrada (RF-1, RF-6, RF-12):** cierra la app de la admin (deslízala fuera de recientes). La clienta A reserva un turno. En menos de un minuto llega «Turno nuevo» con su nombre, el día, la hora y el servicio, en español, sin WhatsApp ni foto. Tócalo: se abre la app en la agenda de ese día.
3. **Edición, en segundo plano (RF-2, RF-12):** deja la app de la admin en segundo plano. La clienta A cambia la hora del turno. Llega «Turno modificado» con la hora nueva. Tócalo: se abre la agenda de ese día.
4. **Cancelación, en primer plano (RF-3, RF-14):** con la app de la admin abierta en Perfil, la clienta A cancela el turno. Abajo sale «Turno cancelado» con «Ver», sin cambiar de pantalla. Pulsa «Ver»: se abre la agenda de ese día; «atrás» vuelve a Perfil.
5. **Cuenta eliminada (RF-4):** la clienta A reserva otro turno y después elimina su cuenta desde Perfil. Llega «Turno cancelado» con «…eliminó su cuenta y se canceló su turno…». (Después, vuelve a crear la clienta A si la necesitas.)
6. **Lo que hace la admin no avisa (RF-1 a RF-3):** la admin agenda un turno para alguien desde Reservas, lo confirma, lo edita y lo cancela desde la agenda. No llega ningún aviso.
7. **Dos dispositivos (RF-19):** inicia sesión como admin también en un segundo teléfono Android y concede el permiso. Hay dos documentos en `pushDevices`. Una reserva de la clienta llega a los dos, una sola vez en cada uno.
8. **Cerrar sesión con conexión (RF-20):** en el segundo teléfono, cierra sesión. Su documento desaparece de `pushDevices` y ya no recibe avisos; el primero sí.
9. **Cerrar sesión sin conexión (RF-20, RF-25):** en el segundo teléfono, inicia sesión como admin otra vez y después activa el modo avión y cierra sesión. La sesión se cierra (como mucho 5 s). Quita el modo avión y abre la app: el dispositivo se da de baja en FCM. Una reserva de la clienta ya no llega a ese teléfono. (Su documento puede seguir en `pushDevices`; la función lo borra en el primer envío que FCM rechace.)
10. **Permiso denegado y activado después (RF-17, RF-18):** en **Ajustes → Apps → shaddai → Notificaciones**, desactívalas. Vuelve a la app: en el panel sale «Avisos desactivados» arriba de la agenda, y no se vuelve a pedir el permiso. Actívalas en los ajustes y vuelve: el aviso desaparece y llegan avisos de nuevo.
11. **Exadmin (RF-22):** en la consola, cambia el rol de la admin del teléfono 2 a `'cliente'` (o usa otra cuenta admin de prueba). Una reserva de la clienta ya no le llega. Devuélvele el rol al terminar.
12. **Icono y canal (plan D-12):** en la barra de estado, el aviso lleva el sello de Studio Shaddai en blanco (no un cuadrado blanco), con el verde de la marca. En **Ajustes → Apps → shaddai → Notificaciones**, el canal se llama «Avisos de turnos» (con el teléfono en portugués, «Avisos de horários»).

**iOS** queda pendiente de la cuenta de desarrollador de Apple (spec 013): hace falta subir la clave APNs (`functions/README.md`). La app ya está configurada (`Runner.entitlements` y `remote-notification`).

Al terminar:
- borra `users/<admin>/pushDevices/fid-admin` y `users/<exadmin>/pushDevices/fid-ex`, y los turnos de prueba;
- devuelve los roles como estaban.

Si algo falla, vuelve a publicar la copia del paso 1.2 y avisa.

## Resultado

- [x] Copia de las reglas anteriores guardada.
- [x] Reglas publicadas, sin errores de sintaxis.
- [x] Casos 1 a 11 del simulador correctos.
- [x] Casos de la spec 009 correctos.
- [x] Recorrido en Android correcto (paso 4).

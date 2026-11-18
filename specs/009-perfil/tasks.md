# Tareas 009 — Perfil y mis turnos
Estado: aprobada

Spec: `spec.md` (aprobada) · Plan: `plan.md` (aprobado). En cada tarea, los tests se escriben primero y se ven en rojo. La tarea termina con `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde; en las de `functions/`, también `npm run build` y `npm test` en verde. Si una tarea añade textos, los añade en `app_es.arb` y `app_pt.arb` (claves del plan § 8), comprueba que existen en los dos idiomas en el test de textos del perfil (`test/features/profile/profile_texts_test.dart`, nuevo en T5) y ejecuta `flutter gen-l10n`.

Salen 16 tareas, en tres bloques (decisión del autor, 2026-11-18: una sola spec):
- **A — Cancelar e historial** (T1 a T8).
- **B — WhatsApp** (T9 y T10).
- **C — Borrar la cuenta** (T11 a T14), y T15 (reglas) y T16 (accesibilidad y cierre).

## Bloque A — Cancelar e historial

- [x] **T1. Campos nuevos del turno.** RF-18, RF-20, RF-35, RF-44 (plan D-1, D-2)
  - Tests: ampliar `test/data/models/appointment_model_test.dart`: `cancelledBy: 'client'` → `cancelledByClient`; sin el campo o con otro valor → `false`; `accountDeleted: true` y ausente; `toMap` no escribe ninguno de los dos; un turno antiguo sin `booked` sigue leyéndose.
  - Hecho cuando: `AppointmentModel` expone `cancelledByClient` y `accountDeleted` y los tests pasan.

- [x] **T2. Lógica pura de cancelar y del perfil.** RF-1, RF-3, RF-4, RF-5, RF-7, RF-14, RF-20, RF-21, RF-22
  - Tests (tablas, "ahora" fijo):
    - `test/features/booking/cancel_appointment_test.dart` (nuevo): `cancelAvailability` (cancelable, borde exacto del margen, margen 0, ya empezado, carga, error) y `checkCancelBeforeSave` (no existe, cancelado, terminado → `notActive`; otra hora, otro fin u otro servicio → `changed`; solo confirmado → `ok`; dentro del margen → `notCancellable`).
    - `test/features/profile/profile_appointments_test.dart` (nuevo): `profileAppointments` (activo y resto, orden descendente, sin activo, lista vacía) y `historyLabel` (cancelado por ti, por el salón, sin `cancelledBy`, realizado, no confirmado, `upcoming`).
  - Hecho cuando: `lib/features/booking/logic/cancel_appointment.dart` y `lib/features/profile/logic/profile_appointments.dart` existen, sin imports de Flutter ni Firebase, y los tests pasan.

- [x] **T3. Cancelar en la capa de datos.** RF-11, RF-13, RF-14, RF-15
  - Tests: ampliar `FakeBookingRepository` con `cancelByClient` (aplica `expected` como la transacción; cambia el turno a `cancelled` con `cancelledBy` en `mine` y `active`; quita su turno ocupado de `busy`; lo registra en `cancelled`; o lanza `cancelError`) y probar el fake en `test/data/fake_booking_test.dart` (ok, `expected` falso sin cambios, error).
  - Hecho cuando: `BookingRepository.cancelByClient` hace la transacción del plan D-3 con `saveTimeout`, el fake la imita y los tests pasan.

- [x] **T4. Controlador de cancelar.** RF-3, RF-4, RF-7, RF-11, RF-12, RF-14, RF-15, RF-17
  - Tests: `test/features/booking/booking_cancel_test.dart` (nuevo, con el fake):
    - `cancelAvailabilityProvider` cambia de cancelable a cerrado al avanzar `salonNowProvider` (RF-7);
    - `cancel`: `ok` y el turno sale de `mine` activo;
    - `notActive`, `changed` y `notCancellable` sin cambios;
    - error y tiempo agotado → `failed` sin cambios;
    - con la edición de ese turno abierta: la cierra y vacía la selección (RF-17).
  - Hecho cuando: `booking_cancel_provider.dart` con `cancelAvailabilityProvider` y `AppointmentCanceller` cumple los tests.

- [x] **T5. Botón y diálogo de cancelar en Reservas.** RF-8, RF-9, RF-10, RF-12, RF-14, RF-15, RF-16, RNF-4 (plan D-5, D-13)
  - Tests: `test/features/booking/active_appointment_cancel_test.dart` (nuevo, pantalla con `pumpApp`):
    - "Cancelar turno" junto a "Editar turno";
    - el diálogo muestra el día, la hora del salón y el servicio;
    - "No, mantener" no cambia nada;
    - "Sí, cancelar": aviso de éxito y vuelta a la vista de reservar;
    - cada motivo de RF-14 con su texto; el fallo con su texto;
    - mientras guarda, los botones están desactivados (un segundo toque no llama dos veces);
    - bloqueada: aviso de bloqueo y "Cancelar turno", sin "Editar";
    - dentro del margen: ni "Editar" ni "Cancelar";
    - `profile_texts_test.dart` con las claves de cancelar en ES y PT.
  - Hecho cuando: `cancel_appointment.dart` (presentación) existe, `ActiveAppointmentView` lo usa y los tests pasan.

- [x] **T6. Tarjeta del turno activo en el perfil.** RF-1, RF-2, RF-3, RF-4, RF-5, RF-6, RF-7, RF-8, RF-44
  - Tests: `test/features/profile/profile_view_test.dart` (nuevo):
    - activo con día, fecha y `HH:mm – HH:mm` en hora del salón (`TZ=Europe/Lisbon` para verlo en rojo), servicio, adicionales y estado;
    - turno antiguo sin servicio;
    - "Editar turno" abre la edición en Reservas (móvil: cambia de pestaña; Web: `/booking`);
    - "Cancelar turno" con el mismo diálogo que en Reservas;
    - al pasar el margen, los botones dan paso al aviso con WhatsApp sin recargar;
    - sin turno activo: "No tienes turnos próximos" y "Reservar";
    - el turno cambia en el stream y el perfil lo muestra sin recargar.
  - Hecho cuando: `profileAppointmentsProvider` y `ProfileActiveCard` existen y el perfil los muestra.

- [x] **T7. Historial y estructura del perfil.** RF-20, RF-21, RF-22, RF-23, RF-24, RF-43, RNF-1 (plan D-12)
  - Tests: ampliar `profile_view_test.dart`:
    - historial del más reciente al más antiguo, cada uno con su etiqueta y sin acciones;
    - sin historial no hay sección;
    - error al cargar: texto y "Reintentar", que vuelve a pedir los turnos, y las preferencias siguen visibles;
    - "Reservar" solo sin turno activo;
    - la admin ve el panel;
    - "Cerrar sesión" es un botón con nombre.
    - Ajustar `profile_dates_test.dart` y `web_profile_test.dart` a la nueva estructura (sin cambiar lo que comprueban).
  - Hecho cuando: el perfil es una sola lista (cabecera, identidad, panel, activo, historial, preferencias), `ProfileHistoryCard` sustituye a `_AppointmentCard`, se borran las claves que dejan de usarse y los tests pasan.

- [x] **T8. Marca "Cancelado por la clienta" en la agenda.** RF-18
  - Tests: ampliar el test de la agenda de la admin: un turno cancelado con `cancelledBy: 'client'` muestra la marca, en ES y PT; uno cancelado sin el campo no.
  - Hecho cuando: `_AppointmentCard` muestra la marca y los tests pasan.

## Bloque B — WhatsApp

- [x] **T9. Campo de WhatsApp compartido y captura.** RF-26, RF-27 (plan D-7)
  - Tests: ampliar el test de la captura del WhatsApp: un número inválido (letras, 7 dígitos) muestra el error junto al campo y no guarda; uno válido guarda y sigue como hoy. Test del `WhatsAppField`: número escrito, error con `brand.danger`, texto de consentimiento.
  - Hecho cuando: `lib/core/widgets/whatsapp_field.dart` existe, `PhoneCaptureView` lo usa con `isValidWhatsApp` y los tests pasan.

- [x] **T10. Cambiar el WhatsApp desde el perfil.** RF-25, RF-26, RF-27, RF-28, RF-29, RF-30
  - Tests:
    - ampliar `FakeUserRepository` con `updateWhatsApp` (registra la ficha y el id del turno, emite la ficha, o lanza);
    - `test/features/profile/change_whatsapp_test.dart` (nuevo): WhatsApp y "Cambiar" en el perfil; el diálogo trae el número actual; inválido → error junto al campo; válido con turno activo → guarda la ficha y el id de ese turno, y el perfil muestra el número nuevo; sin turno activo → solo la ficha; "Cancelar" conserva el número; fallo → aviso y el número anterior.
  - Hecho cuando: `UserRepository.updateWhatsApp` (lote de D-6), `WhatsAppChanger` y `ChangeWhatsAppDialog` cumplen los tests.

## Bloque C — Borrar la cuenta

- [x] **T11. Proyecto `functions/` y lógica del borrado.** RF-34, RF-35, RF-39, RF-40, RF-42 (plan D-8, D-10)
  - Tests: `functions/test/delete_account.test.ts` (`node --test`, almacén en memoria):
    - sin uid → `unauthenticated`; admin → `permission-denied`; bloqueada → `failed-precondition` (`blocked`), sin tocar nada;
    - cancela solo el activo (también dentro del margen), con `cancelledBy: 'client'`, y borra su turno ocupado;
    - todos los turnos quedan con `accountDeleted` y sin foto, con nombre y WhatsApp intactos;
    - borra la ficha y la cuenta de Auth;
    - un fallo a mitad y el reintento dejan el mismo resultado; ficha ya borrada → sigue;
    - más de 400 turnos → varios lotes.
  - Hecho cuando: `functions/` (`package.json`, `tsconfig.json`, `src/delete_account.ts`) compila, `npm test` pasa y `delete_account.ts` no importa Firebase.

- [x] **T12. Función invocable y despliegue.** RF-37, RF-42
  - Tests: `functions/test/index.test.ts`: el adaptador pasa el uid de la sesión (no el de los datos) y traduce los errores de la lógica a `HttpsError`.
  - Hecho cuando: `src/index.ts` exporta `deleteAccount` (v2 `onCall`, `southamerica-east1`) con el almacén de `firebase-admin`, `firebase.json` tiene la entrada `functions`, `npm run build` y `npm test` pasan, y el despliegue queda descrito para el autor (requiere el plan Blaze; lo hace él).

- [x] **T13. Llamada desde la app.** RF-37, RF-39, RF-40
  - Tests: `test/data/account_repository_test.dart` (nuevo, con un `FirebaseFunctions` falso): éxito; `failed-precondition` con `blocked` → `blocked`; `permission-denied` → `notAllowed`; otro error o sin conexión → `failed`. `FakeAccountRepository` en `fake_auth.dart`.
  - Hecho cuando: `cloud_functions` está en `pubspec.yaml` (aprobada), `AccountRepository` y su fake cumplen los tests.

- [ ] **T14. "Eliminar mi cuenta" en el perfil.** RF-31, RF-32, RF-33, RF-36, RF-38, RF-39, RF-40, RNF-4, RNF-5
  - Tests:
    - `test/features/profile/account_deletion_test.dart` (nuevo, lógica): `accountDeletionAccess` y `deletionWordMatches` (mayúsculas, espacios, palabra de otro idioma).
    - `test/features/profile/delete_account_test.dart` (nuevo, pantalla): la clienta ve "Eliminar mi cuenta" y la admin no; bloqueada ve el aviso con WhatsApp; cancelar en el paso 1 o 2 no llama a nada; la palabra en ES (`ELIMINAR`) y PT (`EXCLUIR`) activa el botón; en curso, sin doble envío; éxito → sesión cerrada, aviso e `/home` (móvil) o `/` (Web, con `pumpWebApp`); fallo → texto y "Reintentar"; `blocked` → su texto.
  - Hecho cuando: `account_deletion.dart`, `AccountDeleter` y `DeleteAccountDialog` cumplen los tests.

- [ ] **T15. Reglas de Firestore.** RF-19, RF-28, RF-42
  - Tests: ampliar `test/core/firestore_rules_test.dart`: rama "la clienta cancela" (solo `status` y `cancelledBy`, margen, sin turno ocupado después), rama "copia su WhatsApp" (`getAfter` de la ficha), borrado del turno ocupado por la dueña de un turno cancelado, `users` sigue sin `delete`.
  - Hecho cuando: `firestore.rules` tiene las ramas del plan § 3 y su cabecera cita la spec 009, `specs/009-perfil/rules-check.md` lista los casos para el simulador (los comprueba el autor) y los tests pasan.

- [ ] **T16. Marca "Cuenta eliminada", accesibilidad y cierre.** RF-35, RNF-1 a RNF-5, RC-1
  - Tests:
    - ampliar el test de la agenda: marca "Cuenta eliminada";
    - perfil, historial y los tres diálogos con `textContrastGuideline`, `androidTapTargetGuideline` y `labeledTapTargetGuideline` en claro y oscuro; 320 px con el texto al 200 % sin desbordes; cambio de idioma con un diálogo abierto.
  - Hecho cuando: la agenda muestra la marca, los tests pasan, y `CLAUDE.md`, `MEMORY.md` y `docs/ESPECIFICACION.md` describen los campos nuevos, `functions/` y el estado de la spec.

RF-41 no tiene tarea: ya lo cumple el código (plan § 1) y se comprueba en la validación.

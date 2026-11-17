# Tareas 007 — Reserva de la admin
Estado: aprobada

Spec: `spec.md` (aprobada) · Plan: `plan.md` (aprobado). En cada tarea, los tests se escriben primero y se ven en rojo. La tarea termina con `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde. Si una tarea añade textos, los añade en `app_es.arb` y `app_pt.arb` (claves del plan § 6), añade sus claves a `test/features/booking/booking_texts_test.dart` y ejecuta `flutter gen-l10n`.

Salen 15 tareas, en tres bloques:
- **A** es solo datos, lógica pura y providers. La app sigue igual por fuera.
- **B** cambia la vista: "Para quién", la persona sin cuenta, la confirmación, el guardado y la lista de la admin.
- **C** contiene las reglas, la accesibilidad y el cierre.

Son más de 10, pero la spec no se divide (decisión del autor, 2026-11-16): los bloques B y C dependen de la lógica y los providers del bloque A, y "Para quién" no tiene sentido sin guardar el turno.

Los repositorios no tienen tests propios (tocarían Firebase): su contrato lo fija `FakeBookingRepository` (y un `UserRepository` falso), y su comportamiento real se comprueba en el recorrido manual y en `rules-check.md`, como en la 005 y la 006.

## Bloque A — Datos, lógica y providers

- [x] **T1. Turno sin cuenta y creado por la admin en el modelo.** RF-19, RF-24
  - Tests: `test/data/models/appointment_model_test.dart`:
    - `clientId` `null`, vacío o que falta se lee como `null` y `hasAccount` es `false`;
    - `createdByAdmin` se lee; falta → `false`;
    - `toMap` escribe `clientId: null` de forma explícita y `createdByAdmin` siempre.
  - Hecho cuando: los tests pasan y el resto de la app compila con `clientId` nullable (la reserva de la clienta sigue escribiendo su `uid` y `createdByAdmin: false`).
  - Hecha (2026-11-16):
    - `AppointmentModel.clientId` es `String?` (vacío o que falta → `null`), con `hasAccount`; `createdByAdmin` (por defecto `false`, solo `true` si el campo es `true`). `toMap` escribe `clientId` siempre, también `null` (D-3), y `createdByAdmin`;
    - no hizo falta tocar más código: la reserva de la clienta ya pasaba su `uid`;
    - 6 tests nuevos (uno ajustado); suite completa, 1457 en verde.

- [x] **T2. WhatsApp: normalizar, validar y enlazar.** RF-7, RF-9, RF-10, RF-22, RNF-1
  - Tests: `test/features/booking/logic/whatsapp_test.dart` (nuevo), en tabla:
    - `normalizeWhatsApp`: espacios, guiones, paréntesis, `+55`, `55` delante con 12 y 13 dígitos (se quita), `55` como DDD con 10 y 11 dígitos (se queda, D-1), texto sin dígitos;
    - `isValidWhatsApp`: 7, 8, 15 y 16 dígitos tras normalizar;
    - `sameWhatsApp`: con y sin `+55`, dos vacíos (→ no);
    - `whatsAppLink`: con `+`, con `55`, sin código del país (añade `55`).
  - Hecho cuando: los tests pasan.
  - Hecha (2026-11-16):
    - `lib/features/booking/logic/whatsapp.dart`: `normalizeWhatsApp`, `isValidWhatsApp`, `sameWhatsApp` y `whatsAppLink` (devuelve `Uri?`, `null` sin dígitos);
    - D-1 precisada: el `55` también se quita si va detrás de `+`, aunque el número sea corto (`+55 1234567` → 7 dígitos, no válido);
    - 36 tests nuevos, en tabla; suite completa, 1493 en verde.

- [x] **T3. Para quién y la búsqueda.** RF-2 a RF-5, RF-7 a RF-11, RF-15, RNF-1
  - Tests: `test/features/booking/logic/recipient_test.dart` (nuevo), en tabla:
    - `foldText`: mayúsculas y acentos del español y el portugués (á, ã, â, ç, ñ, ü…);
    - `searchClients`: menos de 2 caracteres (→ vacío), nombre sin acentos ni mayúsculas, dígitos del WhatsApp, sin bloqueadas, admins ni cuentas sin WhatsApp, orden alfabético sin acentos, límite de 20;
    - `accountWithPhone`: clienta con el mismo WhatsApp normalizado, bloqueada incluida; admin (→ no); ninguna;
    - `guestErrors`: nombre vacío, de 80 y de 81 caracteres, WhatsApp no válido, casilla sin marcar;
    - `reconcileRecipient`: la ficha se bloquea, desaparece o deja de ser clienta (→ se quita y avisa); sigue igual (→ sin aviso); persona sin cuenta (→ sin cambios).
  - Hecho cuando: los tests pasan.
  - Hecha (2026-11-16):
    - `lib/features/booking/logic/recipient.dart`: `Recipient` (`AccountRecipient`, con `.of(UserModel)`; `GuestRecipient`, con `empty` y `copyWith`), igualdad por valor; `foldText`, `isBookableClient`, `searchClients`, `accountWithPhone`, `GuestField`, `guestErrors` y `reconcileRecipient`;
    - la búsqueda por dígitos solo se hace si lo escrito parece un número (dígitos, espacios, `+`, `-`, `()` y `.`), y los dígitos se normalizan como un WhatsApp. Así "Ana 2" no ofrece a todas las que tienen un 2 en el número, y "+55 41 9…" encuentra el número guardado sin el 55;
    - `accountWithPhone`: si dos cuentas tienen el mismo número y una está bloqueada, manda la bloqueada (RF-11);
    - el nombre se mide sin los espacios de alrededor y en caracteres, no en unidades UTF-16;
    - 39 tests nuevos, en tabla; suite completa, 1532 en verde.

- [x] **T4. Turno activo de una persona y comprobación al guardar.** RF-11, RF-14, RF-15, RF-18, RNF-1
  - Tests: `test/features/booking/logic/admin_booking_test.dart` (nuevo), en tabla:
    - `activeAppointmentOfPerson`: por `uid`; por WhatsApp de una persona sin cuenta; una clienta con cuenta que tiene un turno sin cuenta con su WhatsApp; en curso (→ activo); terminado o cancelado (→ no);
    - `checkAdminBeforeSave`: `ok`, `slotTaken`, `doesNotFit`, `personActive`, `recipientBlocked` (ficha bloqueada, inexistente o no clienta; persona sin cuenta con el WhatsApp de una bloqueada), en ese orden de prioridad.
  - Hecho cuando: los tests pasan.
  - Hecha (2026-11-16):
    - `lib/features/booking/logic/admin_booking.dart`: `activeAppointmentOfPerson` (por cuenta o por WhatsApp, con el `activeAppointment` de la 005) y `checkAdminBeforeSave`, que devuelve una clase sellada (`AdminCheckOk`, `…RecipientBlocked`, `…PersonActive` con el turno, `…SlotTaken`, `…DoesNotFit`). La prioridad es la de la lista de arriba, de bloqueada a no cabe;
    - trabaja con `AppointmentModel`, no con un tipo genérico como `booking_rules.dart`: es más simple y la lógica ya importa los modelos;
    - con cuenta, el turno activo se busca también por el WhatsApp **actual** de su ficha (leída del servidor), no solo por el que tenía al elegirla;
    - la comprobación de la hora sale de `checkBeforeSave` a `checkSlot` (`booking_rules.dart`), que usan las dos; la 005 no cambia;
    - 22 tests nuevos; suite completa, 1554 en verde.

- [ ] **T5. Ventana de 365 días y "para quién" en lo que falta.** RF-12, RF-13, RF-17, RNF-1
  - Tests:
    - `test/features/booking/logic/booking_window_test.dart`: `bookingWindow(days: 365)` llega al día 365 y no al 366; los días cerrados y bloqueados siguen fuera; sin `days`, 60 como antes;
    - `booking_selection_test.dart`: con `windowDays: 365`, `reconcile` acepta un día a 200 días; `missingParts` en modo admin añade `recipient` sin para quién y con una persona sin cuenta con errores; fuera del modo admin, sin cambios.
  - Hecho cuando: los tests pasan y los de la 005 y la 006 siguen en verde.

- [ ] **T6. Repositorios y providers de la reserva de la admin.** RF-6, RF-12, RF-14, RF-15, RF-18 a RF-20, RF-27
  - Tests: `test/features/booking/admin_booking_provider_test.dart` (nuevo), con `FakeBookingRepository` y un `UserRepository` falso ampliados (`watchActiveAppointments`, `fetchAdminBookingCheck`, `fetchUser`):
    - `bookingWindowDaysProvider`: 365 con la admin, 60 con la clienta; `busySlotsProvider` pide 365 días con la admin;
    - `bookingRecipientProvider`: elegir, cambiar, borrador de la persona sin cuenta; conserva todo al dejar de escucharse (RF-27); se vacía al cambiar de cuenta; quita a la clienta si la bloquean (RF-15);
    - `recipientActiveAppointmentProvider`: el turno activo de la elegida, por `uid` y por WhatsApp;
    - `AdminBookingSubmitter`: guarda confirmado, `createdByAdmin: true`, con los datos de la clienta o de la persona sin cuenta (`clientId: null`) (RF-19); cada resultado de la comprobación; `failed` sin conexión, conservando lo elegido; con `ok` vacía la selección (también el día, D-8) y para quién (RF-20).
  - Hecho cuando: los tests pasan. La vista aún no los usa.

## Bloque B — Vista

- [ ] **T7. La admin ve el formulario con "Para quién".** RF-1, RF-12, RF-28
  - Tests:
    - `booking_screen_states_test.dart`: la admin ve el formulario con "Para quién" sin nada elegido, no `BookingAdminNotice`, ni un turno activo propio ni "Editar turno";
    - `admin_booking_view_test.dart` (nuevo): el calendario de la admin deja elegir un día a 200 días, no uno cerrado ni uno bloqueado; el de la clienta sigue en 60.
  - Hecho cuando: los tests pasan y `BookingAdminNotice` y `bookingAdminNotice` se han borrado. Textos: `bookingAdminTitle`, `bookingStepRecipient`.

- [ ] **T8. Buscar y elegir a una clienta con cuenta.** RF-3 a RF-6, RF-14
  - Tests (`admin_booking_view_test.dart`):
    - con 1 carácter no hay resultados; con 2, las clientas que coinciden, por nombre sin acentos y por WhatsApp; sin bloqueadas ni admins;
    - sin resultados: el texto y "Persona sin cuenta";
    - error al cargar las clientas: aviso con "Reintentar", que vuelve a pedirlas, y "Persona sin cuenta" disponible;
    - elegir a una muestra su tarjeta con "Cambiar"; si tiene turno activo, el aviso con su fecha, su hora y lo reservado.
  - Hecho cuando: los tests pasan. Textos: `bookingRecipientSearch*`, `bookingRecipientNoResults`, `bookingRecipientLoadError`, `bookingRecipientGuestAction`, `bookingRecipientChange`, `bookingRecipientActive`.

- [ ] **T9. Persona sin cuenta.** RF-7 a RF-11
  - Tests (`admin_booking_view_test.dart`):
    - "Persona sin cuenta" muestra nombre, WhatsApp y la casilla; "Buscar clienta" vuelve a la búsqueda;
    - al tocar "Agendar turno", cada campo con error lleva su texto (nombre vacío o de 81 caracteres, WhatsApp no válido, casilla sin marcar);
    - al salir del campo de WhatsApp con el número de una clienta: el aviso, "Elegir a <nombre>" la elige y "Seguir sin cuenta" lo deja como está; con el de una bloqueada: el error en el campo;
    - con el WhatsApp de una persona con turno activo: el aviso de RF-14.
  - Hecho cuando: los tests pasan. Textos: `bookingGuest*`.

- [ ] **T10. Lo que falta, resumen y confirmación.** RF-14, RF-16, RF-17, RF-29
  - Tests (`admin_booking_view_test.dart`):
    - "Agendar turno" sin para quién, sin hora o sin servicio: no abre la confirmación, dice qué falta y marca cada parte;
    - con la persona con turno activo: no abre la confirmación, avisa y marca "Para quién";
    - el resumen y la confirmación muestran primero para quién (y "sin cuenta"), y "El turno quedará confirmado";
    - con un margen de 60 minutos y una hora dentro: el aviso con el nombre de la clienta con cuenta; nada con una persona sin cuenta;
    - cambio de idioma con la confirmación abierta: se traduce.
  - Hecho cuando: los tests pasan. Textos: `bookingMissingRecipient`, `bookingMissingSeveral`, `bookingSummaryFor`, `bookingSummaryGuest`, `bookingAdminConfirmNote`, `bookingAdminMarginWarning`.

- [ ] **T11. Agendar y lo que pasa después.** RF-15, RF-18 a RF-20, RF-27
  - Tests:
    - `admin_booking_view_test.dart`: tras confirmar, el aviso "Turno agendado para <nombre>" y la vista vacía, en Android/iOS (`pumpMobileApp`) y en Web (`pumpWebApp`, sin el diálogo de volver a la landing); `slotTaken`, `doesNotFit` y `failed` con los avisos de la 005 y lo elegido conservado; `personActive` con su aviso; `recipientBlocked` quita para quién y avisa;
    - "Para quién" y lo elegido se conservan al cambiar de pestaña y al ir a otra página de la app en Web (RF-27);
    - desde el detalle, "Reservar cita" abre la reserva de la admin con el servicio elegido y sin para quién.
  - Hecho cuando: los tests pasan. Textos: `bookingAdminCreated`, `bookingRecipientBlocked`.

- [ ] **T12. La clienta ve el turno que le agendó la admin.** RF-21
  - Tests: `test/features/booking/admin_booked_client_test.dart` (nuevo): un turno confirmado con `createdByAdmin` que llega en vivo con la reserva abierta pasa a verse como su turno activo, sin recargar, y en Perfil; se puede editar y al guardar vuelve a esperar confirmación (spec 006).
  - Hecho cuando: los tests pasan (puede que sin cambios de código).

- [ ] **T13. La lista de la admin.** RF-22 a RF-24
  - Tests: `test/features/admin/admin_appointments_booked_test.dart`: un turno sin cuenta muestra su nombre, su WhatsApp, "Sin cuenta" y las iniciales sin foto; uno con `createdByAdmin`, "Agendado por la admin"; el botón de WhatsApp (48 px, con su nombre para el lector de pantalla) abre `whatsAppLink` en `RecordingLinkLauncher`, también en un turno con cuenta (D-6); las horas libres de la clienta no muestran la hora de un turno sin cuenta.
  - Hecho cuando: los tests pasan. Textos: `adminAppointmentGuest`, `adminAppointmentByAdmin`, `adminAppointmentWhatsApp`.

## Bloque C — Reglas, accesibilidad y cierre

- [ ] **T14. Reglas de Firestore.** RF-2, RF-25, RF-26, RF-30, RNF-5
  - Tests: `test/core/firestore_rules_test.dart` fija la estructura de las reglas (qué comprueba cada `match`); se amplía primero con los cambios del plan § 2. Lo que permite cada regla no se prueba automáticamente: se escribe `specs/007-reserva-admin/rules-check.md` con cada caso del simulador:
    - la admin crea un turno confirmado para una clienta, para una persona sin cuenta y su turno ocupado (→ sí);
    - la admin crea a su nombre, para otra admin, para una bloqueada, esperando confirmación o sin `createdByAdmin` (→ no);
    - la clienta crea con `createdByAdmin: true` (→ no); su reserva normal (→ sí);
    - la clienta lee un turno sin cuenta (→ no); la admin (→ sí);
    - la clienta edita un turno que le agendó la admin sin tocar `createdByAdmin` (→ sí) y cambiándolo (→ no);
    - los casos de la 006 que tocan estas reglas siguen igual.
  - Hecho cuando: `firestore.rules` tiene los cambios del plan § 2 y el autor los comprueba en el simulador.

- [ ] **T15. Accesibilidad y cierre.** RNF-2, RNF-3
  - Tests: `test/features/booking/admin_booking_accessibility_test.dart` (nuevo): contraste en tema claro y oscuro, objetivos de 48 px, semántica de los resultados, del aviso de WhatsApp con cuenta y del de turno activo, texto al 200 % y 320 px en "Para quién", en la persona sin cuenta, en la confirmación y en la tarjeta de la lista; todas las claves nuevas en ES y PT.
  - Hecho cuando: los tests pasan, `CLAUDE.md` y `MEMORY.md` describen la reserva de la admin, y queda el recorrido manual de los criterios de finalización para el autor.

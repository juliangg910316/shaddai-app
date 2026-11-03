# Tareas 005 — Reservas
Estado: aprobada

Spec: `spec.md` (aprobada) · Plan: `plan.md` (aprobado). En cada tarea, los tests se escriben primero y se ven en rojo. La tarea termina con `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde. Si una tarea añade textos, los añade en `app_es.arb` y `app_pt.arb` y ejecuta `flutter gen-l10n`.

Salen 18 tareas, en tres bloques:
- **A** es solo lógica pura, datos y providers. La app sigue igual por fuera: la vista actual sigue funcionando hasta el bloque B.
- **B** cambia la vista de reserva y las rutas.
- **C** contiene las reglas, la accesibilidad y el cierre.

La vista antigua y sus providers (`availableSlotsProvider`, `selectedDateProvider`…) conviven con los nuevos hasta T17, donde se borran.

## Bloque A — Lógica, datos y providers

- [x] **T1. Hora del salón y ventana de reserva.** RF-1 a RF-3, RF-5, RNF-1
  - Tests:
    - `test/features/booking/logic/salon_time_test.dart`:
      - `toSalon`/`fromSalon` de ida y vuelta;
      - 23:30 en Curitiba es 02:30 UTC del día siguiente;
      - `deviceIsInSalonZone` con −3 h (Curitiba, Buenos Aires) → sí, y con +0 h (Lisboa) → no.
    - `test/features/booking/logic/booking_window_test.dart`, en tabla:
      - la ventana va de hoy a hoy + 60 días;
      - día bloqueado, día cerrado, cierre ≤ apertura y día fuera de la ventana → no se puede elegir;
      - `dayGrid` con apertura 8:00 y con 8:15;
      - `initialDay` elige hoy si tiene horas libres, mañana si hoy ya no tiene, el primer día que se puede elegir si ninguno tiene horas, y `null` si ninguno se puede elegir.
  - Hecho cuando: `salon_time.dart` y `booking_window.dart` (`lib/features/booking/logic/`) pasan los tests y no importan Flutter ni Firebase.
  - Hecha (2026-11-02):
    - `salon_time.dart`: `salonUtcOffset`, `toSalon`, `fromSalon` (solo cuentan los campos de la hora de pared), `salonDay` y `deviceIsInSalonZone`;
    - `booking_window.dart`: `BookingWindow` (con `contains` y `days`), `bookingWindow`, `blockedDateKey`, `openingOf`, `dayGrid`, `isSelectableDay` e `initialDay`;
    - una hora `HH:mm` mal escrita cuenta como día cerrado;
    - `initialDay` recibe `hasFreeSlot(día)` en lugar de los turnos ocupados, para no depender de T2. Quien la llame (T9) le pasa `freeSlots(…).isNotEmpty`. El comportamiento es el del plan;
    - imports: solo `weekday_key.dart` y `calendar_settings_model.dart`, sin Flutter ni Firebase;
    - 34 tests;
    - arreglo aparte, sin cambio de comportamiento (decisión del autor): dos tests que fallaron al pasar a noviembre:
      - `state_preserved_test` buscaba "outubro" fijo: ahora busca el mes de mañana;
      - `web_booking_flow_test` › "en Android/iOS…": el mes de 6 semanas bajaba las horas fuera de la pantalla de 800×600: ahora usa 800×2400;
    - el formato nuevo de Flutter 3.47.8 en 27 archivos que no se tocaron se queda (decisión del autor);
    - suite completa: 931 en verde.

- [x] **T2. Horas libres y cobertura.** RF-4, RF-12, RF-15, RNF-1
  - Tests: `test/features/booking/logic/free_slots_test.dart`, en tabla, con los casos de RNF-1:
    - turno de 8:00 a 9:10 → la primera hora libre es 9:30;
    - turno de 8:00 a 9:00 → 9:00 es libre;
    - una hora igual a "ahora" no es libre;
    - la cobertura llega justo al cierre;
    - la cobertura termina en el siguiente turno ocupado;
    - un servicio que cabe justo (`fits`);
    - apertura a las 8:15;
    - un día sin rejilla;
    - turnos ocupados de otro día.
  - Hecho cuando: `free_slots.dart` pasa los tests y no importa Flutter ni Firebase.
  - Hecha (2026-11-02):
    - `free_slots.dart`: `FreeSlot` (inicio y cobertura, comparado por valor), `freeSlots` y `fits`;
    - los turnos ocupados entran como `BusyRange` (`({start, end})` en hora de pared del salón), en lugar del `BusySlot` de T6, para no depender de él. El provider de T8 convierte los instantes con `toSalon`. El comportamiento es el del plan;
    - la cobertura se corta en el inicio del siguiente turno ocupado, aunque no caiga en la rejilla (turno a las 9:10 → la hora de las 9:00 tiene 10 min);
    - imports: solo `calendar_settings_model.dart` y `booking_window.dart`;
    - 20 tests;
    - suite completa: 952 en verde.

- [x] **T3. Lo reservado: modelo, catálogo y precio total.** RF-10, RF-11, RF-18, RF-19, RF-22, RF-27, RF-28
  - Tests:
    - `test/data/models/booked_service_model_test.dart`: ida y vuelta, campos que faltan y adicionales vacíos en un combo.
    - `test/features/booking/logic/bookable_catalog_test.dart`:
      - quedan fuera los servicios ocultos, las categorías ocultas y las que solo tienen adicionales;
      - los adicionales visibles son los de la categoría del servicio;
      - un combo no tiene adicionales;
      - `findBookable` de un id inexistente u oculto → `null`;
      - `totalPrice` con y sin "desde";
      - `snapshotOf` copia los nombres en ES y PT, los precios y la duración.
  - Hecho cuando: `booked_service_model.dart` y `bookable_catalog.dart` pasan los tests sin importar Flutter ni Firebase.
  - Hecha (2026-11-02):
    - `lib/data/models/booked_service_model.dart`:
      - `BookedKind` (servicio o combo; un valor desconocido es servicio);
      - `BookedAddonModel` y `BookedServiceModel`, con `fromMap` tolerante y `toMap`;
      - `totalCents`, para el turno activo (RF-33);
    - `lib/features/booking/logic/bookable_catalog.dart`:
      - `BookableRef`, `BookableCategory` y `BookableCatalog`;
      - `Bookable` sellada (`BookableService`, `BookableCombo`);
      - `bookableCatalog`, `findBookable`, `availableAddons`, `totalPrice` y `snapshotOf`;
    - un servicio no disponible tampoco tiene adicionales;
    - imports: solo modelos de `lib/data/models/`, sin Flutter ni Firebase;
    - 29 tests;
    - suite completa: 982 en verde.

- [x] **T4. Lo elegido y su conciliación.** RF-8, RF-9, RF-13, RF-15 a RF-17, RF-20, RF-21, RF-24, RF-40
  - Tests: `test/features/booking/logic/booking_selection_test.dart`, en tabla:
    - `selectDay` quita la hora y conserva lo reservado;
    - `selectSlot` se rechaza, con su aviso, si el servicio elegido no cabe;
    - `selectItem` se rechaza, con su aviso de duración, si no cabe en la hora; si se acepta, desmarca los adicionales;
    - `requestItem` conserva la hora solo si el servicio cabe;
    - `reconcile`:
      - quita una hora que pasó o que se ocupó (`slotGone`);
      - quita una hora en la que el servicio ya no cabe (`slotTooShort`);
      - quita un servicio que ya no está disponible, con sus adicionales;
      - desmarca un adicional oculto;
      - pasa a la fecha de RF-1 si la elegida se bloquea o queda fuera de la ventana a medianoche;
    - `missingParts`.
  - Hecho cuando: `booking_selection.dart` pasa los tests. Los avisos son valores de `BookingNotice`, no textos.
  - Hecha (2026-11-03):
    - `booking_selection.dart`:
      - `BookingSelection` (comparada por valor);
      - `BookingNotice` y `BookingNoticeKind`: `needsLongerSlot`, `slotTooShortFor`, `slotGone`, `slotNoLongerFits`, `itemUnavailable` y `dateMoved`;
      - `BookingContext`: catálogo, ajustes y turnos ocupados, cada uno `null` mientras no ha llegado; lo que depende de un dato que falta no se toca;
      - `selectDay`, `selectSlot`, `selectItem`, `toggleAddon`, `requestItem`, `reconcile`, y `missingParts` con `BookingPart`;
    - dos añadidos que el plan no nombra y que RF-18 y RF-20 necesitan:
      - `toggleAddon`, para marcar y desmarcar adicionales (solo los disponibles);
      - elegir otra vez el mismo servicio conserva los adicionales, porque RF-20 solo los desmarca "al cambiar";
    - el aviso que el plan llama `slotTooShort` se llama `slotNoLongerFits`, como su clave `.arb` (`bookingSlotNoLongerFits`);
    - si la hora elegida ya no es libre, `selectItem` acepta el servicio, y `reconcile` quita la hora con su aviso;
    - si ningún día se puede elegir, `reconcile` deja la selección sin día ni hora (RF-2);
    - imports: solo `calendar_settings_model.dart` y la lógica de T1 a T3;
    - 32 tests;
    - suite completa: 1015 en verde.

- [x] **T5. Turno activo, comprobación al confirmar y estado de la pantalla.** RF-26, RF-29, RF-30, RF-33 a RF-37, RF-39, RF-49
  - Tests: `test/features/booking/logic/booking_rules_test.dart`, en tabla:
    - `activeAppointment` cuenta el turno en curso, y no cuenta uno pasado que sigue esperando confirmación ni uno cancelado;
    - `checkBeforeSave` devuelve `alreadyActive`, `slotTaken` (ocupada o pasada), `doesNotFit` u `ok`;
    - `bookingScreen` sigue su orden: cargando → sin sesión → error → admin → turno activo (con bloqueo o sin él) → bloqueada → reserva.
  - Hecho cuando: `booking_rules.dart` pasa los tests sin importar Flutter ni Firebase.
  - Hecha (2026-11-03):
    - `booking_rules.dart`:
      - `activeAppointment`: el turno que empieza antes entre los que terminan después de "ahora" y están activos; también en curso;
      - `checkBeforeSave` y `BookingCheck` (`ok`, `alreadyActive`, `slotTaken`, `doesNotFit`);
      - `bookingScreen` y la clase sellada `BookingScreen` (`Loading`, `SignedOut`, `Error`, `Admin`, `Active` con `isBlocked`, `Blocked` y `Booking`);
    - las funciones son genéricas sobre el tipo de turno y lo leen con `times` (`AppointmentTimes`: inicio, fin y estado). `AppointmentModel` importa todavía `cloud_firestore` (lo quita T6), y así la lógica no depende de él. T8 les pasa `AppointmentModel`;
    - dos detalles del orden de `bookingScreen`:
      - un error de la ficha va antes que "sin sesión": con la ficha en error no se sabe si hay sesión, y "Reintentar" es lo seguro;
      - la admin no espera a sus turnos;
    - `checkBeforeSave` comprueba primero el turno activo, después la hora libre y por último si cabe;
    - imports: solo `calendar_settings_model.dart`, `free_slots.dart` y `salon_time.dart`;
    - 27 tests;
    - suite completa: 1043 en verde.

- [ ] **T6. Modelos y repositorios.** RF-6, RF-27, RF-28, RF-31, RF-51, RF-56
  - Tests:
    - `test/data/models/appointment_model_test.dart`: ida y vuelta con `booked`, un turno sin `booked`, y `DateTime` en `fromMap`/`toMap`;
    - `test/data/models/busy_slot_model_test.dart`.
  - Código:
    - `AppointmentModel` sin `cloud_firestore`;
    - `BusySlot`;
    - en `BookingRepository`:
      - `watchBusySlots`;
      - `createAppointment` en lote con su turno ocupado y un límite de 15 s;
      - `fetchBookingCheck` leído del servidor;
      - `updateAppointmentStatus('cancelled')` en lote, borrando el turno ocupado;
      - la conversión `Timestamp` ↔ `DateTime`;
    - `UserRepository.watchUser`.
    - Los repositorios no tienen tests propios, como en la 004: no hay un Firestore falso. Se prueban a través de los fakes y en el recorrido manual.
  - Hecho cuando: los tests de los modelos pasan, `grep cloud_firestore lib/data/models` no encuentra nada y `flutter analyze` está limpio.

- [ ] **T7. La ficha de la usuaria en vivo.** RF-38, RF-58
  - Tests:
    - `test/features/auth/current_user_live_test.dart`: un cambio de `isBlocked` o de `role` en la ficha llega a `currentUserProvider` sin invalidarlo;
    - la ficha nueva tras el primer inicio de sesión llega sola (`new_user_profile_test` sigue en verde).
  - Código:
    - `currentUserProvider` pasa a `StreamProvider` sobre `watchUser`;
    - se adaptan `fake_session.sessionOverrides`, `pump_web_app` y los tests que lo sobreescriben (`error_messages_test`, `screens_theme_test`, `new_user_profile_test` y los de reserva).
  - Hecho cuando: toda la suite pasa sin más cambios de comportamiento y las redirecciones siguen esperando con `isLoading`.

- [ ] **T8. Providers de lectura y fakes.** RF-1, RF-5, RF-6, RF-9, RF-33, RF-35, RF-43, RF-47 a RF-49
  - Tests: `test/features/booking/booking_providers_test.dart` (`ProviderContainer`):
    - `busySlotsProvider` pide la ventana de hoy y se actualiza al cambiar los datos;
    - `bookableCatalogProvider` refleja la carga, el error y los datos de la lista de precios;
    - `myAppointmentsProvider`;
    - `bookingScreenProvider` cambia al terminar el turno activo, cuando avanza `salonNowProvider`;
    - `deviceUtcOffsetProvider` se puede sustituir.
  - Código:
    - `clockProvider`, `salonNowProvider` (cada 30 s), `deviceUtcOffsetProvider`, `busySlotsProvider`, `bookableCatalogProvider`, `myAppointmentsProvider` y `bookingScreenProvider`;
    - Perfil pasa de `clientAppointmentsProvider` a `myAppointmentsProvider`;
    - `test/helpers/fake_booking.dart` (`FakeBookingRepository` con `StreamController`, comprobación previa y errores programables) y `bookingOverrides` nuevo.
  - Hecho cuando: los tests pasan y Perfil sigue mostrando los turnos (`profile_dates_test`, `web_profile_test`).

- [ ] **T9. Controladores de lo elegido y del guardado.** RF-1, RF-8, RF-9, RF-12 a RF-21, RF-26 a RF-31, RF-36, RF-40, RF-43, RF-44
  - Tests: `test/features/booking/booking_controllers_test.dart`:
    - `BookingSelectionController`:
      - empieza con el día de `initialDay`;
      - aplica `reconcile` cuando cambian los turnos ocupados, la lista de precios, los ajustes o "ahora", y guarda los avisos;
      - con la lista cargando, `requestItem` espera y se aplica al llegar;
      - un id que no existe avisa;
      - lo elegido se conserva al volver a leer el provider.
    - `bookingSubmitProvider`:
      - con `ok`, guarda la copia correcta, inicio + duración y `waiting_confirmation`;
      - devuelve `slotTaken`, `doesNotFit` y `alreadyActive` sin guardar;
      - `failed` si la comprobación previa o el guardado fallan, o si se agota el tiempo.
  - Hecho cuando: los tests pasan con los fakes de T8.

## Bloque B — Vista de reserva y rutas

- [ ] **T10. Textos nuevos.** RNF-4, RC-1
  - Tests: `test/features/booking/booking_texts_test.dart`:
    - las claves de § 6 del plan existen en ES y en PT;
    - en PT se usa "horário" y en ES, "la confirmación de Beidis".
  - Código: las claves de § 6 del plan en `app_es.arb` y `app_pt.arb`, añadidas al final como texto, y `flutter gen-l10n`.
  - Hecho cuando: `lib/l10n/` está regenerado y los tests pasan.

- [ ] **T11. Estados de la pantalla de reserva.** RF-33, RF-34, RF-37 a RF-39, RF-46, RF-49
  - Tests: `test/features/booking/booking_screen_states_test.dart` (`pumpApp`):
    - un turno activo, con lo reservado, los adicionales, las horas, el total, el estado y el texto de "solo uno";
    - el turno desaparece al cancelarse o al terminar;
    - una bloqueada sin turno ve su aviso con WhatsApp, y con turno ve las dos cosas;
    - el bloqueo con la sesión abierta cambia la vista sin cerrar la sesión;
    - la admin ve su texto;
    - el error de la ficha o de los turnos muestra "Reintentar", que vuelve a cargar.
  - Código:
    - `BookingView` con un `switch (bookingScreen)`;
    - `ActiveAppointmentView`, `BookingBlockedNotice`, `BookingAdminNotice` y `BookingLoadErrorNotice`;
    - `_Notice` pasa a ser `AppNotice` público (refactor).
    - Lo que no es un estado de pantalla sigue mostrando la vista actual hasta T12.
  - Hecho cuando: los tests pasan y los de spec 003 (`mobile_booking_sign_in_test`) siguen en verde.

- [ ] **T12. Calendario y horas.** RF-1 a RF-9, RF-15, RF-48
  - Tests: `test/features/booking/booking_form_slots_test.dart`:
    - abre en el día inicial;
    - sin días que se puedan elegir, muestra el texto y WhatsApp;
    - los días cerrados y bloqueados no se pueden elegir;
    - las horas libres llevan "Horas de Curitiba" en otra zona y no lo llevan en −3 h;
    - las horas cambian en vivo al ocuparse una;
    - sin horas, muestra su texto;
    - cambiar de fecha quita la hora;
    - una hora que se ocupa se quita y avisa;
    - con un servicio elegido, las horas que no alcanzan se ven desactivadas y avisan;
    - con un error, el aviso con "Reintentar".
  - Código:
    - `BookingForm`;
    - `BookingCalendar`, con la conversión del día del salón para `TableCalendar`;
    - `SlotGrid`, con un `Wrap` en lugar de la rejilla de 3 columnas;
    - los avisos de la selección se muestran en un `SnackBar` que traduce en su `build` y se anuncian al lector de pantalla.
  - Hecho cuando: los tests pasan y `localized_dates_test` está adaptado y en verde.

- [ ] **T13. Servicios, adicionales, resumen y "Agendar turno".** RF-10 a RF-14, RF-16 a RF-25, RF-47
  - Tests: `test/features/booking/booking_form_services_test.dart`:
    - los servicios aparecen agrupados por categoría y en orden, y después los combos, con precio y duración;
    - con una hora elegida, los que no caben se ven desactivados y avisan con su duración;
    - sin hora, todos se pueden elegir;
    - los adicionales del servicio elegido aparecen sin marcar, y un combo no tiene;
    - cambiar de servicio desmarca los adicionales;
    - un servicio que se oculta se quita y avisa;
    - el resumen aparece con una hora o con un servicio, con el total y "desde";
    - "Agendar turno" sin algo elegido marca lo que falta;
    - con todo elegido, abre el diálogo con el resumen y "esperando la confirmación de Beidis";
    - con la lista de precios no disponible, su aviso.
  - Código: `ServicePicker`, `AddonPicker`, `BookingSummary`, `BookButton` y el diálogo de confirmación. Se borran los chips fijos de la vista.
  - Hecho cuando: los tests pasan.

- [ ] **T14. Guardar el turno.** RF-26 a RF-32, RF-36, RF-50
  - Tests: `test/features/booking/booking_submit_flow_test.dart` y `booking_locale_test.dart`:
    - al confirmar, se guarda y en Android/iOS sale el aviso de éxito;
    - en Web sale el diálogo con "Volver al inicio";
    - después, la vista muestra el turno activo;
    - con `slotTaken` y `doesNotFit`, se quita la hora, se conservan lo reservado y la fecha, y se avisa con su texto;
    - con `alreadyActive`, se avisa y se ve el turno que ya tiene;
    - con un error, el aviso sin detalles técnicos, y lo elegido se conserva;
    - al cambiar de idioma con un aviso o el diálogo abiertos, cambian de idioma.
  - Hecho cuando: los tests pasan y `web_booking_flow_test` está adaptado y en verde.

- [ ] **T15. Reservar desde el detalle y direcciones.** RF-40 a RF-46
  - Tests:
    - `test/core/router/redirect_logic_test.dart`, casos nuevos:
      - `next` con `service`/`combo` se conserva al pedir el inicio de sesión y el WhatsApp;
      - un id no válido, otras claves o dos claves → `/booking` sin query.
    - `test/features/booking/booking_from_detail_test.dart` (`pumpWebApp` y `pumpMobileApp`):
      - desde el detalle con sesión, el servicio queda elegido, sin adicionales, conservando la fecha y la hora si cabe;
      - sin sesión y sin WhatsApp, vuelve con el servicio elegido (Web y Android/iOS);
      - con la lista cargando, espera;
      - un id inexistente avisa;
      - los otros "Reservar cita" conservan lo elegido;
      - Web abre directamente `/booking?service=…`;
      - con un turno activo, se ve el turno.
  - Código:
    - `_withNext` y `safeNext` (`redirect_logic.dart`);
    - las rutas `/booking` leen la query;
    - `requestItem` se llama en el fotograma siguiente;
    - `_ReserveButton` del detalle.
  - Hecho cuando: los tests pasan y los tests de rutas de las specs 002 y 003 siguen en verde.

## Bloque C — Admin, reglas y cierre

- [ ] **T16. Lo reservado en la lista de la admin y la cancelación.** RF-52, RF-56
  - Tests: `test/features/admin/admin_appointments_booked_test.dart`:
    - la tarjeta muestra lo reservado y los adicionales en el idioma activo;
    - un turno sin `booked` no muestra esa línea;
    - "Cancelar" llama a la cancelación que libera la hora (fake).
  - Hecho cuando: los tests pasan.

- [ ] **T17. Accesibilidad, texto grande y limpieza.** RNF-2, RNF-3, RF-58
  - Tests:
    - `test/features/booking/booking_accessibility_test.dart`:
      - `textContrastGuideline`, `androidTapTargetGuideline` y `labeledTapTargetGuideline` en tema claro y oscuro;
      - semántica de lo elegido y de "no disponible";
      - los avisos se anuncian;
      - texto al 200 % y 320 px en ES y PT sin desbordes.
    - `legacy_cleanup_test.dart`: ya no existen los chips fijos, `availableSlotsProvider`, `selectedDateProvider`, `appointmentsForDateProvider`, `getActiveAppointmentsForDate` ni sus claves `.arb` (se comprueba antes con `grep -w`).
  - Hecho cuando: los tests pasan, se borra lo antiguo y `no_hardcoded_style_test` sigue en verde.

- [ ] **T18. Reglas, índice y comprobación manual.** RF-53 a RF-58, RNF-5
  - Tests: `test/core/firestore_rules_test.dart`:
    - estructura de los `match` de `users`, `appointments` y `busySlots` según § 2 del plan;
    - `firebase.json` apunta a `firestore.indexes.json`;
    - el índice de "mis turnos" está declarado.
  - Código:
    - `firestore.rules`;
    - `firestore.indexes.json`;
    - `firebase.json`;
    - los comentarios "spec 009" → "spec 012" en `firestore.rules`, `redirect_logic.dart` y `firestore_rules_test.dart`;
    - `specs/005-reservas/rules-check.md`, con los casos del simulador, el borrado de la base de datos antes de publicar (RF-51) y el recorrido de RF-58.
  - Hecho cuando: los tests pasan y el autor confirma los casos del simulador y el recorrido manual (criterios de finalización).

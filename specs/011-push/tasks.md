# Tareas 011 — Avisos push a la admin
Estado: aprobada

Spec: `specs/011-push/spec.md` · Plan: `specs/011-push/plan.md` (aprobados el 2026-11-20).

Cada tarea: tests primero (rojo), luego el código (verde). En Flutter: `dart format lib test` sin cambios, `flutter analyze` sin avisos y `flutter test` en verde; tras cambiar un `.arb`, `flutter gen-l10n`. En `functions/`: `npm test` en verde y `npm run build` sin errores. Nunca Firebase real en los tests.

- [x] **T1. Servidor: qué aviso y qué dice** (`functions/src/appointment_notice.ts`, plan D-2, D-4, D-6, § 4). RF-1 a RF-5, RF-7 a RF-11, RNF-4
  - Tests: `functions/test/appointment_notice.test.ts`:
    - `noticeKind` en cada fila de la tabla de D-2: crea la clienta, la admin o una persona sin cuenta; la clienta edita la hora, el servicio o solo los adicionales; la admin edita, confirma o cancela; bloqueo; la clienta cancela (también un turno agendado por la admin); borrado de cuenta con turno activo; turno pasado marcado `accountDeleted`; WhatsApp copiado; turno borrado;
    - `noticeText` de los tres tipos: sin servicio, con la cuenta borrada, sin nombre ("Una clienta"), a las 22:30 de Curitiba (otro día en UTC), nombres de días y meses en español, y nunca el WhatsApp ni la foto;
    - `salonDay`, `uniqueFids` (orden estable) y `noticeTag` (estable, 32 caracteres).
  - Hecho cuando: el archivo no importa Firebase, los tests pasan y `npm run build` compila.

- [x] **T2. Servidor: envío, limpieza y disparador** (`notify_admins.ts`, `notice_store.ts`, `index.ts`, plan D-3, D-5). RF-5, RF-6, RF-12, RF-19, RF-21, RF-22, RF-24
  - Tests: `functions/test/notify_admins.test.ts`, con un almacén en memoria:
    - sin tipo, no envía; sin dispositivos, no envía ni falla;
    - un FID repetido se envía una vez; dos admins con varios dispositivos;
    - los FID no registrados o inválidos se borran de cada dueña, y los demás errores no;
    - el mensaje lleva `kind`, `appointmentId`, `day` y la etiqueta;
    - si `send` lanza, el adaptador lo registra y no relanza.
  - Hecho cuando:
    - `index.ts` exporta `notifyAdminsOnAppointmentWrite` (`onDocumentWritten`, sin reintentos);
    - `notice_store.ts` lee los dispositivos de `role == 'admin'` y envía con `sendEach`, `tag` y `apns-collapse-id`;
    - `README.md` y `package.json` describen la función, la región que hay que mirar en la consola y la clave APNs pendiente;
    - `npm test` y `npm run build` pasan.

- [x] **T3. App: lógica pura y modelo del aviso** (`admin/logic/push_notices.dart`, `data/models/push_notice.dart`, plan § 4). RF-12, RF-15 a RF-18
  - Tests: `test/features/admin/push_notices_logic_test.dart`:
    - `shouldExplainPush`, `shouldRegisterDevice` y `showPushDisabled` con Web, visitante, clienta y admin, con cada `PushPermission`;
    - `shouldRetryUnregister` con y sin marca, y con admin, clienta o sin sesión;
    - `noticeDay`: válido (como día del salón), con formato roto, con fecha imposible o sin `day`.
  - Hecho cuando: los dos archivos no importan Flutter ni Firebase y los tests pasan.

- [x] **T4. Repositorio de push y fake** (plan D-1, D-8, D-11, D-13). RF-16, RF-19, RF-25
  - **`PushRepository`:** recibe `FirebaseMessaging?`, `FirebaseFirestore?` y `SharedPreferences?`. Hace lo del plan § 5: permiso con la marca "ya preguntado", `register`/`onRegistered`/`unregister` con el FID (plan D-15), `registerDevice`/`unregisterDevice` en `users/{uid}/pushDevices/{fid}`, marca "baja pendiente" y avisos como `PushNotice`.
  - **Cambio del plan D-15 en T1, T2 y T3:** `uniqueTokens` → `uniqueFids`, `token` → `fid` en el almacén y en el envío, y `shouldRevokeToken` → `shouldRetryUnregister`, con sus tests.
  - **`FakePushRepository`** (`test/helpers/fake_push.dart`): registra las llamadas, puede fallar o tardar, emite avisos a mano y empieza en `granted`.
  - **Helpers:** `pumpApp`, `pumpWebApp` y `pumpMobileApp` lo ponen por defecto.
  - **`fcmToken`:** se borra `UserRepository.updateFcmToken` y `UserModel.toMap` deja de escribir `fcmToken`; se sigue leyendo.
  - Tests:
    - `test/data/push_repository_prefs_test.dart`: las marcas "ya preguntado" y "pendiente de anular" con un almacenamiento en memoria, y sin almacenamiento (no lanza);
    - en `test/data/models/user_model_test.dart` (nuevo), que `toMap` no escribe `fcmToken` y `fromMap` lo sigue leyendo.
  - Hecho cuando: nadie usa `updateFcmToken` y toda la suite sigue en verde con el fake por defecto.

- [x] **T5. Controlador y cierre de sesión** (`providers/admin_push_provider.dart`, `auth_provider.dart`, plan D-7, § 6). RF-16, RF-18 a RF-21, RF-25
  - Tests:
    - **`test/features/admin/admin_push_controller_test.dart`**, con un `ProviderContainer`:
      - con admin y `granted`, registra el FID y guarda la dueña;
      - con clienta, visitante o Web, no toca el repositorio;
      - vuelve a registrar cuando `onRegistered` trae otro FID y con `sync()` al volver a primer plano;
      - un fallo al registrar no sale y se reintenta;
      - `unregister` borra y anula; si falla, deja la marca, y el siguiente `start()` sin admin anula y la quita.
    - **`test/features/auth/sign_out_push_test.dart`:**
      - cerrar sesión llama a `unregister` antes que a `AuthRepository.signOut`;
      - con `unregister` fallando o tardando más de 5 s, la sesión se cierra igual.
  - Hecho cuando: existen `pushRepositoryProvider`, `pushPermissionProvider` y `adminPushControllerProvider`, `AuthController.signOut` anula antes de cerrar, y los tests pasan.

- [x] **T6. Puerta y explicación del permiso** (`admin_push_gate.dart`, `admin_push_dialog.dart`, `main.dart`, plan D-8, § 6). RF-15, RF-16
  - Tests: `test/features/admin/admin_push_gate_test.dart`, con `pumpMobileApp` y `pumpWebApp`:
    - una admin con `notAsked` ve la explicación, que no se cierra tocando fuera;
    - "Continuar" pide el permiso, y la explicación no vuelve a salir;
    - con una clienta, con `granted`, con `denied` o en Web, no sale;
    - ES y PT, y cambia de idioma con el diálogo abierto.
  - Hecho cuando:
    - `AdminPushGate` está en el `builder` de `MaterialApp.router` y en Web devuelve el hijo sin más;
    - `start()` se llama una vez;
    - las claves `adminPushExplainTitle`, `adminPushExplainBody` y `adminPushExplainContinue` están en los dos `.arb`;
    - los tests pasan.

- [x] **T7. Avisos en primer plano y al tocarlos** (plan D-9, D-10). RF-12 a RF-14
  - Tests: en `admin_push_gate_test.dart`:
    - un aviso con la app abierta muestra un `SnackBar` con el título, el texto y "Ver", sobre cualquier pantalla, y no interrumpe ni navega;
    - "Ver" abre `/admin` en el día del aviso;
    - `initialNotice` (app cerrada) y `onNoticeOpened` (en segundo plano) abren la agenda de ese día, también cuando la sesión aún está cargando;
    - con la agenda ya arriba, solo cambia el día;
    - con la sesión de una clienta o sin sesión, no navega ni muestra nada;
    - un `day` inválido no navega;
    - ES y PT.
  - Hecho cuando:
    - `appScaffoldMessengerKey` está en `MaterialApp.router`;
    - existe `AdminPushController.open`;
    - las claves `adminPushView` y `adminPushViewLabel` están en los dos `.arb`;
    - los tests pasan.

- [x] **T8. Permiso denegado en el panel** (`admin_dashboard_view.dart`, plan D-8, § 6). RF-17, RF-18
  - Tests: `test/features/admin/admin_push_disabled_test.dart`:
    - con `denied`, el aviso sale arriba de la agenda, se lee como una frase y no vuelve a pedir el permiso;
    - no sale con `granted`, `notAsked` ni en Web;
    - al volver a primer plano con el permiso activado, desaparece y se registra el dispositivo;
    - ES y PT.
  - Hecho cuando: las claves `adminPushDisabledTitle` y `adminPushDisabledBody` están en los dos `.arb` y los tests pasan.

- [x] **T9. Accesibilidad y textos** (plan § 8 y § 9). RNF-1 a RNF-3, RC-1
  - Tests:
    - **`test/features/admin/admin_push_accessibility_test.dart`**, en claro y oscuro:
      - contraste de la explicación (`expectDialogTextContrast`), del aviso de permiso denegado y del `SnackBar`;
      - "Continuar" y "Ver" de al menos 48 px y con su nombre;
      - el `SnackBar` se anuncia al lector;
      - con el texto al 200 % en 320 px, en ES y PT, nada se desborda.
    - **`test/features/admin/admin_push_texts_test.dart`:** las 7 claves del plan § 8 están en los dos `.arb`.
  - Hecho cuando: los tests pasan, con los ajustes de estilo que hagan falta, y toda la suite está en verde.

- [ ] **T10. Reglas, Android, iOS y documentos** (plan D-12, D-14, § 3). RF-6, RF-22, RF-23, RNF-5
  - **`firestore.rules`:** el `match` de `pushDevices` del plan § 3, con su comentario.
  - **`specs/011-push/rules-check.md`:** los 11 casos del simulador y el recorrido real del plan § 9: tiempo de llegada (RF-6), exadmin (RF-22), dos dispositivos, cerrar sesión con y sin conexión, permiso denegado y activado, lo que hace la admin no avisa, icono y canal.
  - **Android:**
    - `ic_notification` monocromo a partir del sello;
    - `default_notification_icon` y `default_notification_color` en el manifiesto;
    - `fcm_fallback_notification_channel_label` en `values` y `values-pt`.
  - **iOS:** `Runner.entitlements` con `aps-environment`, `UIBackgroundModes: remote-notification` y el proyecto enlazado.
  - **Documentos:** `CLAUDE.md` (push implementado), `docs/ESPECIFICACION.md` (modelo de datos: dispositivos de la admin) y `MEMORY.md`.
  - Tests: ninguno nuevo; es configuración y documentación.
  - Hecho cuando:
    - `flutter build apk --debug` compila;
    - `npm test` y toda la suite de Flutter están en verde;
    - `flutter analyze` está limpio;
    - existe `rules-check.md`;
    - los documentos están al día.

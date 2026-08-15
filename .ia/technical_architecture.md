# Arquitectura Técnica: App D'Shaddai

Este documento especifica las decisiones técnicas, herramientas, esquemas de bases de datos y la gestión de estados que se utilizarán para el desarrollo de la aplicación móvil D'Shaddai.

## 1. Stack Tecnológico

*   **Frontend:** Flutter SDK (Dart).
*   **Backend:** Firebase (Auth, Cloud Firestore, Cloud Functions, Cloud Messaging).

## 2. Herramientas y Paquetes Principales

*   `firebase_core`, `firebase_auth`, `cloud_firestore`: Integración oficial de datos.
*   `firebase_messaging`: Para enviar y recibir notificaciones push en el dispositivo.
*   `google_sign_in`: Para la validación del acceso con la cuenta de Google (incluye captura de la `photoUrl`).
*   `flutter_riverpod`: Manejo del Estado.
*   `go_router`: Enrutamiento protegido por roles.
*   `table_calendar`: Componente visual para reservas.
*   `intl` y `flutter_localizations`: Para soportar el formato de fechas y la traducción completa de la app (Portugués y Español) basándose automáticamente en el idioma del Sistema Operativo.

## 3. Esquema de Base de Datos (Cloud Firestore)

### Colección: `users`
Guarda el perfil de clientes y administradores.

```json
{
  "uid": "12345abcde...",
  "email": "cliente@gmail.com",
  "displayName": "Nombre Apellido",
  "photoUrl": "https://lh3.googleusercontent.com/a/...",
  "phoneNumber": "+1234567890",
  "role": "cliente", // o "admin"
  "isBlocked": false,
  "fcmToken": "token_dispositivo_para_notificaciones" // Guardado para TODO usuario (Admin y Clientes)
}
```

### Colección: `appointments` (Turnos)

```json
{
  "id": "autogenerado",
  "clientId": "12345abcde...",
  "clientName": "Nombre Apellido",
  "clientPhone": "+1234567890",
  "clientPhotoUrl": "https://...",
  "startTime": "2026-08-15T09:00:00Z",
  "endTime": "2026-08-15T10:00:00Z",
  "status": "waiting_confirmation", // 'waiting_confirmation', 'confirmed', 'cancelled'
  "createdAt": "2026-08-14T15:00:00Z"
}
```

### Colección: `settings` -> Documento: `calendar`

```json
{
  "openingHours": {
    "monday": { "open": "09:00", "close": "18:00", "isClosed": false },
    // ...
  },
  "globalSlotDurationMinutes": 60,
  "blockedDates": ["2026-12-25"]
}
```

## 4. Reglas de Seguridad (Firebase Security Rules)

Implementaremos reglas estrictas en Firestore:
*   `users`: Un cliente solo puede editar su propio documento si `isBlocked == false`. El admin puede editar a todos.
*   `appointments`: Un cliente solo puede crear un turno si su perfil tiene `isBlocked == false`.
*   `settings/calendar`: Lectura pública, escritura solo por admin.

## 5. Arquitectura de Notificaciones Push (Cloud Functions)
La app capturará el token de notificaciones de todos los usuarios.
El flujo base será:
1. El cliente crea un turno.
2. Cloud Function detecta la creación (`onDocumentCreated`).
3. Busca a los usuarios con `role == 'admin'`, extrae sus tokens y envía la notificación ("Nueva Cita Agendada").
4. A futuro: El backend podrá usar los `fcmToken` de los usuarios con `role == 'cliente'` para despachar campañas de marketing, descuentos y promociones.

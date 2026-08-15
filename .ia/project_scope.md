# Scope del Proyecto: App de Reservas D'Shaddai

## Descripción General
Creación de una aplicación móvil multiplataforma desarrollada en Flutter para el salón de belleza "D'Shaddai · Nail Designer · Beidis Viera". La aplicación servirá como plataforma principal para mostrar la información del salón y permitir la autogestión de reserva de turnos por parte de las clientas. El backend estará soportado íntegramente por Firebase.

## Idiomas (Internacionalización)
La aplicación será bilingüe y soportará los siguientes idiomas:
- **Portugués**
- **Español**
El sistema detectará automáticamente el idioma configurado en el sistema operativo (SO) del teléfono de la clienta y mostrará la interfaz en ese idioma por defecto.

## Diseño Visual
La aplicación utilizará la paleta de colores de la web oficial (https://dshaddai.com/):
- Tonos hueso (`#F5F1E8`), Blanco (`#FAFAF8`), Negro (`#1A1A1A`), Verde oscuro (`#2E3D28`), Dorado (`#C7A86D`), Verde oliva (`#7A8264`)

## Perfiles de Usuario
La aplicación soportará dos tipos de roles con permisos y vistas distintas. Los roles se manejan directamente desde Firebase Firestore.

1. **Cliente:**
   * Visualiza la información principal del salón.
   * Se autentica mediante su cuenta de Google (Google Sign-In) al intentar reservar. Se captura su **Nombre, Correo y Foto de Perfil** (para mostrar en la app y en notificaciones).
   * **Contacto Obligatorio:** En su primer inicio de sesión, deberá proveer su número de WhatsApp. *"Tu número se usará para mantener contacto directo con la manicuri por WhatsApp..."*
   * **Notificaciones Push:** Se capturará y guardará el token de su dispositivo para habilitar, en un futuro, el envío de notificaciones con descuentos, promociones o recordatorios.
   * Accede al calendario para reservar turnos basados en la disponibilidad. El turno inicialmente quedará en estado *"Esperando Confirmación"*.
   * Si una clienta es bloqueada por el administrador, no podrá agendar nuevos turnos.

2. **Administrador (Admin):**
   * Configurado inicialmente fijando el correo en Firestore con el rol `admin`.
   * **Configuración del Calendario:** Puede definir los días de apertura, horarios de atención y la duración global de los turnos.
   * **Gestión de Usuarios:** Puede bloquear a clientas maliciosas para evitar que agenden turnos.
   * **Notificaciones Push:** Recibe una notificación en tiempo real cuando una cliente agenda un turno (ej. *"Cita nueva agendada, cliente Ana Herrera"*), incluyendo la foto de la clienta.
   * Calendario general con la programación completa, permitiendo confirmar, cancelar o contactar por WhatsApp.

## Características del MVP (Producto Mínimo Viable)

* **Pantalla Principal (Home):** Interfaz basada en la web oficial. Botón destacado para "Reservar Turno".
* **Autenticación y Perfil:** Firebase Auth (Google Sign-In). Captura de WhatsApp, Foto de Perfil y Token de notificaciones.
* **Módulo de Reservas (Clientes):** Interfaz de calendario. Lógica de disponibilidad calculada dinámicamente. Creación de cita en estado "Esperando Confirmación".
* **Panel de Control (Admin):**
  * Gestión de horarios.
  * Botón para bloquear usuarios problemáticos.
  * Calendario de reservas y datos de contacto de las clientas.
* **Infraestructura Backend (Firebase):**
  * **Firebase Authentication:** Gestión de acceso.
  * **Cloud Firestore:** Base de datos para `usuarios`, `turnos` y `configuracion`.
  * **Firebase Cloud Messaging (FCM):** Envío y recepción de notificaciones push tanto en dispositivos de administradores como de clientes.
  * **Cloud Functions:** Scripts en el backend para disparar las notificaciones push de forma automática y segura.

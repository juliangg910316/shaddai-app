# Especificación funcional — Studio Shaddai

*Versión inicial: 2026-10-20*

> Visión global del producto. Los requisitos de cada funcionalidad (RF en EARS, navegación, casos límite y criterios de finalización) viven en las specs numeradas de `specs/` (sección 8). Aquí solo están los **requisitos comunes**, que aplican a todas (sección 7). Los principios innegociables están en `docs/constitution.md`, y la arquitectura en `CLAUDE.md`.

## 1. Descripción

**Studio Shaddai** es una aplicación Flutter para Android, iOS y Web del salón de uñas **Studio Shaddai · Nail Designer · Beidis Viera** (Capão da Imbuia, Curitiba). Las clientas ven la información del salón (servicios, precios, catálogo, galería y contacto) y **reservan turnos** según la disponibilidad que configura la administradora. La administradora confirma o cancela turnos, contacta por WhatsApp, configura el calendario y bloquea clientas problemáticas. El backend es Firebase.

### Objetivos
- Un solo código base para Android, iOS y Web.
- Reserva de turnos por las propias clientas, sin intermediarios.
- Aviso inmediato a la administradora de cada cita nueva.
- Publicación en Google Play y App Store, y web en dshaddai.com.

## 2. Decisiones

| Tema | Decisión |
| --- | --- |
| Nombre | Studio Shaddai |
| Plataformas | Android, iOS y Web, con las mismas funciones |
| Interfaz por plataforma | Web: landing de una página donde el scroll es la estructura principal. Android/iOS: barra de navegación inferior |
| Diseño | El de la web: tema claro y oscuro (oscuro por defecto), Cormorant Garamond para títulos e Inter para la interfaz |
| Idiomas | Español y portugués, con selector manual que se recuerda; sin preferencia, el del dispositivo (por defecto español) |
| Acceso | Información pública sin sesión; para reservar, inicio de sesión con Google y WhatsApp obligatorio |
| Servicios y precios | Guardados en Firestore |
| Hosting web | Hostinger, dominio dshaddai.com |
| Backend | Firebase (Auth, Firestore, Cloud Messaging, Cloud Functions) |
| Publicación | En tiendas; fecha sin definir. Aún no hay cuentas de desarrollador ni política de privacidad |
| Navegación | Cada spec define la suya |

## 3. Roles

- **Visitante**: sin sesión. Ve la información pública.
- **Cliente**: con sesión de Google y WhatsApp registrado. Reserva turnos y ve los suyos. Si está bloqueada, no puede reservar.
- **Admin**: rol asignado a mano en Firestore. Configura el calendario, gestiona turnos y bloquea clientas. Recibe un aviso push con cada cita nueva.

## 4. Modelo de datos (actual)

- **Usuaria**: correo, nombre, foto, WhatsApp, rol (`cliente` | `admin`), bloqueada (sí/no), token de notificaciones.
- **Turno**: clienta (id, nombre, teléfono, foto), inicio, fin, estado (`waiting_confirmation` | `confirmed` | `cancelled`) y fecha de creación.
- **Calendario**: horario de cada día de la semana (apertura, cierre, cerrado), duración global del turno y fechas bloqueadas.
- **Servicio**: nuevo en Firestore; sus campos se definen en su spec.

## 5. Glosario

| Término | Significado |
| --- | --- |
| Turno / cita | Reserva de una clienta para una fecha y hora |
| Hueco libre | Hora de inicio posible según el calendario y los turnos existentes |
| Esperando confirmación | Estado inicial de un turno hasta que la admin lo confirma o lo cancela |
| Clienta bloqueada | Clienta a la que la admin ha impedido reservar |
| Landing | Página única de la web con toda la información del salón |

## 6. Alcance

**Dentro (v1):** landing/inicio, servicios y precios, inicio de sesión con Google y captura de WhatsApp, reserva de turnos, perfil con mis turnos, panel admin (turnos, usuarias y calendario), aviso push a la admin, tema claro/oscuro y ES/PT.

**Fuera (v1):** campañas push a clientas (descuentos, promociones, recordatorios).

## 7. Requisitos comunes

> [!NOTE]
> Propuesta derivada de las decisiones de la sección 2. Pendiente de revisión del autor.

- **RC-1**: EL SISTEMA muestra todos los textos de la interfaz en español o en portugués, incluidos los textos propios de Flutter (fechas, diálogos, botones del sistema).
- **RC-2**: EL SISTEMA ofrece tema claro y oscuro, usa el oscuro si la persona no ha elegido ninguno y recuerda su elección.
- **RC-3**: EL SISTEMA recuerda el idioma elegido; sin elección, usa el del dispositivo si es español o portugués y, si no, español.
- **RC-4**: EL SISTEMA ofrece las mismas funciones en Android, iOS y Web; en Web la navegación es una página con scroll y en Android/iOS, una barra de navegación inferior.

## 8. Specs

Cada funcionalidad se define con `/sdd-spec NNN-nombre <idea>` y se lista aquí.

Mapa aprobado el 2026-10-20, en orden. Varias funcionalidades (reservas, perfil, admin) ya existen en el código: su plan parte de lo que hay.

| Spec | Nombre | Estado |
| --- | --- | --- |
| 001-design-system | Tema claro/oscuro, tipografía y selector de idioma | sin empezar |
| 002-landing-web | Landing de una página en Web | sin empezar |
| 003-navegacion-movil | Barra de navegación inferior en Android/iOS | sin empezar |
| 004-servicios-firestore | Servicios y precios en Firestore | sin empezar |
| 005-reservas | Reserva de turnos (rediseño y servicio del turno) | sin empezar |
| 006-perfil | Perfil y mis turnos | sin empezar |
| 007-admin | Panel de administración | sin empezar |
| 008-notificaciones-push | Aviso push a la admin con cada cita nueva | sin empezar |
| 009-reglas-seguridad | Reglas de seguridad de Firestore | sin empezar |
| 010-publicacion | Publicación en tiendas y web en Hostinger | sin empezar |

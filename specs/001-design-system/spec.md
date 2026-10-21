# Spec 001 — Design system: tema, tipografía e idioma
Estado: implementada

## Contexto y objetivo
La app y la web de Studio Shaddai se unifican en un solo producto. La web ya tiene la identidad visual de la marca (paleta de verde oscuro, dorado y crema; títulos en Cormorant Garamond y texto de interfaz en Inter; tema claro y oscuro) y un selector de idioma ES/PT. La app móvil usa colores y fuentes propios, sin tema oscuro ni selector de idioma.

El objetivo es que las tres plataformas compartan **una sola identidad visual** y que cualquier persona pueda **elegir tema e idioma**, y que esas elecciones se recuerden. Esta spec define la base visual y la aplica a las pantallas que ya existen. El rediseño de la maquetación de cada pantalla queda para su propia spec.

## Usuarios
- **Visitante** (sin sesión): ve la app con la identidad de la marca y puede cambiar el tema y el idioma.
- **Cliente** y **Admin**: igual que la visitante. Sus preferencias no dependen de la cuenta.

## Historias de usuario
- HU-1. Como visitante, quiero ver la app y la web con la misma identidad visual de la marca para reconocer el salón en cualquier plataforma.
- HU-2. Como visitante, quiero elegir tema claro, oscuro o el del sistema para leer cómodamente según la luz y mis gustos.
- HU-3. Como visitante, quiero elegir entre español y portugués para entender todo en mi idioma, aunque mi dispositivo esté en otro.
- HU-4. Como visitante, quiero que la app recuerde mis elecciones para no repetirlas cada vez que la abro.
- HU-5. Como admin, quiero que las pantallas de administración respeten el tema elegido para trabajar con una interfaz coherente.

## Definiciones
- **Preferencia de tema**: una de tres opciones: *claro*, *oscuro* o *sistema*. Con *sistema*, el tema sigue el modo claro/oscuro del dispositivo o del navegador.
- **Preferencia de idioma**: *español* o *portugués*, elegida a mano. Si no hay preferencia guardada, se usa el idioma del dispositivo si es español o portugués y, si no, español (RF-9).
- **Paleta de la marca**: los colores de la web actual. Son la referencia de RF-14:

  | Color | Valor | Uso principal |
  | --- | --- | --- |
  | Verde oscuro | `#2E3D28` | marca: barra inferior, botón principal, títulos en claro |
  | Dorado | `#C7A86D` | acento: adornos, líneas, iconos, texto en oscuro |
  | Dorado oscuro | `#856933` | texto dorado en claro |
  | Salvia | `#BFC8B3` | acento secundario |
  | Crema | `#F5F1E8` | fondo en claro, texto en oscuro |
  | Blanco roto | `#FAFAF8` | superficies en claro |
  | Negro cálido | `#17170F` / `#202018` | fondo y superficies en oscuro |
  | Tinta | `#201F18` | texto principal en claro |

  Si un color de la paleta no alcanza el contraste de RNF-1 en un uso como texto o icono, en ese uso se emplea una variante del mismo tono: más oscura en el tema claro y más clara en el oscuro. **RNF-1 prevalece sobre la paleta.**
- **Título**: el texto con función de encabezado (título de pantalla, de sección, de tarjeta o de diálogo) y las cifras destacadas (precios y horas). Todo lo demás es texto de interfaz.
- **Pantallas existentes**: inicio, servicios, inicio de sesión, captura de WhatsApp, reservas, perfil y las tres pantallas de administración (turnos, usuarias y calendario). Incluyen sus diálogos, avisos (snackbars), selectores de fecha y hora, y sus estados vacío, de carga y de error.
- **Excepciones de color**: elementos cuyo aspecto no controla la app y que mantienen sus propios colores:
  - las fotos;
  - el mapa de Google (que se ve claro también en el tema oscuro);
  - el botón de inicio de sesión de Google;
  - los logotipos de terceros (Google, WhatsApp).
- **Estado que se conserva**: al cambiar el tema o el idioma se mantienen:
  - la pantalla y la pestaña en que se está;
  - la posición del scroll;
  - el texto escrito;
  - los diálogos y selectores abiertos;
  - la fecha y la hora elegidas en una reserva a medias.

## Requisitos funcionales

### Tema
- RF-1: EL SISTEMA ofrece tres preferencias de tema: claro, oscuro y sistema.
- RF-2: SI no hay ninguna preferencia de tema guardada, ENTONCES EL SISTEMA usa la preferencia *sistema*.
- RF-3: MIENTRAS la preferencia de tema sea *sistema*, EL SISTEMA muestra el tema claro u oscuro según el modo del dispositivo o del navegador.
- RF-4: CUANDO el dispositivo o el navegador cambia de modo claro/oscuro con la app abierta y la preferencia es *sistema*, EL SISTEMA cambia al tema correspondiente sin reiniciar la app.
- RF-5: CUANDO la persona elige una preferencia de tema, EL SISTEMA aplica el tema resultante en la pantalla actual sin reiniciar la app y conservando el estado (ver *Estado que se conserva*).
- RF-6: CUANDO la persona elige una preferencia de tema, EL SISTEMA la guarda en ese dispositivo o navegador.
- RF-7: CUANDO se abre la app con una preferencia de tema guardada, EL SISTEMA muestra desde la primera pantalla de la app el tema que corresponde a esa preferencia.

### Idioma
- RF-8: EL SISTEMA ofrece dos idiomas: español y portugués.
- RF-9: SI no hay ninguna preferencia de idioma guardada, ENTONCES EL SISTEMA usa el idioma del dispositivo o del navegador si es español o portugués y, si no, español.
- RF-10: CUANDO la persona elige un idioma, EL SISTEMA muestra en ese idioma todos los textos de la interfaz, incluidos los propios del sistema (fechas, calendarios, diálogos y botones estándar), conservando el estado (ver *Estado que se conserva*).
- RF-11: CUANDO la persona elige un idioma, EL SISTEMA lo guarda en ese dispositivo o navegador.
- RF-12: CUANDO se abre la app con una preferencia de idioma guardada, EL SISTEMA usa ese idioma desde la primera pantalla de la app, aunque el dispositivo esté en otro.
- RF-20: CUANDO el dispositivo o el navegador cambia de idioma con la app abierta y no hay preferencia de idioma guardada, EL SISTEMA aplica de nuevo RF-9 sin reiniciar la app.
- RF-21: EL SISTEMA muestra las fechas con el formato propio del idioma activo (nombres de días y meses en ese idioma), los calendarios con la semana empezando en lunes y las horas en formato de 24 horas.
- RF-22: SI un servicio externo devuelve un error que se muestra a la persona en una pantalla existente, ENTONCES EL SISTEMA muestra un texto propio de la app en el idioma activo, en lugar del mensaje técnico del servicio.

### Identidad visual
- RF-13: EL SISTEMA muestra los títulos (ver *Título*) con Cormorant Garamond y el resto del texto de la interfaz con Inter.
- RF-14: EL SISTEMA usa en el tema claro y en el oscuro la paleta de la marca (ver *Paleta de la marca*), con las variantes que exija RNF-1.
- RF-15: EL SISTEMA aplica el tema elegido y las tipografías de la marca a todas las pantallas existentes, sin colores ni fuentes fuera del tema, salvo las *Excepciones de color*.
- RF-16: MIENTRAS esté activo cualquiera de los dos temas, EL SISTEMA muestra todos los textos e iconos de las pantallas existentes con el contraste de RNF-1 sobre su fondo.
- RF-23: MIENTRAS esté activo cualquiera de los dos temas, EL SISTEMA muestra en Android/iOS los iconos de la barra de estado y de la barra de navegación del sistema con un contraste de al menos 3:1 sobre el fondo que tienen detrás.

### Selectores y acceso a Preferencias
- RF-17: EL SISTEMA permite cambiar el tema y el idioma sin haber iniciado sesión.
- RF-18: EL SISTEMA muestra en el selector de tema cuál de las tres preferencias está activa.
- RF-19: EL SISTEMA muestra en el selector de idioma cuál de los dos idiomas está activo.
- RF-24: EL SISTEMA muestra la pestaña Perfil en la barra inferior con o sin sesión.
- RF-25: MIENTRAS no haya sesión, EL SISTEMA muestra en Perfil la sección Preferencias y un botón para iniciar sesión.
- RF-26: CUANDO la persona pulsa el botón de iniciar sesión de Perfil, EL SISTEMA abre la pantalla de inicio de sesión.
- RF-27: MIENTRAS no exista la landing de Web (spec 002), EL SISTEMA muestra en Web una barra superior con el selector de tema y el de idioma en las pantallas que tienen barra inferior.

## Requisitos no funcionales
- RNF-1: Contraste mínimo (WCAG 2.1 AA), en ambos temas.
  - Texto normal: al menos 4,5:1 sobre su fondo.
  - Texto grande e iconos: al menos 3:1. Texto grande es el de 24 px o más, o el de 18,66 px o más en negrita.
  - Las pistas y los textos de ejemplo de los campos cuentan como texto normal.
  - Quedan exentos los elementos deshabilitados y las *Excepciones de color*.
  - El texto sobre una foto lleva un fondo o velo con el que cumple el contraste.
- RNF-2: Un cambio de tema o de idioma (elegido por la persona o venido del sistema) se ve en el siguiente fotograma que pinta la app. En un dispositivo de gama media, eso son menos de 1 segundo.
- RNF-3: Las preferencias se guardan solo en el dispositivo o navegador: no se envían a Firebase ni se asocian a la cuenta.
- RNF-4: Accesibilidad de los selectores.
  - Tienen nombre accesible en el idioma activo.
  - La opción activa se anuncia como "seleccionada" y se distingue por algo más que el color (una marca, un relleno o un peso de letra distinto).
  - En Android/iOS, el área táctil es de al menos 48×48 px.
  - En Web se manejan con teclado: Tab para llegar, Intro o Espacio para elegir, Esc para cerrar el menú, y el foco siempre visible.
- RNF-5: Las tipografías de la marca van incluidas en la app: se ven sin conexión desde el primer arranque, sin descargarse de internet.
- RNF-6: Con el tamaño de texto del sistema hasta el 200 %, los selectores y la sección Preferencias se pueden usar sin textos cortados ni desbordados, en los dos idiomas.

## Plataformas
- **Web**:
  - Mientras no exista la landing (spec 002), Web muestra la interfaz actual, con una barra superior que contiene los dos selectores (RF-27). Es una situación provisional: la separación de la interfaz de Web que piden RC-4 y la constitución (principio 3) llega con la spec 002, que llevará los selectores a la barra de la landing sin cambiar su comportamiento.
  - El idioma se muestra como dos opciones, "ES" y "PT".
  - El tema es un botón que abre un menú con las tres preferencias (claro, oscuro y sistema) y marca la activa.
- **Android/iOS**: los dos selectores están en una sección **"Preferencias"** de la pestaña Perfil, visible con o sin sesión.
- Todos los textos de los selectores, incluidos "ES", "PT" y los nombres de los idiomas, van en los archivos de traducción, como el resto de la interfaz.
- La identidad visual, las preferencias disponibles y su comportamiento son iguales en las tres plataformas.

## Navegación
- **Web**: los selectores están en la barra superior (RF-27). Cambiar una preferencia no cambia de sección ni la posición del scroll.
- **Android/iOS**:
  - Perfil → sección "Preferencias". Cambiar una preferencia no sale de Perfil ni cambia de pestaña.
  - La pestaña Perfil, que antes solo aparecía con sesión, ahora está siempre en la barra inferior (RF-24).
  - Sin sesión, Perfil → "Iniciar sesión" lleva a la pantalla de inicio de sesión (RF-26).
- Esta funcionalidad no añade rutas nuevas. Las specs 003 (navegación móvil) y 006 (perfil) pueden rediseñar esas pantallas, pero deben mantener RF-24 a RF-26.

## Casos límite
- **Dispositivo en un idioma que no es ES ni PT** (por ejemplo, inglés) y sin preferencia: español.
- **Dispositivo en una variante regional** (es-AR, pt-BR, pt-PT…): se toma el idioma (español o portugués), sin distinguir la región.
- **Preferencia guardada con un valor desconocido o corrupto**: se ignora y se aplica el valor por defecto (RF-2 o RF-9), sin error visible.
- **No se puede leer ni escribir el almacenamiento** (navegador en modo privado, almacenamiento bloqueado): la app funciona con los valores por defecto y la elección vale para esa sesión, sin mensaje de error.
- **Sesión cerrada o iniciada con otra cuenta en el mismo dispositivo**: las preferencias se mantienen (son del dispositivo, no de la cuenta).
- **Cambio de tema o idioma con un diálogo, un selector de fecha, un formulario o una reserva a medias**: se conserva el estado (ver *Estado que se conserva*).
- **Navegador o dispositivo sin modo oscuro**: *sistema* equivale a claro.
- **Idioma del dispositivo cambiado con la app abierta**: sin preferencia guardada, la app cambia de idioma (RF-20). Con preferencia guardada, no cambia.
- **Fuentes que tardan en cargar** (Web, primera carga): el texto se ve con una fuente de reserva legible y nunca queda invisible.
- **Textos más largos en portugués**, también con el texto del sistema al 200 %: no se cortan ni se desbordan en los selectores ni en la sección Preferencias (RNF-6). En las demás pantallas existentes no se desbordan con el tamaño de texto por defecto.
- **Inicio de sesión, captura de WhatsApp y pantallas de administración en Android/iOS**: no tienen selectores, porque están fuera de la barra inferior. Se muestran en el idioma y el tema vigentes (preferencia guardada, dispositivo o valor por defecto). Es una limitación aceptada. Por ejemplo, una usuaria con sesión pero sin WhatsApp no puede cambiar el idioma hasta registrar el teléfono.
- **Clienta bloqueada**: el aviso de que no puede entrar sale en el idioma y el tema vigentes.
- **Errores de servicios externos** (por ejemplo, del inicio de sesión): se muestra un texto propio de la app en el idioma activo, nunca el mensaje técnico (RF-22).
- **Varias pestañas de la web abiertas**: un cambio hecho en una pestaña se aplica en las demás al recargarlas.
- **Sin conexión**: el tema, el idioma y las tipografías funcionan igual, porque son locales. El comportamiento del resto del contenido (imágenes, mapa, datos) lo define cada spec.
- **Mapa de Google en tema oscuro**: se ve claro (*Excepciones de color*).

## Fuera de alcance
- Rediseño de la maquetación de las pantallas (inicio/landing, servicios, reservas, perfil, admin): cada una en su spec (002 a 007).
- Selectores en las pantallas de inicio de sesión, captura de WhatsApp y administración.
- Sincronizar las preferencias con la cuenta o entre dispositivos, y entre pestañas abiertas de la web sin recargar.
- Conservar preferencias guardadas por la web anterior (`shaddai-web`): no está publicada, así que no hay visitantes con preferencias guardadas.
- Idioma de las notificaciones push: lo decide la spec 008. Como esta spec no guarda el idioma en la cuenta (RNF-3), si la 008 lo necesita tendrá que cambiar esta spec con `/sdd-change`.
- Traducir el contenido guardado en Firestore (servicios, datos de clientas) y el texto que pinta el propio botón de Google.
- Otros idiomas aparte de español y portugués, y la opción "idioma del sistema" en el selector (el idioma del dispositivo solo se usa cuando no hay preferencia).
- Tamaños de letra o contraste alto propios de la app, y adaptar la app al ajuste de contraste alto o de reducir movimiento del sistema.
- Pantalla de arranque nativa, página de carga de Web, color de la pestaña del navegador, favicon e iconos: spec 010 (publicación).
- Mapa en estilo oscuro.
- Temas de color personalizables o de temporada.

## Criterios de finalización
- **Con tests automáticos** (todos en verde):
  - Cada RF y cada RNF verificable en código tiene al menos un test que lo cubre: todos salvo los que se revisan a mano (abajo).
  - Hay un test de contraste por cada par texto–fondo de los dos temas (RNF-1).
  - Ninguna pantalla existente tiene colores ni fuentes fuera del tema, salvo las *Excepciones de color* (RF-15).
- **En el recorrido manual de la validación** (Android, iOS y Web; tema claro y oscuro; español y portugués):
  - Las preferencias de tema e idioma sobreviven a cerrar y volver a abrir la app (o recargar la web).
  - Con preferencia *sistema*, cambiar el modo del dispositivo cambia el tema de la app abierta (RF-4).
  - Sin preferencia de idioma, cambiar el idioma del dispositivo cambia el de la app abierta (RF-20).
  - En el primer arranque sin conexión, las tipografías se ven bien (RNF-5).
  - La barra de estado y la de navegación del sistema se leen en los dos temas (RF-23).
  - En Web, los selectores se manejan con teclado (RNF-4).
- No quedan textos de interfaz fuera de los archivos de traducción.

## Dudas abiertas
Ninguna. Resueltas el 2026-10-20:
- RC-2 de la especificación global se actualiza: el tema por defecto es *sistema*.
- Las tipografías van incluidas en la app (RNF-5).
- En Web, el selector de tema es un menú con las tres opciones.
- Hallazgos del QA (`/sdd-clarify`) resueltos con `/sdd-change`:
  - Sin selectores en inicio de sesión ni en la captura de WhatsApp (decisión del autor).
  - La web anterior no está publicada, así que no hay preferencias que conservar (decisión del autor).
  - Sin preferencia guardada, el idioma sigue en vivo al dispositivo (decisión del autor, RF-20).

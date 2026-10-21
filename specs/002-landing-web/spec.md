# Spec 002 — Landing de una página en Web
Estado: implementada

## Contexto y objetivo
En Web, la app muestra hoy la interfaz móvil con una barra superior provisional (spec 001, RF-27). La web anterior del salón, shaddai-web, es una landing de una sola página con toda la información del salón, pero sin reservas.

Esta spec sustituye esa interfaz provisional por la landing: el mismo contenido y diseño que shaddai-web, con el design system de la spec 001. Además, la reserva de la app y el acceso a la cuenta (perfil y panel de administración) quedan disponibles desde Web. Así la web del dominio dshaddai.com es a la vez escaparate y canal de reserva (RC-4).

## Usuarios
- **Visitante** sin sesión: lee la landing, cambia tema e idioma, contacta y empieza una reserva.
- **Cliente** con sesión: además, reserva, ve sus turnos y cierra sesión.
- **Admin**: además, entra en su panel.

## Historias de usuario
- HU-1. Como visitante, quiero ver en una sola página los servicios, precios, catálogo, normas, trabajos y contacto del salón para decidir si reservo.
- HU-2. Como visitante, quiero saltar a una sección desde la barra superior para no tener que buscarla con el scroll.
- HU-3. Como visitante, quiero pulsar "Reservar" y, tras iniciar sesión, elegir un hueco libre para reservar sin escribir a nadie.
- HU-4. Como clienta con sesión, quiero llegar a mis turnos desde la web para consultarlos.
- HU-5. Como admin, quiero llegar a mi panel desde la web para gestionar los turnos desde un ordenador.
- HU-6. Como visitante, quiero contactar por WhatsApp, teléfono, correo o redes con un toque.

## Definiciones
- **Landing**: la página de entrada de la web. Muestra en scroll vertical, en este orden, las *secciones*:
  1. hero;
  2. franja de servicios;
  3. lista de precios;
  4. combos;
  5. catálogo;
  6. cómo funciona la atención;
  7. galería;
  8. sobre mí;
  9. contacto;
  10. pie.
- **Contenido de referencia**: los textos, precios, combos, datos de contacto, enlaces, imágenes y orden de secciones de shaddai-web a fecha 2026-10-21. Los textos, en sus versiones en español y en portugués. Hay dos diferencias, porque en Web se reserva con la app:
  - los botones de reserva del hero llevan a la reserva de la app;
  - la sección de contacto añade el botón "Reservar cita" (RF-32).
- **Barra superior**: barra fija en lo alto de todas las páginas de Web. Contiene:
  - el logotipo con el nombre "Studio Shaddai";
  - los enlaces a Servicios, Catálogo y Sobre mí;
  - el selector de tema y el de idioma (los de la spec 001; en ancho estrecho van en el *menú lateral*);
  - el botón "Reservar";
  - el *botón de cuenta*.
- **Menú lateral**: panel que se abre desde el borde derecho en ancho estrecho. Contiene los selectores de tema e idioma (los de la spec 001) y los enlaces a Servicios, Catálogo y Sobre mí. Se cierra con su botón de cerrar, al pulsar fuera de él o con Esc.
- **Ancho estrecho / ancho amplio**: ventana de menos de 900 px de ancho / de 900 px o más.
- **Botón de cuenta**: sin sesión muestra "Entrar". Con sesión, muestra la foto de la persona (o su inicial si no tiene foto) y abre un menú con:
  - "Mis turnos";
  - "Panel de administración" (solo si es admin);
  - "Cerrar sesión".
- **Páginas de cuenta**: inicio de sesión, captura de WhatsApp, reserva, perfil (mis turnos) y panel de administración, cada una fuera de la landing.
- **Enlace externo**: WhatsApp, Google Maps, Instagram, TikTok, Facebook, YouTube, teléfono y correo del contenido de referencia.

## Requisitos funcionales

### Landing
- RF-1: CUANDO alguien abre la web en su dirección principal, EL SISTEMA muestra la landing con las diez secciones en el orden de la definición.
- RF-2: EL SISTEMA muestra en cada sección el contenido de referencia, en el idioma activo.
- RF-3: EL SISTEMA muestra la lista de precios y los combos del contenido de referencia, con los precios en reales (R$), igual en los dos idiomas.
- RF-4: CUANDO se pulsa un enlace de sección de la barra superior (Servicios, Catálogo o Sobre mí), EL SISTEMA desplaza la landing hasta el comienzo de esa sección sin que quede tapada por la barra superior.
- RF-5: CUANDO se pulsa "Ver lista de precios" en el hero, EL SISTEMA desplaza la landing hasta la lista de precios.
- RF-6: CUANDO se pulsa una página del catálogo, EL SISTEMA la muestra ampliada sobre la landing.
- RF-7: CUANDO la página ampliada del catálogo está abierta y se pulsa cerrar, fuera de la imagen o Esc, EL SISTEMA la cierra y deja la landing en la misma posición de scroll.
- RF-8: CUANDO se pulsa una foto de la galería, "Ver más en Instagram" o la tarjeta de más páginas del catálogo, EL SISTEMA abre el Instagram del salón en una pestaña nueva.
- RF-9: CUANDO se pulsa la dirección del hero o de contacto, EL SISTEMA abre la ubicación del salón en Google Maps en una pestaña nueva.
- RF-10: CUANDO se pulsa el teléfono, el correo o una red social de contacto o del pie, EL SISTEMA abre su enlace externo: llamada, cliente de correo o la red en una pestaña nueva.
- RF-11: EL SISTEMA muestra en todo momento, sobre la landing, un botón flotante de WhatsApp.
- RF-12: CUANDO se pulsa el botón flotante de WhatsApp o "Agenda por WhatsApp" de contacto, EL SISTEMA abre el WhatsApp del salón en una pestaña nueva.
- RF-32: EL SISTEMA muestra en la sección de contacto el botón "Reservar cita", con el mismo texto que el del hero, junto a "Agenda por WhatsApp". "Reservar cita" es la acción principal; "Agenda por WhatsApp", la secundaria.

### Barra superior
- RF-13: EL SISTEMA muestra la barra superior en la landing y en las páginas de cuenta, fija al hacer scroll.
- RF-14: CUANDO se pulsa el logotipo, EL SISTEMA muestra la landing desde su comienzo.
- RF-15: MIENTRAS la ventana tiene ancho estrecho, EL SISTEMA muestra en la barra solo el logotipo (sin el nombre), "Reservar", el botón de cuenta y un botón de menú. Los enlaces de sección y los selectores de tema e idioma pasan a un menú lateral, que se abre con ese botón.
- RF-16: CUANDO se elige una sección en el menú lateral, EL SISTEMA lo cierra y desplaza la landing hasta esa sección.
- RF-17: CUANDO se pulsa un enlace de sección desde una página de cuenta, EL SISTEMA vuelve a la landing y la desplaza hasta esa sección.
- RF-18: EL SISTEMA retira en Web la barra superior provisional y la barra de navegación inferior.

### Reserva
- RF-19: CUANDO una persona sin sesión pulsa "Reservar" en la barra superior o "Reservar cita" en el hero o en contacto (RF-32), EL SISTEMA muestra la página de inicio de sesión.
- RF-20: CUANDO una persona inicia sesión tras pulsar "Reservar", EL SISTEMA muestra la página de reserva, pasando antes por la captura de WhatsApp si no lo tiene.
- RF-21: CUANDO una persona con sesión y WhatsApp pulsa "Reservar", EL SISTEMA muestra la página de reserva.
- RF-22: CUANDO una reserva se crea, EL SISTEMA muestra su confirmación y ofrece volver a la landing.
- RF-23: SI la clienta está bloqueada, ENTONCES EL SISTEMA se comporta como en Android/iOS: rechaza el inicio de sesión con su mensaje y deja a la persona en la página de inicio de sesión.

### Cuenta
- RF-24: CUANDO una persona sin sesión pulsa "Entrar", EL SISTEMA muestra la página de inicio de sesión. Tras iniciar sesión (y dar su WhatsApp si no lo tenía), vuelve a la landing.
- RF-25: MIENTRAS hay sesión, EL SISTEMA muestra en el botón de cuenta la foto de la persona o, si no tiene, la inicial de su nombre.
- RF-26: CUANDO se elige "Mis turnos", EL SISTEMA muestra la página de perfil con los turnos de la clienta.
- RF-27: MIENTRAS la persona con sesión es admin, EL SISTEMA muestra "Panel de administración" en el menú de cuenta. CUANDO lo elige, muestra el panel.
- RF-28: CUANDO se elige "Cerrar sesión", EL SISTEMA cierra la sesión y muestra la landing.
- RF-29: CUANDO se abre en Web la dirección de una pestaña móvil (inicio, servicios, reserva o perfil), EL SISTEMA muestra:
  - inicio → la landing;
  - servicios → la landing en la lista de precios;
  - reserva → la página de reserva, con las mismas reglas de sesión que "Reservar";
  - perfil → la página de perfil, o el inicio de sesión si no hay sesión.
- RF-30: EL SISTEMA muestra las páginas de cuenta con su contenido actual, centrado y con un ancho máximo legible en ancho amplio.
- RF-31: EL SISTEMA no muestra en la página de perfil de Web la sección de Preferencias, porque tema e idioma están en la barra superior.

## Requisitos no funcionales
- RNF-1: La landing y la barra superior cumplen el contraste WCAG AA en tema claro y oscuro: 4,5:1 en texto normal y 3:1 en texto grande e iconos con significado. También el texto sobre fotos.
- RNF-2: Todo lo que se pulsa en la landing y en la barra superior se puede alcanzar y activar con el teclado (Tab, Intro/Espacio), con el foco visible.
- RNF-3: Cada imagen con información tiene una descripción en el idioma activo para lectores de pantalla. Las decorativas se ignoran.
- RNF-4: Con el texto del navegador al 200 %, ninguna sección corta ni solapa texto, en ancho estrecho (360 px) y amplio (1280 px).
- RNF-5: No hay scroll horizontal en ningún ancho desde 320 px.
- RNF-6: Todos los textos de la landing están en español y portugués (RC-1). Los nombres propios, datos de contacto y precios no se traducen.

## Plataformas
- **Web**: todo lo de esta spec. Sustituye la interfaz provisional de la spec 001 (RF-27 de la 001).
- **Android/iOS**: sin cambios. El contenido de la landing que falta en móvil (catálogo, cómo funciona la atención, galería y sobre mí) se reparte en la spec 003.

## Navegación
- Entrada: dirección principal de la web → landing.
- Landing → secciones (barra superior, menú lateral, hero) · enlaces externos en pestaña nueva · "Reservar" → inicio de sesión / captura de WhatsApp / reserva · "Entrar" → inicio de sesión → landing.
- Menú de cuenta → mis turnos · panel de administración (admin) · cerrar sesión → landing.
- Desde cualquier página de cuenta: logotipo → landing; enlace de sección → landing en esa sección. El botón atrás del navegador vuelve a la página anterior.

## Casos límite
- Abrir la web con sesión iniciada pero sin WhatsApp: la landing se ve. Al pulsar "Reservar", "Entrar" o "Mis turnos", se pide el WhatsApp antes de seguir.
- Cerrar el inicio de sesión de Google sin terminar: la persona se queda en la página de inicio de sesión sin mensaje de error (como en móvil).
- La sesión caduca o se cierra en otra pestaña con una página de cuenta abierta: esa página muestra el inicio de sesión al recargar o al navegar.
- Una clienta (no admin) abre la dirección del panel de administración: no ve el panel. Se le muestra la landing. La seguridad real va en las reglas de Firestore (spec 009).
- Cambiar de tema o de idioma con la landing a media página: se mantiene la posición de scroll (spec 001, RF-5).
- Cambiar el ancho de la ventana entre estrecho y amplio con el menú lateral abierto: el menú se cierra y la barra se adapta sin perder el scroll.
- Cambiar el tema o el idioma desde el menú lateral: el cambio se aplica al momento y el menú sigue abierto, para poder hacer los dos cambios seguidos.
- Motivo del menú lateral (cambio del 2026-10-21): con 48 px por elemento, los seis elementos de la barra no caben en 360 px (unos 368 px), y RNF-5 exige 320 px.
- Con poca anchura o con el texto grande, "Reservar cita" y "Agenda por WhatsApp" de contacto se colocan uno debajo del otro, sin cortarse (RNF-4, RNF-5).
- Una imagen de la landing no carga (sin conexión o error): se ve un recuadro del color de fondo con su descripción, sin romper la sección.
- El navegador bloquea la pestaña nueva de un enlace externo: no se muestra error propio. La landing sigue igual.
- Sin conexión al abrir una página de cuenta: se muestran los mensajes de error ya existentes de esa página (spec 001, RF-22).

## Fuera de alcance
- Servicios, precios y combos en Firestore: los sustituye la spec 004, sin cambiar cómo se ven.
- Mapa incrustado y clave de Google Maps para Web.
- Rediseño de las páginas de reserva, perfil y panel de administración (specs 005, 006 y 007). Aquí solo se integran en la web.
- Contenido de la landing en Android/iOS (spec 003).
- Posicionamiento en buscadores (SEO), analítica, cookies y enlaces directos a una sección con `#`.
- Publicación en Hostinger y configuración de Firebase para Web (spec 010).
- Las cifras del hero (servicios, seguidoras, aviso para cambios) se muestran fijas como en el contenido de referencia, sin actualizarse solas.

## Criterios de finalización
- Todos los RF y RNF tienen test y pasan.
- Recorrido manual con `flutter run -d chrome` en tema claro y oscuro, español y portugués, en ancho estrecho (360 px) y amplio (1280 px), con ratón y con teclado:
  - landing completa;
  - reserva de principio a fin con una cuenta de prueba;
  - "Mis turnos";
  - panel de administración con una cuenta admin;
  - cerrar sesión.
- La landing coincide con shaddai-web en contenido y orden de secciones.
- Android/iOS no cambian: sus tests siguen en verde.
- No quedan textos de interfaz fuera de los archivos de traducción.

## Dudas abiertas
- Ninguna.

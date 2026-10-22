# Spec 003 — Navegación móvil (Android/iOS)
Estado: implementada

## Contexto y objetivo
En Android/iOS, la app tiene una barra inferior con cuatro pestañas: Inicio, Servicios, Reservas y Perfil. El contenido de Inicio y Servicios es todavía el de ejemplo de la plantilla original (servicios y precios en dólares que no son los del salón). Mientras tanto, la landing de Web (spec 002) ya tiene el contenido real.

Esta spec lleva ese contenido real a Android/iOS, repartido entre las pestañas, para que las clientas encuentren lo mismo en la app y en la web (RC-4). También corrige dos cosas de la barra inferior:
- sus pestañas no alcanzan el tamaño táctil mínimo;
- sin sesión, Reservas saca a la persona de las pestañas.

## Usuarios
- **Visitante** sin sesión: consulta Inicio y Servicios, contacta y empieza una reserva.
- **Cliente** con sesión: además, reserva y ve su perfil.
- **Admin**: igual que la clienta, más el acceso al panel desde Perfil (sin cambios).

## Historias de usuario
- HU-1. Como visitante, quiero ver en el móvil la presentación del salón, sus trabajos, quién es Beidis y cómo contactarla para decidir si reservo.
- HU-2. Como visitante, quiero ver en una pestaña los precios reales, los combos, el catálogo y las normas de atención para saber qué pedir y cuánto cuesta.
- HU-3. Como visitante, quiero tocar Reservas e iniciar sesión sin perder la barra inferior para no sentir que salgo de la app.
- HU-4. Como persona con dedos grandes o con el texto del móvil grande, quiero que la barra inferior se pueda tocar y leer bien.

## Definiciones
- **Contenido de la landing**: los textos, precios, combos, datos de contacto, enlaces e imágenes de la landing de Web (spec 002), en español y en portugués. Las dos plataformas toman este contenido de la misma fuente, así que siempre coinciden.
- **Inicio**: pestaña con, en este orden:
  1. la *presentación*: foto, textos del hero, "Reservar cita", "Ver lista de precios" y cifras;
  2. la galería;
  3. "Sobre mí";
  4. el *contacto*.
- **Contacto**: sección de Inicio con:
  - "Reservar cita" y "Agenda por WhatsApp";
  - teléfono, correo, dirección, Instagram y las redes del pie (TikTok, Facebook, YouTube);
  - el mapa incrustado con la ubicación del salón.
- **Servicios**: pestaña con, en este orden: la lista de precios, los combos, el catálogo y "Cómo funciona la atención".
- **Aviso de inicio de sesión**: contenido de la pestaña Reservas cuando no hay sesión. Lleva un texto que explica que hace falta iniciar sesión para reservar y el botón de Google, sin salir de las pestañas.
- **Enlace externo**: WhatsApp, Google Maps, Instagram, TikTok, Facebook, YouTube, teléfono y correo. En el móvil se abren en su app, si está instalada, o en el navegador.

## Requisitos funcionales

### Barra inferior
- RF-1: EL SISTEMA muestra en Android/iOS la barra inferior con cuatro pestañas, en este orden: Inicio, Servicios, Reservas y Perfil, con y sin sesión.
- RF-2: EL SISTEMA marca la pestaña activa con el icono y la etiqueta resaltados, y la anuncia como seleccionada al lector de pantalla.
- RF-3: CUANDO se cambia de pestaña, EL SISTEMA conserva en cada una su posición de scroll y su estado (por ejemplo, la fecha elegida en Reservas).
- RF-4: CUANDO se toca la pestaña que ya está activa, EL SISTEMA vuelve al comienzo de esa pestaña.

### Inicio
- RF-5: EL SISTEMA muestra en Inicio la presentación, la galería, "Sobre mí" y el contacto, en ese orden, con el contenido de la landing.
- RF-6: CUANDO se toca "Reservar cita" (en la presentación o en el contacto), EL SISTEMA abre la pestaña Reservas.
- RF-7: CUANDO se toca "Ver lista de precios", EL SISTEMA abre la pestaña Servicios desde su comienzo.
- RF-8: CUANDO se toca una foto de la galería o "Ver más en Instagram", EL SISTEMA abre el Instagram del salón.
- RF-9: CUANDO se toca la dirección, EL SISTEMA abre la ubicación del salón en Google Maps.
- RF-10: EL SISTEMA muestra en el contacto el mapa incrustado con la ubicación del salón.
- RF-11: CUANDO se toca "Agenda por WhatsApp", el teléfono, el correo, Instagram o una red social del contacto, EL SISTEMA abre su enlace externo.

### Servicios
- RF-12: EL SISTEMA muestra en Servicios la lista de precios, los combos, el catálogo y "Cómo funciona la atención", en ese orden, con el contenido de la landing y los precios en reales (R$).
- RF-13: CUANDO se toca una página del catálogo, EL SISTEMA la muestra ampliada. CUANDO se cierra con su botón, tocando fuera o con el gesto o botón "atrás" del sistema, vuelve a Servicios en la misma posición.
- RF-14: CUANDO se toca la tarjeta de más páginas del catálogo, EL SISTEMA abre el Instagram del salón.
- RF-15: EL SISTEMA muestra en Servicios un botón "Reservar cita" que abre la pestaña Reservas.

### Reservas sin sesión
- RF-16: MIENTRAS no hay sesión, EL SISTEMA muestra en la pestaña Reservas el aviso de inicio de sesión, con la barra inferior visible.
- RF-17: CUANDO una persona inicia sesión desde el aviso, EL SISTEMA muestra la reserva en la pestaña Reservas. Si no tiene WhatsApp, se lo pide antes.
- RF-18: SI la clienta está bloqueada, ENTONCES EL SISTEMA muestra en el aviso su mensaje de cuenta bloqueada y no inicia la sesión.
- RF-19: SI el inicio de sesión falla o se cancela, ENTONCES EL SISTEMA se queda en el aviso: con el mensaje de error de la app si falló, sin mensaje si se canceló.

### Contenido
- RF-20: EL SISTEMA deja de mostrar en Android/iOS los servicios, precios y fotos de ejemplo de la plantilla original.
- RF-21: EL SISTEMA muestra en Android/iOS los mismos textos, precios, combos y datos de contacto que la landing de Web, en el idioma activo.

## Requisitos no funcionales
- RNF-1: Cada pestaña de la barra inferior mide al menos 48 × 48 px y tiene su nombre accesible.
- RNF-2: Inicio, Servicios y el aviso de inicio de sesión cumplen el contraste WCAG AA en tema claro y oscuro: 4,5:1 en texto normal y 3:1 en texto grande e iconos con significado.
- RNF-3: Todo lo que se toca en Inicio, Servicios y el aviso mide al menos 48 × 48 px y tiene nombre accesible. Cada imagen con información tiene su descripción en el idioma activo.
- RNF-4: Con el texto del sistema al 200 %, ni la barra inferior ni ninguna sección cortan o solapan texto, desde 320 px de ancho.
- RNF-5: Las imágenes van incluidas en la app: Inicio y Servicios se ven sin conexión, salvo el mapa incrustado.

## Plataformas
- **Android/iOS**: todo lo de esta spec.
- **Web**: sin cambios. La landing de la spec 002 sigue igual.

## Navegación
- Barra inferior: Inicio · Servicios · Reservas · Perfil, siempre visibles.
- Inicio → "Reservar cita" → Reservas · "Ver lista de precios" → Servicios · enlaces externos (WhatsApp, Maps, Instagram, redes, teléfono y correo).
- Servicios → "Reservar cita" → Reservas · página del catálogo ampliada → vuelve a Servicios.
- Reservas sin sesión → aviso → Google → (captura de WhatsApp) → reserva, dentro de la pestaña.
- Perfil: sin cambios (spec 001; su rediseño es de la spec 006).

## Casos límite
- **Enlaces externos:**
  - no hay app de correo o de teléfono (por ejemplo, una tableta sin SIM): no se muestra error propio y la app sigue igual;
  - WhatsApp o Instagram no están instalados: se abren en el navegador.
- **Sin conexión:**
  - el mapa incrustado muestra su recuadro sin mapa y el resto de Inicio se ve normal;
  - el inicio de sesión desde el aviso muestra el error de la app.
- **Sesión:**
  - si la sesión se cierra (desde Perfil) mientras Reservas tiene una fecha elegida, Reservas vuelve al aviso;
  - si la persona inicia sesión desde Perfil y luego toca Reservas, ve directamente la reserva.
- **Tema o idioma a media pestaña:** se mantienen la pestaña y la posición de scroll (spec 001, RF-5).
- **Pantallas estrechas:** en 320 px y con el texto al 200 %, las etiquetas de la barra inferior no se cortan (pueden ocupar dos líneas o reducirse a los iconos con su nombre accesible).
- **Gesto "atrás" de Android:** con una página del catálogo ampliada, la cierra; en la pestaña Inicio, sale de la app como hasta ahora.
- **Admin:** ve las mismas pestañas; el panel sigue en Perfil.

## Fuera de alcance
- Servicios, precios y combos en Firestore (spec 004): siguen fijos, igual que en la landing.
- Vista de detalle de un servicio y "Reservar" con ese servicio ya elegido (petición del autor del 2026-10-21): los detalles se definen con los servicios en Firestore (spec 004) y la reserva con servicio, en la spec 005, para Web y Android/iOS. Hasta entonces, las filas de la lista de precios no se pueden tocar.
- Rediseño de la reserva y del perfil (specs 005 y 006).
- La franja animada y el botón flotante de WhatsApp de la landing: no van en móvil.
- Diseños específicos para tableta en horizontal: se usa el mismo diseño que en el móvil, sin desbordes.
- Enlaces profundos (abrir la app en una pestaña o sección desde un enlace externo).

## Criterios de finalización
- Todos los RF y RNF tienen test y pasan.
- Recorrido manual con `flutter run` en Android e iOS (emulador, simulador o dispositivo), en tema claro y oscuro, en español y portugués, con el texto normal y al 200 %:
  - las cuatro pestañas;
  - los enlaces externos en un dispositivo real;
  - reserva desde el aviso sin sesión;
  - el gesto "atrás".
- Inicio y Servicios muestran el mismo contenido que la landing de Web.
- La Web no cambia: sus tests siguen en verde.
- No quedan textos de interfaz fuera de los archivos de traducción, ni contenido de ejemplo de la plantilla.

## Dudas abiertas
- Ninguna.

# Spec 004 — Servicios y precios en Firestore
Estado: implementada

## Contexto y objetivo
La lista de precios y los combos que se ven en la landing de Web (spec 002) y en la pestaña Servicios de Android/iOS (spec 003) están fijos en el código. Para cambiar un precio hace falta publicar una versión nueva de la app y de la web, y las clientas no pueden ver el detalle de un servicio (qué incluye, cuánto dura).

Esta spec:
- guarda los servicios, sus categorías y los combos en la base de datos, para que las tres plataformas muestren siempre los mismos precios;
- permite a la admin crearlos, editarlos, ordenarlos, ocultarlos y borrarlos desde la app, en español y en portugués;
- añade una vista de detalle de cada servicio y de cada combo.

Así los precios se actualizan sin publicar versiones, y la clienta sabe qué pide antes de reservar. La spec 005 usará estos servicios para que la reserva guarde el servicio elegido.

Cambios en otras specs:
- Spec 002, RF-1 y RF-3, y spec 003, RF-12: la lista de precios y los combos vienen de la base de datos, no del contenido de referencia, y la sección de combos solo aparece si hay algún combo visible (RF-11).
- La nota de Retiradas, que lleva un precio dentro, deja de ser un texto fijo: pasa a ser la nota de su categoría en la base de datos.
- Los nombres, descripciones y notas de servicios, categorías, adicionales y combos son contenido que gestiona la admin: van en la base de datos, en español y portugués, no en los textos fijos de la interfaz (constitución, principio 6).

## Usuarios
- **Visitante** sin sesión: ve la lista de precios, los combos y el detalle de cada servicio.
- **Cliente** con sesión: igual que la visitante.
- **Admin**: además, gestiona las categorías, los servicios, los adicionales y los combos.

## Historias de usuario
- HU-1. Como visitante, quiero ver los precios actuales del salón para saber cuánto cuesta lo que quiero.
- HU-2. Como visitante, quiero abrir un servicio y ver qué incluye, cuánto dura y cuánto cuesta para decidir si lo reservo.
- HU-3. Como admin, quiero cambiar un precio o un texto desde la app y que las clientas lo vean enseguida, sin esperar a una versión nueva.
- HU-4. Como admin, quiero crear, ordenar, ocultar y borrar servicios, adicionales y combos para que la lista refleje lo que ofrezco.
- HU-5. Como visitante que usa la app en portugués, quiero ver los servicios en portugués.

## Definiciones
- **Texto bilingüe**: un texto con su versión en español y en portugués, las dos obligatorias. Se muestra la del idioma activo.
- **Categoría**: bloque de la lista de precios (hoy: Manos, Pies, Alargamientos, Soft Gel, Retiradas, Decoración y adicionales). Tiene nombre, subtítulo y nota (textos bilingües; subtítulo y nota pueden quedar vacíos en los dos idiomas), una posición en la lista y si está visible. Su número ("01", "02"…) es su posición entre las categorías visibles.
- **Servicio**: una línea con precio de una categoría que se puede reservar (por ejemplo, "Spa de manos" o "Alargamiento · nueva aplicación · largo"). Tiene:
  - nombre, descripción y grupo (textos bilingües; descripción y grupo pueden quedar vacíos);
  - precio en reales y si es un precio "desde";
  - duración en minutos;
  - categoría, posición dentro de ella y si está visible.
- **Grupo**: título opcional que agrupa servicios seguidos de una misma categoría (hoy: "Nueva aplicación" y "Mantenimiento" en Alargamientos). Los servicios seguidos con el mismo grupo se muestran bajo ese título.
- **Adicional**: una línea con precio que se suma a un servicio (por ejemplo, "Cromado / ojo de gato · +R$ 15"). Tiene nombre (bilingüe), precio, categoría, posición y si está visible. No tiene detalle ni se reserva solo.
- **Combo**: varios servicios a un precio conjunto. Tiene nombre y descripción (bilingües), precio, duración, posición entre los combos y si está visible. Se puede reservar y tiene detalle.
- **Detalle**: vista de un servicio o combo con su nombre, categoría (solo servicios), precio, duración, descripción, la nota de su categoría (solo servicios) y "Reservar cita".
- **Gestión de servicios**: pantalla de la admin para mantener categorías, servicios, adicionales y combos.
- **Formato del precio**: "R$ 30" si es entero y "R$ 30,50" si tiene céntimos; "desde R$ 110" (o su traducción) si es un precio "desde"; "+R$ 15" en los adicionales.
- **Formato de la duración**: "45 min" por debajo de una hora; "1 h" o "1 h 30 min" desde una hora.

## Requisitos funcionales

### Lista de precios y combos (Web y Android/iOS)
- RF-1: EL SISTEMA muestra en la lista de precios las categorías visibles en el orden que fija la admin, cada una con su número, nombre, subtítulo, nota y sus servicios y adicionales visibles en su orden.
- RF-2: EL SISTEMA muestra cada servicio con su nombre y su precio, y cada adicional con su nombre y su precio con el signo "+".
- RF-3: EL SISTEMA muestra los combos visibles en el orden que fija la admin, cada uno con su nombre, su descripción y su precio.
- RF-4: EL SISTEMA no muestra una categoría sin servicios ni adicionales visibles.
- RF-5: EL SISTEMA muestra los textos de las categorías, servicios, adicionales y combos en el idioma activo, y los cambia al cambiar de idioma sin recargar.
- RF-6: CUANDO la admin guarda un cambio, EL SISTEMA lo muestra a cualquier persona que tenga abierta la lista o el detalle, sin que esta recargue.
- RF-7: MIENTRAS se cargan los servicios, EL SISTEMA muestra un indicador de carga en el lugar de la lista de precios y de los combos.
- RF-8: SI los servicios no se pueden cargar y no hay datos recibidos antes en ese dispositivo, ENTONCES EL SISTEMA muestra un aviso con un botón "Reintentar" y el enlace "Agenda por WhatsApp" en el lugar de la lista de precios y de los combos.
- RF-9: CUANDO se toca "Reintentar", EL SISTEMA vuelve a cargar los servicios.
- RF-40: MIENTRAS no hay conexión y hay datos recibidos antes en ese dispositivo, EL SISTEMA muestra la lista de precios, los combos y el detalle con esos datos, y los actualiza al volver la conexión.
- RF-41: EL SISTEMA muestra al final de cada servicio y combo de la lista una flecha pequeña ("›") que indica que se puede abrir, y lo resalta al pasar el ratón o al pulsarlo.
- RF-42: EL SISTEMA muestra bajo el catálogo el texto "Los precios vigentes son los de la lista de precios", porque las páginas del catálogo son imágenes fijas que pueden tener precios antiguos.
- RF-10: SI no hay ninguna categoría visible, ENTONCES EL SISTEMA muestra un aviso de que los precios se consultan por WhatsApp, con el enlace "Agenda por WhatsApp", en lugar de la lista de precios.
- RF-11: SI no hay ningún combo visible, ENTONCES EL SISTEMA no muestra la sección de combos.
- RF-12: EL SISTEMA no guarda en el código ningún precio, servicio ni combo para mostrarlo: todos vienen de la base de datos. La única excepción son los datos de la carga inicial (RF-35), que solo se usan para crearla.

### Detalle
- RF-13: CUANDO se toca un servicio o un combo de la lista, EL SISTEMA abre su detalle.
- RF-14: EL SISTEMA muestra en el detalle de un servicio su nombre, su categoría, su precio, su duración, su descripción (si tiene) y la nota de su categoría (si tiene).
- RF-15: EL SISTEMA muestra en el detalle de un combo su nombre, su precio, su duración y su descripción.
- RF-16: CUANDO se toca "Reservar cita" en el detalle, EL SISTEMA abre la reserva como lo hace hoy "Reservar cita" en cada plataforma.
- RF-17: SI el servicio o el combo abierto se borra o se oculta, o no existe, ENTONCES EL SISTEMA muestra en el detalle un aviso de que ya no está disponible y un botón para volver a la lista de precios.
- RF-18: EL SISTEMA no abre detalle al tocar un adicional.

### Detalle en Web
- RF-43: EL SISTEMA muestra el detalle en Web como una página con la barra superior, centrada como las páginas de cuenta, sin pedir sesión y con el botón flotante de WhatsApp.
- RF-44: EL SISTEMA muestra en el detalle de Web el botón "Volver a la lista de precios". CUANDO se toca, muestra la landing en la lista de precios, también si el detalle se abrió directamente por su dirección.

### Detalle en Android/iOS
- RF-45: CUANDO se toca la pestaña Servicios mientras muestra un detalle, EL SISTEMA cierra el detalle y muestra la lista en la posición en que estaba. Un segundo toque vuelve al comienzo de la pestaña (spec 003, RF-4).
- RF-46: CUANDO se toca "Ver lista de precios" en Inicio mientras Servicios muestra un detalle, EL SISTEMA cierra el detalle y abre Servicios desde su comienzo.
- RF-47: CUANDO se cambia de pestaña con un detalle abierto y se vuelve a Servicios, EL SISTEMA sigue mostrando ese detalle.

### Gestión de servicios (admin)
- RF-19: EL SISTEMA muestra a la admin, en el panel de administración, la entrada "Servicios", que abre la gestión de servicios.
- RF-20: EL SISTEMA muestra en la gestión de servicios todas las categorías con sus servicios y adicionales, y todos los combos, también los ocultos, marcando los ocultos como tales.
- RF-21: CUANDO la admin crea o edita una categoría, un servicio, un adicional o un combo, EL SISTEMA le pide todos sus campos en un formulario, con cada texto bilingüe en un campo para español y otro para portugués.
- RF-22: SI al guardar falta un nombre en español o en portugués, ENTONCES EL SISTEMA no guarda y marca el campo que falta.
- RF-23: SI al guardar un texto opcional está escrito en un idioma y vacío en el otro, ENTONCES EL SISTEMA no guarda y marca el campo vacío.
- RF-24: SI al guardar el precio está vacío, es negativo o tiene más de dos decimales, ENTONCES EL SISTEMA no guarda y marca el precio.
- RF-25: SI al guardar la duración de un servicio o combo está vacía, no es un número entero de minutos o está fuera del rango de 5 a 480 minutos, ENTONCES EL SISTEMA no guarda y marca la duración.
- RF-26: CUANDO la admin mueve una categoría, un servicio, un adicional o un combo arriba o abajo, EL SISTEMA guarda el nuevo orden y la lista de precios lo refleja.
- RF-27: CUANDO la admin oculta o vuelve a mostrar un elemento, EL SISTEMA lo quita o lo devuelve a la lista de precios sin borrar sus datos.
- RF-28: MIENTRAS una categoría está oculta, EL SISTEMA no muestra en la lista de precios ninguno de sus servicios ni adicionales.
- RF-29: CUANDO la admin pide borrar un servicio, un adicional o un combo, EL SISTEMA pide confirmación nombrando el elemento, y solo lo borra si la admin confirma.
- RF-30: SI la admin pide borrar una categoría que tiene servicios o adicionales, ENTONCES EL SISTEMA no la borra y le indica que primero los borre o los mueva a otra categoría.
- RF-31: CUANDO la admin pide borrar una categoría vacía, EL SISTEMA pide confirmación y solo la borra si la admin confirma.
- RF-32: CUANDO la admin cambia la categoría de un servicio o adicional, EL SISTEMA lo coloca al final de la categoría nueva.
- RF-33: SI un cambio de la admin no se puede guardar, ENTONCES EL SISTEMA mantiene el formulario con lo escrito y muestra un aviso de error con la opción de reintentar.
- RF-34: CUANDO un cambio se guarda, EL SISTEMA lo confirma a la admin con un aviso breve.

### Datos iniciales
- RF-35: MIENTRAS no hay ninguna categoría, servicio, adicional ni combo guardado, EL SISTEMA muestra a la admin en la gestión de servicios el botón "Cargar la lista de precios actual".
- RF-36: CUANDO la admin toca "Cargar la lista de precios actual", EL SISTEMA pide confirmación y, solo si la admin confirma, crea las categorías, servicios, adicionales y combos de la lista de precios actual, con sus textos en español y portugués, sus precios, su orden, sus grupos y sus notas.
- RF-37: EL SISTEMA crea los servicios y combos de la carga inicial con la duración global del turno del calendario y con la descripción vacía, para que la admin los ajuste después.
- RF-38: SI ya hay algún elemento guardado, ENTONCES EL SISTEMA no ofrece la carga inicial ni la ejecuta, aunque se pida dos veces seguidas.
- RF-39: SI la carga inicial falla a medias, ENTONCES EL SISTEMA no deja ningún elemento creado y muestra un aviso de error con la opción de reintentar.

## Requisitos no funcionales
- RNF-1: Con la carga inicial, la lista de precios y los combos tienen los mismos textos, precios, orden, grupos y notas que hoy (spec 002 y 003), y el mismo diseño salvo la flecha y el resaltado de RF-41.
- RNF-2: Leer categorías, servicios, adicionales y combos no exige sesión. Solo la admin puede crearlos, cambiarlos o borrarlos, y eso se garantiza en las reglas de seguridad de la base de datos, no solo ocultando la gestión en la interfaz (constitución, principio 5). Esta spec escribe las reglas de estos datos, con sus tests; las del resto de datos siguen en la spec 009.
- RNF-3: Todos los textos nuevos de la interfaz (avisos, formularios, etiquetas) están en español y portugués.
- RNF-4: La lista, el detalle y la gestión cumplen el contraste WCAG AA en tema claro y oscuro, tienen objetivos táctiles de al menos 48 px y se leen con el texto del sistema grande sin cortarse.
- RNF-5: El lector de pantalla anuncia cada servicio y combo de la lista como un elemento que se puede abrir, con su nombre y su precio.
- RNF-6: Los errores nunca se muestran en crudo a la persona.

## Plataformas
- **Web**: la lista de precios y los combos siguen en la landing (spec 002). El detalle es una página propia con su dirección, que se puede compartir y abrir directamente (RF-43, RF-44); "atrás" del navegador vuelve a la página anterior. La gestión de servicios es una página de cuenta como el resto del panel de administración.
- **Android/iOS**: la lista de precios y los combos siguen en la pestaña Servicios (spec 003); Inicio no cambia. El detalle se abre dentro de la pestaña Servicios, con la barra inferior visible, y "atrás" vuelve a la lista en la misma posición (RF-45 a RF-47). La gestión de servicios se abre desde el panel de administración, como el resto de pantallas de la admin.

## Navegación
- Lista de precios o combos → detalle (tocando un servicio o combo).
- Detalle → reserva ("Reservar cita") o → lista de precios ("atrás", "Volver a la lista de precios" en Web o el botón del aviso de RF-17).
- Web: dirección del detalle → detalle, sin pasar por la landing; sin sesión.
- Panel de administración → "Servicios" → gestión de servicios → formulario de una categoría, servicio, adicional o combo → de vuelta a la gestión al guardar o cancelar.

## Casos límite
- La admin cambia un precio mientras una clienta tiene abierto ese detalle: el detalle muestra el precio nuevo (RF-6).
- La admin borra u oculta un servicio mientras una clienta tiene abierto su detalle: aviso de RF-17.
- Web: se abre la dirección de un detalle que no existe o está oculto: aviso de RF-17.
- Una categoría visible cuyos servicios están todos ocultos no aparece (RF-4).
- Una categoría solo con adicionales visibles sí aparece (como "Decoración y adicionales").
- Se cambia el idioma con un detalle abierto: el detalle cambia de idioma (RF-5).
- Precio 0: se muestra "R$ 0" (válido, por ejemplo para una cortesía).
- Sin conexión al abrir la app por primera vez y vuelve la conexión: "Reintentar" carga los servicios (RF-9).
- Sin conexión con datos de una visita anterior: se ven esos datos (RF-40), aunque la admin haya cambiado algo después.
- Dos admins editan a la vez: gana el último cambio guardado.
- Una persona no admin abre la dirección de la gestión en Web: se la redirige como al resto del panel.

## Fuera de alcance
- Elegir el servicio al reservar, guardarlo en el turno y usar su duración para los huecos libres (spec 005). Aquí "Reservar cita" abre la reserva sin servicio elegido.
- Fotos por servicio; las páginas del catálogo siguen fijas.
- Adicionales elegibles al reservar.
- Cambiar las cifras del hero ("30+ servicios"), que siguen fijas.
- Historial de cambios de precios y deshacer un borrado.
- Moneda distinta del real y precios por idioma.
- Promociones con fecha de inicio y fin.
- Reglas de seguridad de usuarias, turnos y calendario (spec 009).

## Criterios de finalización
- Todos los RF tienen un test que pasa, sin usar la base de datos real.
- El autor comprueba a mano las reglas de seguridad en el simulador de reglas de la consola de Firebase: lectura sin sesión permitida; escritura sin sesión y de una clienta, rechazada; escritura de la admin, permitida. Tras desplegarlas, la app sigue funcionando (inicio de sesión, reservas y panel de la admin).
- Con la carga inicial, la lista de precios y los combos coinciden con los actuales en Web y en Android/iOS, en español y en portugués (RNF-1).
- El autor cambia un precio desde la gestión y lo ve cambiar en otra plataforma abierta sin recargar.
- El autor recorre el detalle en Web (ancho menor y mayor de 900 px) y en Android/iOS, en tema claro y oscuro, en español y en portugués.
- `dart format` sin cambios, `flutter analyze` sin errores ni avisos y `flutter test` en verde.

## Dudas abiertas
Resueltas el 2026-10-22:
- Duración en la carga inicial: la duración global del turno; la admin la ajusta después (RF-37).
- Descripción en la carga inicial: vacía; Beidis la escribe después (RF-37).
- Carga inicial: botón en la gestión, solo sin datos y con confirmación (RF-35 a RF-39).
- Reglas de seguridad de estos datos: en esta spec (RNF-2).
- Combos: lista aparte, con su propia sección (como hasta ahora).

- Principio 6 de la constitución: se precisa (el contenido que gestiona la admin va en la base de datos, en ES y PT).
- Cómo se ve que un servicio se puede abrir: flecha pequeña y resaltado (RF-41, RNF-1).
- Precios dentro de textos fijos: la nota de Retiradas pasa a la base de datos; el catálogo sigue fijo con un aviso (RF-42).
- Sin combos visibles: la sección se oculta, y se declara el cambio en las specs 002 y 003 (Contexto).
- Detalle en Android/iOS con las pestañas: RF-45 a RF-47.
- Detalle en Web y sin conexión: RF-8, RF-40, RF-43 y RF-44.

Pendientes (menores, de la revisión QA): se resolverán en el plan si no cambian el comportamiento.

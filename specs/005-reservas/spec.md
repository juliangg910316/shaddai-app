# Spec 005 — Reservas
Estado: borrador

## Contexto y objetivo
La reserva ofrece hoy tres opciones fijas (Clásica, Semipermanente, Acrílico), que no son la lista de precios real y no se guardan en el turno. Todos los turnos duran lo mismo, la duración global del calendario, aunque cada servicio tiene ya su propia duración (spec 004). Desde el detalle de un servicio, "Reservar cita" abre la reserva sin nada elegido.

También hay problemas de datos:
- nada impide que una clienta acapare huecos ni que dos clientas reserven la misma hora a la vez;
- cualquier persona con sesión puede leer los turnos de las demás (nombre y WhatsApp) y escribir cualquier turno;
- las horas dependen de la zona horaria del dispositivo.

Esta spec rehace la reserva de la clienta como una sola vista con la fecha, la hora y el servicio:
- la clienta elige una hora libre y un servicio o combo que quepa en ella (y, si quiere, adicionales);
- el turno dura lo que dura el servicio y guarda lo que se reservó;
- "Reservar cita" en un detalle abre la reserva con ese servicio ya elegido;
- cada clienta tiene como mucho un turno activo, y solo ve y escribe sus propios turnos.

Así la admin sabe qué viene a hacerse cada clienta y cuánto tiempo ocupa.

Esta spec es la primera de tres sobre reservas (división decidida por el autor el 2026-10-24):
- **005**: la reserva de la clienta;
- **006-editar-turno**: la clienta edita su turno activo;
- **007-reserva-admin**: la admin reserva para otra persona.

## Usuarios
- **Visitante** sin sesión: empieza una reserva (también desde un detalle) y se le pide iniciar sesión.
- **Cliente** con sesión y WhatsApp: reserva un turno para sí misma y ve el que tiene activo.
- **Clienta bloqueada**: no puede reservar.
- **Admin**: no reserva a su nombre (reservar para otra persona llega con la spec 007). Ve lo reservado en su lista de turnos.

## Historias de usuario
- HU-1. Como clienta, quiero ver las horas libres de un día y elegir el servicio de la lista de precios en la misma vista para reservar sin pasos innecesarios.
- HU-2. Como clienta, quiero ver qué servicios caben en la hora que elegí, y por qué no puedo elegir los demás, para no reservar algo imposible.
- HU-3. Como clienta, quiero añadir adicionales y ver el precio total antes de confirmar para saber cuánto voy a pagar.
- HU-4. Como clienta, quiero tocar "Reservar cita" en el detalle de un servicio y encontrarlo ya elegido, aunque antes tenga que iniciar sesión.
- HU-5. Como admin, quiero ver qué servicio reservó cada clienta y que nadie acapare huecos ni reserve una hora ya ocupada.
- HU-6. Como clienta, quiero que las demás no puedan ver mis datos ni tocar mi turno.

## Definiciones
- **Hora del salón**: la hora de Curitiba (UTC−3, sin horario de verano). "Hoy", "ahora", la rejilla y todas las horas de la reserva se calculan y se muestran en hora del salón, sea cual sea la zona del dispositivo.
- **Vista de reserva**: una sola vista con, de arriba abajo, el calendario, las horas del día elegido, los servicios y combos, los adicionales, el resumen y el botón "Agendar turno".
- **Servicio**: en esta spec, "servicio" incluye los servicios y los combos, salvo que se diga lo contrario.
- **Lo reservado**: un único servicio o combo, más cero o más adicionales.
- **Adicionales disponibles**: los adicionales visibles de la categoría del servicio elegido. Un combo no tiene categoría, así que no lleva adicionales.
- **Servicio disponible**: servicio visible de una categoría visible, o combo visible.
- **Duración del turno**: la duración del servicio elegido. Los adicionales no suman tiempo.
- **Precio total**: el precio del servicio más el de los adicionales elegidos, con el formato de precio de la spec 004. Si el servicio tiene precio "desde", el total también es "desde".
- **Rejilla de horas**: horas de inicio posibles de un día, cada 30 minutos desde la apertura (p. ej., apertura 8:00 → 8:00, 8:30, 9:00…). Un día cuyo cierre no es posterior a su apertura no tiene rejilla y se trata como cerrado.
- **Turno ocupado**: turno de cualquier persona que está esperando confirmación o confirmado.
- **Hora libre**: hora de la rejilla estrictamente posterior a "ahora", anterior al cierre y que no cae dentro de un turno ocupado (desde su inicio hasta antes de su fin). Ejemplo: con un turno ocupado de 8:00 a 9:10, las primeras horas libres son 9:30, 10:00…
- **Cobertura de una hora libre**: minutos desde esa hora hasta el inicio del siguiente turno ocupado del día o, si no hay ninguno, hasta el cierre. Ejemplo: hora 9:30 con un turno ocupado a las 10:00 → 30 minutos.
- **Servicio que cabe**: servicio cuya duración es menor o igual que la cobertura de la hora elegida.
- **Turno activo de una clienta**: turno a su nombre que empieza después de "ahora" y que está esperando confirmación o confirmado.
- **Ventana de reserva**: desde hoy hasta 60 días después de hoy, los dos incluidos.

## Requisitos funcionales

### Fecha y hora
- RF-1: CUANDO se abre la reserva, EL SISTEMA muestra el calendario con hoy elegido y, debajo, las horas libres de hoy. Si hoy no se puede elegir (RF-3), elige el primer día que se pueda.
- RF-2: SI ningún día de la ventana de reserva se puede elegir, ENTONCES EL SISTEMA lo indica con un texto y el enlace a WhatsApp del salón, en lugar del calendario.
- RF-3: EL SISTEMA solo deja elegir fechas dentro de la ventana de reserva, y no deja elegir los días que el calendario tiene cerrados ni las fechas bloqueadas.
- RF-4: EL SISTEMA muestra, para la fecha elegida, todas sus horas libres en orden, en hora del salón.
- RF-5: MIENTRAS la zona horaria del dispositivo no es la del salón, EL SISTEMA indica junto a las horas que son hora de Curitiba.
- RF-6: CUANDO otra persona reserva o se cancela un turno de la fecha elegida, EL SISTEMA actualiza las horas libres y su cobertura sin recargar.
- RF-7: SI una fecha no tiene ninguna hora libre, ENTONCES EL SISTEMA lo indica con un texto, en lugar de una lista vacía.
- RF-8: CUANDO se cambia de fecha, EL SISTEMA quita la hora elegida y conserva lo reservado.
- RF-9: CUANDO la hora elegida deja de ser libre (pasa a ser pasada, la ocupa otro turno o cambia el horario), EL SISTEMA la quita de la selección y avisa.

### Servicios
- RF-10: EL SISTEMA muestra debajo de las horas los servicios disponibles, agrupados bajo el nombre de su categoría en el orden de la lista de precios, y después los combos visibles. Cada uno lleva su nombre, su precio y su duración.
- RF-11: EL SISTEMA no ofrece en la reserva los adicionales sueltos ni los servicios que no están disponibles, y no muestra las categorías que no tienen ningún servicio disponible.
- RF-12: MIENTRAS hay una hora elegida, EL SISTEMA muestra activados los servicios que caben y, desactivados pero visibles, los que no caben.
- RF-13: CUANDO se toca un servicio desactivado, EL SISTEMA no lo elige y avisa de que ese servicio necesita una hora con más tiempo libre, indicando su duración.
- RF-14: MIENTRAS no hay hora elegida, EL SISTEMA deja elegir cualquier servicio disponible.
- RF-15: MIENTRAS hay un servicio elegido, EL SISTEMA muestra desactivadas las horas libres cuya cobertura no alcanza su duración. Si se toca una, no la elige y avisa de que no hay tiempo suficiente para ese servicio a esa hora.
- RF-16: SI el servicio elegido deja de caber en la hora elegida (cambian los turnos ocupados o su duración), ENTONCES EL SISTEMA quita la hora elegida y avisa de que esa hora ya no tiene tiempo suficiente.
- RF-17: SI el servicio elegido deja de estar disponible, ENTONCES EL SISTEMA lo quita de la selección, con sus adicionales, y avisa de que ya no está disponible.
- RF-18: CUANDO se elige un servicio, EL SISTEMA muestra los adicionales disponibles de su categoría, sin ninguno marcado, para marcar los que se quiera.
- RF-19: CUANDO se elige un combo, EL SISTEMA no muestra adicionales.
- RF-20: CUANDO se cambia de servicio, EL SISTEMA desmarca los adicionales elegidos.
- RF-21: SI un adicional marcado deja de estar disponible, ENTONCES EL SISTEMA lo desmarca.

### Agendar
- RF-22: MIENTRAS hay una hora o un servicio elegidos, EL SISTEMA muestra un resumen con lo que haya elegido: la fecha, la hora de inicio y de fin, lo reservado, los adicionales marcados, la duración del turno y el precio total.
- RF-23: EL SISTEMA muestra al final de la vista el botón "Agendar turno", siempre activo.
- RF-24: SI se toca "Agendar turno" sin hora o sin servicio elegidos, ENTONCES EL SISTEMA no agenda, indica qué falta y marca cada parte sin elegir.
- RF-25: CUANDO se toca "Agendar turno" con todo elegido, EL SISTEMA muestra el resumen, indica que el turno queda esperando confirmación de la admin y pide que se confirme.
- RF-26: CUANDO se confirma, EL SISTEMA comprueba otra vez, antes de guardar, que la hora sigue libre, que el servicio sigue cabiendo en ella y que la clienta no tiene ya un turno activo.
- RF-27: CUANDO se confirma y las comprobaciones de RF-26 se cumplen, EL SISTEMA guarda un turno esperando confirmación a nombre de la clienta, con su inicio, su fin (inicio más la duración del turno) y una copia de lo reservado:
  - el nombre del servicio o combo en español y en portugués;
  - si es servicio o combo;
  - su precio, su precio "desde" y su duración;
  - el nombre en los dos idiomas y el precio de cada adicional.
- RF-28: EL SISTEMA conserva en el turno la copia de lo reservado tal como estaba al reservar, aunque la admin cambie o borre después ese servicio, combo o adicional.
- RF-29: SI al confirmar la hora ya está ocupada, ENTONCES EL SISTEMA no guarda el turno, avisa de que esa hora acaba de ocuparse y pide elegir otra. Conserva lo reservado y la fecha.
- RF-30: SI al confirmar el servicio ya no cabe en la hora, ENTONCES EL SISTEMA no guarda el turno, avisa de que esa hora ya no tiene tiempo suficiente para el servicio y pide elegir otra. Conserva lo reservado y la fecha.
- RF-31: SI el turno no se puede guardar (sin conexión o por un error), ENTONCES EL SISTEMA no lo da por reservado, avisa con un texto sin detalles técnicos y conserva lo elegido para reintentar.
- RF-32: CUANDO el turno se guarda, EL SISTEMA confirma la reserva y muestra que está esperando confirmación de la admin. En Web, además, ofrece volver a la landing, como hasta ahora.

### Turno activo
- RF-33: MIENTRAS la clienta tiene un turno activo, EL SISTEMA muestra en la reserva, en lugar de la vista de reserva, ese turno, con:
  - lo reservado y sus adicionales;
  - la fecha y la hora de inicio y de fin;
  - el precio total;
  - si está esperando confirmación o confirmado.
- RF-34: MIENTRAS la clienta tiene un turno activo, EL SISTEMA no le deja pedir otro y le explica que solo puede tener un turno pendiente a la vez.
- RF-35: CUANDO el turno activo de la clienta se cancela o empieza, EL SISTEMA vuelve a mostrarle la vista de reserva sin recargar.
- RF-36: SI al confirmar la clienta ya tiene un turno activo (por ejemplo, reservado desde otro dispositivo), ENTONCES EL SISTEMA no guarda el nuevo turno y le muestra el que ya tiene.

### Clienta bloqueada y admin
- RF-37: MIENTRAS la clienta está bloqueada, EL SISTEMA no le muestra la vista de reserva: le explica que su cuenta no puede reservar y le ofrece el enlace a WhatsApp del salón. Si tiene un turno activo, se lo sigue mostrando.
- RF-38: CUANDO la admin bloquea a una clienta que tiene la sesión abierta, EL SISTEMA aplica RF-37 sin recargar y sin cerrar su sesión.
- RF-39: MIENTRAS la sesión es de la admin, EL SISTEMA no le deja agendar turnos a su propio nombre y le muestra un texto que lo explica, en lugar de la vista de reserva.

### Reservar desde el detalle
- RF-40: CUANDO se toca "Reservar cita" en el detalle de un servicio o combo, EL SISTEMA abre la reserva con ese servicio elegido, sustituyendo el que hubiera y desmarcando los adicionales. Conserva la fecha y, si el servicio cabe, la hora.
- RF-41: CUANDO se toca "Reservar cita" en el detalle sin sesión o sin WhatsApp, EL SISTEMA pide iniciar sesión y el WhatsApp, y después abre la reserva con ese servicio elegido.
- RF-42: EL SISTEMA abre en Web la reserva con un servicio ya elegido desde su dirección propia, también si se copia y se abre en otra pestaña o se recarga.
- RF-43: MIENTRAS la lista de precios está cargando, EL SISTEMA espera a tenerla para elegir el servicio pedido.
- RF-44: SI el servicio pedido no existe, no está disponible o la dirección no es válida, ENTONCES EL SISTEMA abre la reserva sin servicio elegido y avisa de que ese servicio ya no está disponible.
- RF-45: CUANDO se toca "Reservar cita" en la landing, Inicio, Servicios o contacto, o se cambia de pestaña, EL SISTEMA abre la reserva conservando lo que ya estaba elegido (sin nada, la primera vez).
- RF-46: MIENTRAS la clienta tiene un turno activo, EL SISTEMA muestra ese turno (RF-33) también cuando llega desde el detalle de un servicio.

### Errores de carga
- RF-47: SI la lista de precios no está disponible, ENTONCES EL SISTEMA muestra en lugar de los servicios el mismo aviso que la lista de precios (spec 004), con "Reintentar" y el enlace a WhatsApp, y no deja agendar.
- RF-48: SI no se puede cargar el calendario o los turnos ocupados de la fecha elegida, ENTONCES EL SISTEMA muestra en lugar de las horas un aviso con "Reintentar" y el enlace a WhatsApp, y no deja agendar.
- RF-49: SI no se puede saber si la clienta tiene un turno activo o si está bloqueada, ENTONCES EL SISTEMA muestra en lugar de la vista de reserva un aviso con "Reintentar" y el enlace a WhatsApp.

### Idioma, turnos antiguos y lista de la admin
- RF-50: EL SISTEMA muestra lo reservado, en la reserva, en sus avisos y en sus diálogos abiertos, en el idioma de la interfaz, y lo cambia al cambiar de idioma.
- RF-51: EL SISTEMA sigue leyendo los turnos guardados antes de esta spec, que no tienen lo reservado, y los tiene en cuenta como turnos ocupados con su inicio y su fin. Donde se muestre su servicio, muestra "Servicio sin indicar".
- RF-52: EL SISTEMA muestra a la admin, en su lista de turnos de cada día, lo reservado en cada turno, con los adicionales.

### Privacidad y seguridad
- RF-53: EL SISTEMA solo deja a cada clienta leer sus propios turnos. De los turnos de las demás solo conoce su inicio y su fin, sin nombre, WhatsApp, foto ni lo reservado.
- RF-54: EL SISTEMA solo deja a una clienta crear turnos a su nombre, esperando confirmación, con su fin posterior a su inicio, y solo si no está bloqueada. Se comprueba en el servidor.
- RF-55: EL SISTEMA no deja a una clienta cambiar ni borrar turnos en esta spec (editar llega con la 006 y cancelar, con la 009). Se comprueba en el servidor.
- RF-56: EL SISTEMA solo deja a la admin leer todos los turnos y cambiar su estado. Se comprueba en el servidor.
- RF-57: EL SISTEMA solo deja a cada persona leer su propia ficha de usuaria (la admin, todas), y no deja a una clienta cambiar su rol ni si está bloqueada. Se comprueba en el servidor.
- RF-58: EL SISTEMA sigue funcionando con las reglas nuevas en todo lo que ya existe: inicio de sesión y alta de cuenta, captura de WhatsApp, perfil con sus turnos, panel de la admin (turnos, usuarias y bloqueo) y calendario.

## Requisitos no funcionales
- RNF-1: Son reglas puras, que reciben "ahora" como dato y están probadas con tablas de casos:
  - el cálculo de las horas libres y su cobertura, en hora del salón;
  - la ventana de reserva y el primer día que se puede elegir;
  - el precio total;
  - la comprobación de turno activo.

  Los casos incluyen el ejemplo de 8:00 a 9:10, una cobertura que llega justo al cierre, un servicio que cabe justo, una hora igual a "ahora", la rejilla que no coincide con el fin de un turno, una apertura que no cae en media hora exacta, un cierre no posterior a la apertura, el cambio de día y un dispositivo en otra zona horaria.
- RNF-2: Toda la reserva cumple contraste WCAG AA en tema claro y oscuro. Sus controles miden al menos 48 px y tienen nombre para el lector de pantalla, incluidos los servicios, los adicionales marcados y las horas. Los servicios y las horas desactivados se anuncian como no disponibles, y su texto también cumple el contraste. Los avisos se anuncian al lector de pantalla.
- RNF-3: La reserva funciona sin desbordes con el texto al 200 % y a 320 px de ancho, en español y en portugués.
- RNF-4: Todos los textos nuevos de la interfaz están en español y en portugués.
- RNF-5: Las reglas de seguridad de RF-53 a RF-57 se comprueban caso por caso, como en la spec 004.

## Plataformas
- **Android/iOS**: la reserva sigue en la pestaña Reservas, con la barra inferior visible. Sin sesión muestra el aviso de inicio de sesión (spec 003). Desde el detalle de un servicio, "Reservar cita" pasa a la pestaña Reservas con el servicio elegido.
- **Web**: la reserva sigue siendo una página de cuenta, centrada y con la barra superior, con su dirección propia. La dirección puede llevar el servicio elegido. Sin sesión, pasa por el inicio de sesión y la captura de WhatsApp y vuelve a esa misma dirección. Al recargar se conserva el servicio de la dirección; lo demás se pierde.
- La vista de reserva es la misma en las dos: calendario, horas, servicios, resumen y "Agendar turno", en una sola vista con scroll.

## Navegación
- Detalle de un servicio o combo → "Reservar cita" → reserva con ese servicio elegido. Sin sesión, pasa antes por el inicio de sesión y el WhatsApp.
- Landing, Inicio, Servicios y contacto → "Reservar cita" → reserva, con lo que ya estaba elegido.
- Clienta con un turno activo → la reserva muestra ese turno. Para ver todos sus turnos, va a Perfil.
- Tras reservar: en Android/iOS se queda en Reservas, que muestra su turno activo; en Web, puede volver a la landing o quedarse y ver su turno activo.
- Web, "atrás" desde la reserva: vuelve a la página anterior (por ejemplo, el detalle).

## Casos límite
- La admin cambia el precio o la duración del servicio elegido mientras alguien está en la reserva: el resumen y lo que cabe se actualizan (RF-16); se guarda lo que se ve al confirmar.
- La admin oculta la categoría del servicio elegido: el servicio deja de estar disponible (RF-17).
- La admin cambia el horario o bloquea la fecha elegida: las horas se recalculan; si la fecha deja de poderse elegir, se pasa al primer día que se pueda (RF-1) y se avisa.
- Una hora libre en la que no cabe ningún servicio (p. ej., 30 minutos antes del cierre y todos los servicios duran más): se muestra, y todos los servicios quedan desactivados (RF-12, RF-13).
- Un turno que acaba justo cuando empieza una hora de la rejilla: esa hora es libre (p. ej., turno de 8:00 a 9:00 → 9:00 libre).
- Apertura que no cae en media hora exacta (p. ej., 8:15): la rejilla parte de la apertura (8:15, 8:45…).
- Hoy, con horas que ya pasaron: solo se ofrecen las futuras. Si hoy ya no le quedan horas libres, sigue elegido hoy y se aplica RF-7.
- La reserva abierta pasa la medianoche del salón o el día 60 deja de estar dentro de la ventana: la fecha se ajusta a la ventana nueva.
- Dispositivo en otra zona horaria (p. ej., una clienta de visita en Lisboa): ve las horas de Curitiba, con la indicación de RF-5.
- Clienta bloqueada al iniciar sesión: se la saca, como hoy. Con la sesión ya abierta: RF-37 y RF-38.
- Turnos pasados que se quedaron esperando confirmación: no son activos ni ocupan horas futuras.
- Una clienta pasa a admin con un turno activo: como admin, la reserva le muestra RF-39; su turno sigue en la lista de la admin.
- Dos dispositivos de la misma clienta confirman a la vez: el segundo no se guarda (RF-36). La garantía en el servidor llega con la spec 012.
- Sesión cerrada con la reserva a medias: en Android/iOS vuelve al aviso de inicio de sesión (spec 003). En Web pide iniciar sesión, y la dirección conserva el servicio.
- Sin conexión: se ven los últimos datos conocidos de la lista de precios (spec 004), pero la reserva no deja agendar (RF-31, RF-48, RF-49).

## Fuera de alcance
- Que la clienta edite su turno y el margen de edición (spec 006).
- Que la admin reserve para una clienta o para una persona sin cuenta (spec 007).
- Que la admin cierre franjas de horas o días enteros y edite cualquier turno (spec 008).
- Que la clienta cancele su turno, y el rediseño de la lista de sus turnos (spec 009).
- Otras pantallas de la admin y el calendario (spec 010). Qué pasa con la duración global del calendario, que ya no marca la rejilla, se decide en la 010.
- Aviso push a la admin (spec 011).
- Impedir en el servidor los turnos solapados y un segundo turno activo (spec 012). Esta spec lo comprueba en la app al confirmar.
- Varios servicios en un mismo turno, adicionales que suman tiempo, descansos dentro del día, una rejilla distinta de 30 minutos o una ventana distinta de 60 días.
- Pago o señal al reservar.
- Otras zonas horarias para el salón.

## Criterios de finalización
- Todos los RF tienen su test y pasan. `flutter analyze` sin errores ni avisos y `dart format` sin cambios.
- Las reglas puras de RNF-1 tienen tests de tabla.
- El autor comprueba las reglas de seguridad (RF-53 a RF-57) en el simulador de la consola, caso por caso, y, tras publicarlas, que todo lo de RF-58 sigue funcionando.
- Recorrido manual del autor en Android/iOS y en Web (anchos menor y mayor de 900 px), en tema claro y oscuro y en español y portugués. Incluye:
  - elegir primero la hora y ver los servicios que no caben desactivados, con su aviso;
  - elegir primero el servicio y ver las horas que no alcanzan desactivadas;
  - reservar un servicio con adicionales y un combo;
  - "Agendar turno" con algo sin elegir;
  - reservar desde el detalle sin sesión;
  - el choque de una misma hora desde dos dispositivos;
  - el bloqueo por turno activo;
  - una clienta bloqueada con la sesión abierta;
  - el dispositivo en otra zona horaria;
  - ver el turno en la lista de la admin.
- Los turnos antiguos se siguen viendo en la app y ocupan su hora.

## Dudas abiertas
Ninguna. Resueltas con el autor (2026-10-23 y 2026-10-24):
- Lo reservado es un servicio o combo más adicionales de su categoría; los adicionales no suman tiempo.
- Una sola vista: calendario con hoy elegido, horas libres debajo, todos los servicios más abajo y "Agendar turno" al final (siempre activo; dice qué falta).
- Horas cada 30 minutos (fijo); una hora es libre si no cae dentro de un turno ocupado. Los servicios que no caben se ven desactivados con aviso; con un servicio elegido, las horas sin tiempo suficiente también.
- Un solo turno activo por clienta y fechas hasta 60 días.
- Si una hora se ocupa mientras se confirma, se rechaza y se avisa.
- El servicio elegido desde el detalle se conserva tras iniciar sesión; desde el detalle se cambia solo el servicio y los demás "Reservar cita" conservan lo elegido.
- Revisión QA (2026-10-24):
  - reglas de seguridad de turnos y usuarias en esta spec; solapes y un turno activo, en el servidor, en la 012;
  - todo en hora de Curitiba;
  - si falla la carga del calendario, de los turnos o del turno activo: aviso, "Reintentar" y WhatsApp, sin agendar;
  - clienta bloqueada con la sesión abierta: no reserva, sigue viendo su turno, no se cierra la sesión;
  - la spec se divide en 005, 006-editar-turno y 007-reserva-admin.
- Por defecto, para que el autor lo revise: "servicio" incluye combos; categorías solo con adicionales no se muestran; el resumen aparece con hora o servicio; el turno activo sustituye a la vista; una hora igual a "ahora" no es libre; un día con cierre no posterior a la apertura se trata como cerrado; los avisos de choque distinguen "ocupada" y "ya no cabe".

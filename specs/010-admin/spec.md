# Spec 010 — Panel de administración
Estado: aprobada

## Contexto y objetivo
El panel de la admin ya existe en buena parte, construido por las specs 004 (servicios), 007 (reservar para otra persona) y 008 (cierres, editar turnos y margen): una agenda por día con contadores, confirmar y cancelar turnos, la lista de clientas con un interruptor para bloquearlas, y los horarios. Pero tiene huecos:
- cancelar un turno y bloquear o desbloquear a una clienta se hacen al primer toque, sin confirmación (va contra el principio 5 de la constitución) y sin avisar si fallan;
- bloquear a una clienta no toca su turno activo, que sigue ocupando la hora;
- la agenda solo avanza o retrocede un día cada vez, y su día es el del dispositivo, no el del salón;
- los turnos que ya terminaron se pueden cancelar o confirmar;
- la lista de clientas no tiene orden e incluye a la propia admin, que podría bloquearse a sí misma, y no deja escribir a una clienta;
- en la cabecera verde de la agenda, el subtítulo del panel y los nombres de los contadores no tienen contraste suficiente.

El objetivo es completar y pulir lo que hay, sin pantallas nuevas grandes: que cada acción de la admin sea segura (confirmada, sin estados a medias y con aviso de error), que la agenda se recorra con facilidad y que la lista de clientas sirva para gestionarlas.

## Usuarios
- **Admin**: la única que usa el panel. Todo lo de esta spec es suyo.
- **Clienta**: no ve el panel. Le afecta que la bloqueen (su turno activo se cancela y no puede volver a iniciar sesión, como hoy).
- **Visitante sin sesión**: nada cambia.

## Historias de usuario
- HU-1. Como admin, quiero confirmar antes de cancelar un turno, para no cancelarlo por un toque sin querer.
- HU-2. Como admin, quiero ir a hoy o a cualquier fecha de la agenda de un toque, para no avanzar día a día.
- HU-3. Como admin, quiero que los turnos que ya pasaron no se puedan cambiar, para que la agenda refleje lo que ocurrió.
- HU-4. Como admin, quiero bloquear a una clienta con confirmación y que su turno activo se cancele, para que no ocupe una hora que no va a usar.
- HU-5. Como admin, quiero ver a mis clientas ordenadas por nombre y escribirles por WhatsApp desde la lista, para encontrarlas y contactarlas rápido.
- HU-6. Como admin, quiero saber cuándo una acción falla, para no creer que se guardó algo que no se guardó.

## Definiciones
- **Turno activo**: un turno en `waiting_confirmation` o `confirmed` que aún no ha terminado (spec 005).
- **Turno pasado**: un turno cuya hora de fin ya llegó. Se rige por su fin, no por su inicio: un turno en curso no es pasado.
- **Día del salón** y **hora del salón**: los de Curitiba, sea cual sea la zona del dispositivo de la admin.
- **Clienta**: una ficha de usuaria con rol `cliente`. Las admins no son clientas.

## Requisitos funcionales

### Agenda: recorrer los días
- RF-1: EL SISTEMA muestra en la agenda los turnos y los cierres del día del salón elegido, con sus horas en hora del salón, sea cual sea la zona del dispositivo.
- RF-2: CUANDO la admin abre el panel, EL SISTEMA muestra la agenda del día de hoy del salón.
- RF-3: MIENTRAS la agenda muestra un día distinto de hoy, EL SISTEMA ofrece "Hoy", que vuelve al día de hoy del salón.
- RF-4: CUANDO la admin toca la fecha de la agenda, EL SISTEMA abre un calendario para elegir un día, entre 365 días antes y 365 días después de hoy, y al elegirlo muestra la agenda de ese día.
- RF-5: EL SISTEMA mantiene los botones de día anterior y día siguiente, sin límite.
- RF-6: EL SISTEMA muestra en la cabecera de la agenda el número de turnos del día y de los que esperan confirmación, sin contar los cancelados.

### Agenda: acciones sobre un turno
- RF-7: MIENTRAS un turno está activo, EL SISTEMA ofrece en la agenda "Editar" (spec 008) y "Cancelar", y además "Confirmar" si espera confirmación.
- RF-8: MIENTRAS un turno es pasado, EL SISTEMA no ofrece en la agenda "Confirmar", "Cancelar" ni "Editar"; sí el botón de WhatsApp.
- RF-9: SI un turno pasado nunca se confirmó, ENTONCES EL SISTEMA lo muestra en la agenda con la marca "Sin confirmar".
- RF-10: CUANDO un turno pasa a ser pasado mientras la admin mira la agenda, EL SISTEMA retira sus acciones sin recargar, como mucho 1 minuto después.
- RF-11: CUANDO la admin toca "Confirmar", EL SISTEMA confirma el turno sin pedir confirmación.
- RF-12: CUANDO la admin toca "Cancelar", EL SISTEMA le pide confirmación en un diálogo con el nombre de la persona, el día, la hora del salón y el servicio del turno, con "Sí, cancelar" y "No, mantener".
- RF-13: CUANDO la admin elige "No, mantener" o cierra el diálogo, EL SISTEMA no cambia nada.
- RF-14: CUANDO la admin confirma la cancelación, EL SISTEMA marca el turno como cancelado por el salón y libera su hora a la vez: o se hacen las dos cosas o ninguna.
- RF-15: SI al confirmar la cancelación el turno ya no está activo (lo canceló la clienta o ya terminó) o cambió de día, hora o servicio desde que se abrió el diálogo, ENTONCES EL SISTEMA no lo cancela y avisa con un texto distinto para cada caso: que ya no está activo o que cambió y debe revisarlo.
- RF-16: MIENTRAS se guarda una confirmación o una cancelación, EL SISTEMA muestra que está en curso y no deja repetirla.
- RF-17: SI confirmar o cancelar falla por la red o por otro error, ENTONCES EL SISTEMA no cambia el turno, avisa con un texto de la app (nunca el error en crudo) y deja intentarlo de nuevo.
- RF-18: CUANDO se cancela un turno, EL SISTEMA se lo comunica a la admin y lo muestra en la agenda como cancelado, sin recargar.

### Clientas: la lista
- RF-19: EL SISTEMA muestra en la lista de clientas solo a las clientas, nunca a las admins.
- RF-20: EL SISTEMA ordena la lista por nombre, sin distinguir mayúsculas, minúsculas ni acentos.
- RF-21: EL SISTEMA muestra de cada clienta su foto o sus iniciales, su nombre, su WhatsApp y si está bloqueada.
- RF-22: MIENTRAS una clienta tiene WhatsApp, EL SISTEMA ofrece en su fila un botón que abre una conversación de WhatsApp con ella, como en la agenda (spec 007).
- RF-23: CUANDO una clienta se registra, se bloquea, se desbloquea o borra su cuenta, EL SISTEMA actualiza la lista sin recargar.
- RF-24: SI la lista no se puede cargar, ENTONCES EL SISTEMA lo dice con un texto de la app y ofrece "Reintentar".

### Clientas: bloquear y desbloquear
- RF-25: CUANDO la admin pide bloquear a una clienta, EL SISTEMA le pide confirmación en un diálogo con su nombre, que explica que no podrá iniciar sesión ni reservar.
- RF-26: MIENTRAS la clienta que se va a bloquear tiene un turno activo, EL SISTEMA muestra en ese diálogo el día, la hora del salón y el servicio del turno, y avisa de que se cancelará.
- RF-27: CUANDO la admin confirma el bloqueo, EL SISTEMA bloquea a la clienta y, si tiene un turno activo, lo cancela como cancelado por el salón y libera su hora, todo a la vez: o se hace todo o nada.
- RF-28: SI al confirmar el bloqueo el turno activo de la clienta cambió desde que se abrió el diálogo (otro turno, otro día, otra hora o ya no está activo), ENTONCES EL SISTEMA no bloquea y avisa de que debe revisarlo; al volver a pedirlo, el diálogo muestra el turno como está ahora.
- RF-29: CUANDO la admin pide desbloquear a una clienta, EL SISTEMA le pide confirmación en un diálogo con su nombre, que explica que podrá volver a iniciar sesión y reservar.
- RF-30: CUANDO la admin confirma el desbloqueo, EL SISTEMA desbloquea a la clienta; sus turnos cancelados siguen cancelados.
- RF-31: CUANDO la admin elige no seguir o cierra el diálogo, EL SISTEMA no cambia nada.
- RF-32: MIENTRAS se guarda un bloqueo o un desbloqueo, EL SISTEMA muestra que está en curso y no deja repetirlo.
- RF-33: CUANDO se guarda un bloqueo o un desbloqueo, EL SISTEMA se lo comunica a la admin y muestra el estado nuevo en la lista.
- RF-34: SI bloquear o desbloquear falla, ENTONCES EL SISTEMA no cambia nada, avisa con un texto de la app y deja intentarlo de nuevo.
- RF-35: EL SISTEMA solo deja bloquear, desbloquear y cancelar turnos ajenos a la admin. Se comprueba en el servidor.

### Lo que se mantiene
- RF-36: EL SISTEMA sigue ofreciendo desde el panel los cierres, la edición de turnos y el margen (spec 008), los servicios y precios (spec 004), los horarios y reservar para otra persona (spec 007), como hasta ahora.
- RF-37: EL SISTEMA sigue mostrando en la agenda las marcas de cada turno ("Sin cuenta", "Agendado por la admin", "Cancelado por la clienta", "Cuenta eliminada") y su botón de WhatsApp.
- RF-38: EL SISTEMA sigue funcionando con los turnos y las fichas que ya existen, incluidos los turnos sin servicio guardado (anteriores a la spec 005), que se muestran sin servicio.

## Requisitos no funcionales
- RNF-1: Todos los textos nuevos, en español y en portugués (RC-1), y con contraste WCAG AA en tema claro y oscuro en todo el panel, incluida la cabecera verde de la agenda (subtítulo y nombres de los contadores). Los turnos pasados y cancelados se distinguen por su etiqueta y su tono, nunca bajando la opacidad del texto.
- RNF-2: Las acciones (Hoy, la fecha, Confirmar, Cancelar, Editar, WhatsApp, Bloquear, Desbloquear, Reintentar) tienen un área táctil de al menos 48 × 48 px y un nombre para el lector de pantalla; cada fila de clienta se lee como una frase (nombre, WhatsApp, estado), y el control de bloqueo anuncia su estado.
- RNF-3: La agenda, la lista de clientas y los diálogos de esta spec se usan con el texto al 200 % en un ancho de 320 px sin desbordes ni texto cortado.
- RNF-4: Los avisos de éxito y error se anuncian al lector de pantalla.
- RNF-5: Nada se cancela ni se bloquea sin confirmación (constitución, principio 5), y la seguridad de RF-35 está en las reglas del servidor.

## Plataformas
- **Android/iOS:** el panel se abre desde Perfil, como hoy, y sus páginas se apilan sobre él.
- **Web:** el panel es la página de cuenta `/admin` (se llega desde el botón de cuenta de la barra superior), como hoy.
- Todo lo de esta spec es igual en las tres plataformas.

## Navegación
- Panel → agenda de hoy → "<" / ">" → día anterior o siguiente.
- Panel → la fecha → calendario → un día → agenda de ese día.
- Panel → "Hoy" → agenda de hoy.
- Agenda → turno activo → "Cancelar" → diálogo → agenda, con el turno cancelado.
- Agenda → turno → WhatsApp → conversación con la persona (fuera de la app).
- Panel → Clientas → lista → bloquear o desbloquear → diálogo → lista, con el estado nuevo.
- Panel → Clientas → WhatsApp de una clienta → conversación con ella (fuera de la app).
- Lo demás (cierres, servicios, horarios, editar turno, reservar para otra persona) sigue como en las specs 004, 007 y 008.

## Casos límite
- La admin está de viaje o su dispositivo tiene otra zona horaria: la agenda, "Hoy" y el calendario usan el día y la hora del salón (RF-1 a RF-4).
- Un turno empezado y sin terminar: sigue activo, con sus acciones (no es pasado).
- Un turno termina con el diálogo de cancelar abierto: al confirmar, RF-15 ("ya no está activo").
- La clienta cancela su turno con el diálogo de cancelar de la admin abierto: RF-15 ("ya no está activo").
- La clienta edita su turno con el diálogo abierto: RF-15 ("cambió").
- La admin solo confirma el turno con el diálogo de cancelar abierto en otro dispositivo: se cancela igual, porque el día, la hora y el servicio no cambiaron.
- Bloquear a una clienta cuyo turno activo está dentro del margen de edición: se cancela igual (el margen solo limita a la clienta).
- Bloquear a una clienta sin turno activo: solo se bloquea; el diálogo no menciona turnos.
- Bloquear a una clienta con un turno agendado por la admin (spec 007): ese turno es su turno activo y se cancela igual.
- Los turnos de personas sin cuenta no tienen ficha en la lista ni se ven afectados por ningún bloqueo.
- La clienta reserva un turno con el diálogo de bloqueo abierto: RF-28.
- Una clienta bloqueada con la sesión abierta: sigue como hoy (no se cierra su sesión; no puede reservar y sí cancelar, spec 009).
- Una clienta sin WhatsApp (ficha antigua): su fila no tiene botón de WhatsApp y muestra su correo.
- Dos clientas con el mismo nombre: aparecen las dos, una junto a la otra.
- El calendario y los botones de día anterior y siguiente pueden mostrar días cerrados o sin turnos: la agenda dice que no hay turnos o que el salón está cerrado, como hoy.
- Sin conexión: confirmar, cancelar, bloquear y desbloquear fallan con aviso (RF-17, RF-34) y no dejan nada a medias.

## Fuera de alcance
- Buscar clientas o ver una ficha por clienta con su historial.
- Ver la agenda por semana o por mes.
- Confirmar o cancelar varios turnos a la vez.
- Avisar a la clienta (push, correo o WhatsApp automático) de que se canceló su turno o se la bloqueó (spec 011 solo cubre el aviso a la admin).
- Cerrar al momento la sesión de una clienta bloqueada.
- Dar o quitar el rol de admin desde la app, y que la admin borre cuentas.
- Estadísticas o informes más allá de los dos contadores de la cabecera.
- Cambiar los horarios, el margen, los cierres o los servicios (siguen como en las specs 004 y 008).

## Criterios de finalización
- La admin recorre la agenda por días, vuelve a hoy y elige cualquier fecha del calendario, siempre con el día y la hora del salón.
- Cancelar un turno pide confirmación, libera su hora al momento y avisa si falla o si el turno cambió.
- Los turnos pasados no tienen acciones, salvo WhatsApp, y los nunca confirmados se marcan "Sin confirmar".
- La lista de clientas excluye a las admins, está ordenada por nombre y ofrece WhatsApp.
- Bloquear y desbloquear piden confirmación; bloquear cancela el turno activo de la clienta en la misma operación.
- Las reglas del servidor solo permiten a la admin bloquear y cancelar lo ajeno (comprobado en el simulador).
- La cabecera de la agenda pasa la prueba de contraste en tema claro y oscuro.
- Todo funciona en tema claro y oscuro, en español y portugués, en Android/iOS y en Web.
- Todos los tests en verde, `dart format` sin cambios y `flutter analyze` sin avisos.

## Dudas abiertas
Ninguna. Resueltas por el autor el 2026-11-19:
- Alcance: pulir y completar el panel que existe; sin buscador, ficha de clienta ni vista semanal.
- Bloquear a una clienta cancela siempre su turno activo, avisando antes en el diálogo.
- Lista de clientas: sin admins, por nombre y con botón de WhatsApp.
- Agenda: "Hoy" y elegir fecha; "Confirmar" sigue siendo inmediato, solo cancelar pide confirmación.
- Turnos pasados: solo lectura, con WhatsApp y la marca "Sin confirmar" si nunca se confirmó.

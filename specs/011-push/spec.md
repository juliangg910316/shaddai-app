# Spec 011 — Avisos push a la admin
Estado: implementada

## Contexto y objetivo
Hoy la admin solo se entera de lo que hacen sus clientas si abre la agenda: una reserva nueva puede pasar horas esperando confirmación, y una hora que se libera no se aprovecha. La visión del producto pide un "aviso inmediato a la administradora de cada cita nueva", y las specs 006, 007 y 009 dejaron para esta los avisos de los turnos editados y cancelados.

El objetivo es que la admin reciba en su móvil un aviso push en cuanto una clienta reserva, edita o cancela un turno, aunque tenga la app cerrada, y que al tocarlo llegue a la agenda de ese día para actuar.

## Usuarios
- **Admin**: la única que da permiso de notificaciones y recibe avisos, en Android e iOS.
- **Clienta**: no recibe avisos ni se le pide permiso. Lo que hace (reservar, editar, cancelar) genera los avisos.
- **Visitante sin sesión**: nada cambia.

## Historias de usuario
- HU-1. Como admin, quiero recibir un aviso cuando una clienta reserva un turno, para confirmarlo cuanto antes.
- HU-2. Como admin, quiero recibir un aviso cuando una clienta edita su turno, porque vuelve a esperar mi confirmación.
- HU-3. Como admin, quiero recibir un aviso cuando una clienta cancela su turno, para saber que esa hora queda libre.
- HU-4. Como admin, quiero tocar el aviso y llegar a la agenda del día del turno, para confirmarlo o revisarlo sin buscarlo.
- HU-5. Como admin, quiero recibir los avisos en todos los dispositivos donde tengo la sesión iniciada, y dejar de recibirlos en uno al cerrar la sesión.

## Definiciones
- **Aviso**: notificación push del sistema operativo, con título y texto, que llega aunque la app esté cerrada o en segundo plano.
- **Dispositivo de la admin**: un móvil Android o iOS con la app instalada, una sesión de admin iniciada y el permiso de notificaciones concedido.
- **Hora del salón**: la de Curitiba (spec 005), sea cual sea la zona del dispositivo.
- **Turno de una clienta**: un turno con cuenta que no agendó la admin (spec 007). Los que agenda la admin, o los de personas sin cuenta, no lo son.

## Requisitos funcionales

### Qué genera un aviso
- RF-1: CUANDO una clienta reserva un turno, EL SISTEMA envía un aviso "Turno nuevo" a todos los dispositivos de la admin.
- RF-2: CUANDO una clienta guarda un cambio en su turno activo (día, hora, servicio o adicionales, spec 006), EL SISTEMA envía un aviso "Turno modificado" a todos los dispositivos de la admin.
- RF-3: CUANDO una clienta cancela su turno activo (spec 009), también al borrar su cuenta o estando bloqueada, EL SISTEMA envía un aviso "Turno cancelado" a todos los dispositivos de la admin.
- RF-4: EL SISTEMA no envía avisos por lo que hace la admin: agendar para otra persona (spec 007), editar o cancelar un turno, crear cierres (spec 008), confirmar o bloquear (spec 010).
- RF-5: EL SISTEMA envía un solo aviso por cada reserva, cambio o cancelación, aunque la admin tenga varios dispositivos (uno en cada uno).
- RF-6: EL SISTEMA envía el aviso desde el servidor, como mucho 1 minuto después de guardarse el turno, aunque la clienta cierre la app y la de la admin esté cerrada.

### Qué dice el aviso
- RF-7: EL SISTEMA escribe los avisos siempre en español, sea cual sea el idioma de la app de la admin o de la clienta.
- RF-8: EL SISTEMA muestra en el aviso "Turno nuevo" el nombre de la clienta, el día, la hora de inicio del salón y el servicio.
- RF-9: EL SISTEMA muestra en el aviso "Turno modificado" el nombre de la clienta y el día, la hora de inicio del salón y el servicio como quedaron, y que espera confirmación.
- RF-10: EL SISTEMA muestra en el aviso "Turno cancelado" el nombre de la clienta, el día y la hora de inicio del salón, y que esa hora queda libre; si la clienta borró su cuenta, lo dice.
- RF-11: SI el turno no tiene servicio guardado (anterior a la spec 005), ENTONCES EL SISTEMA envía el aviso sin servicio.

### Al tocar el aviso
- RF-12: CUANDO la admin toca un aviso, EL SISTEMA abre la app en el panel con la agenda del día del salón del turno, también si la app estaba cerrada.
- RF-13: SI al tocar el aviso la sesión iniciada en ese dispositivo no es de admin (cerró sesión o entró otra cuenta), ENTONCES EL SISTEMA solo abre la app, sin ir al panel.
- RF-14: MIENTRAS la app está abierta en primer plano, CUANDO llega un aviso, EL SISTEMA lo muestra dentro de la app con su título y su texto y con un botón "Ver" que abre la agenda de ese día; no interrumpe lo que la admin está haciendo y se cierra solo.

### Permiso y dispositivos
- RF-15: CUANDO una admin entra en la app en Android o iOS con su sesión iniciada y aún no se le ha pedido permiso en ese dispositivo, EL SISTEMA le explica para qué sirven los avisos y después le pide el permiso de notificaciones del sistema.
- RF-16: EL SISTEMA nunca pide el permiso de notificaciones a una clienta ni a un visitante, ni guarda nada de sus dispositivos para avisos.
- RF-17: MIENTRAS la admin tiene el permiso de notificaciones denegado en ese dispositivo, EL SISTEMA lo indica en el panel con un texto que explica cómo activarlo en los ajustes del teléfono, sin volver a pedirlo.
- RF-18: CUANDO la admin concede el permiso, EL SISTEMA registra ese dispositivo para recibir avisos; si después lo activa desde los ajustes del teléfono, lo registra la próxima vez que abra la app.
- RF-19: EL SISTEMA mantiene registrados a la vez todos los dispositivos de la admin, y a todas las admins si hay más de una.
- RF-20: CUANDO la admin cierra sesión en un dispositivo, EL SISTEMA deja de enviarle avisos a ese dispositivo; los demás siguen recibiéndolos.
- RF-21: SI un dispositivo registrado deja de ser válido (se desinstaló la app o se renovó su registro), ENTONCES EL SISTEMA deja de enviarle avisos y, si la app sigue instalada, lo vuelve a registrar al abrirse.
- RF-22: SI una usuaria deja de ser admin, ENTONCES EL SISTEMA deja de enviar avisos a sus dispositivos.
- RF-23: EL SISTEMA solo deja a cada admin registrar o quitar sus propios dispositivos, y solo el servidor lee los registros para enviar avisos. Se comprueba en el servidor.

### Errores
- RF-24: SI el aviso no se puede enviar, ENTONCES EL SISTEMA guarda igual la reserva, el cambio o la cancelación, y la clienta no ve ningún error.
- RF-25: SI no se puede registrar o quitar un dispositivo (sin conexión, por ejemplo), ENTONCES EL SISTEMA no muestra errores en crudo ni impide usar la app o cerrar sesión, y lo intenta otra vez la próxima vez que se abra la app.

## Requisitos no funcionales
- RNF-1: Los textos nuevos de la app (la explicación del permiso, el aviso de permiso denegado, el aviso dentro de la app con "Ver") en español y portugués (RC-1), con contraste WCAG AA en tema claro y oscuro. Los avisos push van solo en español (RF-7).
- RNF-2: El botón "Ver" y las acciones de la explicación del permiso tienen un área táctil de al menos 48 × 48 px y un nombre para el lector de pantalla; el aviso dentro de la app se anuncia al lector.
- RNF-3: La explicación del permiso y el aviso de permiso denegado se usan con el texto al 200 % en un ancho de 320 px sin desbordes ni texto cortado.
- RNF-4: Los avisos no llevan el WhatsApp, el correo ni la foto de la clienta: solo su nombre y los datos del turno (constitución, principio 5).
- RNF-5: La seguridad de RF-23 está en las reglas del servidor, y el envío de avisos no depende de que la app de la clienta siga abierta.

## Plataformas
- **Android/iOS:** todo lo de esta spec. En iOS se escribe y se prueba en el simulador hasta donde se pueda; recibir avisos reales en iOS necesita la cuenta de desarrollador de Apple (spec 013).
- **Web:** no recibe avisos ni pide permiso. La admin que usa el panel en Web lo ve como hoy. Lo que hacen las clientas desde Web sí genera avisos (RF-1 a RF-3).

## Navegación
- Aviso (app cerrada, en segundo plano o en primer plano con "Ver") → panel con la agenda del día del turno.
- Desde la agenda abierta así, la admin sigue como en la spec 010 ("<" / ">", "Hoy", la fecha, confirmar, cancelar, editar).
- Primera entrada como admin en un dispositivo → explicación del permiso → diálogo del sistema → donde estaba.

## Casos límite
- La admin tiene la app abierta en otra pantalla (por ejemplo, editando un turno): el aviso dentro de la app no la interrumpe; "Ver" la lleva a la agenda solo si lo toca (RF-14).
- La clienta reserva y cancela enseguida: llegan los dos avisos, en orden.
- La clienta edita su turno varias veces seguidas: un aviso por cada cambio guardado.
- La clienta intenta reservar o editar y no se guarda (hora ocupada, error): no hay aviso.
- La admin cancela un turno de una clienta o la bloquea: no hay aviso (RF-4).
- La admin agenda un turno para una clienta con cuenta: no hay aviso (RF-4), y si después esa clienta lo cancela, sí (RF-3).
- Una persona sin cuenta no puede reservar, editar ni cancelar por sí misma: sus turnos nunca generan avisos.
- La admin cierra sesión sin conexión: la sesión se cierra igual (RF-25); ese dispositivo deja de recibir avisos en cuanto vuelva a tener conexión y se abra la app.
- La admin y una clienta usan el mismo teléfono: tras cerrar la admin su sesión, la clienta no recibe los avisos de la admin (RF-20).
- La admin denegó el permiso y luego lo activa en los ajustes: empieza a recibir avisos tras abrir la app (RF-18).
- El turno está en otro día que el que muestra la agenda: tocar el aviso cambia la agenda a ese día.
- Un aviso de un turno que ya se canceló o cambió cuando la admin lo toca: abre la agenda de ese día, que muestra el turno como está ahora.
- No hay ninguna admin con dispositivos registrados: no se envía nada y las clientas reservan igual (RF-24).

## Fuera de alcance
- Avisos en Web (notificaciones del navegador).
- Avisos a las clientas: confirmaciones, cancelaciones del salón, recordatorios, promociones o campañas.
- Avisos en portugués o en el idioma de la app de la admin.
- La foto de la clienta en el aviso.
- Elegir qué avisos se reciben, horas de silencio o sonidos propios.
- Un historial de avisos dentro de la app.
- Avisos de turnos que empiezan pronto o que siguen sin confirmar.

## Criterios de finalización
- Una reserva, un cambio y una cancelación de una clienta llegan como aviso a todos los dispositivos de la admin, con la app cerrada y abierta, en Android (y en iOS cuando haya cuenta de Apple).
- Lo que hace la admin no genera avisos.
- Tocar un aviso abre la agenda del día del turno.
- El permiso solo se pide a la admin, después de explicarlo, y su rechazo se indica en el panel.
- Cerrar sesión deja de enviar avisos a ese dispositivo.
- Las reglas del servidor protegen los registros de los dispositivos (comprobado en el simulador), y el envío tiene tests sin Firebase real.
- Todo lo visible en la app funciona en tema claro y oscuro, en español y portugués.
- Todos los tests en verde, `dart format` sin cambios y `flutter analyze` sin avisos.

## Dudas abiertas
Ninguna. Resueltas por el autor el 2026-11-20:
- Eventos: turno nuevo, editado y cancelado por una clienta; nada de lo que hace la admin.
- Idioma: siempre español.
- Plataformas: Android e iOS; Web sin avisos.
- Al tocarlo: la agenda del día del turno.
- Permiso y registro de dispositivos: solo la admin; nada de las clientas.

Decisiones tomadas en la redacción (cámbialas si no te convencen):
- La cancelación por borrar la cuenta (spec 009) cuenta como cancelación de la clienta (RF-3).
- Sin foto de la clienta en el aviso (RNF-4, fuera de alcance), aunque el documento de alcance original la mencionaba: evita datos personales en la pantalla de bloqueo.
- Con la app abierta, el aviso se muestra dentro de la app con "Ver" (RF-14), en lugar de una notificación del sistema.

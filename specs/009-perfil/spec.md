# Spec 009 — Perfil y mis turnos
Estado: aprobada

## Contexto y objetivo
Hoy el perfil muestra la foto, el nombre y el WhatsApp de la clienta y una lista plana de todos sus turnos (fecha, hora y estado). Le faltan cosas:
- la hora se muestra en la zona del dispositivo y no en la del salón, así que una clienta que viaja ve una hora equivocada;
- la lista no dice qué servicio reservó ni separa el turno que viene de los ya pasados;
- no puede cancelar su turno (las specs 005 y 006 lo dejaron para esta), así que tiene que escribir al salón y la hora queda ocupada hasta que la admin lo cancela;
- no puede cambiar su WhatsApp después de registrarlo;
- no puede borrar su cuenta, y la App Store lo exige a toda app que permite crear una.

El objetivo es que la clienta gestione sola su turno y su cuenta desde el perfil: ver su turno activo y su historial con la hora del salón, cancelar su turno sin intermediarios (liberando la hora para otras), mantener al día su WhatsApp y borrar su cuenta.

## Usuarios
- **Clienta**: con sesión y WhatsApp registrado. Es quien usa todo lo de esta spec.
- **Admin**: ve su perfil como hoy (con acceso al panel). No cancela desde aquí (lo hace desde su agenda), no tiene turno activo propio (spec 007) y no puede borrar su cuenta desde la app.
- **Visitante sin sesión**: en Android/iOS ve el perfil de invitada como hoy (preferencias y botón para iniciar sesión). Nada cambia para ella.

## Historias de usuario
- HU-1. Como clienta, quiero ver mi próximo turno destacado, con el día, la hora del salón, el servicio y su estado, para saber de un vistazo cuándo tengo que ir y si ya está confirmado.
- HU-2. Como clienta, quiero cancelar mi turno desde la app, para no tener que escribir al salón y para que otra persona pueda usar esa hora.
- HU-3. Como clienta, quiero ver mis turnos pasados y cancelados, para recordar qué me hice y cuándo.
- HU-4. Como clienta, quiero cambiar mi número de WhatsApp, para que el salón pueda contactarme si cambio de número.
- HU-5. Como clienta, quiero borrar mi cuenta y mis datos, para dejar de usar la app sin dejar mis datos en ella.
- HU-6. Como admin, quiero que la hora de un turno que la clienta cancela quede libre al momento y ver ese turno como cancelado en mi agenda, para poder ofrecerla a otra persona.

## Definiciones
- **Turno activo**: el turno de la clienta en `waiting_confirmation` o `confirmed` que aún no ha terminado (spec 005). Una clienta tiene como mucho uno.
- **Margen de edición**: los minutos antes del inicio a partir de los cuales la clienta ya no puede cambiar su turno; los fija la admin (specs 006 y 008). En esta spec, el mismo margen vale para cancelar.
- **Cancelable**: un turno activo que empieza más allá del margen de edición desde ahora.
- **Historial**: los turnos de la clienta que no son el activo: los cancelados (por ella o por la admin) y los que ya terminaron.
- **Hora del salón**: la hora de Curitiba, con la que se reserva y se muestra todo turno, sea cual sea la zona del dispositivo.

## Requisitos funcionales

### Turno activo en el perfil
- RF-1: MIENTRAS la clienta tiene un turno activo, EL SISTEMA lo muestra en el perfil destacado y por encima del historial, con el día de la semana, la fecha, la hora de inicio y fin, el servicio y los adicionales, y su estado ("Esperando confirmación" o "Confirmado").
- RF-2: EL SISTEMA muestra la fecha y las horas de todo turno del perfil en hora del salón, sea cual sea la zona horaria del dispositivo.
- RF-3: MIENTRAS el turno activo es cancelable, EL SISTEMA ofrece en su tarjeta del perfil "Editar turno", que abre la edición de la spec 006, y "Cancelar turno".
- RF-4: MIENTRAS el turno activo no es cancelable, EL SISTEMA no ofrece "Editar turno" ni "Cancelar turno", explica que falta poco para el turno y ofrece escribir al salón por WhatsApp.
- RF-5: MIENTRAS la clienta no tiene turno activo, EL SISTEMA muestra en su lugar que no tiene turnos próximos y el acceso para reservar uno.
- RF-6: CUANDO el turno activo cambia (la admin lo confirma, lo edita o lo cancela, o termina), EL SISTEMA actualiza el perfil sin recargar: si deja de estar activo, pasa al historial.
- RF-7: CUANDO el turno activo deja de ser cancelable mientras la clienta mira el perfil, EL SISTEMA retira "Editar turno" y "Cancelar turno" sin recargar, como mucho 1 minuto después.

### Cancelar el turno
- RF-8: EL SISTEMA ofrece "Cancelar turno" en dos lugares, con el mismo comportamiento: la vista de su turno activo en Reservas (junto a "Editar turno", spec 006) y la tarjeta del turno activo en el perfil.
- RF-9: CUANDO la clienta toca "Cancelar turno", EL SISTEMA le pide confirmación en un diálogo que muestra el día, la hora del salón y el servicio del turno, con "Sí, cancelar" y "No, mantener".
- RF-10: CUANDO la clienta elige "No, mantener" o cierra el diálogo, EL SISTEMA no cambia nada.
- RF-11: CUANDO la clienta confirma, EL SISTEMA marca el turno como cancelado por la clienta y libera su hora a la vez: o se hacen las dos cosas o ninguna.
- RF-12: CUANDO se cancela el turno, EL SISTEMA se lo comunica a la clienta, lo pasa a su historial y le vuelve a mostrar en Reservas la vista para reservar (spec 005, RF-35), sin recargar.
- RF-13: CUANDO la clienta cancela su turno, EL SISTEMA ofrece esa hora como libre a cualquier persona que reserve, sin recargar (spec 005, RF-6).
- RF-14: SI al confirmar el turno ya no es cancelable, ya no está activo o cambió desde que la clienta lo vio, ENTONCES EL SISTEMA no lo cancela, muestra el turno como está ahora y avisa con un texto distinto para cada caso: que falta poco para el turno (con el acceso a WhatsApp del salón), que el turno ya no está activo, o que el turno cambió y debe revisarlo antes de cancelar.
- RF-15: SI la cancelación falla por la red o por otro error, ENTONCES EL SISTEMA no cambia el turno, avisa con un texto de la app (nunca el error en crudo) y deja intentarlo de nuevo.
- RF-16: MIENTRAS se guarda la cancelación, EL SISTEMA muestra que está en curso y no deja confirmarla otra vez.
- RF-17: CUANDO la clienta cancela su turno mientras lo estaba editando (spec 006), EL SISTEMA cierra la edición sin guardar sus cambios.
- RF-18: EL SISTEMA muestra a la admin, en su agenda, el turno cancelado por la clienta como cancelado e indica que lo canceló la clienta, sin recargar.
- RF-19: EL SISTEMA solo deja a una clienta cancelar su propio turno activo y cancelable, y solo cambiando su estado a cancelado y liberando su hora: no puede borrarlo ni tocar otros datos. Se comprueba en el servidor.

### Historial
- RF-20: EL SISTEMA muestra bajo el turno activo el historial de la clienta, del más reciente al más antiguo, cada turno con su fecha, la hora del salón, el servicio y su estado: "Cancelado por ti", "Cancelado por el salón" o "Realizado" (turno confirmado ya terminado).
- RF-21: SI un turno terminó sin haber sido confirmado ni cancelado, ENTONCES EL SISTEMA lo muestra en el historial como "No confirmado".
- RF-22: MIENTRAS el historial está vacío, EL SISTEMA no muestra la sección de historial.
- RF-23: EL SISTEMA no ofrece ninguna acción sobre los turnos del historial.
- RF-24: SI no se pueden cargar los turnos, ENTONCES EL SISTEMA lo indica con un texto de la app y ofrece "Reintentar", sin ocultar el resto del perfil (datos, preferencias, salir).

### Cambiar el WhatsApp
- RF-25: EL SISTEMA muestra en el perfil el WhatsApp de la clienta con la acción "Cambiar".
- RF-26: CUANDO la clienta toca "Cambiar", EL SISTEMA le pide el número nuevo con las mismas reglas de validación y el mismo consentimiento que al registrarlo, con el número actual ya escrito.
- RF-27: SI el número no es válido o falta el consentimiento, ENTONCES EL SISTEMA no lo guarda y señala el error junto al campo.
- RF-28: CUANDO la clienta guarda un número válido, EL SISTEMA lo guarda en su cuenta, lo muestra en el perfil sin recargar y lo copia también a su turno activo, si tiene uno; los turnos del historial conservan el número que tenían.
- RF-29: CUANDO la clienta cancela el cambio, EL SISTEMA conserva el número anterior.
- RF-30: SI el guardado falla, ENTONCES EL SISTEMA conserva el número anterior, avisa con un texto de la app y deja intentarlo de nuevo.

### Borrar la cuenta
- RF-31: MIENTRAS la persona es clienta, EL SISTEMA ofrece en el perfil "Eliminar mi cuenta"; a la admin no se lo ofrece.
- RF-32: CUANDO la clienta toca "Eliminar mi cuenta", EL SISTEMA le explica qué se borra y qué se conserva (RF-34, RF-35) y le pide confirmarlo dos veces: primero en ese aviso y después escribiendo una palabra de confirmación que el aviso le indica.
- RF-33: CUANDO la clienta cancela en cualquiera de los dos pasos, EL SISTEMA no borra nada.
- RF-34: CUANDO la clienta confirma, EL SISTEMA cancela su turno activo (si lo tiene) liberando su hora, sea cual sea el margen de edición, y borra su ficha (nombre, correo, foto, WhatsApp, token de notificaciones) y su cuenta de inicio de sesión.
- RF-35: CUANDO se borra la cuenta, EL SISTEMA conserva los turnos de la clienta para la agenda de la admin con su nombre y su WhatsApp (la admin sigue pudiendo escribirle), pero sin su foto, y la admin los ve marcados como de una "Cuenta eliminada".
- RF-36: CUANDO termina el borrado, EL SISTEMA cierra la sesión, se lo comunica y la lleva al inicio (la landing en Web, Inicio en Android/iOS).
- RF-37: EL SISTEMA hace el borrado completo (RF-34 y RF-35) en el servidor, a petición de la clienta con su sesión iniciada, sin pedirle que vuelva a iniciar sesión.
- RF-38: MIENTRAS se borra la cuenta, EL SISTEMA muestra que está en curso y no deja pedirlo otra vez.
- RF-39: SI el borrado falla a mitad, ENTONCES EL SISTEMA avisa con un texto de la app y deja reintentarlo; reintentar completa lo que faltaba sin repetir ni romper lo ya hecho.
- RF-40: SI la clienta está bloqueada, ENTONCES EL SISTEMA no borra su cuenta (ni en la app ni en el servidor) y le indica que hable con el salón, para que el bloqueo no se pierda.
- RF-41: CUANDO una persona con la cuenta borrada vuelve a iniciar sesión con Google, EL SISTEMA la trata como una cuenta nueva (pide su WhatsApp otra vez) y no le muestra los turnos anteriores.
- RF-42: EL SISTEMA solo borra la cuenta de la persona que lo pide, y nunca la de una admin. Se comprueba en el servidor.

### Lo que se mantiene
- RF-43: EL SISTEMA sigue mostrando en el perfil la foto, el nombre, el acceso al panel (solo la admin), "Reservar otro turno" (solo sin turno activo), las preferencias (solo en Android/iOS) y "Cerrar sesión", como hasta ahora.
- RF-44: EL SISTEMA sigue funcionando con los turnos y las fichas que ya existen, incluidos los turnos sin servicio guardado (anteriores a la spec 005), que se muestran sin servicio.

## Requisitos no funcionales
- RNF-1: Todos los textos nuevos, en español y en portugués (RC-1), y con contraste WCAG AA en tema claro y oscuro; los turnos cancelados o pasados se distinguen por su etiqueta y su tono, nunca bajando la opacidad del texto.
- RNF-2: Las acciones (Editar, Cancelar, Cambiar, Eliminar, Reintentar, WhatsApp) tienen un área táctil de al menos 48 × 48 px y un nombre para el lector de pantalla; cada tarjeta de turno se lee como una frase (fecha, hora, servicio, estado).
- RNF-3: El perfil se usa con el texto al 200 % en un ancho de 320 px sin desbordes ni texto cortado.
- RNF-4: Los avisos de éxito y error se anuncian al lector de pantalla.
- RNF-5: Nada se borra ni se cancela sin confirmación (constitución, principio 5), y la seguridad de RF-19 y RF-42 está en las reglas del servidor.

## Plataformas
- **Android/iOS:** el perfil es la pestaña Perfil de la barra inferior, con las preferencias al final. "Cerrar sesión" sigue en la cabecera.
- **Web:** el perfil es la página de cuenta `/profile` (centrada, como las demás páginas de cuenta), sin preferencias (están en la barra superior). Al borrar la cuenta vuelve a la landing.
- El resto (turno activo, historial, cancelar, cambiar WhatsApp, borrar la cuenta) es igual en las tres plataformas.

## Navegación
- Perfil → tarjeta del turno activo → "Editar turno" → edición en Reservas (spec 006) → al guardar o cancelar la edición, se queda en Reservas.
- Perfil → tarjeta del turno activo → "Cancelar turno" → diálogo → Perfil, con el turno en el historial.
- Reservas → su turno activo → "Cancelar turno" → diálogo → Reservas, con la vista para reservar.
- Perfil → turno no cancelable → "Escribir al salón" → WhatsApp del salón (fuera de la app).
- Perfil → sin turno activo → "Reservar" → Reservas.
- Perfil → WhatsApp → "Cambiar" → formulario del número → Perfil.
- Perfil → "Eliminar mi cuenta" → aviso → palabra de confirmación → inicio sin sesión.

## Casos límite
- El turno empieza justo en el límite del margen: deja de ser cancelable en ese mismo minuto (igual que editar, spec 006).
- Margen de edición 0: se puede cancelar hasta la hora de inicio; una vez empezado, no.
- La admin cancela, confirma o edita el turno con el diálogo de cancelar abierto: al confirmar se aplica RF-14 (cancelado por la admin → "ya no está activo"; confirmado sin otros cambios → se cancela igual, porque el día, la hora y el servicio no cambiaron; editado → "el turno cambió").
- La admin cambia el margen con el diálogo abierto y el turno deja de ser cancelable: RF-14.
- La clienta tiene la app abierta en dos dispositivos y cancela en uno: el otro lo pasa al historial sin recargar (RF-6).
- Turno agendado por la admin para la clienta (spec 007): se muestra y se cancela igual que uno reservado por ella.
- Turno sin cuenta (spec 007): no aparece en ningún perfil.
- La admin cambió la persona del turno (spec 008): deja de verlo la clienta anterior y lo ve la nueva.
- Turno antiguo sin servicio guardado: se muestra sin servicio (RF-44).
- El dispositivo está en otra zona horaria: todo se muestra en hora del salón (RF-2).
- La clienta pone el mismo WhatsApp que ya tenía: se guarda sin cambios visibles.
- La clienta borra su cuenta con un turno activo dentro del margen: se cancela igual (RF-34).
- La clienta es bloqueada mientras tiene el perfil abierto: no puede borrar la cuenta (RF-40); cancelar su turno activo sigue permitido.
- Sin conexión: cancelar, cambiar el número y borrar la cuenta fallan con aviso (RF-15, RF-30, RF-39) y no dejan nada a medias que no se pueda reintentar.

## Fuera de alcance
- Avisar a la admin (push) de que la clienta canceló (spec 011), y avisar a la clienta de cualquier cambio.
- Que la clienta pida la cancelación fuera del margen desde la app (lo hace por WhatsApp).
- Cambiar el nombre o la foto (vienen de Google).
- Paginar o filtrar el historial.
- Que la admin borre cuentas ajenas o la suya desde la app.
- Borrar del todo los turnos de una cuenta eliminada, o su nombre y WhatsApp en ellos (se conservan para la admin, RF-35).
- Impedir que una clienta bloqueada cree otra cuenta con otra cuenta de Google.
- Política de privacidad y textos legales (spec 013).

## Criterios de finalización
- La clienta ve su turno activo y su historial con la hora del salón y el servicio, en tema claro y oscuro, en español y portugués, en Android/iOS y en Web.
- La clienta cancela su turno desde Reservas y desde Perfil, con confirmación; la hora queda libre al momento para otras personas y la admin lo ve como cancelado por la clienta.
- Fuera del margen no puede cancelar ni editar y se le ofrece WhatsApp.
- La clienta cambia su WhatsApp y el cambio llega a su turno activo.
- La clienta borra su cuenta con doble confirmación; su ficha y su cuenta de inicio de sesión desaparecen y sus turnos quedan como "Cuenta eliminada", con su nombre y su WhatsApp para la admin.
- El borrado en el servidor está probado sin usar Firebase real.
- Las reglas del servidor impiden cancelar o borrar lo ajeno, y cancelar fuera del margen (comprobado en el simulador).
- Todos los tests en verde, `dart format` sin cambios y `flutter analyze` sin avisos.

## Dudas abiertas
Ninguna. Resueltas por el autor el 2026-11-18:
- El borrado de la cuenta (incluida la de inicio de sesión) lo hace una función en el servidor, que se escribe en esta spec (RF-37).
- La admin sigue viendo el nombre y el WhatsApp en los turnos de una cuenta borrada (RF-35).

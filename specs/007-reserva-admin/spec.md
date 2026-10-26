# Spec 007 — Reserva de la admin
Estado: borrador

## Contexto y objetivo
Con la spec 005, la admin no puede agendar turnos: no reserva a su propio nombre, y no tiene forma de apuntar los turnos que le piden por WhatsApp, por teléfono o en el salón. Esta spec le deja reservar desde la misma vista de reserva, siempre para otra persona:
- una clienta con cuenta;
- o alguien sin cuenta, con su nombre y su WhatsApp.

Así todos los turnos del salón están en la app y ocupan sus horas.

Depende de la spec 005, que tiene que estar implementada. Tercera de las tres specs de reservas (división decidida por el autor el 2026-10-24).

## Usuarios
- **Admin**: reserva para una clienta con cuenta o para una persona sin cuenta, nunca para sí misma.
- **Cliente** con cuenta: ve como suyo el turno que le agenda la admin.
- **Persona sin cuenta**: no usa la app; solo se guardan su nombre y su WhatsApp en el turno.

## Historias de usuario
- HU-1. Como admin, quiero agendar el turno que una clienta me pide por WhatsApp o en el salón, aunque no tenga cuenta, para tener todos los turnos en la app.
- HU-2. Como admin, quiero encontrar rápido a una clienta por su nombre o su WhatsApp.
- HU-3. Como clienta, quiero ver en la app el turno que me agendó la admin.

## Definiciones
Las de la spec 005, más:
- **Para quién**: la persona a cuyo nombre queda el turno que agenda la admin. Es una de estas dos:
  - una **clienta con cuenta**: rol clienta, no bloqueada y con WhatsApp;
  - una **persona sin cuenta**: un nombre y un WhatsApp que escribe la admin.
- **WhatsApp normalizado**: solo los dígitos del WhatsApp, sin espacios, guiones, paréntesis ni el prefijo 55 de Brasil. Dos WhatsApp son el mismo si su versión normalizada coincide.
- **Persona**: una clienta con cuenta y una persona sin cuenta con el mismo WhatsApp normalizado cuentan como la misma persona para el turno activo.
- **Turno activo de una persona**: turno a su nombre, o con su WhatsApp normalizado, que empieza después de "ahora" y está esperando confirmación o confirmado.
- **WhatsApp válido**: al menos 8 dígitos y como mucho 15, una vez normalizado.

## Requisitos funcionales

### Para quién
- RF-1: MIENTRAS la sesión es de la admin, EL SISTEMA muestra la vista de reserva con "Para quién" al principio, sin nada elegido, en lugar del texto de la spec 005 (RF-39).
- RF-2: EL SISTEMA nunca guarda un turno a nombre de la propia admin.
- RF-3: CUANDO la admin escribe al menos 2 caracteres en la búsqueda de "Para quién", EL SISTEMA le ofrece hasta 20 clientas con cuenta, en orden alfabético, cuyo nombre contiene lo escrito sin distinguir mayúsculas ni acentos, o cuyo WhatsApp normalizado contiene los dígitos escritos.
- RF-4: EL SISTEMA no ofrece en la búsqueda a las clientas bloqueadas, a las admins ni a las cuentas sin WhatsApp.
- RF-5: SI la búsqueda no encuentra a nadie, ENTONCES EL SISTEMA lo indica y ofrece "Persona sin cuenta".
- RF-6: SI no se pueden cargar las clientas, ENTONCES EL SISTEMA muestra un aviso con "Reintentar" y deja usar "Persona sin cuenta".
- RF-7: CUANDO la admin elige "Persona sin cuenta", EL SISTEMA le pide el nombre (obligatorio, como mucho 80 caracteres) y el WhatsApp (obligatorio y válido).
- RF-8: CUANDO la admin elige "Persona sin cuenta", EL SISTEMA le pide además que confirme, con una casilla obligatoria, que la persona acepta dar su nombre y su WhatsApp para el turno.
- RF-9: SI el nombre está vacío o es demasiado largo, el WhatsApp no es válido o la casilla no está marcada, ENTONCES EL SISTEMA no agenda y marca el campo.
- RF-10: CUANDO la admin sale del campo de WhatsApp de "Persona sin cuenta" y el número coincide con el de una clienta con cuenta, EL SISTEMA se lo avisa y le propone elegir a esa clienta. Si la admin sigue como persona sin cuenta, el turno se guarda así.
- RF-11: SI ese WhatsApp coincide con el de una clienta bloqueada, ENTONCES EL SISTEMA avisa de que esa clienta está bloqueada y no agenda.

### Reglas de la reserva de la admin
- RF-12: MIENTRAS reserva la admin, EL SISTEMA aplica las reglas de la vista de reserva de la spec 005, salvo la ventana de reserva: deja elegir fechas desde hoy hasta 365 días después.
- RF-13: MIENTRAS reserva la admin, EL SISTEMA no deja elegir días cerrados ni fechas bloqueadas, ni, con la spec 008, horas dentro de un cierre.
- RF-14: SI la persona elegida ya tiene un turno activo, ENTONCES EL SISTEMA no deja agendar otro, se lo indica a la admin con la fecha, la hora y lo reservado de ese turno, y conserva lo elegido.
- RF-15: SI la admin bloquea a la clienta elegida antes de confirmar, ENTONCES EL SISTEMA no guarda el turno, la quita de "Para quién" y avisa.

### Agendar
- RF-16: EL SISTEMA muestra en el resumen y en la confirmación, antes que lo demás, para quién es el turno.
- RF-17: SI se toca "Agendar turno" sin para quién, sin hora o sin servicio, ENTONCES EL SISTEMA no agenda, indica qué falta y marca cada parte sin elegir.
- RF-18: CUANDO la admin confirma, EL SISTEMA comprueba otra vez la hora, que el servicio cabe y el turno activo de la persona (RF-14), como en la spec 005 (RF-26).
- RF-19: CUANDO se cumplen las comprobaciones, EL SISTEMA guarda el turno confirmado, con la copia de lo reservado (spec 005, RF-27), marca que lo creó la admin y guarda:
  - de una clienta con cuenta, su cuenta, su nombre y su WhatsApp;
  - de una persona sin cuenta, solo su nombre, su WhatsApp y que no tiene cuenta.
- RF-20: CUANDO la admin guarda un turno, EL SISTEMA confirma que está agendado y deja la vista lista para agendar otro, sin nada elegido, también en Web (en lugar de ofrecer volver a la landing).

### Clienta con cuenta y lista de la admin
- RF-21: CUANDO la admin agenda un turno para una clienta con cuenta, EL SISTEMA se lo muestra a la clienta como su turno activo (spec 005, RF-33) sin recargar, y en su perfil.
- RF-22: EL SISTEMA muestra en la lista de turnos de la admin los turnos de personas sin cuenta con su nombre y su WhatsApp, marcados como "sin cuenta", con el enlace a WhatsApp y sin foto.
- RF-23: EL SISTEMA muestra en la lista de turnos de la admin cuáles creó ella.
- RF-24: EL SISTEMA sigue mostrando bien los turnos de personas sin cuenta en todas las vistas que ya leen turnos (lista de la admin y cálculo de horas libres), aunque no tengan cuenta asociada.

### Seguridad y privacidad
- RF-25: EL SISTEMA solo deja a la admin crear turnos confirmados, turnos a nombre de otra persona y turnos de personas sin cuenta. Se comprueba en el servidor.
- RF-26: EL SISTEMA solo deja leer el nombre y el WhatsApp de una persona sin cuenta a la admin. Se comprueba en el servidor.

## Requisitos no funcionales
- RNF-1: Son reglas puras, probadas con tablas de casos:
  - la normalización y la validez del WhatsApp (espacios, guiones, paréntesis, +55, 55 delante y números cortos);
  - la búsqueda de "Para quién" (acentos, mayúsculas, dígitos, límite de 20 y orden);
  - el turno activo de una persona, con cuenta y por WhatsApp;
  - la ventana de 365 días.
- RNF-2: Mismos requisitos de contraste, 48 px, lector de pantalla, texto al 200 % y 320 px que la spec 005, también en "Para quién".
- RNF-3: Todos los textos nuevos de la interfaz están en español y en portugués.
- RNF-4: De una persona sin cuenta solo se guardan su nombre y su WhatsApp, dentro del turno, sin una ficha aparte (constitución, principio 5).
- RNF-5: Las reglas de RF-25 y RF-26 se comprueban caso por caso en el simulador.

## Plataformas
- **Android/iOS**: la admin reserva en la pestaña Reservas, con la barra inferior visible.
- **Web**: la admin reserva en la página de reserva. Tras agendar se queda en ella (RF-20).

## Navegación
- Admin → Reservas (o "Reservar" en Web) → "Para quién" → fecha, hora y servicio → "Agendar turno" → confirmar → vista vacía para el siguiente.
- Admin → detalle de un servicio → "Reservar cita" → reserva con ese servicio elegido y sin para quién.
- Los turnos agendados se ven en el panel de la admin.

## Casos límite
- Dos admins: tampoco aparecen en la búsqueda ni reciben turnos.
- La clienta elegida cambia su WhatsApp después: el turno conserva el que tenía al agendar.
- La persona sin cuenta se registra después con el mismo WhatsApp: sus turnos anteriores no se unen a su cuenta; mientras uno esté activo, cuenta como su turno activo para RF-14, pero ella no lo ve en la app.
- La admin agenda un turno para una clienta que tiene la reserva abierta: la clienta pasa a ver su turno activo sin recargar (RF-21).
- La clienta y la admin confirman a la vez un turno para la misma clienta: el segundo no se guarda (RF-18); la garantía en el servidor llega con la spec 012.
- La admin cambia de idioma con la confirmación abierta: se traduce.

## Fuera de alcance
- Unir los turnos de una persona sin cuenta a su cuenta si después se registra.
- Editar los datos de una persona sin cuenta o cambiar la persona de un turno (spec 008).
- Que la admin agende turnos que se solapen, que pasen del cierre o en días cerrados o bloqueados.
- Aviso push de los turnos que crea la admin (spec 011).
- Política de privacidad (spec 013).

## Criterios de finalización
- Todos los RF tienen su test y pasan. `flutter analyze` sin errores ni avisos y `dart format` sin cambios.
- Las reglas puras de RNF-1 tienen tests de tabla.
- El autor comprueba las reglas de RF-25 y RF-26 en el simulador.
- Recorrido manual del autor en Android/iOS y en Web, en tema claro y oscuro y en español y portugués. Incluye:
  - agendar para una clienta con cuenta, que lo ve como su turno activo;
  - agendar para una persona sin cuenta, más allá de 60 días;
  - el aviso de un WhatsApp que ya tiene cuenta y el de una clienta bloqueada;
  - el bloqueo por turno activo de la persona;
  - ver los turnos en la lista de la admin.

## Dudas abiertas
Ninguna. Resueltas con el autor (2026-10-24):
- La admin reserva siempre para otra persona: una clienta con cuenta (no bloqueada) o una persona sin cuenta, con nombre y WhatsApp obligatorios.
- Sus turnos quedan confirmados y sin el límite de 60 días; se mantienen un turno activo por persona y que el servicio quepa.
- Tampoco agenda en días cerrados, bloqueados o dentro de un cierre.
- WhatsApp que coincide con una clienta con cuenta: se avisa y se propone; con una bloqueada, se avisa y no se agenda.
- WhatsApp comparado por sus dígitos sin +55; con cuenta y sin cuenta con el mismo número son la misma persona.
- Datos de la persona sin cuenta solo en el turno, solo los lee la admin, y la admin confirma que la persona acepta darlos.
- Por defecto, para que el autor lo revise: búsqueda desde 2 caracteres, hasta 20 resultados en orden alfabético; nombre de hasta 80 caracteres; WhatsApp de 8 a 15 dígitos; ventana de la admin de 365 días; el aviso de WhatsApp con cuenta salta al salir del campo.

# Spec 012 — Reglas del servidor para los turnos
Estado: implementada

## Contexto y objetivo
Hoy la app comprueba, antes de guardar un turno, que la hora está libre, que no cae en un cierre, que la persona no tiene ya un turno activo, que la hora está dentro del horario y de la ventana de reserva, y que lo reservado es lo de la lista de precios (specs 005 a 008). Pero el servidor solo protege quién puede escribir qué, no estas reglas de la agenda. Dos confirmaciones en el mismo instante, o una app modificada, pueden guardar dos turnos a la misma hora, un turno dentro de un cierre, un segundo turno activo, un turno a las 3 de la mañana o un servicio de dos horas guardado como de media hora y con otro precio. Las specs 005, 006, 007 y 008 dejaron esta garantía para esta spec.

El objetivo es que el servidor haga cumplir siempre las reglas de la agenda, sea cual sea la app que escribe, sin cambiar lo que ven la clienta y la admin cuando todo va bien.

## Usuarios
- **Clienta**: reserva, edita y cancela su turno como hasta ahora. Si el servidor rechaza un turno, ve el mismo aviso que ya le da la app.
- **Admin**: sigue las mismas reglas de la agenda que las clientas (con su ventana de 365 días). Confirmar y cancelar no cambian.
- **Visitante sin sesión**: nada cambia.

## Historias de usuario
- HU-1. Como admin, quiero que nunca se guarden dos turnos a la misma hora, aunque dos clientas confirmen a la vez, para no tener que llamar a una para moverla.
- HU-2. Como admin, quiero que nadie pueda reservar en un cierre, fuera del horario o un servicio con otra duración o precio, aunque use una app modificada, para que la agenda sea siempre fiable.
- HU-3. Como admin, quiero que cada persona tenga como mucho un turno activo, como dice la regla del salón.
- HU-4. Como clienta, quiero que, si alguien me gana la hora, la app me lo diga como hasta ahora y me deje elegir otra.

## Definiciones
- **Reglas de la agenda**: las que hoy comprueba la app al guardar un turno (specs 005 a 008): hora libre, sin cierre, un turno activo por persona, horario, ventana, duración y lo reservado. Esta spec las lleva al servidor; no cambia ninguna.
- **Turno activo**, **persona**, **hora libre**, **ventana de reserva** y **duración del turno**: como en las specs 005 y 007. Una clienta con cuenta y una persona sin cuenta con el mismo WhatsApp normalizado son la misma persona.
- **Solaparse**: dos rangos se solapan si uno empieza antes de que termine el otro y termina después de que empiece el otro. Un turno que empieza justo cuando termina otro no se solapa con él.
- **Turno existente**: turno ya guardado cuando se aplica esta spec, o guardado con reglas que después cambiaron (otro horario, un cierre nuevo).
- **Rechazo del servidor**: el servidor no guarda un cambio que la app dio por bueno.

## Requisitos funcionales

### Sin solapes
- RF-1: EL SISTEMA no guarda un turno nuevo (de la clienta o de la admin) cuyo rango se solapa con el de otro turno activo. Se comprueba en el servidor.
- RF-2: EL SISTEMA no guarda la edición de un turno (de la clienta o de la admin) si su nuevo rango se solapa con el de otro turno activo. El propio turno no cuenta. Se comprueba en el servidor.
- RF-3: CUANDO dos personas confirman a la vez turnos que se solapan, EL SISTEMA guarda solo uno y rechaza el otro, también si llegan en el mismo instante.

### Cierres
- RF-4: EL SISTEMA no guarda un turno nuevo ni la edición de un turno si su rango se solapa con un cierre de la agenda o cae en una fecha bloqueada. Se comprueba en el servidor.
- RF-5: EL SISTEMA no guarda un cierre que se solapa con un turno activo, también si el turno se guarda en el mismo instante que el cierre. Se comprueba en el servidor.

### Un turno activo por persona
- RF-6: EL SISTEMA no guarda un turno nuevo para una persona que ya tiene un turno activo, ya sea una clienta con cuenta o una persona sin cuenta identificada por su WhatsApp. Se comprueba en el servidor.
- RF-7: EL SISTEMA no guarda la edición de la admin que cambia la persona de un turno a una que ya tiene otro turno activo. Se comprueba en el servidor.
- RF-8: CUANDO la misma persona confirma dos turnos a la vez (por ejemplo, desde dos dispositivos), EL SISTEMA guarda solo uno.

### Horario, ventana y duración
- RF-9: EL SISTEMA no guarda un turno nuevo ni la edición de un turno si su inicio no es una hora de la rejilla del salón en un día abierto, si el turno no termina antes o justo al cierre de ese día, o si empieza antes de "ahora" según el servidor. Se comprueba en el servidor.
- RF-10: EL SISTEMA no guarda un turno nuevo ni la edición de un turno si su día está fuera de la ventana de reserva: 60 días para la clienta y 365 para la admin, contados desde el día del salón de "ahora" según el servidor. Se comprueba en el servidor.
- RF-11: EL SISTEMA no guarda un turno nuevo ni la edición de un turno si su fin no es su inicio más la duración del servicio o combo reservado. Se comprueba en el servidor.

### Lo reservado
- RF-12: EL SISTEMA no guarda un turno nuevo ni la edición de un turno si lo reservado no coincide con la lista de precios vigente: el servicio o combo y sus adicionales existen y están disponibles, los adicionales son de la categoría del servicio (un combo no lleva adicionales), y los nombres, precios y duración copiados son los de la lista. Se comprueba en el servidor.
- RF-13: EL SISTEMA conserva la copia de lo reservado de un turno ya guardado aunque la lista de precios cambie después (spec 005, RF-28): confirmarlo, cancelarlo o editarlo sin cambiar lo reservado no exige que siga coincidiendo con la lista.

### Turnos existentes
- RF-14: EL SISTEMA deja confirmar y cancelar los turnos existentes aunque ya no cumplan las reglas de la agenda.
- RF-15: CUANDO se edita un turno existente sin cambiar su día ni su hora, EL SISTEMA no le exige las reglas de horario, ventana ni días cerrados que ya no cumpla, como hoy la app (spec 006); sí le exige que ningún cierre ni otro turno cubra esa hora, y que el servicio quepa hasta el siguiente turno o cierre y hasta el cierre del día o su fin original, lo que sea más tarde. Lo que sí cambie (otra hora, otro servicio) debe cumplir todas las reglas.

### Lo que ve la persona
- RF-16: SI el servidor rechaza un turno nuevo o una edición, ENTONCES EL SISTEMA muestra el mismo aviso que daría la app si hubiera detectado ese problema al comprobar (la hora acaba de ocuparse, ya no tiene tiempo suficiente, ya hay un turno activo, el servicio ya no está disponible…) y conserva lo elegido para elegir otra cosa.
- RF-17: SI el servidor rechaza un turno por un motivo que la app no sabe explicar, ENTONCES EL SISTEMA muestra el aviso de error al guardar que ya existe (sin detalles técnicos) y conserva lo elegido.
- RF-18: SI el servidor rechaza un cierre por solaparse con turnos, ENTONCES EL SISTEMA muestra esos turnos como ya hace el formulario del cierre (spec 008), con "Editar" y "Cancelar".

### Sin cambios
- RF-19: EL SISTEMA sigue funcionando igual en todo lo demás: reservar, editar y cancelar de la clienta, agendar y editar de la admin, confirmar, cancelar, bloquear, cierres, perfil, borrar la cuenta y los avisos push.

## Requisitos no funcionales
- RNF-1: Con conexión normal, guardar un turno, una edición o un cierre tarda como mucho 5 segundos, incluida la comprobación del servidor.
- RNF-2: Las reglas de la agenda tienen una sola definición: el servidor y la app no pueden dar resultados distintos para el mismo turno con los mismos datos. Las diferencias de los turnos existentes (RF-14, RF-15) son las únicas permitidas.
- RNF-3: Las reglas del servidor se comprueban con tests sin Firebase real y a mano en el simulador de la consola, como en las specs anteriores.
- RNF-4: Ninguna clienta conoce, por un rechazo del servidor, datos de otra persona: solo que la hora no está libre (constitución, principio 5).
- RNF-5: Los textos que hagan falta van en español y portugués (RC-1). Se reutilizan los avisos existentes siempre que se pueda.

## Plataformas
Igual en Android, iOS y Web: las reglas están en el servidor y los avisos son los que ya tiene cada plataforma.

## Navegación
No cambia. Tras un rechazo, la persona sigue en la misma pantalla (reserva, edición o formulario del cierre) con lo que había elegido.

## Casos límite
- Dos clientas confirman la misma hora en el mismo segundo: una ve su turno guardado; la otra, "esa hora acaba de ocuparse", con su servicio y su fecha intactos (RF-3, RF-16).
- La clienta confirma desde el móvil y la Web a la vez: se guarda uno; el otro dispositivo le muestra el turno que ya tiene (RF-8, spec 005 RF-36).
- La admin guarda un cierre mientras una clienta confirma un turno dentro de él: se guarda solo lo primero que llegue; al otro se le avisa (RF-4, RF-5).
- La admin agenda para una persona sin cuenta con el mismo WhatsApp que una clienta con un turno activo: no se guarda (RF-6).
- La admin cambia el horario y un turno ya guardado queda fuera: se puede confirmar, cancelar y editar el servicio sin moverlo; moverlo exige una hora válida (RF-14, RF-15).
- La admin cambia el precio de un servicio mientras una clienta tiene la reserva abierta: si confirma con el precio viejo, el servidor la rechaza como "servicio cambiado" y la app le muestra el nuevo (RF-12, RF-16).
- Un turno termina justo cuando empieza otro: no se solapan (Definiciones).
- El reloj del teléfono está mal: cuenta la hora del servidor para "ahora" y la ventana (RF-9, RF-10).
- Una app modificada intenta guardar un turno de 2 h como de 30 min, a otro precio o a las 3 de la mañana: no se guarda (RF-9, RF-11, RF-12).
- Un turno cancelado o que ya terminó no cuenta para solapes ni para el turno activo.

## Fuera de alcance
- Cambiar cualquier regla de la agenda (horas, ventana, duración, un turno activo): solo se llevan al servidor.
- Dejar a la admin saltarse las reglas (atender fuera de horario o solapar turnos a propósito): para eso cambia el horario o quita el cierre.
- Revisar o corregir los turnos existentes que ya no cumplen las reglas, o listarlos en el panel.
- Validar en el servidor el formato del WhatsApp, los nombres o la foto de las fichas.
- Límites de uso contra abusos (muchas reservas y cancelaciones seguidas).

## Criterios de finalización
- Ningún camino de la app ni una escritura directa con la sesión de una clienta o de la admin puede guardar un turno o un cierre que rompa las reglas de la agenda (comprobado en el simulador y con tests sin Firebase real).
- Dos confirmaciones simultáneas de la misma hora o de la misma persona guardan solo una.
- Los turnos existentes se siguen pudiendo confirmar, cancelar y editar como dice RF-14 y RF-15.
- Ante un rechazo, la persona ve el aviso de siempre y conserva lo elegido, en español y portugués, en Android, iOS y Web.
- Todo lo que ya existía funciona igual (RF-19).
- Todos los tests en verde, `dart format` sin cambios y `flutter analyze` sin avisos.

## Dudas abiertas
Ninguna. Resueltas por el autor el 2026-11-23:
- Alcance: sin solapes entre turnos, sin solapes con cierres, un turno activo por persona, y horario, ventana y duración.
- La admin sigue las mismas reglas que las clientas (con su ventana de 365 días).
- Los turnos existentes se respetan: se confirman y cancelan siempre, y al editarlos su día y hora originales siguen permitidos.
- Lo reservado se comprueba entero contra la lista de precios vigente.
- Ante un rechazo, el mismo aviso que hoy y lo elegido intacto.

Precisado por el autor el 2026-11-23 (T1): RF-15 sigue la regla de la app de la 006 y la 008; un cierre u otro turno sobre la hora original sí la bloquea, para que la app y el servidor den lo mismo (RNF-2).

Decisiones tomadas en la redacción (cámbialas si no te convencen):
- RF-13 y RF-15 extienden "se respetan" a lo reservado: un turno que no cambia lo reservado conserva su copia aunque la lista cambie.
- RNF-1 fija 5 segundos como máximo para guardar, para dejar margen a una comprobación en el servidor que hoy no existe.
- RNF-2: una sola definición de las reglas para la app y el servidor, para que la app nunca ofrezca una hora que el servidor rechace.

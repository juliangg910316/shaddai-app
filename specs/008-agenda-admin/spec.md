# Spec 008 — Agenda de la admin
Estado: aprobada

## Contexto y objetivo
Hoy la admin solo cambia el horario de cada día de la semana, y confirma o cancela turnos en la agenda de su panel. No puede:
- cerrar unas horas o unos días concretos (un descanso, una cita médica, una enfermedad, unas vacaciones): las fechas bloqueadas existen en los datos, pero no hay forma de gestionarlas desde la app;
- corregir un turno guardado (otro día, otra hora, otro servicio u otra persona) sin cancelarlo y agendarlo de nuevo;
- cambiar el margen de edición de la spec 006, que solo se cambia a mano en la base de datos.

Esta spec le da las tres cosas desde su panel, para que la agenda refleje siempre lo que de verdad pasa en el salón.

Parte de las specs 005 (reservas), 006 (editar el turno) y 007 (reserva de la admin), todas implementadas. Cumple lo que la 007 dejó para aquí (RF-13: horas dentro de un cierre).

## Usuarios
- **Admin**: crea y quita cierres, edita cualquier turno activo y cambia el margen de edición.
- **Cliente** con cuenta: ve las horas de un cierre como no disponibles; ve sin recargar los cambios que la admin hace en su turno; el margen nuevo decide hasta cuándo puede editar su turno.
- **Persona sin cuenta**: no usa la app; la admin puede corregir su nombre y su WhatsApp en el turno.

## Historias de usuario
- HU-1. Como admin, quiero cerrar unas horas o unos días concretos para que nadie reserve cuando no voy a estar.
- HU-2. Como admin, quiero saber qué turnos chocan con un cierre antes de guardarlo, para avisar a esas clientas y moverlos.
- HU-3. Como admin, quiero corregir el día, la hora, el servicio o la persona de un turno sin tener que cancelarlo y agendarlo de nuevo.
- HU-4. Como admin, quiero elegir con cuánta antelación las clientas dejan de poder cambiar su turno.
- HU-5. Como clienta, quiero ver al momento los cambios que la admin hace en mi turno.

## Definiciones
Las de las specs 005, 006 y 007, más:
- **Cierre**: un tiempo concreto en el que el salón no atiende, además del horario semanal. Es uno de estos dos:
  - una **franja**: de una hora a otra dentro de una misma fecha (p. ej., el martes 24 de 13:00 a 14:30);
  - unos **días enteros**: de una fecha a otra, ambas incluidas (p. ej., del 2 al 9 de enero). Un solo día es un cierre de días enteros que empieza y termina en la misma fecha.
- **Fecha bloqueada existente**: cada fecha bloqueada que ya hay guardada de antes de esta spec. Cuenta como un cierre de un día entero.
- **Cierre próximo**: un cierre que termina después de "ahora".
- **Hora libre** (spec 005) y **cobertura**: además de los turnos ocupados, un cierre ocupa su tiempo. Una hora dentro de un cierre no es libre, y la cobertura de una hora libre termina, como muy tarde, donde empieza el siguiente cierre del día.
- **Turno que choca con un cierre**: un turno esperando confirmación o confirmado que termina después de "ahora" y cuyo tiempo, desde su inicio hasta antes de su fin, se cruza con el del cierre.
- **Edición de la admin**: la vista de reserva de la admin (spec 007) abierta sobre un turno guardado, con su persona, su día, su hora y lo reservado ya elegidos, y "Guardar cambios" en lugar de "Agendar turno".
- **Opciones del margen de edición**: sin margen (0), 1 h, 2 h, 3 h, 6 h, 12 h, 24 h, 48 h y 72 h.

## Requisitos funcionales

### Cierres
- RF-1: CUANDO la admin abre los cierres desde su panel, EL SISTEMA muestra los cierres próximos, ordenados por su inicio, cada uno con sus fechas y, si es una franja, sus horas.
- RF-2: SI no hay cierres próximos, ENTONCES EL SISTEMA lo indica y ofrece crear uno.
- RF-3: CUANDO la admin crea un cierre, EL SISTEMA le deja elegir entre una franja (una fecha, hora de inicio y hora de fin, en pasos de 15 minutos) y días enteros (fecha de inicio y fecha de fin).
- RF-4: SI la franja no termina después de su inicio, el cierre termina antes o en "ahora", la fecha de fin es anterior a la de inicio o alguna fecha queda a más de 365 días de hoy, ENTONCES EL SISTEMA no guarda el cierre y marca lo que está mal.
- RF-5: SI hay turnos que chocan con el cierre, ENTONCES EL SISTEMA no lo guarda y le muestra a la admin esos turnos, con su fecha, su hora, la persona y lo reservado, cada uno con acceso a editarlo o cancelarlo.
- RF-6: CUANDO la admin guarda un cierre sin turnos que choquen, EL SISTEMA lo comprueba otra vez con los datos actuales justo antes de guardarlo, lo guarda, confirma que está guardado y lo muestra en la lista.
- RF-7: CUANDO la admin quita un cierre, EL SISTEMA le pide que lo confirme y, si confirma, lo quita y vuelve a dejar libres esas horas.
- RF-8: EL SISTEMA muestra y deja quitar las fechas bloqueadas existentes como cierres de un día entero.
- RF-9: CUANDO la admin mira un día en la agenda, EL SISTEMA muestra los cierres de ese día junto a sus turnos, en orden de hora.
- RF-10: SI no se pueden cargar los cierres, ENTONCES EL SISTEMA lo indica con "Reintentar" en la lista de cierres y en la agenda, y no deja crear un cierre.
- RF-11: SI no se puede guardar o quitar un cierre, ENTONCES EL SISTEMA lo indica y conserva lo que la admin había elegido.

### Los cierres en la reserva
- RF-12: MIENTRAS hay un cierre, EL SISTEMA no ofrece como libres sus horas en ninguna reserva: la de la clienta, la edición de la clienta (spec 006) y la de la admin (spec 007).
- RF-13: EL SISTEMA no deja elegir en el calendario de la reserva un día cerrado entero por un cierre.
- RF-14: EL SISTEMA solo ofrece un servicio a una hora si cabe antes del siguiente cierre del día, igual que antes del siguiente turno ocupado (spec 005).
- RF-15: CUANDO la admin crea o quita un cierre, EL SISTEMA actualiza las horas libres de quien tiene la reserva abierta sin recargar, como con los turnos ocupados (spec 005).
- RF-16: SI la hora elegida en una reserva abierta queda dentro de un cierre nuevo, ENTONCES EL SISTEMA la quita y avisa, como cuando otra persona la ocupa (spec 005).
- RF-17: EL SISTEMA muestra a la clienta las horas de un cierre solo como no disponibles, sin indicar que hay un cierre ni por qué.

### La admin edita un turno
- RF-18: MIENTRAS un turno está esperando confirmación o confirmado y termina después de "ahora", EL SISTEMA muestra "Editar" en su tarjeta de la agenda.
- RF-19: CUANDO la admin toca "Editar", EL SISTEMA abre la edición de la admin con la persona, el día, la hora y lo reservado del turno ya elegidos.
- RF-20: MIENTRAS la admin edita un turno, EL SISTEMA aplica las reglas de su reserva (spec 007): ventana de 365 días, sin días cerrados, fechas bloqueadas ni cierres, y el servicio debe caber.
- RF-21: MIENTRAS la admin edita un turno, EL SISTEMA da por válidos su día y su hora originales aunque ya no cumplan las reglas (también si el turno está en curso), y el tiempo del propio turno no cuenta como ocupado.
- RF-22: MIENTRAS la admin edita un turno, EL SISTEMA no tiene en cuenta el margen de edición.
- RF-23: CUANDO la admin cambia la persona del turno, EL SISTEMA le deja elegir otra clienta con cuenta o una persona sin cuenta, igual que al agendar (spec 007, RF-3 a RF-11).
- RF-24: CUANDO la admin edita un turno de una persona sin cuenta, EL SISTEMA le deja corregir su nombre y su WhatsApp, con las mismas comprobaciones que al agendar (spec 007, RF-9 a RF-11), y la casilla de que la persona acepta aparece ya marcada.
- RF-25: SI la nueva persona ya tiene otro turno activo, ENTONCES EL SISTEMA no guarda y se lo indica a la admin con la fecha, la hora y lo reservado de ese turno (spec 007, RF-14). El turno que edita no cuenta.
- RF-26: SI no cambia nada, ENTONCES EL SISTEMA no guarda y lo indica.
- RF-27: CUANDO la admin toca "Guardar cambios" con todo elegido, EL SISTEMA le muestra el antes y el después (persona, día, hora y lo reservado), indica que el turno quedará confirmado y pide que lo confirme. Si la nueva persona es una clienta con cuenta y el turno empieza dentro del margen de edición, también le avisa de que la clienta no lo podrá cambiar (spec 007, RF-29).
- RF-28: CUANDO la admin confirma, EL SISTEMA vuelve a comprobar con los datos actuales la hora, que el servicio quepa, la persona (bloqueada o con otro turno activo) y que nadie haya cambiado el turno desde que abrió la edición; si todo vale, guarda el turno confirmado, cambia su tiempo ocupado en el mismo paso y vuelve a la agenda en el día del turno, con un aviso de que se guardó.
- RF-29: SI al confirmar la hora ya no está libre, el servicio ya no cabe, la persona está bloqueada o tiene otro turno activo, ENTONCES EL SISTEMA no guarda, conserva lo elegido y avisa con un texto distinto para cada caso.
- RF-30: SI al confirmar el turno ya no está activo (se canceló o terminó) o alguien lo cambió mientras la admin lo editaba, ENTONCES EL SISTEMA no guarda, avisa con un texto distinto para cada caso y vuelve a la agenda.
- RF-31: EL SISTEMA conserva al guardar la marca de "agendado por la admin" que tenía el turno, y se la pone si la admin cambió la persona.
- RF-32: CUANDO la admin guarda un turno de una clienta con cuenta, EL SISTEMA se lo muestra a la clienta con los cambios sin recargar, en su reserva y en su perfil. Si la persona cambió, deja de verlo la clienta anterior y lo ve la nueva como su turno activo.
- RF-33: MIENTRAS la admin edita un turno, EL SISTEMA conserva lo que tenía elegido para agendar en la reserva (spec 007, RF-27), y lo vuelve a mostrar al terminar la edición.
- RF-34: SI se toca "Guardar cambios" sin persona, sin hora o sin servicio, ENTONCES EL SISTEMA no guarda, indica qué falta y marca cada parte sin elegir (spec 007, RF-17).
- RF-35: CUANDO la admin sale de la edición sin guardar, EL SISTEMA vuelve a la agenda sin cambiar el turno.

### Margen de edición
- RF-36: CUANDO la admin abre los ajustes del horario, EL SISTEMA muestra el margen de edición actual entre las opciones del margen.
- RF-37: SI el margen guardado no es una de las opciones, ENTONCES EL SISTEMA lo muestra en horas y minutos como opción elegida hasta que la admin elija otra.
- RF-38: CUANDO la admin elige otra opción del margen, EL SISTEMA la guarda, sin cambiar el horario semanal, y confirma que se guardó.
- RF-39: SI no se puede guardar el margen, ENTONCES EL SISTEMA lo indica y vuelve a mostrar el margen que había.
- RF-40: CUANDO cambia el margen, EL SISTEMA aplica el nuevo en la edición de las clientas sin recargar (spec 006, RF-21): "Editar turno" aparece o desaparece según el margen nuevo.
- RF-41: EL SISTEMA guarda el horario semanal sin cambiar el margen, y el margen sin cambiar el horario semanal.

### Seguridad
- RF-42: EL SISTEMA solo deja crear y quitar cierres a la admin, y deja leerlos a cualquier persona con sesión. Un cierre solo guarda su inicio y su fin. Se comprueba en el servidor.
- RF-43: EL SISTEMA solo deja a la admin cambiar la persona, el día, la hora y lo reservado de un turno de otra persona, junto con su tiempo ocupado y siempre dejándolo confirmado; la clienta sigue editando solo su propio turno como en la spec 006. Se comprueba en el servidor.
- RF-44: EL SISTEMA solo deja cambiar el margen de edición a la admin, como un número entero de minutos mayor o igual que 0. Se comprueba en el servidor.

## Requisitos no funcionales
- RNF-1: Son reglas puras, probadas con tablas de casos:
  - las horas libres y la cobertura con cierres (franja al principio, en medio y al final del día; cierre que empieza justo cuando termina un turno; días enteros; varios cierres que se cruzan; un cierre que pasa de un día a otro; las fechas bloqueadas existentes);
  - la validez de un cierre (fin no posterior al inicio, pasado, más de 365 días, fechas al revés);
  - los turnos que chocan con un cierre (que toca justo el borde, en curso, cancelado, terminado);
  - la edición de la admin: hora y día originales válidos, el propio turno no ocupa, la persona con otro turno activo, sin cambios;
  - el margen que no está entre las opciones.
- RNF-2: Mismos requisitos de contraste, 48 px, lector de pantalla, texto al 200 % y 320 px que la spec 005, en los cierres, la edición de la admin y el margen.
- RNF-3: Todos los textos nuevos de la interfaz están en español y en portugués.
- RNF-4: Todo sigue leyendo los datos que ya existen: las fechas bloqueadas existentes, los turnos sin marca de la admin y un margen guardado a mano (constitución, principio 5).
- RNF-5: Las reglas de RF-42 a RF-44 se comprueban caso por caso en el simulador, y las de las specs 005 a 007 se siguen cumpliendo.

## Plataformas
- **Android/iOS**: los cierres se abren desde el panel de la admin; la edición de un turno se abre desde la agenda del panel, y al terminar vuelve a ella. El margen está en los ajustes del horario.
- **Web**: lo mismo, en las páginas del panel, centradas como las demás páginas de cuenta. La edición de un turno tiene su propia dirección dentro del panel, y "atrás" del navegador sale de ella sin guardar (RF-35).

## Navegación
- Panel de la admin → Cierres → lista de cierres próximos → "Nuevo cierre" → franja o días enteros → guardar (o la lista de turnos que chocan → editar o cancelar uno → volver al cierre).
- Panel de la admin → agenda de un día → cierres y turnos del día → "Editar" en un turno → edición de la admin → "Guardar cambios" → confirmar → agenda en el día del turno.
- Panel de la admin → ajustes del horario → margen de edición.

## Casos límite
- Un cierre que empieza justo cuando termina un turno, o termina justo cuando empieza uno: no choca.
- Un cierre que cubre un turno en curso: choca (RF-5).
- Un turno cancelado o ya terminado dentro del cierre: no choca.
- Un cierre que se cruza con otro cierre o con un día ya cerrado por el horario semanal: se guarda; las horas siguen cerradas mientras quede uno de ellos.
- Una clienta reserva justo mientras la admin guarda un cierre que cubre esa hora: la app vuelve a comprobar al guardar el cierre (RF-6), pero no puede impedir del todo que se crucen; la garantía en el servidor llega con la spec 012.
- La clienta tiene abierta la edición de su turno cuando la admin lo edita: al confirmar, la clienta no guarda y ve el turno como está ahora (spec 006, RF-15).
- La admin cambia una clienta con cuenta por una persona sin cuenta: la clienta deja de ver el turno y puede reservar otro.
- La admin edita un turno que agendó una clienta a más de 60 días: puede mantener la fecha o cambiarla dentro de sus 365 días.
- La admin edita un turno que estaba esperando confirmación: queda confirmado al guardarlo.
- La admin sube el margen mientras una clienta edita su turno: si el turno deja de ser editable, al confirmar no se guarda (spec 006, RF-15).
- Un cierre de días enteros que empieza hoy cuando ya pasaron unas horas: se guarda; solo cuenta lo que queda de hoy.
- Cambio de idioma con la confirmación abierta: se traduce.

## Fuera de alcance
- Cierres que se repiten (p. ej., todos los días de 13:00 a 14:00): para eso está el horario semanal.
- Un motivo o nota en el cierre.
- Editar un cierre: se quita y se crea otro.
- Mover o cancelar a la vez los turnos que chocan con un cierre.
- Avisar a la clienta (push, WhatsApp o correo) de que la admin cambió o canceló su turno (spec 011 y siguientes).
- Que el servidor impida turnos que se solapan con otros o con un cierre (spec 012).
- Editar turnos pasados o cancelados.

## Criterios de finalización
- Todos los RF tienen su test y pasan. `flutter analyze` sin errores ni avisos y `dart format` sin cambios.
- Las reglas puras de RNF-1 tienen tests de tabla.
- El autor comprueba las reglas de RF-42 a RF-44 en el simulador, y que las de las specs 005 a 007 siguen igual.
- Recorrido manual del autor en Android/iOS y en Web, en tema claro y oscuro y en español y portugués. Incluye:
  - crear una franja y unos días enteros, y ver esas horas no disponibles en la reserva de una clienta, sin recargar;
  - intentar un cierre que choca con un turno, editar ese turno y guardar después el cierre;
  - quitar un cierre y una fecha bloqueada existente;
  - editar un turno: cambiar la hora, el servicio y la persona (de una clienta a otra y a una persona sin cuenta), y que cada clienta lo vea sin recargar;
  - cambiar el margen y ver "Editar turno" aparecer o desaparecer en la clienta.

## Dudas abiertas
Resueltas con el autor (2026-11-17):
- Un cierre que choca con turnos no se guarda: se muestran los turnos para que la admin los mueva o los cancele.
- Cierres puntuales: una franja dentro de un día o varios días enteros seguidos; sin cierres repetidos.
- La admin edita cualquier turno activo, también la persona, con las reglas de su reserva y sin margen; queda confirmado.
- El margen se elige de una lista de opciones fijas.
- Todo en una sola spec, aunque salgan más de 10 tareas.

Por defecto, para que el autor lo revise:
- Franjas en pasos de 15 minutos; cierres hasta 365 días desde hoy.
- Las fechas bloqueadas existentes cuentan y se ven como cierres de un día entero, y se pueden quitar.
- El cierre no lleva motivo, porque lo leen todas las personas con sesión.
- "Editar" también en un turno en curso: mantiene su hora y puede cambiar lo reservado.
- Al cambiar la persona, el turno pasa a estar marcado como agendado por la admin.
- La casilla de que la persona sin cuenta acepta aparece ya marcada al editar su turno.
- El margen se guarda al elegirlo, sin un botón aparte.

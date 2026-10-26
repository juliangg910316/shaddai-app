# Spec 006 — Editar el turno
Estado: borrador

## Contexto y objetivo
Con la spec 005, una clienta tiene como mucho un turno activo y no puede cambiarlo: si se equivoca de día, de hora o de servicio, tiene que escribir al salón. Esta spec le deja editar su turno activo desde la propia reserva, con las mismas reglas que al reservar, mientras falte más de un margen que fija la admin. Al editarlo, el turno vuelve a esperar confirmación, para que la admin vea el cambio.

Depende de la spec 005, que tiene que estar implementada. Segunda de las tres specs de reservas (división decidida por el autor el 2026-10-24).

## Usuarios
- **Cliente** con sesión y WhatsApp: edita su turno activo.
- **Clienta bloqueada**: ve su turno, pero no lo edita.
- **Admin**: ve el turno editado esperando confirmación. Cambia el margen de edición en la spec 008.

## Historias de usuario
- HU-1. Como clienta, quiero cambiar el día, la hora o el servicio de mi turno mientras falte tiempo para adaptarlo sin tener que escribir al salón.
- HU-2. Como admin, quiero que un turno editado vuelva a esperar mi confirmación y que no se pueda cambiar a última hora.

## Definiciones
Las de la spec 005 (hora del salón, vista de reserva, servicio, lo reservado, hora libre, cobertura, servicio que cabe, turno activo, ventana de reserva), más:
- **Margen de edición**: minutos antes del inicio de un turno a partir de los cuales la clienta ya no puede editarlo. Es un único ajuste del salón, que solo cambia la admin (spec 008). Mientras no lo cambie, vale 0.
- **Turno editable**: turno activo de la clienta cuyo inicio está a más del margen de edición de "ahora", si la clienta no está bloqueada. Ejemplo: con un margen de 30 minutos, un turno de las 10:00 deja de ser editable a las 9:30. Con margen 0, es editable hasta que empieza.
- **Edición**: la vista de reserva abierta sobre el turno activo, con sus datos ya elegidos y "Guardar cambios" en lugar de "Agendar turno".

## Requisitos funcionales

### Botón "Editar turno"
- RF-1: MIENTRAS el turno activo de la clienta es editable, EL SISTEMA muestra junto a él el botón "Editar turno".
- RF-2: MIENTRAS el turno activo de la clienta no es editable, EL SISTEMA no muestra "Editar turno" y explica que ya no se puede cambiar, con el enlace a WhatsApp del salón.
- RF-3: CUANDO el turno pasa a ser o deja de ser editable (pasa el tiempo, la admin cambia el margen o bloquea a la clienta), EL SISTEMA muestra u oculta "Editar turno" sin recargar.

### Abrir la edición
- RF-4: CUANDO la clienta toca "Editar turno", EL SISTEMA abre la edición con la fecha, la hora, el servicio y los adicionales del turno ya elegidos.
- RF-5: EL SISTEMA abre la edición con la fecha y la hora del turno aunque no cumplan las reglas actuales: más allá de la ventana de reserva, en un día ahora cerrado o bloqueado, o a una hora fuera de la rejilla actual.
- RF-6: SI el servicio, el combo o un adicional del turno ya no está disponible, o el turno no tiene lo reservado (turnos antiguos), ENTONCES EL SISTEMA abre la edición sin él elegido y avisa de que ya no está disponible.

### Editar
- RF-7: MIENTRAS la clienta edita su turno, EL SISTEMA aplica las reglas de la vista de reserva de la spec 005 (RF-3 a RF-24) y no cuenta ese turno como ocupado.
- RF-8: MIENTRAS la clienta no cambia la fecha ni la hora del turno, EL SISTEMA las da por válidas aunque no cumplan las reglas actuales (RF-5), y solo exige que el servicio quepa desde esa hora.
- RF-9: CUANDO la clienta cambia la fecha o la hora, EL SISTEMA exige que las nuevas cumplan todas las reglas de la reserva.
- RF-10: SI se toca "Guardar cambios" sin hora o sin servicio elegidos, ENTONCES EL SISTEMA no guarda, indica qué falta y marca cada parte sin elegir.
- RF-11: CUANDO se toca "Guardar cambios" con todo elegido, EL SISTEMA muestra el turno de antes y el de después, indica que el turno volverá a esperar confirmación de la admin y pide que se confirme.

### Guardar
- RF-12: CUANDO la clienta confirma los cambios, EL SISTEMA comprueba otra vez, antes de guardar:
  - que la hora sigue libre y el servicio cabe (sin contar el propio turno);
  - que el turno sigue activo y editable;
  - que nadie lo ha cambiado desde que se abrió la edición, contando también un cambio de estado.
- RF-13: CUANDO se cumplen las comprobaciones de RF-12, EL SISTEMA actualiza ese mismo turno con el nuevo inicio, el nuevo fin y la nueva copia de lo reservado (como en la spec 005, RF-27), y lo deja esperando confirmación aunque estuviera confirmado.
- RF-14: SI la hora ya no está libre o el servicio ya no cabe, ENTONCES EL SISTEMA no guarda y avisa como en la spec 005 (RF-29, RF-30), conservando lo elegido.
- RF-15: SI el turno ya no es editable, ya no está activo o alguien lo ha cambiado, ENTONCES EL SISTEMA no guarda, avisa y vuelve a mostrar el turno como está ahora.
- RF-16: SI los cambios no se pueden guardar (sin conexión o por un error), ENTONCES EL SISTEMA no los da por guardados, avisa con un texto sin detalles técnicos y conserva lo elegido para reintentar.
- RF-17: CUANDO los cambios se guardan, EL SISTEMA lo confirma y vuelve a mostrar el turno activo, esperando confirmación.

### Salir de la edición
- RF-18: CUANDO la clienta toca "Cancelar" en la edición, EL SISTEMA vuelve a mostrar su turno sin cambios.
- RF-19: CUANDO la clienta cambia de pestaña (Android/iOS) y vuelve, EL SISTEMA conserva la edición tal como estaba.
- RF-20: CUANDO la clienta va atrás o recarga la página en Web, EL SISTEMA deja la edición sin guardar y muestra su turno.

### Margen y errores
- RF-21: EL SISTEMA lee el margen de edición del ajuste del salón y usa 0 si no existe.
- RF-22: SI no se puede leer el margen de edición, ENTONCES EL SISTEMA no muestra "Editar turno" y muestra un aviso con "Reintentar".
- RF-23: CUANDO la clienta reserva un turno que ya empieza dentro del margen de edición, EL SISTEMA le avisa en el resumen de confirmación (spec 005, RF-25) de que no lo podrá cambiar.

### Seguridad
- RF-24: EL SISTEMA solo deja a una clienta cambiar sus propios turnos activos, si no está bloqueada y fuera del margen de edición. Solo puede cambiar el inicio, el fin y lo reservado, y el turno queda esperando confirmación. Se comprueba en el servidor.
- RF-25: EL SISTEMA solo deja a la admin cambiar el margen de edición. Se comprueba en el servidor.

## Requisitos no funcionales
- RNF-1: Son reglas puras, que reciben "ahora" como dato y están probadas con tablas de casos:
  - si un turno es editable con el margen de edición (incluido un turno justo en el límite y el margen 0);
  - las horas libres sin contar el propio turno;
  - la validez de la fecha y la hora originales (RF-8).
- RNF-2: Mismos requisitos de contraste, 48 px, lector de pantalla, texto al 200 % y 320 px que la spec 005 (RNF-2, RNF-3), también en el diálogo de "antes y después".
- RNF-3: Todos los textos nuevos de la interfaz están en español y en portugués.
- RNF-4: Las reglas de seguridad de RF-24 y RF-25 se comprueban caso por caso en el simulador.

## Plataformas
- **Android/iOS**: la edición se abre dentro de la pestaña Reservas, con la barra inferior visible.
- **Web**: la edición se abre en la página de reserva, sin dirección propia (RF-20).

## Navegación
- Reserva con turno activo → "Editar turno" (si es editable) → edición → "Guardar cambios" → confirmar → su turno activo.
- Edición → "Cancelar" → su turno activo.

## Casos límite
- El turno deja de ser editable mientras la clienta lo edita: al confirmar no se guarda (RF-15).
- La admin confirma, cancela o edita (spec 008) el turno mientras la clienta lo edita: al confirmar no se guarda (RF-15).
- La misma clienta edita el turno desde dos dispositivos: el segundo en guardar no se guarda (RF-15).
- La clienta guarda sin cambiar nada: se guarda igual y vuelve a esperar confirmación.
- Turno que agendó la admin para la clienta (spec 007): se edita igual.
- Turno agendado más allá de 60 días: se puede mantener su fecha; cambiarla obliga a elegir una dentro de la ventana (RF-8, RF-9).
- Turno antiguo con una hora fuera de la rejilla actual: se puede mantener su hora si el servicio cabe (RF-8).
- La clienta es bloqueada mientras edita: la edición se cierra y se aplica la spec 005, RF-37.

## Fuera de alcance
- Que la admin cambie el margen de edición desde la app (spec 008). Hasta entonces vale 0.
- Que la clienta cancele su turno (spec 009).
- Historial de cambios de un turno.
- Aviso a la admin de que un turno se ha editado (spec 011).

## Criterios de finalización
- Todos los RF tienen su test y pasan. `flutter analyze` sin errores ni avisos y `dart format` sin cambios.
- Las reglas puras de RNF-1 tienen tests de tabla.
- El autor comprueba las reglas de RF-24 y RF-25 en el simulador.
- Recorrido manual del autor en Android/iOS y en Web, en tema claro y oscuro y en español y portugués: editar día, hora y servicio; volver a esperar confirmación; no poder editar dentro del margen (poniendo a mano un margen en la base de datos); el choque al editar desde dos dispositivos.

## Dudas abiertas
Ninguna. Resueltas con el autor (2026-10-24):
- Se editan día, hora, servicio y adicionales, con las mismas reglas que al reservar; el propio turno no cuenta como ocupado.
- Al editarlo vuelve a esperar confirmación.
- Margen de edición global, por defecto 0, que solo cambia la admin (spec 008).
- Turno ya no editable: explicación y enlace a WhatsApp.
- Si el turno cambia por otra vía mientras se edita, no se guarda y se avisa.
- La clienta edita también los turnos que le agendó la admin.
- La fecha y la hora originales se pueden mantener aunque no cumplan las reglas actuales; las nuevas, sí las cumplen.
- La clienta bloqueada no edita.
- Por defecto, para que el autor lo revise: la edición no tiene dirección propia en Web; aviso en la confirmación si el turno nace dentro del margen.

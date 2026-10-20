---
name: sdd-implement
description: SDD · Implementa UNA tarea de una spec con tests primero (uso - /sdd-implement 001-nombre T3)
argument-hint: <NNN-nombre> <Tn>
disable-model-invocation: true
---

Si specs/$0/tasks.md no está en "Estado: aprobada", para y avísame.

Implementa SOLO la tarea $1 de specs/$0/tasks.md, siguiendo specs/$0/plan.md,
docs/constitution.md, CLAUDE.md y la skill sdd.

1. Escribe primero los tests de la tarea y ejecuta `flutter test`: muéstrame que fallan (rojo).
2. Escribe el código de la tarea hasta que pasen (verde). Si necesitas desviarte del plan, para y pregúntame.
3. Si cambian los .arb, ejecuta `flutter gen-l10n`. Si cambian colecciones o campos de Firestore,
   asegúrate de que los documentos existentes se siguen leyendo y actualiza firestore.rules si toca.
4. Ejecuta `dart format .`, `flutter analyze` y `flutter test`, y muéstrame el resultado
   (sin errores ni avisos, todo en verde).
5. Marca $1 como hecha en tasks.md e indica qué RF cubre.
6. Actualiza MEMORY.md si hubo una decisión o un error a evitar.

Después PÁRATE. No empieces la siguiente tarea.

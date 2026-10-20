---
name: sdd-tasks
description: SDD · Divide el plan en tareas pequeñas y verificables
argument-hint: <NNN-nombre>
disable-model-invocation: true
---

Si specs/$0/plan.md no está en "Estado: aprobada", para y avísame. No modifiques código.

A partir de specs/$0/spec.md y specs/$0/plan.md, genera specs/$0/tasks.md
con "Estado: borrador", siguiendo el formato de la skill sdd:
- Tareas pequeñas (máx. 20-30 min cada una), en orden de dependencia.
- Cada una con los RF que cubre, los tests que se escriben primero y una línea "Hecho cuando:" verificable.
- Checkboxes.
- Intenta que no sean más de 10: si salen más, propón dividir la spec.

Muéstrame las tareas y espera. Si te digo que las apruebo, cambia su estado a "aprobada".

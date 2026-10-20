---
name: sdd-change
description: SDD · Nuevo requisito - primero la spec, luego el código
argument-hint: <NNN-nombre> <requisito>
disable-model-invocation: true
---

Nuevo requisito para la spec specs/$0/ (el texto que va después del nombre de
la carpeta): $ARGUMENTS

NO toques código. Usa la skill sdd.
1. Actualiza specs/$0/spec.md: nuevo RF (o cambio de uno existente) en EARS,
   sus casos límite y lo que queda fuera de alcance. Pon su estado en "borrador".
2. Si existen plan.md y tasks.md, ponlos también en "borrador" e indica qué partes
   habría que cambiar después (incluidos los tests afectados).
3. Muéstrame el diff de la spec y espera. Si te digo que la apruebo, cambia su estado a "aprobada".

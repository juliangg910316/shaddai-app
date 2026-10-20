---
name: sdd-plan
description: SDD · Genera el plan técnico de una spec aprobada
argument-hint: <NNN-nombre>
disable-model-invocation: true
---

Lee docs/constitution.md, CLAUDE.md, MEMORY.md, docs/ESPECIFICACION.md y specs/$0/spec.md, y el código relacionado. Usa la skill sdd.
NO escribas código.

Si la spec no está en "Estado: aprobada" o tiene dudas abiertas, para y avísame.

Genera specs/$0/plan.md con "Estado: borrador" y: qué parte de la spec ya existe en el código,
archivos que se crean o modifican y la responsabilidad de cada uno (capas features → data → Firebase),
funciones puras de lógica y validaciones (sin Flutter ni Firebase, con "ahora" como parámetro),
algoritmo en pseudocódigo, cómo se pinta en la interfaz (pantallas en Web y en Android/iOS,
providers y controladores Riverpod, rutas y guardas de go_router), cambios en Firestore
(colecciones, campos, compatibilidad con los documentos existentes, firestore.rules e índices),
textos nuevos en los .arb (ES y PT), decisiones técnicas justificadas (con su alternativa descartada)
y estrategia de tests (qué test cubre cada RF y qué fakes se usan para Firebase).

Todo debe respetar la constitución y cubrir todos los RF y los requisitos comunes. Marca qué RF
cubre cada parte. Si el plan necesita una dependencia nueva, márcalo como decisión del autor.
Muéstrame el plan y espera. Si te digo que lo apruebo, cambia su estado a "aprobada".

---
name: sdd-clarify
description: SDD · Revisa la spec como un QA (solo detecta, no resuelve)
argument-hint: <NNN-nombre>
disable-model-invocation: true
---

Revisa specs/$0/spec.md como si fueras un QA muy profesional. Usa la skill sdd.
Lista:
1. Ambigüedades restantes (requisitos que no se pueden verificar).
2. Contradicciones entre requisitos (también con otras specs de specs/ y con los requisitos comunes de docs/ESPECIFICACION.md).
3. Casos límite no cubiertos (incluidos roles, clientas bloqueadas, sin conexión, Web frente a Android/iOS).
4. Conflictos con docs/constitution.md.

No propongas soluciones todavía: solo detecta. Formato: lista numerada.
No modifiques ningún archivo.

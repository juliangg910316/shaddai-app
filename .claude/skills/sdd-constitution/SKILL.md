---
name: sdd-constitution
description: SDD · Propone o revisa la constitución del proyecto (principios innegociables)
argument-hint: [contexto adicional]
disable-model-invocation: true
---

Vamos a revisar docs/constitution.md (o a crearla si no existe). Usa la skill sdd.
Antes de proponer nada, lee CLAUDE.md, MEMORY.md, docs/ESPECIFICACION.md, docs/constitution.md y el código del proyecto.
Contexto adicional: $ARGUMENTS

Proponme 6 principios innegociables, cortos y verificables, que cubran:
simplicidad del stack (Flutter + Firebase), relación entre spec y código, separación entre lógica
e interfaz (y entre la UI de Web y la de Android/iOS), tests como puerta (tests primero),
protección de los datos de las clientas e idioma del código y los textos (ES/PT).
Máximo 15 líneas. Si ya existe, muéstrame solo los cambios que propones.

NO escribas el archivo todavía: espera mi aprobación.

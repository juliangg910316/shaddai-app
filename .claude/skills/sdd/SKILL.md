---
name: sdd
description: Úsala siempre que trabajes con Spec-Driven Development en este proyecto (docs/constitution.md, docs/ESPECIFICACION.md o cualquier archivo dentro de specs/) - redactar, revisar o cambiar specs, planes y tareas, o implementar y validar tareas de una spec.
---

# Spec-Driven Development (SDD)

## Flujo
Constitución → Spec → Clarificación → Plan → Tareas → Implementación → Validación → Cambio.
- Nunca pases a la siguiente fase sin la aprobación explícita del usuario.
- La spec manda: si algo no está en la spec, no se implementa. Si falta una decisión, para y pregunta.
- Un cambio de requisitos se hace primero en la spec, luego en el plan y las tareas, y por último en el código.
- Cada spec vive en su carpeta: `specs/NNN-nombre/` con `spec.md`, `plan.md` y `tasks.md`.
- `docs/ESPECIFICACION.md` es la visión global del producto (decisiones, roles, modelo de datos, glosario, alcance y **requisitos comunes**, que aplican a todas las specs). Los requisitos de cada funcionalidad viven solo en su spec: no los dupliques.
- `CLAUDE.md` describe la arquitectura y las reglas del código; `docs/constitution.md`, los principios innegociables.
- Antes de planificar, revisa qué parte de la spec ya existe en el código: el plan parte de ahí, no lo rehace.
- Al terminar cada fase, actualiza `MEMORY.md`.

## Estados
`spec.md`, `plan.md` y `tasks.md` empiezan con una línea `Estado:`.
- Al crearse o cambiar: `Estado: borrador`.
- **Cuando el usuario apruebe explícitamente** un archivo en la conversación, cambia su línea a `Estado: aprobada`. Nunca lo apruebes por tu cuenta.
- Una fase solo empieza si la anterior está `aprobada`: el plan exige la spec aprobada; las tareas, el plan aprobado; la implementación, las tareas aprobadas.
- Cuando la validación confirma que se cumple, la spec pasa a `implementada`.
- Si cambia la spec (`/sdd-change`), vuelve a `borrador`, y `plan.md` y `tasks.md` (si existen) también, hasta que se revisen.

## Plantilla de spec (spec.md)
```
# Spec NNN — <Nombre>
Estado: borrador | aprobada | implementada
## Contexto y objetivo
## Usuarios (cliente, admin, visitante sin sesión…)
## Historias de usuario
- HU-1. Como <rol>, quiero <acción> para <beneficio>.
## Definiciones (solo si hay términos que puedan interpretarse de varias formas)
## Requisitos funcionales
## Requisitos no funcionales
## Plataformas (qué cambia en Web y qué en Android/iOS, si algo cambia)
## Navegación (desde dónde se llega a esta funcionalidad y a dónde se puede ir)
## Casos límite
## Fuera de alcance
## Criterios de finalización
## Dudas abiertas
- [NECESITA ACLARACIÓN] <duda>
```
La spec describe el QUÉ y el POR QUÉ. Nada de stack, arquitectura ni nombres de archivos. Cada spec define su propia navegación. La UI se separa por plataforma (Web = landing con scroll; Android/iOS = barra de navegación inferior): si la funcionalidad se ve distinta en cada una, dilo en "Plataformas".

## Requisitos en EARS (en español)
- RF-x: CUANDO <evento>, EL SISTEMA <respuesta>.
- RF-x: SI <condición no deseada>, ENTONCES EL SISTEMA <respuesta>.
- RF-x: MIENTRAS <estado>, EL SISTEMA <respuesta>.
- RF-x: EL SISTEMA <comportamiento permanente>.

Una frase = un comportamiento. Cada RF debe ser verificable (casi un test): nada de "rápido", "intenso" o "bonito" sin un criterio medible.

## Plan (plan.md)
`Estado: borrador` · Qué parte de la spec ya existe en el código · Archivos que se crean o modifican y su responsabilidad, respetando las capas de `CLAUDE.md` (`features → data → Firebase`; solo `lib/data/` toca Firebase) · Funciones puras de lógica y validaciones (sin imports de Flutter ni Firebase, con "ahora" como parámetro) · Algoritmo en pseudocódigo · Interfaz: pantallas en Web y en Android/iOS, providers y controladores Riverpod, rutas de `go_router` y guardas · Datos: colecciones y campos de Firestore, compatibilidad con los documentos existentes, `firestore.rules` e índices · Textos nuevos en los `.arb` (ES y PT) · Decisiones justificadas con su alternativa descartada · Estrategia de tests (qué test cubre cada RF). Indica qué RF cubre cada parte. Una dependencia nueva es siempre decisión del autor.

## Tareas (tasks.md)
```
Estado: borrador

- [ ] **Tn. <Descripción>.** RF-x, RF-y
  - Tests: <qué test se escribe primero>.
  - Hecho cuando: <comprobación verificable>.
```
Máximo 20-30 min por tarea, en orden de dependencia. Si salen más de 10, propón dividir la spec.

## Implementación (tests primero)
Una sola tarea cada vez:
1. Escribe primero los tests de la tarea y ejecuta `flutter test`: deben fallar (rojo).
2. Escribe el código mínimo para que pasen (verde). Prohibido avanzar con tests en rojo.
3. Si cambian los `.arb`, ejecuta `flutter gen-l10n`.
4. `dart format .` → `flutter analyze` sin errores ni avisos → `flutter test` en verde.
5. Marca la tarea y PARA.

Firebase en los tests: los repositorios reciben `FirebaseFirestore`/`FirebaseAuth` por constructor; en los tests se inyectan fakes. Nunca se usan los servicios reales de Firebase en un test.

## Validación
Recorre la spec RF por RF:
- Cada RF con su test: qué test lo cubre y si pasa.
- **Interfaz**: recorrido manual con los pasos exactos para que el autor lo ejecute y confirme. En Android/iOS con `flutter run` (emulador, simulador o dispositivo); en Web con `flutter run -d chrome` (se puede revisar con Chrome DevTools). Incluye tema claro y oscuro, español y portugués, y ancho menor y mayor de 900 px en Web cuando la spec lo afecte.
- Veredicto final: ¿la spec está cumplida?

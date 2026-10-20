---
name: sdd-validate
description: SDD · Valida la spec RF por RF (tests + recorrido en Web y en Android o iOS)
argument-hint: <NNN-nombre>
disable-model-invocation: true
---

Recorre specs/$0/spec.md requisito por requisito. Usa la skill sdd.
Para cada RF indica qué código lo cumple, qué test lo cubre y cómo se verifica:
- Tests: ejecuta `flutter test` e indica para cada RF su test y si pasa.
- Interfaz: dame los pasos exactos de un recorrido manual para que yo lo ejecute y lo confirme:
  en Android o iOS con `flutter run` (emulador, simulador o dispositivo) y en Web con
  `flutter run -d chrome`, según las plataformas que afecte la spec. Incluye tema claro y oscuro,
  español y portugués, y en Web anchos menores y mayores de 900 px cuando aplique.

Ejecuta también `flutter analyze`.
Si algún RF no está cubierto, no tiene test o falla, dilo claramente. NO arregles nada todavía.
Después comprueba los criterios de finalización y dame un veredicto:
¿la spec está cumplida? Si lo está y lo confirmo, cambia su estado a "implementada" y actualiza MEMORY.md.

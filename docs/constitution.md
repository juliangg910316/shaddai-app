# Constitución — Studio Shaddai
Principios innegociables. Si una spec, un plan o una tarea los contradice, gana la constitución. Cambiarla requiere la aprobación del autor. Aprobada el 2026-10-20.

1. **Stack mínimo.** Flutter + Firebase (Auth, Firestore, Messaging, Functions) + Riverpod + go_router + intl. Nada de dependencias nuevas ni otros backends sin aprobación del autor.
2. **La spec manda.** No se implementa comportamiento nuevo sin una spec aprobada (las correcciones y refactors que no cambian el comportamiento no la necesitan). Todo cambio va primero a la spec, luego al plan y al final al código. Cada RF se puede rastrear hasta su test y el código que lo cumple.
3. **Capas y plataformas separadas.** Solo `lib/data/` toca Firebase. Las reglas de negocio (huecos libres, validaciones) son funciones puras, sin Flutter ni Firebase, que reciben "ahora" como parámetro. La UI de Web (landing con scroll) y la de Android/iOS (barra de navegación inferior) son vistas distintas sobre los mismos providers.
4. **Tests como puerta.** Tests primero. No se da una tarea por terminada si hay tests en rojo, si `dart format .` deja cambios o si `flutter analyze` da errores o avisos. Nunca se usa Firebase real en los tests.
5. **Los datos de las clientas son sagrados.** Solo se piden los datos necesarios. La seguridad está en `firestore.rules`, nunca solo en la interfaz. No se borra nada sin confirmación, y todo cambio en Firestore sigue leyendo los documentos existentes.
6. **Idiomas.** La interfaz va en español y portugués, con todos los textos en los `.arb` (nunca literales). Documentación, comentarios y commits en español; el código, en inglés.

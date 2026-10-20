/// Por qué no se pudo iniciar sesión (RF-22).
///
/// El controlador emite este valor, nunca un texto: la vista lo traduce con
/// los `.arb` al idioma activo, y el detalle técnico solo va al log.
enum AuthFailure {
  /// La administradora bloqueó a la clienta.
  blocked,

  /// La persona cerró el diálogo de Google sin elegir cuenta. No se muestra
  /// ningún mensaje.
  cancelled,

  /// Cualquier otro error de un servicio externo.
  unknown,
}

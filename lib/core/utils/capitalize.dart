/// Primera letra en mayúscula. `intl` da los nombres de meses y días en
/// minúscula en español y portugués ("octubre de 2026"), y la interfaz los
/// muestra como título.
String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

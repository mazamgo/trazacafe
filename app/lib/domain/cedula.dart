/// Cédula nicaragüense normalizada (`001-010190-0001A`), o `null` si no
/// tiene el formato: municipio (3 dígitos), fecha de nacimiento DDMMAA y 4
/// dígitos con una letra. Se acepta sin guiones y en minúsculas. Igual que
/// `normalizarCedula` de la API (backend/src/sync.ts).
String? normalizarCedula(String texto) {
  final m = RegExp(r'^(\d{3})(\d{2})(\d{2})(\d{2})(\d{4})([A-Z])$')
      .firstMatch(texto.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), ''));
  if (m == null) return null;
  final dia = int.parse(m[2]!);
  final mes = int.parse(m[3]!);
  if (dia < 1 || dia > 31 || mes < 1 || mes > 12) return null;
  return '${m[1]}-${m[2]}${m[3]}${m[4]}-${m[5]}${m[6]}';
}

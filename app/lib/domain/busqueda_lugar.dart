import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// Comunidad, comarca o pueblo de la lista de OpenStreetMap incluida en la
/// app (`assets/lugares_ni.json`, generada por
/// `schemas/scripts/lugares-nicaragua.ts`).
class Lugar {
  Lugar(this.nombre, this.punto, {this.municipio = '', this.departamento = ''})
    : _clave = normalizar('$nombre $municipio $departamento'),
      _nombre = normalizar(nombre);

  final String nombre;
  final LatLng punto;
  final String municipio;
  final String departamento;
  final String _clave;
  final String _nombre;

  /// "El Cuá, Jinotega" para distinguir los lugares con el mismo nombre.
  String get detalle => [
    municipio,
    departamento,
  ].where((s) => s.isNotEmpty && s != nombre).join(', ');
}

/// Lee el JSON compacto: `{municipios: [[nombre, depto]], lugares: [[nombre, lat, lon, municipio]]}`.
List<Lugar> parsearLugares(String json) {
  final datos = jsonDecode(json) as Map<String, dynamic>;
  final municipios = (datos['municipios'] as List).cast<List>();
  return [
    for (final l in (datos['lugares'] as List).cast<List>())
      Lugar(
        l[0] as String,
        LatLng((l[1] as num).toDouble(), (l[2] as num).toDouble()),
        municipio: (l[3] as int) >= 0 ? municipios[l[3] as int][0] as String : '',
        departamento: (l[3] as int) >= 0
            ? municipios[l[3] as int][1] as String
            : '',
      ),
  ];
}

const _sinTilde = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
  'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
};

/// Minúsculas, sin tildes y con un solo espacio: "El  Cuá" → "el cua".
String normalizar(String texto) => texto
    .toLowerCase()
    .split('')
    .map((c) => _sinTilde[c] ?? c)
    .join()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// Lugares que contienen todas las palabras buscadas (en el nombre, el
/// municipio o el departamento). Primero los que se llaman igual, después los
/// que empiezan así y al final los que solo las contienen.
List<Lugar> buscarLugares(List<Lugar> lugares, String texto, {int max = 20}) {
  final q = normalizar(texto);
  if (q.length < 2) return const [];
  final palabras = q.split(' ');
  int puntaje(Lugar l) {
    if (l._nombre == q) return 0;
    if (l._nombre.startsWith(q)) return 1;
    if (l._nombre.startsWith(palabras.first)) return 2;
    if (l._nombre.split(' ').any((p) => p.startsWith(palabras.first))) return 3;
    return 4;
  }

  final encontrados = [
    for (final l in lugares)
      if (palabras.every(l._clave.contains)) (puntaje(l), l),
  ]..sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      final largo = a.$2.nombre.length.compareTo(b.$2.nombre.length);
      return largo != 0 ? largo : a.$2.detalle.compareTo(b.$2.detalle);
    });
  return [for (final e in encontrados.take(max)) e.$2];
}

/// Enlace corto de Google Maps (`maps.app.goo.gl/…`): no trae coordenadas,
/// hay que abrirlo con señal para saber a dónde lleva.
bool esEnlaceCorto(String texto) =>
    RegExp(r'(maps\.app\.goo\.gl|goo\.gl/maps)/', caseSensitive: false)
        .hasMatch(texto);

const _numero = r'-?\d{1,3}(?:[.,]\d+)?';

/// Coordenadas escritas o pegadas, o `null` si el texto no las trae:
/// - `13.0910, -86.0023` o `13,0910 -86,0023`;
/// - `13°05'27.6"N 86°00'08.3"W` (también `O` de oeste) o `13.091 N, 86.002 W`;
/// - enlaces de Google Maps: `…/@13.09,-86.00,17z`, `?q=13.09,-86.00`, `!3d13.09!4d-86.00`.
LatLng? parsearCoordenadas(String texto) {
  final t = texto.trim();
  double n(String s) => double.parse(s.replaceAll(',', '.'));
  String decodificado;
  try {
    decodificado = Uri.decodeFull(t);
  } on ArgumentError {
    decodificado = t;
  }

  // Enlaces: el punto exacto (!3d!4d) va antes que el centro de la vista (@).
  for (final patron in [
    RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
    RegExp(r'[?&](?:q|query|ll|destination|center)=(-?\d+\.\d+),\s*(-?\d+\.\d+)'),
    RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
    RegExp(r'/place/(-?\d+\.\d+),\s*(-?\d+\.\d+)'),
  ]) {
    final m = patron.firstMatch(decodificado);
    if (m != null) return _valida(n(m[1]!), n(m[2]!));
  }

  // Con hemisferio: grados (y opcionalmente minutos y segundos) y N/S/E/W/O.
  final gms = RegExp(
    r'''(\d{1,3}(?:[.,]\d+)?)\s*°?\s*(?:(\d{1,2}(?:[.,]\d+)?)\s*['′]\s*)?(?:(\d{1,2}(?:[.,]\d+)?)\s*(?:["″]|'')\s*)?([NSEWO])\b''',
    caseSensitive: false,
  ).allMatches(t).toList();
  if (gms.length == 2) {
    double? lat, lon;
    for (final m in gms) {
      final valor =
          n(m[1]!) +
          (m[2] == null ? 0 : n(m[2]!) / 60) +
          (m[3] == null ? 0 : n(m[3]!) / 3600);
      switch (m[4]!.toUpperCase()) {
        case 'N':
          lat = valor;
        case 'S':
          lat = -valor;
        case 'E':
          lon = valor;
        case 'W' || 'O':
          lon = -valor;
      }
    }
    if (lat != null && lon != null) return _valida(lat, lon);
  }

  // Dos números: latitud y longitud.
  final dos = RegExp('^($_numero)\\s*[,; ]\\s*($_numero)\$').firstMatch(t);
  if (dos != null) return _valida(n(dos[1]!), n(dos[2]!));
  return null;
}

LatLng? _valida(double lat, double lon) {
  // Pegadas al revés (longitud primero): en la Antártida no hay fincas.
  if (lat < -60 && lon.abs() <= 60) (lat, lon) = (lon, lat);
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return LatLng(lat, lon);
}

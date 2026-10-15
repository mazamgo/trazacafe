import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';

/// Umbral del EUDR: las parcelas de 4 ha o más necesitan polígono completo;
/// las menores pueden declararse con un solo punto.
const double umbralPoligonoHa = 4.0;

bool requierePoligono(double areaHa) => areaHa >= umbralPoligonoHa;

/// Radio medio de la Tierra, el mismo que usa Turf.js v7 (`earthRadius`).
const double _radioTierra = 6371008.8;

/// Área de un polígono en hectáreas, con el mismo método que Turf.js.
/// Acepta el anillo abierto o cerrado.
double areaHectareas(List<LatLng> puntos) {
  if (puntos.length < 3) return 0;
  final anillo = List<LatLng>.of(puntos);
  if (anillo.first != anillo.last) anillo.add(anillo.first);

  double total = 0;
  for (var i = 0; i < anillo.length - 1; i++) {
    final p1 = anillo[i];
    final p2 = anillo[i + 1];
    final p3 = anillo[(i + 2) % (anillo.length - 1)];
    total += (_rad(p3.longitude) - _rad(p1.longitude)) *
        math.sin(_rad(p2.latitude));
  }
  final m2 = (total * _radioTierra * _radioTierra / 2).abs();
  return m2 / 10000;
}

double _rad(double grados) => grados * math.pi / 180;

/// Texto canónico de las coordenadas: `lon,lat;lon,lat` con 6 decimales
/// (~11 cm). El backend usa exactamente el mismo formato; ver
/// `schemas/test-vectors.json`.
String coordenadasCanonicas(List<LatLng> puntos) => puntos
    .map((p) =>
        '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
    .join(';');

/// Hash `0x…` (SHA-256) de las coordenadas: va en la attestation en lugar
/// de la ubicación exacta, para proteger la privacidad del productor.
String geoHash(List<LatLng> puntos) =>
    '0x${sha256.convert(utf8.encode(coordenadasCanonicas(puntos)))}';

enum ProblemaPoligono { pocosPuntos, puntosRepetidos, seCruza }

extension ProblemaPoligonoTexto on ProblemaPoligono {
  /// Código igual al de la API (`schemas/src/index.ts`).
  String get codigo => switch (this) {
        ProblemaPoligono.pocosPuntos => 'pocos_puntos',
        ProblemaPoligono.puntosRepetidos => 'puntos_repetidos',
        ProblemaPoligono.seCruza => 'se_cruza',
      };

  String get mensaje => switch (this) {
        ProblemaPoligono.pocosPuntos => 'Marca al menos 3 puntos para el polígono.',
        ProblemaPoligono.puntosRepetidos =>
          'Hay dos puntos seguidos en el mismo lugar. Quita el último.',
        ProblemaPoligono.seCruza =>
          'Los linderos se cruzan. Marca los puntos en orden, siguiendo el borde de la finca.',
      };
}

/// Por qué el polígono no es válido para el EUDR, o `null` si lo es. Recibe
/// el anillo abierto. Mismo algoritmo que `problemaPoligono` de la API
/// (schemas/src/index.ts); ambos se prueban con test-vectors.json.
ProblemaPoligono? problemaPoligono(List<LatLng> puntos) {
  final n = puntos.length;
  if (n < 3) return ProblemaPoligono.pocosPuntos;
  List<double> p(int i) => [puntos[i % n].longitude, puntos[i % n].latitude];

  for (var i = 0; i < n; i++) {
    if (p(i)[0] == p(i + 1)[0] && p(i)[1] == p(i + 1)[1]) {
      return ProblemaPoligono.puntosRepetidos;
    }
  }
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final a = p(i), b = p(i + 1), c = p(j), d = p(j + 1);
      if (j == i + 1) {
        // Lados seguidos comparten b: solo fallan si el segundo "regresa".
        if (_seDevuelve(a, b, d)) return ProblemaPoligono.seCruza;
      } else if (i == 0 && j == n - 1) {
        // El último lado termina en el primer punto (a).
        if (_seDevuelve(b, a, c)) return ProblemaPoligono.seCruza;
      } else if (_segmentosSeTocan(a, b, c, d)) {
        return ProblemaPoligono.seCruza;
      }
    }
  }
  return null;
}

int _orientacion(List<double> p, List<double> q, List<double> r) =>
    ((q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])).sign.toInt();

bool _dentroDelRectangulo(List<double> p, List<double> q, List<double> r) =>
    math.min(p[0], q[0]) <= r[0] &&
    r[0] <= math.max(p[0], q[0]) &&
    math.min(p[1], q[1]) <= r[1] &&
    r[1] <= math.max(p[1], q[1]);

bool _segmentosSeTocan(List<double> a, List<double> b, List<double> c, List<double> d) {
  final o1 = _orientacion(a, b, c);
  final o2 = _orientacion(a, b, d);
  final o3 = _orientacion(c, d, a);
  final o4 = _orientacion(c, d, b);
  if (o1 != o2 && o3 != o4) return true;
  return (o1 == 0 && _dentroDelRectangulo(a, b, c)) ||
      (o2 == 0 && _dentroDelRectangulo(a, b, d)) ||
      (o3 == 0 && _dentroDelRectangulo(c, d, a)) ||
      (o4 == 0 && _dentroDelRectangulo(c, d, b));
}

/// Los lados p→s y s→q van en línea recta pero de regreso (una "espina").
bool _seDevuelve(List<double> p, List<double> s, List<double> q) {
  if (_orientacion(p, s, q) != 0) return false;
  return (p[0] - s[0]) * (q[0] - s[0]) + (p[1] - s[1]) * (q[1] - s[1]) > 0;
}

/// El GPS del celular varía unos metros aunque el técnico no se mueva; un
/// punto nuevo más cerca que esto del anterior se descarta.
const double distanciaMinimaGpsMetros = 3.0;

double distanciaMetros(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

/// Coordenadas en formato GeoJSON (`[[lon, lat], ...]`) para guardar y exportar.
String aGeoJsonCoords(List<LatLng> puntos) =>
    jsonEncode(puntos.map((p) => [p.longitude, p.latitude]).toList());

List<LatLng> desdeGeoJsonCoords(String json) => (jsonDecode(json) as List)
    .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
    .toList();

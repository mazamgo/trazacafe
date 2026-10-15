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

/// Coordenadas en formato GeoJSON (`[[lon, lat], ...]`) para guardar y exportar.
String aGeoJsonCoords(List<LatLng> puntos) =>
    jsonEncode(puntos.map((p) => [p.longitude, p.latitude]).toList());

List<LatLng> desdeGeoJsonCoords(String json) => (jsonDecode(json) as List)
    .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
    .toList();

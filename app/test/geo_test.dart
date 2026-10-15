import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trazacafe/domain/geo.dart';

/// Los mismos casos que usa el backend (schemas/test-vectors.json): si la app
/// y el backend calculan distinto el hash, la sincronización se rechaza.
void main() {
  final vectores = jsonDecode(
    File('../schemas/test-vectors.json').readAsStringSync(),
  ) as List;

  for (final v in vectores) {
    final puntos = (v['coords'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    group(v['nombre'] as String, () {
      test('coordenadas canónicas y geoHash iguales al backend', () {
        expect(coordenadasCanonicas(puntos), v['canonico']);
        expect(geoHash(puntos), v['geoHash']);
      });

      test('área igual a Turf.js', () {
        expect(areaHectareas(puntos), closeTo((v['areaHa'] as num).toDouble(), 1e-4));
      });
    });
  }

  test('regla EUDR: polígono obligatorio desde 4 ha', () {
    expect(requierePoligono(3.99), isFalse);
    expect(requierePoligono(4), isTrue);
  });

  test('GeoJSON ida y vuelta conserva las coordenadas', () {
    final puntos = [const LatLng(13.091, -86.0023), const LatLng(13.092, -86.0013)];
    expect(desdeGeoJsonCoords(aGeoJsonCoords(puntos)), puntos);
  });
}

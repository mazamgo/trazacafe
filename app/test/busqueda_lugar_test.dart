import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trazacafe/domain/busqueda_lugar.dart';

void main() {
  group('parsearCoordenadas', () {
    void es(String texto, double lat, double lon) {
      final p = parsearCoordenadas(texto);
      expect(p, isNotNull, reason: texto);
      expect(p!.latitude, closeTo(lat, 1e-4), reason: texto);
      expect(p.longitude, closeTo(lon, 1e-4), reason: texto);
    }

    test('decimales con coma, espacio o punto y coma', () {
      es('13.0910, -86.0023', 13.0910, -86.0023);
      es('13.0910 -86.0023', 13.0910, -86.0023);
      es(' 13.0910;-86.0023 ', 13.0910, -86.0023);
      es('13,0910 -86,0023', 13.0910, -86.0023);
      es('13,0910, -86,0023', 13.0910, -86.0023);
    });

    test('al revés (longitud primero) se corrige', () {
      es('-86.0023, 13.0910', 13.0910, -86.0023);
    });

    test('grados, minutos y segundos con hemisferio', () {
      es('13°05\'27.6"N 86°00\'08.3"W', 13.091, -86.00231);
      es('13°05\'27.6"N 86°00\'08.3"O', 13.091, -86.00231);
      es('13.091 N, 86.0023 W', 13.091, -86.0023);
      es("13°05'N 86°00'W", 13.08333, -86.0);
    });

    test('enlaces de Google Maps', () {
      es('https://www.google.com/maps/@13.0910,-86.0023,17z', 13.0910, -86.0023);
      es('https://maps.google.com/?q=13.0910,-86.0023', 13.0910, -86.0023);
      es('https://www.google.com/maps/search/?api=1&query=13.0910%2C-86.0023', 13.0910, -86.0023);
      es(
        'https://www.google.com/maps/place/Finca/@13.1,-86.1,15z/data=!3m1!4b1!4m6!3m5!3d13.0910!4d-86.0023',
        13.0910,
        -86.0023,
      );
    });

    test('texto que no son coordenadas', () {
      expect(parsearCoordenadas('El Cuá'), isNull);
      expect(parsearCoordenadas('13.09'), isNull);
      expect(parsearCoordenadas('120, 300'), isNull);
      expect(parsearCoordenadas(''), isNull);
    });

    test('enlace corto', () {
      expect(esEnlaceCorto('https://maps.app.goo.gl/abc123'), isTrue);
      expect(parsearCoordenadas('https://maps.app.goo.gl/abc123'), isNull);
      expect(esEnlaceCorto('13.09, -86.00'), isFalse);
    });
  });

  group('buscarLugares', () {
    final lugares = [
      Lugar('Jinotega', const LatLng(13.09, -86.0), municipio: 'Jinotega', departamento: 'Jinotega'),
      Lugar('El Cuá', const LatLng(13.37, -85.67), municipio: 'El Cuá', departamento: 'Jinotega'),
      Lugar('San José', const LatLng(13.2, -85.8), municipio: 'El Cuá', departamento: 'Jinotega'),
      Lugar('San José', const LatLng(12.9, -85.9), municipio: 'Matagalpa', departamento: 'Matagalpa'),
      Lugar('Colonia San José de las Mulas', const LatLng(12.5, -85.5), municipio: 'Matiguás', departamento: 'Matagalpa'),
      Lugar('La Cuchilla', const LatLng(13.3, -85.7), municipio: 'El Cuá', departamento: 'Jinotega'),
    ];
    List<String> nombres(String q) => [for (final l in buscarLugares(lugares, q)) '${l.nombre} (${l.municipio})'];

    test('ignora tildes y mayúsculas', () {
      expect(nombres('jinotega').first, 'Jinotega (Jinotega)');
      expect(nombres('EL CUA').first, 'El Cuá (El Cuá)');
    });

    test('el nombre exacto va primero y el municipio desempata', () {
      expect(nombres('san jose').take(2), ['San José (El Cuá)', 'San José (Matagalpa)']);
      expect(nombres('san jose').last, 'Colonia San José de las Mulas (Matiguás)');
      expect(nombres('san jose matagalpa'), ['San José (Matagalpa)', 'Colonia San José de las Mulas (Matiguás)']);
    });

    test('menos de 2 letras no busca', () {
      expect(nombres('s'), isEmpty);
    });

    test('detalle sin repetir el nombre', () {
      expect(lugares[0].detalle, '', reason: 'municipio y departamento se llaman igual que el lugar');
      expect(lugares[2].detalle, 'El Cuá, Jinotega');
    });
  });

  test('el asset de lugares se puede leer', () {
    final lugares = parsearLugares(File('assets/lugares_ni.json').readAsStringSync());
    expect(lugares.length, greaterThan(1000));
    expect(buscarLugares(lugares, 'jinotega'), isNotEmpty);
    for (final l in lugares) {
      // Nicaragua, con margen (incluye los cayos del Caribe).
      expect(l.punto.latitude, inInclusiveRange(10.5, 15.5), reason: l.nombre);
      expect(l.punto.longitude, inInclusiveRange(-88, -82), reason: l.nombre);
    }
  });
}

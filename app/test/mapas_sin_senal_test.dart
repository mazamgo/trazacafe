import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/mapas_sin_senal_screen.dart';
import 'package:trazacafe/services/mapas_sin_senal.dart';
import 'package:trazacafe/services/mbtiles.dart';

const indice = {
  'paquetes': [
    {
      'id': 'jinotega',
      'nombre': 'Jinotega (zona cafetalera)',
      'archivo': 'jinotega.mbtiles',
      'bytes': 6,
      'bounds': [-86.3, 12.95, -85.3, 13.85],
      'minzoom': 8,
      'maxzoom': 14,
      'imagenes': '2025-12-01 a 2026-05-15',
      'atribucion': 'Contains modified Copernicus Sentinel data 2026',
    },
  ],
};

void main() {
  late Directory temporal;
  setUp(() => temporal = Directory.systemTemp.createTempSync('trazacafe_mapas'));
  tearDown(() => temporal.deleteSync(recursive: true));

  MapasSinSenal servicio({int estado = 200}) => MapasSinSenal(
        carpeta: () async => Directory('${temporal.path}/mapas'),
        cliente: MockClient((req) async {
          if (req.url.path.endsWith('indice.json')) return http.Response(jsonEncode(indice), 200);
          if (req.url.path.endsWith('jinotega.mbtiles')) return http.Response.bytes([1, 2, 3, 4, 5, 6], estado);
          return http.Response('', 404);
        }),
      );

  test('lee los mosaicos del MBTiles con filas TMS (de sur a norte)', () {
    final ruta = '${temporal.path}/prueba.mbtiles';
    final db = sqlite3.open(ruta)
      ..execute('CREATE TABLE tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob)')
      ..execute('INSERT INTO tiles VALUES (14, 4300, ?, ?)', [(1 << 14) - 1 - 7561, Uint8List.fromList([9, 8, 7])]);
    db.close();

    final p = MbTilesTileProvider(ruta);
    expect(p.leer(14, 4300, 7561), [9, 8, 7]);
    expect(p.leer(14, 4300, 7562), isNull, reason: 'fuera del paquete no hay mosaico');
    p.dispose();
  });

  test('lista, descarga con avance, queda en el celular y se borra', () async {
    final s = servicio();
    final disponibles = await s.disponibles();
    expect(disponibles.single.nombre, 'Jinotega (zona cafetalera)');
    expect(disponibles.single.maxZoom, 14);
    expect(await s.descargados(), isEmpty);

    final avances = <double>[];
    final m = await s.descargar(disponibles.single, avance: avances.add);
    expect(avances.last, 1);
    expect(File(m.ruta).readAsBytesSync(), [1, 2, 3, 4, 5, 6]);

    final enCelular = await s.descargados();
    expect(enCelular.single.paquete.atribucion, contains('Copernicus'));
    expect(enCelular.single.paquete.limites.north, 13.85);

    await s.borrar('jinotega');
    expect(await s.descargados(), isEmpty);
    expect(Directory('${temporal.path}/mapas').listSync(), isEmpty);
  });

  test('una descarga que falla no deja un mapa a medias', () async {
    final s = servicio(estado: 500);
    final p = (await s.disponibles()).single;
    await expectLater(s.descargar(p), throwsA(isA<HttpException>()));
    expect(await s.descargados(), isEmpty);
  });

  testWidgets('la pantalla ofrece descargar y, sin señal, explica que lo descargado sigue sirviendo', (tester) async {
    Future<void> abrir(MapasSinSenal s) async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          mapasSinSenalProvider.overrideWithValue(s),
          mapasDescargadosProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: MapasSinSenalScreen()),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    await abrir(servicio());
    expect(find.text('Jinotega (zona cafetalera)'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Descargar'), findsOneWidget);

    await abrir(MapasSinSenal(
      carpeta: () async => Directory('${temporal.path}/mapas'),
      cliente: MockClient((_) async => throw http.ClientException('sin señal')),
    ));
    expect(find.textContaining('Sin señal: la lista de mapas necesita internet'), findsOneWidget);
  });
}

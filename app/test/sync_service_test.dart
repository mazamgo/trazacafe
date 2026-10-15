import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/domain/geo.dart';
import 'package:trazacafe/services/api_client.dart';
import 'package:trazacafe/services/sync_service.dart';

/// Mismo JSON que valida el backend en backend/test/contrato.test.ts.
final ejemplo = jsonDecode(
  File('../schemas/fixtures/sync-ejemplo.json').readAsStringSync(),
) as Map<String, dynamic>;

Future<void> cargarEjemplo(AppDatabase db) async {
  final p = (ejemplo['productores'] as List).single as Map;
  final f = (ejemplo['fincas'] as List).single as Map;
  final foto = (ejemplo['fotos'] as List).single as Map;
  final puntos = [
    for (final c in f['coordenadas'] as List)
      LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
  ];

  await db.into(db.productores).insert(ProductoresCompanion.insert(
        id: p['id'],
        nombre: p['nombre'],
        comunidad: Value(p['comunidad']),
        consentimientoFirmado: const Value(true),
      ));
  await db.into(db.fincas).insert(FincasCompanion.insert(
        id: f['id'],
        productorId: p['id'],
        nombre: f['nombre'],
        coordenadasJson: aGeoJsonCoords(puntos),
        areaHa: (f['areaHa'] as num).toDouble(),
        geoHash: geoHash(puntos),
      ));
  await db.into(db.fotos).insert(FotosCompanion.insert(
        id: foto['id'],
        entidadTipo: foto['entidadTipo'],
        entidadId: foto['entidadId'],
        tipo: foto['tipo'],
        ruta: '/tmp/foto.jpg',
        sha256: foto['sha256'],
      ));
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await cargarEjemplo(db);
  });
  tearDown(() => db.close());

  ApiClient api(http.Client cliente, {String? token = 'token'}) =>
      ApiClient(token: () async => token, cliente: cliente, baseUrl: 'https://api.test');

  test('el payload coincide con el contrato que valida el backend', () async {
    expect(SyncService.payload(await db.pendientes()), ejemplo);
  });

  test('envía lo pendiente con el token y lo marca como sincronizado', () async {
    late http.Request enviada;
    final cliente = MockClient((req) async {
      enviada = req;
      return http.Response('{"recibidos":{}}', 200);
    });

    final r = await SyncService(db, api(cliente)).sincronizar();

    expect(r.enviados, 3);
    expect(enviada.url.toString(), 'https://api.test/v1/sync');
    expect(enviada.headers['Authorization'], 'Bearer token');
    expect((await db.pendientes()).vacio, isTrue);
    expect(await db.observarTotalPendientes().first, 0);
  });

  test('si la API rechaza, nada se marca y el error explica por qué', () async {
    final cliente = MockClient((_) async => http.Response(
          jsonEncode({
            'error': 'Datos inválidos',
            'detalles': [
              {'message': 'geoHash no coincide con las coordenadas'},
            ],
          }),
          422,
        ));

    await expectLater(
      SyncService(db, api(cliente)).sincronizar(),
      throwsA(isA<ApiError>().having((e) => e.mensaje, 'mensaje', contains('geoHash no coincide'))),
    );
    expect((await db.pendientes()).total, 3);
  });

  test('sin sesión no llama a la API', () async {
    var llamadas = 0;
    final cliente = MockClient((_) async {
      llamadas++;
      return http.Response('{}', 200);
    });

    await expectLater(
      SyncService(db, api(cliente, token: null)).sincronizar(),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
    expect(llamadas, 0);
  });

  test('sin pendientes no hace nada', () async {
    await db.marcarSincronizados(await db.pendientes());
    final cliente = MockClient((_) async => fail('no debía llamar a la API'));
    expect((await SyncService(db, api(cliente)).sincronizar()).enviados, 0);
  });
}

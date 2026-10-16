import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/domain/geo.dart';
import 'package:trazacafe/services/api_client.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/sync_service.dart';

import 'fakes.dart';

/// Mismo JSON que valida el backend en backend/test/contrato.test.ts.
final ejemplo = jsonDecode(
  File('../schemas/fixtures/sync-ejemplo.json').readAsStringSync(),
) as Map<String, dynamic>;

const org = '11111111-1111-4111-8111-111111111111';
const tecnico = Sesion(uid: 'u1', email: 't@coop.org', organizacionId: org, rol: 'tecnico');
const vacio = {'productores': [], 'fincas': [], 'entregas': []};

class SubidorFalso implements SubidorArchivos {
  final subidas = <String>[];
  Exception? fallar;

  @override
  Future<void> subir(String rutaStorage, File archivo) async {
    if (fallar != null) throw fallar!;
    subidas.add(rutaStorage);
  }
}

late Directory temporal;

Future<void> cargarEjemplo(AppDatabase db) async {
  final p = (ejemplo['productores'] as List).single as Map;
  final f = (ejemplo['fincas'] as List).single as Map;
  final e = (ejemplo['entregas'] as List).single as Map;
  final foto = (ejemplo['fotos'] as List).single as Map;
  final puntos = [
    for (final c in f['coordenadas'] as List)
      LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
  ];
  final archivo = File('${temporal.path}/foto.jpg')..writeAsBytesSync([1, 2, 3]);

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
  await db.into(db.entregas).insert(EntregasCompanion.insert(
        id: e['id'],
        fincaId: f['id'],
        kg: (e['kg'] as num).toDouble(),
        estado: e['estado'],
        fecha: DateTime.parse(e['fecha']),
      ));
  await db.into(db.fotos).insert(FotosCompanion.insert(
        id: foto['id'],
        entidadTipo: foto['entidadTipo'],
        entidadId: foto['entidadId'],
        tipo: foto['tipo'],
        ruta: archivo.path,
        sha256: foto['sha256'],
      ));
}

void main() {
  late AppDatabase db;
  late SubidorFalso subidor;

  setUp(() async {
    temporal = Directory.systemTemp.createTempSync('trazacafe_test');
    db = AppDatabase(NativeDatabase.memory());
    subidor = SubidorFalso();
    await cargarEjemplo(db);
  });
  tearDown(() async {
    await db.close();
    temporal.deleteSync(recursive: true);
  });

  final fotoId = (ejemplo['fotos'] as List).single['id'] as String;

  /// API que acepta todo y devuelve [datos] en GET /v1/datos.
  ApiFalsa apiOk({Map<String, dynamic> datos = vacio}) => ApiFalsa({
        'POST /v1/sync': (200, {'recibidos': {}}),
        'POST /v1/fotos/$fotoId/subida': (200, {'storagePath': 'x'}),
        'GET /v1/datos': (200, datos),
      });

  SyncService servicio(ApiFalsa api, {Sesion? sesion = tecnico}) => SyncService(
        db,
        api.cliente(AuthFalso(inicial: sesion)),
        subidor,
        () => sesion?.organizacionId,
      );

  test('el payload coincide con el contrato que valida el backend', () async {
    expect(SyncService.payload(await db.pendientes()), ejemplo);
  });

  test('envía lo pendiente, sube la foto a la carpeta de la organización y la confirma', () async {
    final api = apiOk();
    final r = await servicio(api).sincronizar();

    expect(r.enviados, 4);
    expect(r.fotosSubidas, 1);
    expect(r.errorFotos, isNull);
    expect(subidor.subidas, ['organizaciones/$org/fotos/$fotoId.jpg']);
    expect(api.peticiones.map((p) => '${p.method} ${p.url.path}'), [
      'POST /v1/sync',
      'POST /v1/fotos/$fotoId/subida',
      'GET /v1/datos',
    ]);
    expect(await db.observarTotalPendientes().first, 0);
  });

  test('si la API rechaza el envío, nada se marca y no se suben fotos', () async {
    final api = ApiFalsa({
      'POST /v1/sync': (
        422,
        {
          'error': 'Datos inválidos',
          'detalles': [
            {'message': 'geoHash no coincide con las coordenadas'},
          ],
        },
      ),
    });

    await expectLater(
      servicio(api).sincronizar(),
      throwsA(isA<ApiError>().having((e) => e.mensaje, 'mensaje', contains('geoHash no coincide'))),
    );
    expect((await db.pendientes()).total, 4);
    expect(subidor.subidas, isEmpty);
  });

  test('si la API no confirma la foto, se reintenta la próxima vez', () async {
    final api = ApiFalsa({
      'POST /v1/sync': (200, {'recibidos': {}}),
      'POST /v1/fotos/$fotoId/subida': (409, {'error': 'sin_archivo', 'mensaje': 'El archivo todavía no está en Storage.'}),
      'GET /v1/datos': (200, vacio),
    });
    final r = await servicio(api).sincronizar();

    expect(r.fotosSubidas, 0);
    expect(r.errorFotos, contains('todavía no está'));
    expect(await db.fotosPorSubir(), hasLength(1));
  });

  test('si la subida falla porque el archivo ya está, igual pide la confirmación', () async {
    subidor.fallar = Exception('permission-denied');
    final r = await servicio(apiOk()).sincronizar();
    expect(r.fotosSubidas, 1);
  });

  test('sin sesión no llama a la API', () async {
    final api = apiOk();
    await expectLater(
      servicio(api, sesion: null).sincronizar(),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
    expect(api.peticiones, isEmpty);
  });

  group('descarga de los datos de la organización', () {
    test('agrega lo que registró otro técnico, ya como sincronizado', () async {
      await servicio(apiOk()).sincronizar();
      final datos = {
        'productores': [
          ...(ejemplo['productores'] as List).map((p) => {...p, 'consentimientoFirmado': true}),
          {'id': 'p-otro', 'nombre': 'Otro productor', 'cedula': null, 'comunidad': 'El Tuma', 'consentimientoFirmado': true},
        ],
        'fincas': [
          for (final f in ejemplo['fincas'] as List) {...f, 'areaOficialHa': 1.2001, 'deforestacion': 'pendiente', 'attestationUid': null},
          {
            'id': 'f-otra',
            'productorId': 'p-otro',
            'nombre': 'La Otra',
            'coordenadas': [[-86.1, 13.1]],
            'areaHa': 2.0,
            'areaOficialHa': 2.0,
            'geoHash': '0x${'0' * 64}',
            'deforestacion': 'pendiente',
            'attestationUid': null,
          },
        ],
        'entregas': ejemplo['entregas'],
      };

      await servicio(apiOk(datos: datos)).sincronizar();

      final fincas = await db.select(db.fincas).get();
      expect(fincas.map((f) => f.id), containsAll(['f-otra', (ejemplo['fincas'] as List).single['id']]));
      expect(fincas.every((f) => f.sincronizado), isTrue);
      final mia = fincas.firstWhere((f) => f.id != 'f-otra');
      expect(mia.areaOficialHa, 1.2001);
      expect(await db.observarTotalPendientes().first, 0);
    });

    test('no pisa lo que este celular todavía no envió', () async {
      final finca = (ejemplo['fincas'] as List).single as Map<String, dynamic>;
      final local = await (db.select(db.fincas)..where((f) => f.id.equals(finca['id']))).getSingle();
      final datos = {
        'productores': [],
        'fincas': [
          {...finca, 'nombre': 'Nombre del servidor', 'areaOficialHa': 9.9, 'deforestacion': 'pendiente', 'attestationUid': null},
        ],
        'entregas': [],
      };
      // Solo la descarga: el envío falla, así que la finca sigue pendiente.
      final api = ApiFalsa({'POST /v1/sync': (503, null), 'GET /v1/datos': (200, datos)});
      await expectLater(servicio(api).sincronizar(), throwsA(isA<ApiError>()));
      await db.aplicarDatosServidor(SyncService.desdeServidor(datos));

      final despues = await (db.select(db.fincas)..where((f) => f.id.equals(finca['id']))).getSingle();
      expect(despues.nombre, local.nombre);
      expect(despues.sincronizado, isFalse);
    });

    test('quita las fincas que otro técnico borró en el servidor', () async {
      await servicio(apiOk()).sincronizar(); // todo queda sincronizado
      // El servidor ya no tiene la finca (ni su entrega).
      await servicio(apiOk(datos: {'productores': ejemplo['productores'], 'fincas': [], 'entregas': []})).sincronizar();

      expect(await db.select(db.fincas).get(), isEmpty);
      expect(await db.select(db.entregas).get(), isEmpty);
      expect(await db.select(db.productores).get(), hasLength(1));
    });
  });

  test('sin pendientes solo descarga', () async {
    await servicio(apiOk()).sincronizar();
    final api = apiOk();
    final r = await servicio(api).sincronizar();
    expect(r.enviados, 0);
    expect(api.peticiones.map((p) => p.url.path), ['/v1/datos']);
  });
}

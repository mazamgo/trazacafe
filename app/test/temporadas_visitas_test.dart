import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/services/sync_service.dart';

/// Temporadas, visitas de verificación y versiones del lindero en la base local.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'P'));
    await db.into(db.temporadas).insert(TemporadasCompanion.insert(
          id: 't1',
          nombre: '2026/27',
          inicio: DateTime(2026, 10, 1),
          fin: DateTime(2027, 9, 30),
        ));
  });
  tearDown(() => db.close());

  Future<Finca> finca({bool sincronizada = true}) async {
    await db.into(db.fincas).insert(FincasCompanion.insert(
          id: 'f1',
          productorId: 'p1',
          nombre: 'Leona II',
          coordenadasJson: '[[-86.0,13.0],[-86.001,13.0],[-86.001,13.001]]',
          areaHa: 1.0,
          geoHash: '0xviejo',
          sincronizado: Value(sincronizada),
        ));
    return (db.select(db.fincas)..where((f) => f.id.equals('f1'))).getSingle();
  }

  VerificacionesCompanion visita(String id) => VerificacionesCompanion.insert(
        id: id,
        fincaId: 'f1',
        fecha: DateTime(2026, 10, 16, 10),
        linderoCambio: const Value(true),
        versionFinca: 1,
      );

  const nuevo = (coordenadasJson: '[[-86.0,13.0],[-86.002,13.0],[-86.002,13.002]]', areaHa: 4.5, geoHash: '0xnuevo');

  test('la temporada se encuentra por día de calendario, incluidos los extremos', () async {
    expect((await db.temporadaDe(DateTime(2026, 10, 1, 0, 5)))?.id, 't1');
    expect((await db.temporadaDe(DateTime(2027, 9, 30, 23, 59)))?.id, 't1');
    expect(await db.temporadaDe(DateTime(2026, 9, 30, 23, 59)), isNull);
  });

  test('visita con lindero nuevo en una finca enviada: crea la versión 2 y conserva la 1 en el servidor', () async {
    final f = await finca();
    await db.guardarVisita(finca: f, visita: visita('v1'), fotosVisita: const [], linderoNuevo: nuevo);

    final despues = await (db.select(db.fincas)..where((x) => x.id.equals('f1'))).getSingle();
    expect(despues.version, 2);
    expect(despues.geoHash, '0xnuevo');
    expect(despues.areaOficialHa, isNull);
    expect(despues.deforestacion, 'pendiente');

    final version = (await db.select(db.versionesFinca).get()).single;
    expect((version.version, version.sincronizado), (2, false));

    final v = (await db.select(db.verificaciones).get()).single;
    expect((v.versionFinca, v.temporadaId), (2, 't1'));
    expect(await db.verificadaEnTemporadaActual('f1', hoy: DateTime(2026, 11, 1)), isTrue);

    final p = await db.pendientes();
    expect(SyncService.payload(p)['versionesFinca'], [
      {'fincaId': 'f1', 'version': 2, 'coordenadas': [[-86.0, 13.0], [-86.002, 13.0], [-86.002, 13.002]], 'areaHa': 4.5, 'geoHash': '0xnuevo'},
    ]);
  });

  test('si la finca aún no se envió, el lindero nuevo reemplaza al anterior sin crear versión', () async {
    final f = await finca(sincronizada: false);
    await db.guardarVisita(finca: f, visita: visita('v1'), fotosVisita: const [], linderoNuevo: nuevo);

    final despues = await (db.select(db.fincas)..where((x) => x.id.equals('f1'))).getSingle();
    expect((despues.version, despues.geoHash), (1, '0xnuevo'));
    expect(await db.select(db.versionesFinca).get(), isEmpty);
  });

  test('las fotos de la visita quedan ligadas a ella y se borran con la finca', () async {
    final f = await finca();
    final archivo = File('${Directory.systemTemp.path}/visita_${DateTime.now().microsecondsSinceEpoch}.jpg')
      ..writeAsBytesSync([1]);
    await db.guardarVisita(
      finca: f,
      visita: visita('v1'),
      fotosVisita: [
        FotosCompanion.insert(id: 'fo1', entidadTipo: 'verificacion', entidadId: 'v1', tipo: 'verificacion', ruta: archivo.path, sha256: '0x1'),
      ],
    );
    expect((await db.select(db.fotos).get()).single.entidadId, 'v1');

    final rutas = await db.eliminarFincaLocal('f1');
    expect(rutas, [archivo.path]);
    expect(await db.select(db.verificaciones).get(), isEmpty);
    expect(await db.select(db.fotos).get(), isEmpty);
    archivo.deleteSync();
  });

  test('la descarga no pisa una finca con lindero nuevo sin enviar y reemplaza las temporadas', () async {
    final f = await finca();
    await db.guardarVisita(finca: f, visita: visita('v1'), fotosVisita: const [], linderoNuevo: nuevo);

    await db.aplicarDatosServidor(SyncService.desdeServidor({
      'temporadas': [
        {'id': 't2', 'nombre': '2027/28', 'inicio': '2027-10-01', 'fin': '2028-09-30'},
      ],
      'productores': [],
      'fincas': [
        {
          'id': 'f1', 'productorId': 'p1', 'nombre': 'Leona II', 'coordenadas': [[-86.0, 13.0]],
          'areaHa': 1.0, 'areaOficialHa': 1.0, 'geoHash': '0xviejo', 'version': 1,
          'deforestacion': 'verde', 'ultimoChequeo': null, 'attestationUid': null,
        },
      ],
      'verificaciones': [],
      'entregas': [],
    }));

    final despues = await (db.select(db.fincas)..where((x) => x.id.equals('f1'))).getSingle();
    expect((despues.version, despues.geoHash), (2, '0xnuevo'), reason: 'el lindero local sin enviar se conserva');
    expect((await db.select(db.temporadas).get()).map((t) => t.id), ['t2']);
    expect((await db.select(db.verificaciones).get()).single.id, 'v1', reason: 'la visita sin enviar se conserva');
  });

  test('migra una base v3 (la del APK anterior) a v4 sin perder datos', () async {
    final archivo = File('${Directory.systemTemp.path}/trazacafe_v3_${DateTime.now().microsecondsSinceEpoch}.sqlite');
    // Crea la base actual, la deja como estaba en v3 y la vuelve a abrir.
    final v4 = AppDatabase(NativeDatabase(archivo));
    await v4.into(v4.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'P'));
    await v4.into(v4.fincas).insert(FincasCompanion.insert(
          id: 'f1', productorId: 'p1', nombre: 'Leona II', coordenadasJson: '[[-86.0,13.0]]', areaHa: 1, geoHash: '0x0'));
    for (final sql in [
      'DROP TABLE temporadas',
      'DROP TABLE versiones_finca',
      'DROP TABLE verificaciones',
      'ALTER TABLE fincas DROP COLUMN version',
      'ALTER TABLE fincas DROP COLUMN deforestacion',
      'ALTER TABLE fincas DROP COLUMN ultimo_chequeo',
      'ALTER TABLE entregas DROP COLUMN temporada_id',
      'PRAGMA user_version = 3',
    ]) {
      await v4.customStatement(sql);
    }
    await v4.close();

    final migrada = AppDatabase(NativeDatabase(archivo));
    final f = (await migrada.select(migrada.fincas).get()).single;
    expect((f.nombre, f.version, f.deforestacion), ('Leona II', 1, 'pendiente'));
    expect(await migrada.select(migrada.temporadas).get(), isEmpty);
    expect(await migrada.select(migrada.verificaciones).get(), isEmpty);
    await migrada.close();
    archivo.deleteSync();
  });
}

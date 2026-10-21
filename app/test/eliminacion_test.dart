import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/eliminacion_service.dart';
import 'package:trazacafe/services/sync_service.dart';

import 'fakes.dart';

const org = '11111111-1111-4111-8111-111111111111';
const tecnico = Sesion(uid: 'u1', email: 't@coop.org', organizacionId: org, rol: 'tecnico');

class SubidorNulo implements SubidorArchivos {
  @override
  Future<void> subir(String rutaStorage, File archivo) async {}
}

/// Eliminación de datos en el celular: lo que llega del servidor después de
/// eliminar o anonimizar a un productor, y eliminar la propia cuenta.
void main() {
  late AppDatabase db;
  late Directory temporal;

  setUp(() async {
    temporal = Directory.systemTemp.createTempSync('trazacafe_elim');
    db = AppDatabase(NativeDatabase.memory());
    for (final (id, nombre) in [('p1', 'María López'), ('p2', 'Juan Pérez')]) {
      await db.into(db.productores).insert(ProductoresCompanion.insert(
            id: id,
            nombre: nombre,
            cedula: const Value('001-010190-0001A'),
            sincronizado: const Value(true),
          ));
      await db.into(db.fincas).insert(FincasCompanion.insert(
            id: 'f-$id',
            productorId: id,
            nombre: 'Finca de $nombre',
            coordenadasJson: '[[-86.0,13.0]]',
            areaHa: 1,
            geoHash: '0x0',
            sincronizado: const Value(true),
          ));
      for (final (tipo, entidad) in [('productor', id), ('finca', 'f-$id')]) {
        final archivo = File('${temporal.path}/$tipo-$id.jpg')..writeAsBytesSync([1]);
        await db.into(db.fotos).insert(FotosCompanion.insert(
              id: 'foto-$tipo-$id',
              entidadTipo: tipo,
              entidadId: entidad,
              tipo: tipo == 'productor' ? 'consentimiento' : 'finca',
              ruta: archivo.path,
              sha256: '0x1',
              sincronizado: const Value(true),
              subida: const Value(true),
            ));
      }
    }
  });
  tearDown(() async {
    await db.close();
    temporal.deleteSync(recursive: true);
  });

  Map<String, dynamic> finca(String productorId, String nombre) => {
        'id': 'f-$productorId', 'productorId': productorId, 'nombre': nombre, 'coordenadas': [[-86.0, 13.0]],
        'areaHa': 1.0, 'geoHash': '0x0',
      };

  /// Respuesta de GET /v1/datos: p1 anonimizado (queda su finca exportada) y p2 ya no existe.
  final despues = {
    'organizacion': {'id': org, 'nombre': 'Coop', 'tipo': 'cooperativa', 'cultivos': ['cafe'], 'eliminacionProgramada': null},
    'solicitudesPendientes': 2,
    'temporadas': [],
    'productores': [
      {
        'id': 'p1', 'nombre': 'Productor eliminado', 'cedula': null, 'comunidad': null, 'consentimientoFirmado': true,
        'anonimizado': true, 'conservarHasta': '2032-03-15',
      },
    ],
    'fincas': [finca('p1', 'Finca eliminada · f-p1')],
    'verificaciones': [],
    'entregas': [],
  };

  test('quita al productor eliminado y deja al anonimizado sin datos ni fotos en el celular', () async {
    final rutas = await db.aplicarDatosServidor(SyncService.desdeServidor(despues));

    final productores = await db.select(db.productores).get();
    expect(productores.map((p) => p.id), ['p1']);
    final p1 = productores.single;
    expect((p1.nombre, p1.cedula, p1.anonimizado, p1.conservarHasta), ('Productor eliminado', null, true, DateTime(2032, 3, 15)));
    expect((await db.select(db.fincas).get()).map((f) => f.id), ['f-p1']);
    expect(await db.select(db.fotos).get(), isEmpty, reason: 'ni las del eliminado ni las del anonimizado');
    expect(rutas.map((r) => r.split(RegExp(r'[\\/]')).last), unorderedEquals(['productor-p1.jpg', 'finca-p1.jpg', 'productor-p2.jpg', 'finca-p2.jpg']));
  });

  test('guarda las solicitudes pendientes y la eliminación programada; una API anterior no las borra', () async {
    await db.aplicarDatosServidor(SyncService.desdeServidor({
      ...despues,
      'organizacion': {...despues['organizacion'] as Map, 'eliminacionProgramada': '2026-11-20T15:00:00Z'},
    }));
    expect(await db.observarAjuste(ClaveAjuste.solicitudesPendientes).first, '2');
    expect(await db.observarAjuste(ClaveAjuste.eliminacionProgramada).first, '2026-11-20T15:00:00Z');

    await db.aplicarDatosServidor(SyncService.desdeServidor({'productores': [], 'fincas': [], 'entregas': []}));
    expect(await db.observarAjuste(ClaveAjuste.solicitudesPendientes).first, '2');
  });

  group('eliminar mi cuenta', () {
    ApiFalsa api({int sync = 200}) => ApiFalsa({
          'POST /v1/sync': (sync, {'recibidos': {}}),
          'GET /v1/datos': (200, {...despues, 'productores': [], 'fincas': []}),
          'DELETE /v1/cuenta': (204, null),
        });

    EliminacionService servicio(ApiFalsa api, AuthFalso auth) {
      final cliente = api.cliente(auth);
      return EliminacionService(db, cliente, SyncService(db, cliente, SubidorNulo(), () => org), auth);
    }

    Future<void> pendiente() => db.into(db.productores).insert(ProductoresCompanion.insert(id: 'p-nuevo', nombre: 'Nuevo'));

    test('envía lo pendiente, borra la cuenta y deja el celular sin datos ni sesión', () async {
      await pendiente();
      final auth = AuthFalso(inicial: tecnico);
      final a = api();
      await servicio(a, auth).eliminarMiCuenta();

      expect(a.peticiones.map((p) => '${p.method} ${p.url.path}'), ['POST /v1/sync', 'GET /v1/datos', 'DELETE /v1/cuenta']);
      expect(await db.select(db.productores).get(), isEmpty);
      expect(await db.select(db.fotos).get(), isEmpty);
      expect(temporal.listSync(), isEmpty, reason: 'los archivos de fotos también');
      expect(auth.cierres, 1);
    });

    test('sin señal para enviar lo pendiente avisa y no borra nada', () async {
      await pendiente();
      final auth = AuthFalso(inicial: tecnico);
      final a = api(sync: 503);
      await expectLater(servicio(a, auth).eliminarMiCuenta(), throwsA(isA<PendientesSinEnviar>()));
      expect(a.peticiones.map((p) => p.url.path), isNot(contains('/v1/cuenta')));
      expect(await db.select(db.productores).get(), hasLength(3));
      expect(auth.cierres, 0);

      await servicio(a, auth).eliminarMiCuenta(descartarPendientes: true);
      expect(await db.select(db.productores).get(), isEmpty);
      expect(auth.cierres, 1);
    });
  });

  test('migra una base v6 a v7: productores sin anonimizar y tabla de ajustes vacía', () async {
    final archivo = File('${temporal.path}/trazacafe_v6.sqlite');
    final actual = AppDatabase(NativeDatabase(archivo));
    await actual.into(actual.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'P'));
    for (final sql in [
      'DROP TABLE ajustes',
      'ALTER TABLE productores DROP COLUMN anonimizado',
      'ALTER TABLE productores DROP COLUMN conservar_hasta',
      'PRAGMA user_version = 6',
    ]) {
      await actual.customStatement(sql);
    }
    await actual.close();

    final migrada = AppDatabase(NativeDatabase(archivo));
    final p = (await migrada.select(migrada.productores).get()).single;
    expect((p.nombre, p.anonimizado, p.conservarHasta), ('P', false, null));
    expect(await migrada.observarAjuste(ClaveAjuste.solicitudesPendientes).first, isNull);
    await migrada.close();
  });
}

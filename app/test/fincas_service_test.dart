import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/services/api_client.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/fincas_service.dart';

import 'fakes.dart';

const tecnico = Sesion(uid: 'u1', email: 't@coop.org', organizacionId: 'org', rol: 'tecnico');

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'Productora'));
  });
  tearDown(() => db.close());

  Future<Finca> crearFinca({bool sincronizado = false, String? attestationUid}) async {
    await db.into(db.fincas).insert(FincasCompanion.insert(
          id: 'f1',
          productorId: 'p1',
          nombre: 'La Leona',
          coordenadasJson: '[[-86.0,13.0]]',
          areaHa: 1,
          geoHash: '0x00',
          sincronizado: Value(sincronizado),
          attestationUid: Value(attestationUid),
        ));
    await db.into(db.fotos).insert(FotosCompanion.insert(
          id: 'foto1',
          entidadTipo: 'finca',
          entidadId: 'f1',
          tipo: 'finca',
          ruta: 'C:/no-existe/foto1.jpg',
          sha256: '0x01',
        ));
    return (await db.fincasPendientes()).firstOrNull ??
        (await db.select(db.fincas).get()).single;
  }

  FincasService servicio(ApiFalsa api) => FincasService(db, api.cliente(AuthFalso(inicial: tecnico)));

  test('una finca sin enviar se borra solo del celular, con sus fotos', () async {
    final api = ApiFalsa({});
    await servicio(api).eliminar(await crearFinca());

    expect(await db.select(db.fincas).get(), isEmpty);
    expect(await db.select(db.fotos).get(), isEmpty);
    expect(api.peticiones, isEmpty);
  });

  test('una finca enviada se borra primero en la API', () async {
    final api = ApiFalsa({'DELETE /v1/fincas/f1': (204, null)});
    await servicio(api).eliminar(await crearFinca(sincronizado: true));

    expect(api.peticiones.single.method, 'DELETE');
    expect(await db.select(db.fincas).get(), isEmpty);
  });

  test('si en la API ya no existe, igual se borra del celular', () async {
    final api = ApiFalsa({'DELETE /v1/fincas/f1': (404, {'error': 'no_encontrada'})});
    await servicio(api).eliminar(await crearFinca(sincronizado: true));
    expect(await db.select(db.fincas).get(), isEmpty);
  });

  test('si la API falla, la finca se queda en el celular', () async {
    final api = ApiFalsa({'DELETE /v1/fincas/f1': (503, null)});
    await expectLater(servicio(api).eliminar(await crearFinca(sincronizado: true)), throwsA(isA<ApiError>()));
    expect(await db.select(db.fincas).get(), hasLength(1));
  });

  test('una finca atestada no se puede borrar', () async {
    final f = await crearFinca(sincronizado: true, attestationUid: '0xabc');
    expect(FincasService.sePuedeEliminar(f), isFalse);
    await expectLater(servicio(ApiFalsa({})).eliminar(f), throwsStateError);
  });
}

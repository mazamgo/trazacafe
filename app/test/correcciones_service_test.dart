import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/domain/cedula.dart';
import 'package:trazacafe/services/api_client.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/correcciones_service.dart';

import 'fakes.dart';

const tecnico = Sesion(uid: 'u1', email: 't@coop.org', organizacionId: 'org', rol: 'tecnico');

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'Ana Perz', sincronizado: const Value(true)));
    await db.into(db.fincas).insert(FincasCompanion.insert(
          id: 'f1', productorId: 'p1', nombre: 'La Leonesa', coordenadasJson: '[[-86.0,13.0]]', areaHa: 1.5, geoHash: '0x0',
          sincronizado: const Value(true)));
    await db.into(db.temporadas).insert(TemporadasCompanion.insert(
          id: 't-vieja', nombre: '2025/26', inicio: DateTime(2025, 10, 1), fin: DateTime(2026, 9, 30)));
    await db.into(db.temporadas).insert(TemporadasCompanion.insert(
          id: 't-actual', nombre: '2026/27', inicio: DateTime(2026, 10, 1), fin: DateTime(2027, 9, 30)));
  });
  tearDown(() => db.close());

  Future<Entrega> entrega({bool enviada = false, String? lote}) async {
    await db.into(db.entregas).insert(EntregasCompanion.insert(
          id: 'e1', fincaId: 'f1', kg: 5000, estado: 'uva', fecha: DateTime(2026, 10, 10, 9),
          temporadaId: const Value('t-actual'), sincronizado: Value(enviada), loteCodigo: Value(lote)));
    return (db.select(db.entregas)).getSingle();
  }

  CorreccionesService servicio(ApiFalsa api) => CorreccionesService(db, api.cliente(AuthFalso(inicial: tecnico)));

  test('una entrega sin enviar se corrige solo en el celular y recalcula la temporada', () async {
    final api = ApiFalsa({});
    await servicio(api).corregirEntrega(await entrega(), kg: 500, fecha: DateTime(2026, 9, 20, 9));
    final e = await db.select(db.entregas).getSingle();
    expect((e.kg, e.temporadaId, e.corregida), (500.0, 't-vieja', false));
    expect(api.peticiones, isEmpty);
  });

  test('una entrega enviada se corrige en la API (solo lo que cambió) y queda marcada', () async {
    final api = ApiFalsa({
      'PATCH /v1/entregas/e1': (200, {'id': 'e1', 'kg': 500, 'estado': 'uva', 'fecha': '2026-10-10T15:00:00.000Z', 'temporadaId': 't-actual'}),
    });
    await servicio(api).corregirEntrega(await entrega(enviada: true), kg: 500, estado: 'uva', motivo: 'un cero de más');
    expect(jsonDecode(api.peticiones.single.body), {'kg': 500.0, 'motivo': 'un cero de más'});
    final e = await db.select(db.entregas).getSingle();
    expect((e.kg, e.corregida, e.sincronizado), (500.0, true, true));
  });

  test('si la API la rechaza (ya está en un lote), el celular no cambia', () async {
    final api = ApiFalsa({
      'PATCH /v1/entregas/e1': (409, {'error': 'no_corregible', 'mensaje': 'La entrega está en el lote CAFE-001; para corregirla, primero deshaz el lote.'}),
    });
    await expectLater(
      servicio(api).corregirEntrega(await entrega(enviada: true), kg: 500, motivo: 'error'),
      throwsA(isA<ApiError>().having((e) => e.mensaje, 'mensaje', contains('CAFE-001'))),
    );
    expect((await db.select(db.entregas).getSingle()).kg, 5000);
  });

  test('anular: sin enviar se borra del celular; enviada, primero en la API', () async {
    final sinEnviar = ApiFalsa({});
    await servicio(sinEnviar).anularEntrega(await entrega(), 'duplicada');
    expect(await db.select(db.entregas).get(), isEmpty);
    expect(sinEnviar.peticiones, isEmpty);

    final api = ApiFalsa({'POST /v1/entregas/e1/anular': (204, null)});
    await servicio(api).anularEntrega(await entrega(enviada: true), 'registrada dos veces');
    expect(jsonDecode(api.peticiones.single.body), {'motivo': 'registrada dos veces'});
    expect(await db.select(db.entregas).get(), isEmpty);
  });

  test('en un lote o firmada en la blockchain, el celular ya no ofrece corregirla', () async {
    expect(CorreccionesService.bloqueoEntrega(await entrega(lote: 'CAFE-001')), contains('CAFE-001'));
  });

  test('corrige el productor enviado en la API y en el celular', () async {
    final api = ApiFalsa({'PATCH /v1/productores/p1': (204, null)});
    final p = await db.select(db.productores).getSingle();
    await servicio(api).corregirProductor(p, nombre: 'Ana Pérez', cedula: '001-010190-0001A', comunidad: null);
    expect(jsonDecode(api.peticiones.single.body), {'nombre': 'Ana Pérez', 'cedula': '001-010190-0001A'});
    final despues = await db.select(db.productores).getSingle();
    expect((despues.nombre, despues.cedula), ('Ana Pérez', '001-010190-0001A'));
  });

  test('una finca de un punto: corrige el área declarada, que pasa a ser la oficial', () async {
    final api = ApiFalsa({'PATCH /v1/fincas/f1': (204, null)});
    final f = await db.select(db.fincas).getSingle();
    await servicio(api).corregirFinca(f, nombre: 'La Leonesa', areaHa: 2.5, motivo: 'área mal escrita');
    expect(jsonDecode(api.peticiones.single.body), {'areaHa': 2.5, 'motivo': 'área mal escrita'});
    final despues = await db.select(db.fincas).getSingle();
    expect((despues.areaHa, despues.areaOficialHa), (2.5, 2.5));
  });

  test('una visita con lindero nuevo no se anula', () async {
    await db.into(db.verificaciones).insert(VerificacionesCompanion.insert(
          id: 'v1', fincaId: 'f1', fecha: DateTime(2026, 10, 10), versionFinca: 2, linderoCambio: const Value(true)));
    final v = await db.select(db.verificaciones).getSingle();
    await expectLater(servicio(ApiFalsa({})).anularVisita(v, 'error'), throwsStateError);
  });

  test('cédula nicaragüense: se normaliza igual que en la API', () {
    expect(normalizarCedula('0010101900001a'), '001-010190-0001A');
    expect(normalizarCedula('281 251288 0000 y'), '281-251288-0000Y');
    expect(normalizarCedula('001-320190-0001A'), isNull);
    expect(normalizarCedula('12345'), isNull);
  });
}

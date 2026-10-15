import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('una finca nueva queda pendiente de sincronizar', () async {
    await db.into(db.productores).insert(
          ProductoresCompanion.insert(id: 'p1', nombre: 'Productora'),
        );
    await db.into(db.fincas).insert(FincasCompanion.insert(
          id: 'f1',
          productorId: 'p1',
          nombre: 'La Esperanza',
          coordenadasJson: '[[-86.235,13.6305]]',
          areaHa: 2.5,
          geoHash: '0x00',
        ));

    final pendientes = await db.fincasPendientes();
    expect(pendientes.map((f) => f.id), ['f1']);
    expect((await db.observarFincas().first).single.nombre, 'La Esperanza');
  });
}

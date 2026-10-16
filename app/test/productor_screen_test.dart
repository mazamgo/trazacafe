import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/productor_screen.dart';

void main() {
  testWidgets('el productor muestra su consentimiento subido y sus fincas', (tester) async {
    late AppDatabase db;
    late Productor productor;
    await tester.runAsync(() async {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      await db.into(db.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'Mauricio Zambrana'));
      await db.into(db.fincas).insert(FincasCompanion.insert(
            id: 'f1',
            productorId: 'p1',
            nombre: 'Leona II',
            coordenadasJson: '[[-86.0,13.0]]',
            areaHa: 1.9266,
            areaOficialHa: const Value(1.9192),
            geoHash: '0x00',
          ));
      await db.into(db.fotos).insert(FotosCompanion.insert(
            id: 'c1',
            entidadTipo: 'productor',
            entidadId: 'p1',
            tipo: 'consentimiento',
            ruta: 'no-existe.jpg',
            sha256: '0x01',
            sincronizado: const Value(true),
            subida: const Value(true),
          ));
      productor = await db.select(db.productores).getSingle();
    });
    addTearDown(() => tester.runAsync(db.close));

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: ProductorScreen(productor: productor)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Consentimiento de datos'), findsOneWidget);
    expect(find.text('Todas las fotos están guardadas en el servidor ✓'), findsOneWidget);
    expect(find.text('Leona II'), findsOneWidget);
    expect(find.text('1.92 ha'), findsOneWidget);
  });
}

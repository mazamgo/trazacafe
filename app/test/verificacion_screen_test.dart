import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/verificacion_screen.dart';

void main() {
  testWidgets('la visita exige foto y, si cambió el lindero, dibujarlo', (tester) async {
    late AppDatabase db;
    late Finca finca;
    await tester.runAsync(() async {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      await db.into(db.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'P'));
      await db.into(db.fincas).insert(FincasCompanion.insert(
            id: 'f1',
            productorId: 'p1',
            nombre: 'Leona II',
            coordenadasJson: '[[-86.0,13.0]]',
            areaHa: 1,
            geoHash: '0x0',
          ));
      finca = await db.select(db.fincas).getSingle();
    });
    addTearDown(() => tester.runAsync(db.close));
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(480, 2000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: VerificacionScreen(finca: finca)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    final guardar = find.widgetWithText(FilledButton, 'Guardar visita');
    expect(find.text('Toma al menos una foto de la finca en esta visita.'), findsOneWidget);
    expect(tester.widget<FilledButton>(guardar).onPressed, isNull);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Dibujar el lindero nuevo'), findsOneWidget);
    expect(tester.widget<FilledButton>(guardar).onPressed, isNull);
    expect(await tester.runAsync(() => db.select(db.verificaciones).get()), isEmpty);
  });
}

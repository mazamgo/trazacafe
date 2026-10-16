import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/finca_screen.dart';

/// En pruebas de widgets el tiempo es simulado, pero drift trabaja con tiempo
/// real: las operaciones de base van dentro de `runAsync` y se le da a la
/// pantalla un momento real para recibir los datos antes de `pump`.
void main() {
  late AppDatabase db;

  Future<void> esperar(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  /// [antes] carga datos extra antes de mostrar la pantalla: insertar con la
  /// pantalla ya abierta bloquea la prueba (drift avisa del cambio con el
  /// reloj simulado, y el insert lo espera con el real).
  Future<void> abrir(WidgetTester tester, {Future<void> Function()? antes}) async {
    await tester.runAsync(() async {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      await db.into(db.productores).insert(ProductoresCompanion.insert(id: 'p1', nombre: 'Productora'));
      await db.into(db.fincas).insert(FincasCompanion.insert(
            id: 'f1',
            productorId: 'p1',
            nombre: 'Leona II',
            coordenadasJson: '[[-86.0,13.0]]',
            areaHa: 1.9266,
            geoHash: '0x00',
            areaOficialHa: const Value(1.9192),
          ));
      await antes?.call();
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: FincaScreen(fincaId: 'f1')),
    ));
    await esperar(tester);
  }

  Future<List<Entrega>> entregas(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.entregas).get()))!;

  Future<void> abrirFormulario(WidgetTester tester) async {
    await tester.tap(find.text('Entrega'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // animación de la hoja
  }

  testWidgets('muestra el área oficial del servidor', (tester) async {
    await abrir(tester);
    expect(find.text('1.92 ha (área oficial)'), findsOneWidget);
  });

  testWidgets('registra una entrega de uva y queda pendiente de enviar', (tester) async {
    await abrir(tester);
    await abrirFormulario(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Kilos entregados'), '345,5');
    await tester.tap(find.text('Guardar entrega'));
    await tester.pump(const Duration(milliseconds: 500));
    await esperar(tester);

    final e = (await entregas(tester)).single;
    expect(e.kg, 345.5);
    expect(e.estado, 'uva');
    expect(e.sincronizado, isFalse);
    expect(find.textContaining('345.5 kg'), findsOneWidget);
  });

  testWidgets('sin fotos ofrece agregar una', (tester) async {
    await abrir(tester);
    expect(find.text('Fotos de la finca'), findsOneWidget);
    expect(find.text('Agregar foto'), findsOneWidget);
    expect(find.text('Sin fotos todavía.'), findsOneWidget);
  });

  testWidgets('muestra las fotos de la finca y cuáles faltan por subir', (tester) async {
    await abrir(tester, antes: () async {
      for (final (id, subida) in [('a', true), ('b', false)]) {
        await db.into(db.fotos).insert(FotosCompanion.insert(
              id: id,
              entidadTipo: 'finca',
              entidadId: 'f1',
              tipo: 'finca',
              ruta: 'no-existe-$id.jpg',
              sha256: '0x$id',
              sincronizado: const Value(true),
              subida: Value(subida),
            ));
      }
    });

    expect(find.text('1 de 2 se subirán al sincronizar'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });

  testWidgets('no acepta kilos vacíos ni exagerados', (tester) async {
    await abrir(tester);
    await abrirFormulario(tester);

    await tester.tap(find.text('Guardar entrega'));
    await tester.pump();
    expect(find.text('Escribe los kilos entregados.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Kilos entregados'), '25000');
    await tester.tap(find.text('Guardar entrega'));
    await tester.pump();
    expect(find.textContaining('20,000 kg'), findsOneWidget);
    expect(await entregas(tester), isEmpty);
  });
}

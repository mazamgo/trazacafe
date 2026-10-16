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
  final hoy = DateTime.now();

  Future<void> esperar(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  /// [antes] carga datos extra antes de mostrar la pantalla: insertar con la
  /// pantalla ya abierta bloquea la prueba (drift avisa del cambio con el
  /// reloj simulado, y el insert lo espera con el real).
  Future<void> abrir(
    WidgetTester tester, {
    bool conTemporada = true,
    bool visitaHecha = false,
    String deforestacion = 'pendiente',
    Future<void> Function()? antes,
  }) async {
    // Pantalla alta para que toda la lista quede a la vista.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(480, 2400);
    addTearDown(tester.view.reset);
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
            deforestacion: Value(deforestacion),
            sincronizado: const Value(true),
          ));
      if (conTemporada) {
        await db.into(db.temporadas).insert(TemporadasCompanion.insert(
              id: 't1',
              nombre: 'Actual',
              inicio: DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 30)),
              fin: DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 300)),
            ));
      }
      if (visitaHecha) {
        await db.into(db.verificaciones).insert(VerificacionesCompanion.insert(
              id: 'v1',
              fincaId: 'f1',
              temporadaId: const Value('t1'),
              fecha: hoy,
              versionFinca: 1,
              sincronizado: const Value(true),
            ));
      }
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

  Future<void> tocarEntrega(WidgetTester tester) async {
    // El botón aparece con animación cuando carga la finca; antes no recibe toques.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Entrega'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Abre el formulario aceptando el aviso si aparece.
  Future<void> abrirFormulario(WidgetTester tester) async {
    await tocarEntrega(tester);
    if (find.text('Registrar de todos modos').evaluate().isNotEmpty) {
      await tester.tap(find.text('Registrar de todos modos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('muestra el área oficial del servidor y el estado satelital', (tester) async {
    await abrir(tester, deforestacion: 'verde');
    expect(find.text('1.92 ha (área oficial)'), findsOneWidget);
    expect(find.textContaining('Sin deforestación detectada'), findsOneWidget);
  });

  testWidgets('sin visita en la temporada avisa antes de registrar la entrega', (tester) async {
    await abrir(tester);
    expect(find.text('Visita de Actual: pendiente'), findsOneWidget);

    await tocarEntrega(tester);
    expect(find.textContaining('no tiene la visita de verificación de Actual'), findsOneWidget);
    expect(find.text('Hacer la visita primero'), findsOneWidget);
  });

  testWidgets('con la visita hecha registra la entrega sin aviso', (tester) async {
    await abrir(tester, visitaHecha: true);
    expect(find.textContaining('Visita de Actual: hecha el'), findsOneWidget);

    await tocarEntrega(tester);
    expect(find.text('Antes de registrar'), findsNothing);
    expect(find.text('Nueva entrega'), findsOneWidget);
  });

  testWidgets('una finca en rojo avisa aunque tenga la visita', (tester) async {
    await abrir(tester, visitaHecha: true, deforestacion: 'rojo');
    await tocarEntrega(tester);
    expect(find.textContaining('detectó pérdida de bosque'), findsOneWidget);
  });

  testWidgets('registra una entrega de uva en la temporada actual, pendiente de enviar', (tester) async {
    await abrir(tester);
    await abrirFormulario(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Kilos entregados'), '345,5');
    await tester.tap(find.text('Guardar entrega'));
    await tester.pump(const Duration(milliseconds: 500));
    await esperar(tester);

    final e = (await entregas(tester)).single;
    expect((e.kg, e.estado, e.temporadaId, e.sincronizado), (345.5, 'uva', 't1', false));
    expect(find.textContaining('345.5 kg · Uva'), findsOneWidget);
    expect(find.text('Actual · 1 entrega · 345.5 kg'), findsOneWidget);
  });

  testWidgets('agrupa las entregas por temporada con el total de kg', (tester) async {
    await abrir(tester, antes: () async {
      for (final (id, kg, temporada) in [('e1', 1000.0, 't1'), ('e2', 500.0, 't1'), ('e3', 80.0, null)]) {
        await db.into(db.entregas).insert(EntregasCompanion.insert(
              id: id,
              fincaId: 'f1',
              kg: kg,
              estado: 'uva',
              fecha: hoy,
              temporadaId: Value(temporada),
            ));
      }
    });
    expect(find.text('Actual · 2 entregas · 1500 kg'), findsOneWidget);
    expect(find.text('Sin temporada · 1 entrega · 80 kg'), findsOneWidget);
  });

  testWidgets('sin temporada creada lo dice en la tarjeta de verificación', (tester) async {
    await abrir(tester, conTemporada: false);
    expect(find.textContaining('aún no creó la temporada actual'), findsOneWidget);
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
    await esperar(tester);

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

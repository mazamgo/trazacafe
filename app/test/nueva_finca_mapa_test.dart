import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/domain/busqueda_lugar.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/nueva_finca_screen.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/mapas_service.dart';
import 'package:trazacafe/services/mapas_sin_senal.dart';
import 'package:trazacafe/widgets/capa_sin_senal.dart';

/// Nueva finca con el mapa, el buscador y el inicio cerca del terreno.
/// drift trabaja con tiempo real: los datos se cargan antes de abrir la
/// pantalla, dentro de `runAsync` (ver finca_screen_test.dart).
void main() {
  late AppDatabase db;

  final lugares = [
    Lugar('El Cuá', const LatLng(13.37, -85.67), municipio: 'El Cuá', departamento: 'Jinotega'),
    Lugar('La Cuchilla', const LatLng(13.30, -85.70), municipio: 'El Cuá', departamento: 'Jinotega'),
  ];

  Future<void> esperar(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  Future<void> abrir(
    WidgetTester tester, {
    List<Override> overrides = const [],
    List<String> cultivos = const ['cafe'],
    String? comunidad,
    SesionMapa? sesion,
    Future<void> Function()? antes,
  }) async {
    // Con el mapa de Google no se deja correr el tiempo real: la caché de
    // mosaicos de flutter_map buscaría la carpeta del celular.
    final esperarDatos = sesion == null;
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      await db.into(db.productores).insert(ProductoresCompanion.insert(
            id: 'p1',
            nombre: 'José Pérez',
            comunidad: Value(comunidad),
          ));
      await antes?.call();
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        lugaresProvider.overrideWith((ref) async => lugares),
        sesionMapaProvider.overrideWith((ref) async => sesion),
        cultivosOrganizacionProvider.overrideWith((ref) => Stream.value(cultivos)),
        ...overrides,
      ],
      child: const MaterialApp(home: NuevaFincaScreen(productorId: 'p1')),
    ));
    if (esperarDatos) {
      await esperar(tester);
      await esperar(tester);
    } else {
      await tester.pump();
    }
  }

  LatLng centro(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera.center;

  Future<void> otraFinca(String productorId, String nombre, String coords) => db.into(db.fincas).insert(
        FincasCompanion.insert(
          id: 'f-$nombre',
          productorId: productorId,
          nombre: nombre,
          coordenadasJson: coords,
          areaHa: 1,
          geoHash: '0x00',
        ),
      );

  testWidgets('Nueva finca se dibuja con el mapa de Google', (tester) async {
    final sesion = SesionMapa('sesion-prueba', DateTime.now().add(const Duration(days: 10)));
    await abrir(tester, sesion: sesion);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Guardar finca'), findsOneWidget);
    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.text('Cacao'), findsNothing, reason: 'con un solo cultivo no se pregunta');
    expect(find.text('Cultivo: Café'), findsOneWidget, reason: 'pero sí se muestra');
    expect(find.textContaining('Activa más cultivos'), findsNothing, reason: 'el técnico no puede activarlos');
  });

  testWidgets('al administrador con un solo cultivo le dice dónde activar más', (tester) async {
    await abrir(tester, overrides: [
      sesionProvider.overrideWith((ref) => Stream.value(
            const Sesion(uid: 'u1', email: 'a@coop.org', organizacionId: 'org', rol: 'admin'),
          )),
    ]);
    expect(find.text('Cultivo: Café'), findsOneWidget);
    expect(find.text('Activa más cultivos en ⋮ → Cultivos'), findsOneWidget);
  });

  testWidgets('si la organización trabaja café y cacao, pregunta el cultivo', (tester) async {
    await abrir(tester, cultivos: ['cafe', 'cacao']);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Cacao'), findsOneWidget);
    await tester.tap(find.text('Cacao'));
    await tester.pump();
    final boton = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(boton.selected, {'cacao'});
  });

  group('dónde abre el mapa', () {
    testWidgets('sin nada que lo ubique, en Jinotega', (tester) async {
      await abrir(tester);
      expect(centro(tester).latitude, closeTo(13.091, 1e-3));
    });

    testWidgets('en otra finca del productor', (tester) async {
      await abrir(tester, antes: () => otraFinca('p1', 'La Primera', '[[-85.5,13.5]]'));
      expect(centro(tester).latitude, closeTo(13.5, 1e-6));
      expect(centro(tester).longitude, closeTo(-85.5, 1e-6));
    });

    testWidgets('en las fincas de su comunidad', (tester) async {
      await abrir(
        tester,
        comunidad: 'Las Nubes',
        antes: () async {
          await db.into(db.productores).insert(ProductoresCompanion.insert(
                id: 'p2',
                nombre: 'Vecina',
                comunidad: const Value('las nubes'),
              ));
          await otraFinca('p2', 'De la vecina', '[[-85.9,13.2]]');
        },
      );
      expect(centro(tester).latitude, closeTo(13.2, 1e-6));
    });

    testWidgets('en su comunidad, si está en la lista de lugares', (tester) async {
      await abrir(tester, comunidad: 'El Cua');
      expect(centro(tester).latitude, closeTo(13.37, 1e-6));
    });
  });

  testWidgets('el buscador encuentra fincas y lugares y mueve el mapa sin marcar puntos', (tester) async {
    await abrir(
      tester,
      antes: () async {
        await db.into(db.productores).insert(ProductoresCompanion.insert(
              id: 'p2',
              nombre: 'María Cuadra',
              comunidad: const Value('Wiwilí'),
            ));
        await otraFinca('p2', 'El Roble', '[[-85.8,13.6],[-85.79,13.6],[-85.79,13.61],[-85.8,13.6]]');
      },
    );
    await tester.tap(find.byTooltip('Buscar lugar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cua');
    await tester.pumpAndSettle();

    expect(find.text('Fincas de la cooperativa'), findsOneWidget);
    expect(find.text('El Roble'), findsOneWidget, reason: 'por el nombre de la productora');
    expect(find.text('Lugares'), findsOneWidget);
    expect(find.text('El Cuá'), findsOneWidget);
    expect(find.text('La Cuchilla'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);

    await tester.tap(find.text('La Cuchilla'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar finca'), findsOneWidget, reason: 'volvió a la pantalla');
    expect(centro(tester).latitude, closeTo(13.30, 1e-6));
    expect(find.textContaining('Puntos: 0'), findsOneWidget, reason: 'el lugar no es un vértice');
    expect(find.byIcon(Icons.location_on), findsOneWidget, reason: 'queda el pin');
  });

  testWidgets('pegar coordenadas lleva el mapa ahí', (tester) async {
    await abrir(tester);
    await tester.tap(find.byTooltip('Buscar lugar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '13°30\'00"N 85°45\'00"W');
    await tester.pumpAndSettle();
    expect(find.text('Ir a estas coordenadas'), findsOneWidget);
    await tester.tap(find.text('Ir a estas coordenadas'));
    await tester.pumpAndSettle();
    expect(centro(tester).latitude, closeTo(13.5, 1e-6));
    expect(centro(tester).longitude, closeTo(-85.75, 1e-6));
    expect(find.textContaining('Puntos: 0'), findsOneWidget);
  });

  testWidgets('un enlace corto ofrece abrirlo con señal', (tester) async {
    await abrir(tester);
    await tester.tap(find.byTooltip('Buscar lugar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://maps.app.goo.gl/abc123');
    await tester.pumpAndSettle();
    expect(find.text('Abrir el enlace de Google Maps'), findsOneWidget);
    expect(find.textContaining('No se encontró'), findsNothing);
  });

  testWidgets('sin señal, con el mapa de la zona descargado, se ve la capa Sentinel-2 con su crédito', (tester) async {
    final ruta = '${Directory.systemTemp.createTempSync('trazacafe_capa').path}/zona.mbtiles';
    sqlite3.open(ruta)
      ..execute('CREATE TABLE tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob)')
      ..close();
    final mapa = MapaDescargado(
      PaqueteMapa.desdeJson({
        'id': 'zona',
        'nombre': 'Zona',
        'archivo': 'zona.mbtiles',
        'bytes': 1,
        'bounds': [-86.3, 12.95, -85.3, 13.85],
        'maxzoom': 14,
        'atribucion': 'Contains modified Copernicus Sentinel data 2026',
      }),
      ruta,
    );
    await abrir(tester, overrides: [mapasDescargadosProvider.overrideWith((ref) async => [mapa])]);
    expect(find.byType(CapaSinSenal), findsOneWidget);
    expect(find.text('Contains modified Copernicus Sentinel data 2026'), findsOneWidget);
    expect(find.textContaining('se ve el mapa descargado'), findsOneWidget);
  });

  testWidgets('las fincas registradas se ven en el mapa con su nombre', (tester) async {
    await abrir(tester, antes: () => otraFinca('p1', 'La Primera', '[[-85.5,13.5]]'));
    expect(find.text('La Primera'), findsOneWidget);
  });
}

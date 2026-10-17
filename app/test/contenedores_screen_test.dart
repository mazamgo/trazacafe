import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/contenedores_screen.dart';
import 'package:trazacafe/screens/nuevo_contenedor_screen.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/compartir_service.dart';

import 'fakes.dart';

const admin = Sesion(uid: 'u-admin', email: 'admin@coop.org', organizacionId: 'org-1', rol: 'admin');

class CompartidorFalso implements Compartidor {
  final compartidos = <(String, String, int)>[];
  @override
  Future<void> compartir({required String nombre, required List<int> bytes, required String tipo, required String asunto}) async {
    compartidos.add((nombre, tipo, bytes.length));
  }
}

Map<String, dynamic> exportacionJson({String? contenedor, int sinVerde = 1, String estado = 'abierta'}) => {
  'id': 'x1',
  'codigo': 'EXP-2026-001',
  'cultivo': 'cafe',
  'comprador': 'Tostador GmbH',
  'destino': 'Hamburgo, Alemania',
  'contenedor': contenedor,
  'fechaEmbarque': null,
  'ddsRef': null,
  'estado': estado,
  'attestationUid': null,
  'creadoEn': '2026-10-16T20:00:00.000Z',
  'kg': 160,
  'lotes': [
    {'id': 'l1', 'codigo': 'CAFE-001', 'kg': 100, 'estado': 'pergamino', 'temporadaNombre': '2026/27'},
    {'id': 'l2', 'codigo': 'CAFE-002', 'kg': 60, 'estado': 'pergamino', 'temporadaNombre': '2026/27'},
  ],
  'resumen': {'entregas': 2, 'fincas': 2, 'areaOficialHa': 2.4, 'fincasSinVerde': sinVerde},
};

Map<String, dynamic> lote(String id, String codigo, {String cultivo = 'cafe', String estado = 'pergamino', String? exportacion}) => {
  'id': id,
  'codigo': codigo,
  'cultivo': cultivo,
  'temporadaId': 't',
  'temporadaNombre': '2026/27',
  'estado': estado,
  'kg': 100,
  'kgEsperados': 100,
  'beneficio': 'B',
  'proceso': null,
  'avisos': [],
  'attestationUid': null,
  'creadoEn': '2026-10-16T20:00:00.000Z',
  'exportacionCodigo': exportacion,
  'entregas': [],
};

void main() {
  late CompartidorFalso compartidor;

  Future<ApiFalsa> abrir(WidgetTester tester, Widget pantalla, Map<String, (int, Object?)> respuestas) async {
    compartidor = CompartidorFalso();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(480, 2400);
    addTearDown(tester.view.reset);
    final auth = AuthFalso(inicial: admin);
    final api = ApiFalsa(respuestas);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
        compartidorProvider.overrideWithValue(compartidor),
      ],
      child: MaterialApp(home: pantalla),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('la lista muestra el contenedor, su origen y el aviso satelital', (tester) async {
    await abrir(tester, const ContenedoresScreen(), {
      'GET /v1/exportaciones': (200, {'exportaciones': [exportacionJson()]}),
    });
    expect(find.text('EXP-2026-001 · 160 kg'), findsOneWidget);
    expect(find.textContaining('Sin número de contenedor'), findsOneWidget);
    expect(find.byIcon(Icons.satellite_alt), findsOneWidget);

    await tester.tap(find.text('EXP-2026-001 · 160 kg'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Origen: 2 fincas (2.40 ha), 2 entregas'), findsOneWidget);
    expect(find.textContaining('el paquete EUDR no se podrá cerrar'), findsOneWidget);
    expect(find.text('CAFE-001 · 100 kg pergamino · 2026/27'), findsOneWidget);
  });

  testWidgets('completa el número de contenedor y la DDS con Editar datos', (tester) async {
    final api = await abrir(tester, const ContenedoresScreen(), {
      'GET /v1/exportaciones': (200, {'exportaciones': [exportacionJson()]}),
      'PATCH /v1/exportaciones/x1': (200, exportacionJson(contenedor: 'CSQU3054383')),
    });
    await tester.tap(find.text('EXP-2026-001 · 160 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar datos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Número de contenedor'), 'CSQU3054383');
    await tester.enterText(find.widgetWithText(TextField, 'Referencia de la DDS (TRACES)'), '26NI000123');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final patch = api.peticiones.firstWhere((p) => p.method == 'PATCH');
    // Solo viaja lo que cambió.
    expect(jsonDecode(patch.body), {'contenedor': 'CSQU3054383', 'ddsRef': '26NI000123'});
  });

  Future<void> expandir(WidgetTester tester) async {
    await tester.tap(find.text('EXP-2026-001 · 160 kg'));
    await tester.pumpAndSettle();
  }

  testWidgets('descarga el PDF y el GeoJSON sin nombres y los comparte', (tester) async {
    final api = await abrir(tester, const ContenedoresScreen(), {
      'GET /v1/exportaciones': (200, {'exportaciones': [exportacionJson()]}),
      'GET /v1/exportaciones/x1/pdf': (200, '%PDF-1.3 falso'),
      'GET /v1/exportaciones/x1/geojson': (200, {'type': 'FeatureCollection', 'features': []}),
    });
    await expandir(tester);
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GeoJSON (TRACES)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¿Incluir los nombres de los productores?'), findsOneWidget);
    await tester.tap(find.text('Sin nombres'));
    await tester.pumpAndSettle();

    expect(compartidor.compartidos.map((c) => (c.$1, c.$2)), [
      ('Paquete-EUDR-EXP-2026-001.pdf', 'application/pdf'),
      ('EXP-2026-001.geojson', 'application/geo+json'),
    ]);
    final geo = api.peticiones.firstWhere((p) => p.url.path.endsWith('/geojson'));
    expect(geo.url.query, isEmpty, reason: 'sin nombres de productores');
  });

  testWidgets('si no se puede cerrar, explica los motivos de la API', (tester) async {
    await abrir(tester, const ContenedoresScreen(), {
      'GET /v1/exportaciones': (200, {'exportaciones': [exportacionJson()]}),
      'POST /v1/exportaciones/x1/cerrar': (
        409,
        {
          'error': 'incompleto',
          'mensaje': 'No se puede cerrar: Falta el número de contenedor. 1 finca no tiene chequeo satelital verde: XXX (sin chequeo).',
        },
      ),
    });
    await expandir(tester);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cerrar')));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no se puede cerrar'), findsOneWidget);
    expect(find.textContaining('Falta el número de contenedor'), findsOneWidget);
  });

  testWidgets('cerrado: no se deshace ni se cierra, y solo se anota la DDS', (tester) async {
    final api = await abrir(tester, const ContenedoresScreen(), {
      'GET /v1/exportaciones': (200, {'exportaciones': [exportacionJson(contenedor: 'CSQU3054383', sinVerde: 0, estado: 'cerrada')]}),
      'PATCH /v1/exportaciones/x1': (200, exportacionJson(contenedor: 'CSQU3054383', sinVerde: 0, estado: 'cerrada')),
    });
    expect(find.textContaining('CSQU3054383 · cerrado'), findsOneWidget);
    await expandir(tester);
    expect(find.text('Deshacer'), findsNothing);
    expect(find.text('Cerrar'), findsNothing);
    await tester.tap(find.text('Anotar DDS'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Número de contenedor'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Referencia de la DDS (TRACES)'), '26NI000123');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final patch = api.peticiones.firstWhere((p) => p.method == 'PATCH');
    expect(jsonDecode(patch.body), {'ddsRef': '26NI000123'});
  });

  testWidgets('arma un contenedor: solo lotes libres y de un mismo cultivo', (tester) async {
    final api = await abrir(tester, const NuevoContenedorScreen(), {
      'GET /v1/lotes': (
        200,
        {
          'lotes': [
            lote('l1', 'CAFE-001'),
            lote('l2', 'CAFE-002'),
            lote('l3', 'CACAO-001', cultivo: 'cacao', estado: 'seco'),
            lote('l4', 'CAFE-000', exportacion: 'EXP-2026-000'),
          ],
        },
      ),
      'GET /v1/exportaciones': (200, {'exportaciones': []}),
      'POST /v1/exportaciones': (201, exportacionJson()),
    });
    expect(find.text('Lotes libres (3)'), findsOneWidget, reason: 'el ya embarcado no aparece');
    expect(find.text('EXP-${DateTime.now().year}-001'), findsOneWidget, reason: 'código sugerido');

    await tester.tap(find.text('CAFE-001 · 100 kg'));
    await tester.pump();
    expect(find.textContaining('un contenedor lleva un solo cultivo'), findsOneWidget);
    await tester.tap(find.text('CACAO-001 · 100 kg'));
    await tester.pump();
    await tester.tap(find.text('CAFE-002 · 100 kg'));
    await tester.pump();
    expect(find.text('2 lotes · 200 kg'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Comprador'), 'Tostador GmbH');
    await tester.enterText(find.widgetWithText(TextField, 'Destino'), 'Hamburgo, Alemania');
    await tester.tap(find.text('Crear contenedor'));
    await tester.pumpAndSettle();
    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    expect(jsonDecode(post.body), {
      'codigo': 'EXP-${DateTime.now().year}-001',
      'comprador': 'Tostador GmbH',
      'destino': 'Hamburgo, Alemania',
      'lotes': ['l1', 'l2'],
    });
  });
}

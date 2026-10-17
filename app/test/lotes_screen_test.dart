import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/data/database.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/lotes_screen.dart';
import 'package:trazacafe/screens/nuevo_lote_screen.dart';
import 'package:trazacafe/services/auth_service.dart';

import 'fakes.dart';

const admin = Sesion(uid: 'u-admin', email: 'admin@coop.org', organizacionId: 'org-1', rol: 'admin');
const t = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> loteJson({List<Map<String, String>> avisos = const []}) => {
  'id': 'l1',
  'codigo': 'CAFE-2026/27-001',
  'cultivo': 'cafe',
  'temporadaId': t,
  'temporadaNombre': '2026/27',
  'estado': 'pergamino',
  'kg': 160,
  'kgEsperados': 160,
  'beneficio': 'Beneficio La Esperanza',
  'proceso': 'lavado',
  'avisos': avisos,
  'attestationUid': null,
  'creadoEn': '2026-10-16T20:00:00.000Z',
  'entregas': [
    {'id': 'e1', 'fincaId': 'f1', 'fincaNombre': 'La Leonesa', 'productorNombre': 'Ana', 'kg': 500, 'estado': 'uva', 'fecha': '2026-10-16T17:00:00.000Z'},
    {'id': 'e2', 'fincaId': 'f1', 'fincaNombre': 'La Leonesa', 'productorNombre': 'Ana', 'kg': 300, 'estado': 'uva', 'fecha': '2026-10-16T18:00:00.000Z'},
  ],
};

Map<String, dynamic> disponible(String id, {double kg = 500, String? motivo, String deforestacion = 'verde'}) => {
  'id': id,
  'fincaId': 'f-$id',
  'fincaNombre': 'Finca $id',
  'productorNombre': 'Productor $id',
  'kg': kg,
  'estado': 'uva',
  'fecha': '2026-10-16T17:00:00.000Z',
  'deforestacion': deforestacion,
  'motivo': motivo,
};

void main() {
  Future<ApiFalsa> abrir(WidgetTester tester, Widget pantalla, Map<String, (int, Object?)> respuestas) async {
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
        cultivosOrganizacionProvider.overrideWith((ref) => Stream.value(['cafe'])),
        temporadasProvider.overrideWith((ref) => Stream.value([
              Temporada(id: t, nombre: '2026/27', inicio: DateTime(2026, 10, 1), fin: DateTime(2027, 9, 30)),
            ])),
      ],
      child: MaterialApp(home: pantalla),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('la lista muestra cada lote con sus avisos y entregas', (tester) async {
    await abrir(tester, const LotesScreen(), {
      'GET /v1/lotes': (
        200,
        {
          'lotes': [
            loteJson(avisos: [
              {'codigo': 'satelite', 'mensaje': '1 de 1 finca aún sin chequeo satelital verde.'},
            ]),
          ],
        },
      ),
    });
    expect(find.text('CAFE-2026/27-001 · 160 kg'), findsOneWidget);
    expect(find.textContaining('Café pergamino · 2026/27 · 2 entregas, 1 finca'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    await tester.tap(find.text('CAFE-2026/27-001 · 160 kg'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sin chequeo satelital verde'), findsOneWidget);
    expect(find.textContaining('La Leonesa (Ana) · 500 kg uva'), findsOneWidget);
    expect(find.text('Deshacer lote'), findsOneWidget);
  });

  testWidgets('sin lotes explica qué es un lote', (tester) async {
    await abrir(tester, const LotesScreen(), {'GET /v1/lotes': (200, {'lotes': []})});
    expect(find.textContaining('Un lote agrupa entregas'), findsOneWidget);
  });

  testWidgets('arma un lote: elige entregas, propone el peso y no deja elegir las excluidas', (tester) async {
    final api = await abrir(tester, const NuevoLoteScreen(), {
      'GET /v1/lotes/disponibles': (
        200,
        {
          'entregas': [
            disponible('a', kg: 500),
            disponible('b', kg: 300, deforestacion: 'pendiente'),
            disponible('c', motivo: 'La finca no tiene la visita de verificación de la temporada'),
          ],
        },
      ),
      'POST /v1/lotes': (201, loteJson()),
    });
    final pedida = api.peticiones.firstWhere((p) => p.url.path == '/v1/lotes/disponibles').url;
    expect(pedida.queryParameters, {'cultivo': 'cafe', 'temporadaId': t});
    expect(find.text('CAFE-2026/27-001'), findsOneWidget, reason: 'código sugerido');
    expect(find.text('No pueden ir en un lote (1)'), findsOneWidget);
    expect(find.text('La finca no tiene la visita de verificación de la temporada'), findsOneWidget);
    expect(find.textContaining('satélite: pendiente'), findsOneWidget);

    // El lote se arma en pergamino: 800 kg de uva rinden unos 160 kg.
    await tester.tap(find.text('Pergamino'));
    await tester.pump();
    await tester.tap(find.text('Elegir todas'));
    await tester.pump();
    expect(find.text('2 entregas: rinden unos 160 kg de pergamino.'), findsOneWidget);
    expect(find.widgetWithText(TextField, '160'), findsOneWidget, reason: 'peso propuesto');

    // Un peso mucho mayor muestra el aviso de volumen antes de guardar.
    await tester.enterText(find.widgetWithText(TextField, '160'), '250');
    await tester.pump();
    expect(find.textContaining('Pesa más de lo que rinden'), findsOneWidget);

    await tester.tap(find.text('Crear lote'));
    await tester.pumpAndSettle();
    final post = api.peticiones.last;
    expect(post.method, 'POST');
    expect(jsonDecode(post.body), {
      'codigo': 'CAFE-2026/27-001',
      'cultivo': 'cafe',
      'temporadaId': t,
      'estado': 'pergamino',
      'kg': 250.0,
      'entregas': ['a', 'b'],
    });
  });

  testWidgets('si la API rechaza el lote, lo dice y no se cierra', (tester) async {
    await abrir(tester, const NuevoLoteScreen(), {
      'GET /v1/lotes/disponibles': (200, {'entregas': [disponible('a')]}),
      'POST /v1/lotes': (
        422,
        {'error': 'entregas_excluidas', 'mensaje': '1 entrega no puede ir en el lote: Ya está en el lote CAFE-9.'},
      ),
    });
    await tester.tap(find.text('Elegir todas'));
    await tester.pump();
    await tester.tap(find.text('Crear lote'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ya está en el lote CAFE-9'), findsOneWidget);
    expect(find.text('Nuevo lote'), findsOneWidget);
  });
}

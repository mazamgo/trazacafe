import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/consola_screen.dart';
import 'package:trazacafe/services/auth_service.dart';

import 'fakes.dart';

const propietario = Sesion(uid: 'u-go', email: 'mauricio@goproduction.com', propietario: true);
const admin = Sesion(uid: 'u-a', email: 'admin@coop.org', organizacionId: 'o1', rol: 'admin');

void main() {
  Future<ApiFalsa> abrir(WidgetTester tester, Sesion sesion) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final auth = AuthFalso(inicial: sesion);
    final api = ApiFalsa({
      'GET /v1/consola/organizaciones': (200, {
        'organizaciones': [
          {
            'id': 'o1', 'nombre': 'Coop Sur', 'tipo': 'cooperativa', 'cultivos': ['cafe'], 'suspendida': false,
            'eliminacionProgramada': null, 'administradores': 1, 'usuarios': 3, 'productores': 120, 'fincas': 150,
            'hectareas': 310.5, 'contenedoresCerrados': 4, 'plan': 'basico', 'estadoContrato': 'activo',
          },
        ],
      }),
      'GET /v1/consola/organizaciones/o1/equipo': (200, {
        'equipo': [{'email': 'ana@gmail.com', 'rol': 'tecnico', 'activo': true}],
      }),
      'POST /v1/consola/organizaciones/o1/suspender': (204, null),
      'GET /v1/consola/salud': (200, {
        'tareas': [{'tarea': 'attestations', 'ultima': '2026-11-22T12:15:00.000Z', 'ok': true, 'detalle': {'firmadas': 3}}],
        'attestations': {'pendientes': 2, 'conError': 0, 'masAntigua': null},
        'firma': {'red': 'optimism-sepolia', 'saldoEth': '0.012345'},
        'fincasEnRojo': [],
      }),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
      ],
      child: const MaterialApp(home: ConsolaWeb()),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('quien no es propietario no entra', (tester) async {
    await abrir(tester, admin);
    expect(find.text('La consola es solo para GoProduction.'), findsOneWidget);
  });

  testWidgets('el propietario ve las organizaciones y suspende una', (tester) async {
    final api = await abrir(tester, propietario);
    expect(find.text('Coop Sur · Cooperativa'), findsOneWidget);
    expect(find.textContaining('120 productores'), findsOneWidget);
    await tester.tap(find.text('Coop Sur · Cooperativa'));
    await tester.pumpAndSettle();
    expect(find.text('ana@gmail.com'), findsOneWidget);
    await tester.tap(find.text('Suspender por falta de pago'));
    await tester.pumpAndSettle();
    expect(api.peticiones.any((p) => p.method == 'POST' && p.url.path.endsWith('/suspender')), isTrue);
  });

  testWidgets('la salud muestra tareas, cola y saldo', (tester) async {
    await abrir(tester, propietario);
    await tester.tap(find.text('Salud'));
    await tester.pumpAndSettle();
    expect(find.text('Attestations pendientes: 2 (0 con error)'), findsOneWidget);
    expect(find.text('Saldo de la clave de firma: 0.012345 ETH'), findsOneWidget);
  });
}

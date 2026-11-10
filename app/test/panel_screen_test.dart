import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/panel_screen.dart';
import 'package:trazacafe/services/auth_service.dart';

import 'fakes.dart';

const admin = Sesion(uid: 'u-admin', email: 'admin@x.org', organizacionId: 'org-1', rol: 'admin');
const tecnico = Sesion(uid: 'u-tec', email: 'tec@x.org', organizacionId: 'org-1', rol: 'tecnico');

Map<String, (int, Object?)> respuestas({String tipo = 'cooperativa'}) => {
  'GET /v1/organizacion': (200, {'id': 'org-1', 'nombre': 'Coop Sur', 'tipo': tipo, 'cultivos': ['cafe'], 'eliminacionProgramada': null}),
  'GET /v1/temporadas': (200, {
    'temporadas': [
      {'id': 't1', 'nombre': '2026/27', 'inicio': '2026-10-01', 'fin': '2027-03-31', 'cultivo': null},
    ],
  }),
  'GET /v1/lotes': (200, {'lotes': []}),
  'GET /v1/exportaciones': (200, {'exportaciones': []}),
  'GET /v1/proveedores': (200, {'proveedores': [], 'porRecibir': []}),
  'GET /v1/clientes': (200, {'clientes': []}),
  'GET /v1/observaciones': (200, {'observaciones': []}),
  'GET /v1/invitaciones': (200, {'invitaciones': []}),
  'GET /v1/red/avisos': (200, {'invitaciones': [], 'lotesPorRecibir': 0, 'observacionesSinResponder': 0}),
};

void main() {
  Future<(ApiFalsa, ProviderContainer)> abrir(
    WidgetTester tester, {
    Sesion sesion = admin,
    String tipo = 'cooperativa',
    String? seccion,
    Size tamano = const Size(1280, 900),
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = tamano;
    addTearDown(tester.view.reset);
    final auth = AuthFalso(inicial: sesion);
    final api = ApiFalsa(respuestas(tipo: tipo));
    final contenedor = ProviderContainer(
      overrides: [
        // Como en la web: nada sale de la base local.
        conBaseLocalProvider.overrideWithValue(false),
        databaseProvider.overrideWith((ref) => throw StateError('el panel no abre la base local')),
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
        sesionMapaProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(contenedor.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp(home: PanelWeb(seccion: seccion)),
    ));
    await tester.pumpAndSettle();
    return (api, contenedor);
  }

  testWidgets('un técnico ve el aviso y no el menú', (tester) async {
    await abrir(tester, sesion: tecnico);
    expect(find.textContaining('El panel web es para administradores'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('una cooperativa ve Clientes y no Proveedores', (tester) async {
    await abrir(tester);
    expect(find.text('TrazaCafé · Coop Sur'), findsOneWidget);
    final menu = find.byType(NavigationRail);
    expect(find.descendant(of: menu, matching: find.text('Clientes')), findsOneWidget);
    expect(find.descendant(of: menu, matching: find.text('Proveedores')), findsNothing);
  });

  testWidgets('una exportadora ve Proveedores y no Clientes', (tester) async {
    await abrir(tester, tipo: 'exportadora');
    final menu = find.byType(NavigationRail);
    expect(find.descendant(of: menu, matching: find.text('Proveedores')), findsOneWidget);
    expect(find.descendant(of: menu, matching: find.text('Clientes')), findsNothing);
  });

  testWidgets('empieza en Lotes y cambia de sección desde el menú', (tester) async {
    final (api, _) = await abrir(tester);
    expect(api.peticiones.map((r) => r.url.path), contains('/v1/lotes'));
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Contenedores')));
    await tester.pumpAndSettle();
    expect(api.peticiones.map((r) => r.url.path), contains('/v1/exportaciones'));
  });

  testWidgets('abre la sección de la URL', (tester) async {
    final (api, _) = await abrir(tester, seccion: 'equipo');
    expect(api.peticiones.map((r) => r.url.path), contains('/v1/invitaciones'));
    expect(api.peticiones.map((r) => r.url.path), isNot(contains('/v1/lotes')));
  });

  testWidgets('en pantalla angosta el menú va abajo', (tester) async {
    await abrir(tester, tamano: const Size(400, 900));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('los avisos se vuelven a pedir al volver a la pestaña y cada pocos minutos', (tester) async {
    final (api, _) = await abrir(tester);
    int avisos() => api.peticiones.where((r) => r.url.path == '/v1/red/avisos').length;
    final inicio = avisos();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(avisos(), inicio + 1);
    await tester.pump(avisosCada);
    await tester.pumpAndSettle();
    expect(avisos(), inicio + 2);
  });

  testWidgets('organización, cultivos y temporadas salen de la API', (tester) async {
    final (_, contenedor) = await abrir(tester);
    contenedor.listen(cultivosOrganizacionProvider, (_, _) {});
    contenedor.listen(temporadasProvider, (_, _) {});
    await tester.pumpAndSettle();
    expect(contenedor.read(cultivosOrganizacionProvider).value, ['cafe']);
    final temporadas = contenedor.read(temporadasProvider).value!;
    expect(temporadas.single.nombre, '2026/27');
    expect(temporadas.single.inicio, DateTime(2026, 10, 1));
    expect(temporadas.single.fin, DateTime(2027, 3, 31));
  });
}

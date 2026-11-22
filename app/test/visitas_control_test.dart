import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/visitas_control_screen.dart';
import 'package:trazacafe/services/api_client.dart';
import 'package:trazacafe/services/auth_service.dart';

import 'fakes.dart';

const tecnico = Sesion(uid: 'u-tec', email: 'tec@x.org', organizacionId: 'org-1', rol: 'tecnico');

Map<String, dynamic> finca({bool visitada = false}) => {
  'id': 'f1',
  'nombre': 'Finca 3F2A',
  'productorNombre': null,
  'comunidad': 'El Cuá',
  'proveedor': 'Coop Sur',
  'cultivo': 'cafe',
  'coordenadas': [[-85.7, 13.4], [-85.69, 13.4], [-85.69, 13.41], [-85.7, 13.4]],
  'areaOficialHa': 2.5,
  'temporadaNombre': '2026/27',
  'visitada': visitada,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ApiClient cliente(ApiFalsa api) => api.cliente(AuthFalso(inicial: tecnico));

  test('guarda la lista para usarla sin señal', () async {
    final conSenal = ControlService(cliente(ApiFalsa({'GET /v1/control': (200, {'fincas': [finca()]})})));
    expect((await conSenal.cargar()).fincas.single.nombre, 'Finca 3F2A');
    final sinSenal = await ControlService(cliente(ApiFalsa({'GET /v1/control': (503, null)}))).cargar();
    expect(sinSenal.sinSenal, isTrue);
    expect(sinSenal.fincas.single.proveedor, 'Coop Sur');
  });

  test('sin señal la visita queda guardada y se envía al volver', () async {
    final caida = ApiFalsa({'POST /v1/control/visitas': (503, null)});
    await ControlService(cliente(caida)).registrar(fincaId: 'f1', linderoCambio: false, nota: 'Bien');
    final antes = await ControlService(cliente(ApiFalsa({'GET /v1/control': (503, null), 'POST /v1/control/visitas': (503, null)}))).cargar();
    expect(antes.pendientes, hasLength(1));

    final api = ApiFalsa({'POST /v1/control/visitas': (204, null), 'GET /v1/control': (200, {'fincas': [finca(visitada: true)]})});
    final despues = await ControlService(cliente(api)).cargar();
    expect(despues.pendientes, isEmpty);
    final enviada = jsonDecode(api.peticiones.firstWhere((p) => p.method == 'POST').body) as Map;
    expect(enviada['fincaId'], 'f1');
    expect(enviada['linderoCambio'], false);
    expect(enviada['nota'], 'Bien');
    expect(enviada['id'], isA<String>());
  });

  test('una visita que la API rechaza no se reintenta', () async {
    final api = ApiFalsa({'POST /v1/control/visitas': (403, {'mensaje': 'Esa finca no está'})});
    final s = ControlService(cliente(api));
    await s.registrar(fincaId: 'f1', linderoCambio: true);
    final estado = await ControlService(cliente(ApiFalsa({'GET /v1/control': (200, {'fincas': []})}))).cargar();
    expect(estado.pendientes, isEmpty);
  });

  testWidgets('el técnico registra la visita desde la lista', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(480, 1600);
    addTearDown(tester.view.reset);
    final auth = AuthFalso(inicial: tecnico);
    final api = ApiFalsa({
      'GET /v1/control': (200, {'fincas': [finca()]}),
      'POST /v1/control/visitas': (204, null),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
        sesionMapaProvider.overrideWith((ref) async => null),
        mapasDescargadosProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: VisitasControlScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Finca 3F2A · Coop Sur'), findsOneWidget);
    expect(find.textContaining('por visitar'), findsOneWidget);
    await tester.tap(find.text('Finca 3F2A · Coop Sur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar visita'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.enterText(find.byType(TextField), 'Hay potrero al norte');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    final cuerpo = jsonDecode(post.body) as Map;
    expect(cuerpo['linderoCambio'], isTrue);
    expect(cuerpo['nota'], 'Hay potrero al norte');
    expect(find.text('Visita de Finca 3F2A guardada.'), findsOneWidget);
  });
}

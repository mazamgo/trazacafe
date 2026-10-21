import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/eliminar_datos_screen.dart';
import 'package:trazacafe/screens/solicitudes_eliminacion_screen.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/eliminacion_service.dart';

import 'fakes.dart';

const org = '11111111-1111-4111-8111-111111111111';

/// Página pública de eliminación de datos (Google Play) y solicitudes en la app.
void main() {
  testWidgets('el productor elige su cooperativa, llena el formulario y lo envía', (tester) async {
    final enviadas = <Map<String, dynamic>>[];
    final publica = EliminacionPublica(
      baseUrl: 'https://api.test',
      cliente: MockClient((req) async {
        if (req.method == 'GET') {
          return http.Response(jsonEncode({'organizaciones': [{'id': org, 'nombre': 'Cooperativa Prueba'}]}), 200);
        }
        enviadas.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'recibida': true}), 201);
      }),
    );
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        eliminacionPublicaProvider.overrideWithValue(publica),
        authServiceProvider.overrideWithValue(AuthFalso()),
      ],
      child: const MaterialApp(home: EliminarDatosScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('GoProduction'), findsWidgets);
    expect(find.text('Qué se borra, qué se conserva y por cuánto tiempo'), findsOneWidget);

    await tester.tap(find.text('Pedir que borren mis datos'));
    await tester.pump();
    expect(find.textContaining('Elige tu cooperativa'), findsOneWidget);

    await tester.tap(find.text('Tu cooperativa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cooperativa Prueba').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre completo'), 'María López');
    await tester.enterText(find.widgetWithText(TextField, 'Cédula (opcional, ayuda a encontrarte)'), '12345');
    await tester.enterText(find.widgetWithText(TextField, 'Teléfono o correo para avisarte'), '8888-0000');
    await tester.tap(find.text('Pedir que borren mis datos'));
    await tester.pump();
    expect(find.textContaining('formato 001-010190-0001A'), findsOneWidget);
    expect(enviadas, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Cédula (opcional, ayuda a encontrarte)'), '');
    await tester.tap(find.text('Pedir que borren mis datos'));
    await tester.pumpAndSettle();
    expect(enviadas.single, {'organizacionId': org, 'nombre': 'María López', 'contacto': '8888-0000'});
    expect(find.text('Recibimos tu solicitud'), findsOneWidget);
  });

  testWidgets('quien trabaja en una cooperativa entra con Google y ve cómo eliminar su cuenta', (tester) async {
    final auth = AuthFalso()..alEntrar = const Sesion(uid: 'u', email: 'admin@coop.org', organizacionId: org, rol: 'admin');
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        eliminacionPublicaProvider.overrideWithValue(
          EliminacionPublica(baseUrl: 'https://api.test', cliente: MockClient((_) async => http.Response('{"organizaciones":[]}', 200))),
        ),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: const MaterialApp(home: EliminarDatosScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar con Google'));
    await tester.pumpAndSettle();
    expect(find.text('Sesión: admin@coop.org'), findsOneWidget);
    expect(find.text('Eliminar mi cuenta'), findsOneWidget);
    expect(find.text('Eliminar toda la organización'), findsOneWidget);
  });

  testWidgets('el administrador ve las solicitudes con el contacto del productor', (tester) async {
    final auth = AuthFalso(inicial: const Sesion(uid: 'u', email: 'admin@coop.org', organizacionId: org, rol: 'admin'));
    final api = ApiFalsa({
      'GET /v1/solicitudes-eliminacion': (
        200,
        {
          'solicitudes': [
            {
              'id': 's1', 'nombre': 'María López', 'cedula': '001-010190-0001A', 'comunidad': 'El Tuma',
              'contacto': '8888-0000', 'mensaje': null, 'creadaEn': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
            },
          ],
        },
      ),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
      ],
      child: const MaterialApp(home: SolicitudesEliminacionScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('María López'), findsOneWidget);
    expect(find.textContaining('Contacto: 8888-0000'), findsOneWidget);
    expect(find.textContaining('respóndela pronto'), findsOneWidget);
    expect(find.text('Buscar y eliminar'), findsOneWidget);
  });
}

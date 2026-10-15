import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/equipo_screen.dart';
import 'package:trazacafe/services/auth_service.dart';

import 'fakes.dart';

const admin = Sesion(uid: 'u-admin', email: 'admin@coop.org', organizacionId: 'org-1', rol: 'admin');

void main() {
  Future<ApiFalsa> abrir(WidgetTester tester) async {
    final auth = AuthFalso(inicial: admin);
    final api = ApiFalsa({
      'GET /v1/invitaciones': (
        200,
        {
          'invitaciones': [
            {'email': 'admin@coop.org', 'rol': 'admin', 'usuarioUid': 'u-admin'},
            {'email': 'juan@gmail.com', 'rol': 'tecnico', 'usuarioUid': null},
          ],
        },
      ),
      'POST /v1/invitaciones': (201, {'email': 'ana@gmail.com', 'rol': 'tecnico'}),
      'DELETE /v1/invitaciones/juan@gmail.com': (204, null),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
      ],
      child: const MaterialApp(home: EquipoScreen()),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('lista el equipo con su rol y estado', (tester) async {
    await abrir(tester);
    expect(find.text('juan@gmail.com'), findsOneWidget);
    expect(find.text('Técnico · pendiente de entrar'), findsOneWidget);
    expect(find.text('Administrador · activo'), findsOneWidget);
    // El administrador no puede quitarse a sí mismo.
    expect(find.text('Tú'), findsOneWidget);
    expect(find.byTooltip('Quitar acceso'), findsOneWidget);
  });

  testWidgets('invita a un técnico con su correo de Google', (tester) async {
    final api = await abrir(tester);
    await tester.tap(find.text('Invitar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Correo de Google'), ' Ana@Gmail.com ');
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pumpAndSettle();

    final post = api.peticiones.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'email': 'ana@gmail.com', 'rol': 'tecnico'});
    expect(find.textContaining('Invitación enviada a ana@gmail.com'), findsOneWidget);
  });

  testWidgets('rechaza correos inválidos sin llamar a la API', (tester) async {
    final api = await abrir(tester);
    await tester.tap(find.text('Invitar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Correo de Google'), 'juan');
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pump();

    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(api.peticiones.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('quita el acceso después de confirmar', (tester) async {
    final api = await abrir(tester);
    await tester.tap(find.byTooltip('Quitar acceso'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar acceso'));
    await tester.pumpAndSettle();

    expect(api.peticiones.any((r) => r.method == 'DELETE'), isTrue);
    expect(find.textContaining('Se quitó el acceso a juan@gmail.com'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/activacion_screen.dart';
import 'package:trazacafe/screens/login_screen.dart';
import 'package:trazacafe/services/auth_service.dart';

import 'fakes.dart';

const sinAcceso = Sesion(uid: 'u1', email: 'juan@gmail.com');

void main() {
  group('LoginScreen', () {
    Future<AuthFalso> abrir(WidgetTester tester, {Exception? error}) async {
      final auth = AuthFalso()
        ..errorAlEntrar = error
        ..alEntrar = sinAcceso;
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      return auth;
    }

    testWidgets('muestra el botón de Google', (tester) async {
      await abrir(tester);
      expect(find.text('Entrar con Google'), findsOneWidget);
    });

    testWidgets('si se cancela el selector no muestra error', (tester) async {
      await abrir(tester, error: AuthCancelado());
      await tester.tap(find.text('Entrar con Google'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo'), findsNothing);
    });

    testWidgets('muestra el error de Google', (tester) async {
      await abrir(tester, error: AuthError('No se pudo iniciar sesión con Google.'));
      await tester.tap(find.text('Entrar con Google'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo iniciar sesión con Google.'), findsOneWidget);
    });
  });

  group('ActivacionScreen', () {
    Future<(AuthFalso, ApiFalsa, ProviderContainer)> abrir(
      WidgetTester tester,
      Map<String, (int, Object?)> respuestas,
    ) async {
      final auth = AuthFalso(inicial: sinAcceso);
      final api = ApiFalsa(respuestas);
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ActivacionScreen(email: 'juan@gmail.com')),
      ));
      await tester.pumpAndSettle();
      return (auth, api, container);
    }

    testWidgets('con invitación activa el acceso y refresca el token', (tester) async {
      final (auth, api, _) = await abrir(tester, {
        'POST /v1/activar': (200, {'organizacionId': 'org-1', 'rol': 'tecnico'}),
      });
      expect(api.peticiones.single.url.path, '/v1/activar');
      expect(auth.refrescos, 1);
      expect(auth.cierres, 0);
    });

    testWidgets('sin invitación cierra la sesión y deja el motivo para el login', (tester) async {
      final (auth, _, container) = await abrir(tester, {
        'POST /v1/activar': (
          403,
          {'error': 'sin_invitacion', 'mensaje': 'Tu cuenta no está autorizada.'},
        ),
      });
      expect(auth.cierres, 1);
      expect(container.read(avisoAccesoProvider), 'Tu cuenta no está autorizada.');
    });

    testWidgets('sin señal ofrece reintentar sin cerrar la sesión', (tester) async {
      final (auth, _, _) = await abrir(tester, {'POST /v1/activar': (503, null)});
      expect(find.text('Reintentar'), findsOneWidget);
      expect(auth.cierres, 0);
    });
  });
}

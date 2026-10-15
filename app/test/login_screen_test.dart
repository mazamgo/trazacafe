import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/login_screen.dart';
import 'package:trazacafe/services/auth_service.dart';

class AuthFalso implements AuthService {
  final intentos = <String>[];

  @override
  Future<void> iniciarSesion(String correo, String clave) async {
    intentos.add(correo);
    if (clave != 'correcta') throw AuthError('Correo o contraseña incorrectos.');
  }

  @override
  Stream<String?> observarUsuario() => const Stream.empty();
  @override
  Future<void> recuperarClave(String correo) async {}
  @override
  Future<void> cerrarSesion() async {}
  @override
  Future<String?> token() async => null;
}

void main() {
  late AuthFalso auth;

  Future<void> abrir(WidgetTester tester) async {
    auth = AuthFalso();
    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: LoginScreen()),
    ));
  }

  testWidgets('pide correo y contraseña antes de intentar', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Escribe tu correo y contraseña.'), findsOneWidget);
    expect(auth.intentos, isEmpty);
  });

  testWidgets('muestra el error de credenciales', (tester) async {
    await abrir(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Correo'), ' tecnico@coop.org ');
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'mala');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(auth.intentos, ['tecnico@coop.org']);
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });
}

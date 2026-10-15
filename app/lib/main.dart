import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers.dart';
import 'screens/login_screen.dart';
import 'screens/productores_screen.dart';
import 'screens/verificador_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: TrazaCafeApp()));
}

class TrazaCafeApp extends StatelessWidget {
  const TrazaCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrazaCafé',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6F4E37)),
      ),
      // En la web solo se publica el verificador (/v/{uid}); la app de campo
      // es para Android.
      onGenerateRoute: (settings) {
        final ruta = Uri.parse(settings.name ?? '/');
        if (ruta.pathSegments.length == 2 && ruta.pathSegments.first == 'v') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => VerificadorScreen(uid: ruta.pathSegments[1]),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              kIsWeb ? const VerificadorScreen(uid: null) : const _Inicio(),
        );
      },
    );
  }
}

/// Muestra el login o la app según haya sesión.
class _Inicio extends ConsumerWidget {
  const _Inicio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(usuarioProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (usuario) => usuario == null ? const LoginScreen() : const ProductoresScreen(),
        );
  }
}

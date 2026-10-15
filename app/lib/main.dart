import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/fincas_screen.dart';
import 'screens/verificador_screen.dart';

void main() {
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
          builder: (_) => kIsWeb
              ? const VerificadorScreen(uid: null)
              : const FincasScreen(),
        );
      },
    );
  }
}

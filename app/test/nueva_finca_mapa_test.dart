import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/nueva_finca_screen.dart';
import 'package:trazacafe/services/mapas_service.dart';

/// La pantalla con el mapa de Google ya cargado (como en un celular con
/// señal). Las pruebas anteriores solo cubrían el caso sin mapa.
void main() {
  testWidgets('Nueva finca se dibuja con el mapa de Google', (tester) async {
    final sesion = SesionMapa('sesion-prueba', DateTime.now().add(const Duration(days: 10)));
    await tester.pumpWidget(ProviderScope(
      overrides: [sesionMapaProvider.overrideWith((ref) async => sesion)],
      child: const MaterialApp(home: NuevaFincaScreen(productorId: 'p1')),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Guardar finca'), findsOneWidget);
    expect(find.textContaining('Google'), findsOneWidget);
  });
}

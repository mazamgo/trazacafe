import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/nueva_finca_screen.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/mapas_service.dart';

/// La pantalla con el mapa de Google ya cargado (como en un celular con
/// señal). Las pruebas anteriores solo cubrían el caso sin mapa.
void main() {
  testWidgets('Nueva finca se dibuja con el mapa de Google', (tester) async {
    final sesion = SesionMapa('sesion-prueba', DateTime.now().add(const Duration(days: 10)));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sesionMapaProvider.overrideWith((ref) async => sesion),
        cultivosOrganizacionProvider.overrideWith((ref) => Stream.value(['cafe'])),
      ],
      child: const MaterialApp(home: NuevaFincaScreen(productorId: 'p1')),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Guardar finca'), findsOneWidget);
    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.text('Cacao'), findsNothing, reason: 'con un solo cultivo no se pregunta');
    expect(find.text('Cultivo: Café'), findsOneWidget, reason: 'pero sí se muestra');
    expect(find.textContaining('Activa más cultivos'), findsNothing, reason: 'el técnico no puede activarlos');
  });

  testWidgets('al administrador con un solo cultivo le dice dónde activar más', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sesionMapaProvider.overrideWith((ref) async => null),
        cultivosOrganizacionProvider.overrideWith((ref) => Stream.value(['cafe'])),
        sesionProvider.overrideWith((ref) => Stream.value(
              const Sesion(uid: 'u1', email: 'a@coop.org', organizacionId: 'org', rol: 'admin'),
            )),
      ],
      child: const MaterialApp(home: NuevaFincaScreen(productorId: 'p1')),
    ));
    await tester.pump();
    expect(find.text('Cultivo: Café'), findsOneWidget);
    expect(find.text('Activa más cultivos en ⋮ → Cultivos'), findsOneWidget);
  });

  testWidgets('si la organización trabaja café y cacao, pregunta el cultivo', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sesionMapaProvider.overrideWith((ref) async => null),
        cultivosOrganizacionProvider.overrideWith((ref) => Stream.value(['cafe', 'cacao'])),
      ],
      child: const MaterialApp(home: NuevaFincaScreen(productorId: 'p1')),
    ));
    await tester.pump();
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Cacao'), findsOneWidget);
    await tester.tap(find.text('Cacao'));
    await tester.pump();
    final boton = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(boton.selected, {'cacao'});
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/screens/verificador_screen.dart';

void main() {
  testWidgets('el verificador muestra el UID y el enlace a EAS', (tester) async {
    const uid = '0xabc123';
    await tester.pumpWidget(
      const MaterialApp(home: VerificadorScreen(uid: uid)),
    );

    expect(find.text(uid), findsOneWidget);
    expect(find.textContaining('optimism.easscan.org'), findsOneWidget);
  });

  testWidgets('sin UID pide escanear el QR', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VerificadorScreen(uid: null)),
    );
    expect(find.textContaining('Escanea'), findsOneWidget);
  });
}

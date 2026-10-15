import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/screens/nueva_finca_screen.dart';
import 'package:trazacafe/screens/nuevo_productor_screen.dart';

/// Android 15+ dibuja la app detrás de la barra de navegación (en Samsung,
/// los botones ◁ ○ ▢). Los botones de guardar deben quedar completos encima.
void main() {
  const barra = 48.0;
  var alto = 780.0;

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = Size(400, alto)
      ..padding = const FakeViewPadding(bottom: barra)
      ..viewPadding = const FakeViewPadding(bottom: barra);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: pantalla)));
    await tester.pump();
  }

  void quedaEncimaDeLaBarra(WidgetTester tester, String boton) {
    final rect = tester.getRect(find.widgetWithText(FilledButton, boton));
    expect(rect.bottom, lessThanOrEqualTo(alto - barra),
        reason: '"$boton" termina en ${rect.bottom}, la barra empieza en ${alto - barra}');
  }

  testWidgets('Nueva finca: "Guardar finca" no queda bajo la barra', (tester) async {
    alto = 780;
    await abrir(tester, const NuevaFincaScreen(productorId: 'p1'));
    quedaEncimaDeLaBarra(tester, 'Guardar finca');
  });

  testWidgets('Nuevo productor: "Guardar productor" no queda bajo la barra', (tester) async {
    // Pantalla baja para que el formulario tenga que desplazarse, como pasa
    // con la foto del consentimiento o con el teclado abierto.
    alto = 420;
    await abrir(tester, const NuevoProductorScreen());
    // Hasta el final de la lista, como el técnico al terminar el formulario.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    quedaEncimaDeLaBarra(tester, 'Guardar productor');
  });
}

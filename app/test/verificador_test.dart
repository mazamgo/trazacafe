import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trazacafe/screens/verificador_screen.dart';
import 'package:trazacafe/services/preferencias.dart';
import 'package:trazacafe/services/verificador_service.dart';

import 'datos_verificador.dart';

/// API y RPC falsos con datos reales: la cadena pública y la attestation de
/// [uid] (contenedor o lote).
VerificadorService servicio({
  String uid = uidContenedor,
  int statusApi = 200,
  Object? cuerpoApi,
  bool rpcFalla = false,
}) {
  final (cadena, ethCall) = uid == uidLote ? (cadenaLote, ethCallLote) : (cadenaContenedor, ethCallContenedor);
  return VerificadorService(
    baseUrl: 'https://api.test',
    cliente: MockClient((req) async {
      if (req.url.host == 'api.test') {
        final cuerpo = cuerpoApi == null ? cadena : jsonEncode(cuerpoApi);
        return http.Response.bytes(utf8.encode(cuerpo), statusApi);
      }
      if (rpcFalla) return http.Response('bad gateway', 502);
      final pedido = jsonDecode(req.body) as Map;
      expect((pedido['params'] as List).first['data'], '0xa3112a64${uid.substring(2)}');
      return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': ethCall}), 200);
    }),
  );
}

CadenaPublica cadena(String json) => CadenaPublica.desdeJson(jsonDecode(json) as Map<String, dynamic>);

/// Como en `main.dart`: el tema sale de [temaProvider].
class _App extends ConsumerWidget {
  const _App(this.pantalla);
  final Widget pantalla;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      MaterialApp(theme: temaClaro, darkTheme: temaOscuro, themeMode: ref.watch(temaProvider), home: pantalla);
}

Future<void> abrir(WidgetTester tester, VerificadorService s, {String uid = uidContenedor, String idioma = 'es'}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(480, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [idiomaInicialProvider.overrideWithValue(idioma)],
      child: _App(VerificadorScreen(uid: uid, servicio: s, mostrarMapa: false)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('attestation leída de la blockchain', () {
    test('decodifica la respuesta real de getAttestation', () {
      final a = AttestationEnCadena.decodificar(ethCallContenedor);
      expect(a.existe, isTrue);
      expect(a.uid, uidContenedor);
      expect(a.schema, esquemaUid['Exportacion']);
      expect(a.attester, atestadorOficial);
      expect(a.revocationTime, 0);
      expect(a.data.texto(4), 'CSQU3054383');
      expect(a.data.texto(6), 'PRUEBA-0001');
      expect(a.data.entero(3), BigInt.from(15000));
    });

    test('la cadena de la API coincide con lo firmado', () {
      final c = comprobar(cadena(cadenaContenedor), AttestationEnCadena.decodificar(ethCallContenedor));
      expect(c.diferencias, isEmpty);
      expect(c.valida, isTrue);
    });

    test('el lote (QR del saco) también coincide con lo firmado', () {
      final a = AttestationEnCadena.decodificar(ethCallLote);
      expect(a.schema, esquemaUid['Lote']);
      final c = comprobar(cadena(cadenaLote), a);
      expect(c.diferencias, isEmpty);
      expect(c.valida, isTrue);
    });

    test('si la API dijera otros kg u otra DDS, lo detecta', () {
      final j = jsonDecode(cadenaContenedor) as Map<String, dynamic>;
      j['exportacion']['kg'] = 1500;
      j['exportacion']['ddsRef'] = 'OTRA';
      final c = comprobar(CadenaPublica.desdeJson(j), AttestationEnCadena.decodificar(ethCallContenedor));
      expect(c.diferencias, ['kg', 'DDS']);
      expect(c.valida, isFalse);
    });

    test('un contenedor presentado con la attestation de un lote no pasa', () {
      final c = comprobar(cadena(cadenaContenedor), AttestationEnCadena.decodificar(ethCallLote));
      expect(c.esquemaCorrecto, isFalse);
      expect(c.valida, isFalse);
    });

    test('una attestation que no existe devuelve uid cero', () {
      // Tupla vacía: offset 0x20, 9 palabras en cero, offset de data 0x140 y largo 0.
      final palabras = [
        '20'.padLeft(64, '0'),
        for (var i = 0; i < 9; i++) '0' * 64,
        '140'.padLeft(64, '0'),
        '0' * 64,
      ];
      expect(AttestationEnCadena.decodificar('0x${palabras.join()}').existe, isFalse);
    });
  });

  testWidgets('muestra la cadena sin datos personales y verificada en la blockchain', (tester) async {
    await abrir(tester, servicio());
    expect(find.text('Contenedor CSQU3054383'), findsOneWidget);
    expect(find.textContaining('DDS (TRACES): PRUEBA-0001'), findsOneWidget);
    expect(find.text('Verificado en la blockchain'), findsOneWidget);
    expect(find.textContaining('Firmado por TrazaCafé (0xbfc2…cb99)'), findsOneWidget);
    expect(find.textContaining('Red de pruebas'), findsOneWidget);
    expect(find.textContaining('Finca 1 · 4.19 ha · 500 kg'), findsOneWidget);
    expect(find.textContaining('Sin deforestación después de 2020'), findsOneWidget);
    expect(find.textContaining('La Leonesa'), findsNothing);
  });

  testWidgets('en inglés para el comprador, y recuerda el idioma elegido', (tester) async {
    await abrir(tester, servicio(), idioma: 'en');
    expect(find.text('Container CSQU3054383'), findsOneWidget);
    expect(find.text('Verified on the blockchain'), findsOneWidget);
    expect(find.textContaining('Coffee · 150 kg'), findsOneWidget);
    expect(find.textContaining('Farm 1 · 4.19 ha · 500 kg in this shipment'), findsOneWidget);
    expect(find.textContaining('No deforestation after 2020'), findsOneWidget);
    expect(find.textContaining('500 kg coffee cherry'), findsOneWidget);

    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(find.text('Contenedor CSQU3054383'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('idioma'), 'es');
  });

  testWidgets('cambia a tema oscuro desde el menú y lo recuerda', (tester) async {
    await abrir(tester, servicio());
    expect(Theme.of(tester.element(find.text('Contenedor CSQU3054383'))).brightness, Brightness.light);
    await tester.tap(find.byTooltip('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Contenedor CSQU3054383'))).brightness, Brightness.dark);
    expect((await SharedPreferences.getInstance()).getString('tema'), 'dark');
  });

  testWidgets('el QR de un lote muestra el lote verificado', (tester) async {
    await abrir(tester, servicio(uid: uidLote), uid: uidLote);
    expect(find.text('Lote CAFE-2026/27-001'), findsOneWidget);
    expect(find.text('Verificado en la blockchain'), findsOneWidget);
    expect(find.textContaining('Finca 1'), findsOneWidget);
  });

  testWidgets('si la blockchain no responde, igual muestra la cadena y lo avisa', (tester) async {
    await abrir(tester, servicio(rpcFalla: true));
    expect(find.text('Contenedor CSQU3054383'), findsOneWidget);
    expect(find.text('No se pudo consultar la blockchain ahora'), findsOneWidget);
  });

  testWidgets('un código que no existe lo explica en el idioma elegido', (tester) async {
    await abrir(tester, servicio(statusApi: 404, cuerpoApi: {'error': 'no_encontrado', 'mensaje': 'x'}), idioma: 'en');
    expect(find.textContaining('does not match any container or lot'), findsOneWidget);
  });

  testWidgets('sin UID pide escanear el QR', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [idiomaInicialProvider.overrideWithValue('es')],
        child: const MaterialApp(home: VerificadorScreen(uid: null)),
      ),
    );
    expect(find.textContaining('Escanea'), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trazacafe/screens/verificador_screen.dart';
import 'package:trazacafe/services/verificador_service.dart';

import 'datos_verificador.dart';

/// API y RPC falsos: la cadena pública y la attestation real del contenedor.
VerificadorService servicio({
  int statusApi = 200,
  Object? cuerpoApi,
  bool rpcFalla = false,
}) => VerificadorService(
  baseUrl: 'https://api.test',
  cliente: MockClient((req) async {
    if (req.url.host == 'api.test') {
      final cuerpo = cuerpoApi == null ? cadenaContenedor : jsonEncode(cuerpoApi);
      return http.Response.bytes(utf8.encode(cuerpo), statusApi);
    }
    if (rpcFalla) return http.Response('bad gateway', 502);
    final pedido = jsonDecode(req.body) as Map;
    expect((pedido['params'] as List).first['data'], '0xa3112a64${uidContenedor.substring(2)}');
    return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': ethCallContenedor}), 200);
  }),
);

CadenaPublica cadena() => CadenaPublica.desdeJson(jsonDecode(cadenaContenedor) as Map<String, dynamic>);

Future<void> abrir(WidgetTester tester, VerificadorService s) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(480, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: VerificadorScreen(uid: uidContenedor, servicio: s, mostrarMapa: false)),
  );
  await tester.pumpAndSettle();
}

void main() {
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
      final c = comprobar(cadena(), AttestationEnCadena.decodificar(ethCallContenedor));
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

  testWidgets('si la blockchain no responde, igual muestra la cadena y lo avisa', (tester) async {
    await abrir(tester, servicio(rpcFalla: true));
    expect(find.text('Contenedor CSQU3054383'), findsOneWidget);
    expect(find.text('No se pudo consultar la blockchain ahora'), findsOneWidget);
  });

  testWidgets('un código que no existe muestra el mensaje de la API', (tester) async {
    await abrir(
      tester,
      servicio(statusApi: 404, cuerpoApi: {'error': 'no_encontrado', 'mensaje': 'Este código no corresponde a ningún contenedor.'}),
    );
    expect(find.text('Este código no corresponde a ningún contenedor.'), findsOneWidget);
  });

  testWidgets('sin UID pide escanear el QR', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VerificadorScreen(uid: null)));
    expect(find.textContaining('Escanea'), findsOneWidget);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/observaciones_screen.dart';
import 'package:trazacafe/services/auth_service.dart';
import 'package:trazacafe/services/mensajeria.dart';
import 'package:trazacafe/widgets/avisos_push.dart';

import 'fakes.dart';

const admin = Sesion(uid: 'u-admin', email: 'admin@x.org', organizacionId: 'org-1', rol: 'admin');
const tecnico = Sesion(uid: 'u-tec', email: 'tec@x.org', organizacionId: 'org-1', rol: 'tecnico');

class MensajeriaFalsa implements Mensajeria {
  bool permiso = true;
  int registros = 0;
  final _tokens = StreamController<String>.broadcast();
  final _primerPlano = StreamController<AvisoPush>.broadcast();
  final _abiertos = StreamController<AvisoPush>.broadcast();
  AvisoPush? alAbrirLaApp;

  @override
  Future<bool> pedirPermiso() async => permiso;
  @override
  Future<void> registrarse() async {
    registros++;
    _tokens.add('fcm-token-1');
  }

  @override
  Stream<String> get tokens => _tokens.stream;
  @override
  Stream<AvisoPush> get enPrimerPlano => _primerPlano.stream;
  @override
  Stream<AvisoPush> get abiertos => _abiertos.stream;
  @override
  Future<AvisoPush?> inicial() async => alAbrirLaApp;

  void llega(AvisoPush a) => _primerPlano.add(a);
  void toca(AvisoPush a) => _abiertos.add(a);
}

void main() {
  Future<(ApiFalsa, MensajeriaFalsa)> abrir(WidgetTester tester, {Sesion sesion = admin, MensajeriaFalsa? m}) async {
    final auth = AuthFalso(inicial: sesion);
    final api = ApiFalsa({
      'POST /v1/dispositivos': (204, null),
      'GET /v1/observaciones': (200, {'observaciones': []}),
      'GET /v1/red/avisos': (200, {'invitaciones': [], 'lotesPorRecibir': 0, 'observacionesSinResponder': 0}),
    });
    final mensajeria = m ?? MensajeriaFalsa();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
        mensajeriaProvider.overrideWithValue(mensajeria),
      ],
      child: MaterialApp(home: Consumer(
        builder: (_, ref, _) => ref.watch(sesionProvider).hasValue
            ? const AvisosPush(child: Scaffold(body: Text('Inicio')))
            : const SizedBox(),
      )),
    ));
    await tester.pumpAndSettle();
    return (api, mensajeria);
  }

  testWidgets('un administrador registra el token del celular', (tester) async {
    final (api, m) = await abrir(tester);
    expect(m.registros, 1);
    final post = api.peticiones.singleWhere((p) => p.url.path == '/v1/dispositivos');
    expect(jsonDecode(post.body), {'token': 'fcm-token-1', 'plataforma': 'android'});
  });

  testWidgets('un técnico no se registra', (tester) async {
    final (api, m) = await abrir(tester, sesion: tecnico);
    expect(m.registros, 0);
    expect(api.peticiones.where((p) => p.url.path == '/v1/dispositivos'), isEmpty);
  });

  testWidgets('sin permiso no se registra', (tester) async {
    final (api, m) = await abrir(tester, m: MensajeriaFalsa()..permiso = false);
    expect(m.registros, 0);
    expect(api.peticiones, isEmpty);
  });

  testWidgets('un aviso con la app abierta se muestra y Ver abre su pantalla', (tester) async {
    final (_, m) = await abrir(tester);
    m.llega((titulo: 'Observación de Exportadora Norte', cuerpo: 'Revisar el lindero', pantalla: 'observaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Observación de Exportadora Norte: Revisar el lindero'), findsOneWidget);
    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.byType(ObservacionesScreen), findsOneWidget);
  });

  testWidgets('tocar el aviso en segundo plano abre su pantalla', (tester) async {
    final (_, m) = await abrir(tester);
    m.toca((titulo: null, cuerpo: null, pantalla: 'observaciones'));
    await tester.pumpAndSettle();
    expect(find.byType(ObservacionesScreen), findsOneWidget);
  });

  testWidgets('el aviso que abrió la app desde cerrada lleva a su pantalla', (tester) async {
    await abrir(tester, m: MensajeriaFalsa()..alAbrirLaApp = (titulo: null, cuerpo: null, pantalla: 'observaciones'));
    expect(find.byType(ObservacionesScreen), findsOneWidget);
  });

  test('pantallas que abre un aviso', () {
    expect(pantallaDeAviso('observaciones'), isA<ObservacionesScreen>());
    expect(pantallaDeAviso('otra'), isNull);
    expect(pantallaDeAviso(null), isNull);
  });
}

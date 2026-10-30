import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trazacafe/providers.dart';
import 'package:trazacafe/screens/clientes_screen.dart';
import 'package:trazacafe/screens/lotes_screen.dart';
import 'package:trazacafe/screens/nuevo_contenedor_screen.dart';
import 'package:trazacafe/screens/observaciones_screen.dart';
import 'package:trazacafe/screens/proveedores_screen.dart';
import 'package:trazacafe/screens/revision_proveedor_screen.dart';
import 'package:trazacafe/services/api_client.dart';
import 'package:trazacafe/services/auth_service.dart';

import 'fakes.dart';

const admin = Sesion(uid: 'u-admin', email: 'admin@x.org', organizacionId: 'org-1', rol: 'admin');

String hoy() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> vinculo({String id = 'v1', String soy = 'cliente', String estado = 'activo', String nombre = 'Coop Sur', bool nombres = false}) => {
  'id': id,
  'soy': soy,
  'organizacion': {'id': 'o-$id', 'nombre': nombre},
  'estado': estado,
  'comparteNombres': nombres,
  'invitadoEn': '2026-10-28T15:00:00.000Z',
  'respondidoEn': null,
  'terminadoEn': null,
  'lotesEnviados': 1,
  'lotesRecibidos': 2,
};

Map<String, dynamic> lote(String id, {String? proveedor, Map<String, dynamic>? venta, String? productor = 'Ana'}) => {
  'id': id,
  'codigo': 'CAFE-$id',
  'cultivo': 'cafe',
  'temporadaId': 't1',
  'temporadaNombre': '2026/27',
  'estado': 'pergamino',
  'kg': 1000,
  'kgEsperados': 1000,
  'beneficio': 'Beneficio',
  'proceso': null,
  'avisos': [],
  'attestationUid': null,
  'exportacionCodigo': null,
  'proveedor': proveedor,
  'venta': venta,
  'creadoEn': '2026-10-16T20:00:00.000Z',
  'entregas': [
    {'id': 'e1', 'fincaId': 'f1', 'fincaNombre': productor == null ? 'Finca 3F2A' : 'La Leonesa', 'productorNombre': productor, 'kg': 500, 'estado': 'uva', 'fecha': '2026-10-16T17:00:00.000Z'},
  ],
};

Map<String, dynamic> venta({bool recibido = false, bool enContenedor = false}) => {
  'vinculoId': 'v1',
  'cliente': 'Exportadora Norte',
  'estado': recibido ? 'recibido' : 'enviado',
  'kgEnviados': 1000,
  'fechaEnvio': '2026-10-27',
  'kgRecibidos': recibido ? 980 : null,
  'fechaRecibido': recibido ? '2026-10-28' : null,
  'enContenedor': enContenedor,
};

void main() {
  Future<ApiFalsa> abrir(WidgetTester tester, Widget pantalla, Map<String, (int, Object?)> respuestas) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(480, 2400);
    addTearDown(tester.view.reset);
    final auth = AuthFalso(inicial: admin);
    final api = ApiFalsa(respuestas);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiProvider.overrideWithValue(api.cliente(auth)),
        tipoOrganizacionProvider.overrideWith((ref) => Stream.value('cooperativa')),
        sesionMapaProvider.overrideWith((ref) async => null),
        mapasDescargadosProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(home: pantalla),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('exportadora: recibe un lote con otros kg y ve el aviso de diferencia', (tester) async {
    final api = await abrir(tester, const ProveedoresScreen(), {
      'GET /v1/proveedores': (
        200,
        {
          'proveedores': [vinculo(), vinculo(id: 'v2', estado: 'pendiente', nombre: 'Coop Norte')],
          'porRecibir': [
            {
              'id': 'l1',
              'codigo': 'CAFE-001',
              'cultivo': 'cafe',
              'estado': 'pergamino',
              'temporadaNombre': '2026/27',
              'proveedor': 'Coop Sur',
              'kgEnviados': 1000,
              'fechaEnvio': '2026-10-27',
            },
          ],
        },
      ),
      'POST /v1/proveedores/lotes/l1/recibir': (
        200,
        {
          'aviso': {'codigo': 'diferencia', 'mensaje': 'Se recibieron 980 kg de 1,000 enviados (-20 kg, -2.0 %).'},
        },
      ),
    });
    expect(find.text('Lotes por recibir'), findsOneWidget);
    expect(find.text('CAFE-001 · 1,000 kg'), findsOneWidget);
    expect(find.textContaining('2 lotes recibidos, 1 por recibir · fincas sin nombres'), findsOneWidget);
    expect(find.textContaining('falta que la acepte'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Recibir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kg recibidos'), '980');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Recibir').last);
    await tester.pumpAndSettle();

    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    expect(jsonDecode(post.body), {'kgRecibidos': 980, 'fecha': hoy()});
    expect(find.textContaining('-20 kg'), findsOneWidget);
  });

  testWidgets('exportadora: invita a una cooperativa con el correo de su administrador', (tester) async {
    final api = await abrir(tester, const ProveedoresScreen(), {
      'GET /v1/proveedores': (200, {'proveedores': [], 'porRecibir': []}),
      'POST /v1/proveedores': (201, vinculo(estado: 'pendiente')),
    });
    expect(find.textContaining('Invita a las cooperativas que te venden'), findsOneWidget);
    await tester.tap(find.text('Invitar proveedor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Correo del administrador'), ' Admin@CoopSur.org ');
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pumpAndSettle();
    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    expect(jsonDecode(post.body), {'email': 'admin@coopsur.org'});
  });

  testWidgets('cooperativa: acepta la invitación compartiendo nombres', (tester) async {
    final api = await abrir(tester, const ClientesScreen(), {
      'GET /v1/clientes': (200, {'clientes': [vinculo(soy: 'proveedora', estado: 'pendiente', nombre: 'Exportadora Norte')]}),
      'POST /v1/clientes/v1/aceptar': (200, vinculo(soy: 'proveedora', nombre: 'Exportadora Norte', nombres: true)),
    });
    expect(find.text('Exportadora Norte te invitó como proveedora'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Aceptar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No ve el resto de tus fincas'), findsOneWidget);
    await tester.tap(find.text('Compartir nombres de productores y fincas'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Aceptar').last);
    await tester.pumpAndSettle();
    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    expect(jsonDecode(post.body), {'comparteNombres': true});
  });

  testWidgets('cooperativa: responde una observación de su cliente', (tester) async {
    final api = await abrir(tester, const ObservacionesScreen(), {
      'GET /v1/observaciones': (
        200,
        {
          'observaciones': [
            {
              'id': 'o1',
              'hecha': false,
              'cliente': 'Exportadora Norte',
              'proveedora': 'Coop Sur',
              'fincaId': 'f1',
              'fincaNombre': 'La Leonesa',
              'loteId': null,
              'loteCodigo': null,
              'texto': 'Revisar el lindero norte',
              'creadoEn': '2026-10-28T15:00:00.000Z',
              'respuesta': null,
              'respondidoEn': null,
            },
          ],
        },
      ),
      'POST /v1/observaciones/o1/respuesta': (204, null),
    });
    expect(find.text('La Leonesa · Exportadora Norte'), findsOneWidget);
    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Respuesta'), 'Ya se corrigió');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
    await tester.pumpAndSettle();
    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    expect(jsonDecode(post.body), {'texto': 'Ya se corrigió'});
  });

  testWidgets('cooperativa: vende un lote libre a su cliente', (tester) async {
    final api = await abrir(tester, const LotesScreen(), {
      'GET /v1/lotes': (200, {'lotes': [lote('l1')]}),
      'GET /v1/clientes': (200, {'clientes': [vinculo(soy: 'proveedora', nombre: 'Exportadora Norte')]}),
      'POST /v1/lotes/l1/venta': (200, lote('l1', venta: venta())),
    });
    await tester.tap(find.text('CAFE-l1 · 1,000 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vender'));
    await tester.pumpAndSettle();
    expect(find.text('Exportadora Norte'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Kg enviados'), '995');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Vender').last);
    await tester.pumpAndSettle();
    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    expect(jsonDecode(post.body), {'vinculoId': 'v1', 'kg': 995, 'fecha': hoy()});
    expect(find.textContaining('vendido a Exportadora Norte'), findsOneWidget);
  });

  testWidgets('cooperativa: un lote vendido no se corrige; la venta se deshace mientras no esté en un contenedor', (tester) async {
    await abrir(tester, const LotesScreen(), {
      'GET /v1/lotes': (200, {'lotes': [lote('l1', venta: venta()), lote('l2', venta: venta(recibido: true, enContenedor: true))]}),
    });
    await tester.tap(find.text('CAFE-l1 · 1,000 kg'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vendido a Exportadora Norte: enviado el 27/10/2026'), findsOneWidget);
    expect(find.text('Deshacer venta'), findsOneWidget);
    expect(find.text('Corregir'), findsNothing);
    expect(find.text('Vender'), findsNothing);

    await tester.tap(find.text('CAFE-l2 · 1,000 kg'));
    await tester.pumpAndSettle();
    expect(find.textContaining('recibido el 28/10/2026 · 980 kg (enviados 1,000)'), findsOneWidget);
    expect(find.text('Deshacer venta'), findsOneWidget, reason: 'solo el del primer lote');
  });

  testWidgets('exportadora: el lote comprado muestra su proveedor y la finca sin nombre del productor', (tester) async {
    await abrir(tester, const LotesScreen(), {
      'GET /v1/lotes': (200, {'lotes': [lote('l1', proveedor: 'Coop Sur', venta: venta(recibido: true), productor: null)]}),
    });
    await tester.tap(find.text('CAFE-l1 · 1,000 kg'));
    await tester.pumpAndSettle();
    expect(find.text('Comprado a Coop Sur'), findsOneWidget);
    expect(find.textContaining('Recibido el 28/10/2026 · 980 kg'), findsOneWidget);
    expect(find.textContaining('Finca 3F2A · 500 kg'), findsOneWidget);
    expect(find.text('Corregir'), findsNothing);
    expect(find.text('Deshacer venta'), findsNothing);
  });

  testWidgets('exportadora: el contenedor lleva lotes comprados con sus kg recibidos, no los vendidos', (tester) async {
    await abrir(tester, const NuevoContenedorScreen(), {
      'GET /v1/lotes': (
        200,
        {
          'lotes': [
            lote('l1'),
            lote('l2', proveedor: 'Coop Sur', venta: venta(recibido: true)),
            lote('l3', venta: venta()),
          ],
        },
      ),
      'GET /v1/exportaciones': (200, {'exportaciones': []}),
    });
    expect(find.text('Lotes libres (2)'), findsOneWidget);
    expect(find.text('CAFE-l2 · 980 kg'), findsOneWidget);
    expect(find.textContaining('de Coop Sur'), findsOneWidget);
    expect(find.textContaining('CAFE-l3'), findsNothing);
  });

  testWidgets('exportadora: revisa lo que le vendió un proveedor y deja una observación', (tester) async {
    final api = await abrir(
      tester,
      RevisionProveedorScreen(vinculo: Vinculo.desdeJson(vinculo())),
      {
        'GET /v1/proveedores/v1/revision': (
          200,
          {
            'vinculo': vinculo(),
            'lotes': [
              {
                'id': 'l1',
                'codigo': 'CAFE-001',
                'cultivo': 'cafe',
                'temporadaNombre': '2026/27',
                'estado': 'pergamino',
                'kgEnviados': 1000,
                'kgRecibidos': 980,
                'venta': 'recibido',
                'avisos': [
                  {'codigo': 'diferencia', 'mensaje': 'Se recibieron 980 kg de 1,000 enviados (-20 kg, -2.0 %).'},
                ],
                'attestationUid': null,
              },
            ],
            'fincas': [
              {
                'id': 'f1',
                'nombre': 'Finca 3F2A',
                'productorNombre': null,
                'comunidad': 'San Rafael',
                'cultivo': 'cafe',
                'geometria': {'type': 'Point', 'coordinates': [-86.1, 13.1]},
                'areaOficialHa': 1.5,
                'deforestacion': 'verde',
                'ultimoChequeo': null,
                'conVisita': false,
                'ultimaVisita': null,
                'attestationUid': null,
                'lotes': ['CAFE-001'],
              },
            ],
            'resumen': {'fincas': 1, 'verdes': 1, 'conVisita': 0, 'areaOficialHa': 1.5},
          },
        ),
        'POST /v1/observaciones': (201, {}),
      },
    );
    expect(find.text('En verde por satélite: 1 de 1'), findsOneWidget);
    expect(find.text('Con visita en la temporada: 0 de 1'), findsOneWidget);
    expect(find.textContaining('-20 kg'), findsOneWidget);
    expect(find.text('Sin visita de verificación en la temporada'), findsOneWidget);
    expect(find.textContaining('no comparte los nombres'), findsOneWidget);

    await tester.tap(find.byTooltip('Observación').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Observación'), 'Falta la visita de esta temporada');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
    await tester.pumpAndSettle();
    final post = api.peticiones.firstWhere((p) => p.method == 'POST');
    expect(jsonDecode(post.body), {'fincaId': 'f1', 'texto': 'Falta la visita de esta temporada'});
  });
}

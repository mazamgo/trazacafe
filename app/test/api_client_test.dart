import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trazacafe/services/api_client.dart';

/// Cliente que corta la conexión las primeras [cortes] veces (como
/// "Connection closed before full header was received") y luego responde.
({ApiClient api, List<String> llamadas}) cliente({int cortes = 1, Object? cuerpo}) {
  final llamadas = <String>[];
  final api = ApiClient(
    token: () async => 'token',
    baseUrl: 'https://api.test',
    cliente: MockClient((req) async {
      llamadas.add('${req.method} ${req.url.path}');
      if (llamadas.length <= cortes) {
        throw http.ClientException('Connection closed before full header was received', req.url);
      }
      return http.Response(jsonEncode(cuerpo ?? {'resultado': 'verde'}), 200, headers: {'content-type': 'application/json'});
    }),
  );
  return (api: api, llamadas: llamadas);
}

void main() {
  test('revisar por satélite se repite una vez si se corta la conexión', () async {
    final c = cliente();
    expect((await c.api.chequearFinca('f1'))['resultado'], 'verde');
    expect(c.llamadas, ['POST /v1/fincas/f1/chequeo', 'POST /v1/fincas/f1/chequeo']);
  });

  test('las lecturas y la sincronización también se repiten', () async {
    final datos = cliente(cuerpo: {'productores': []});
    await datos.api.datos();
    expect(datos.llamadas, hasLength(2));
    final sync = cliente(cuerpo: {'recibidos': {}});
    await sync.api.sync({'productores': []});
    expect(sync.llamadas, hasLength(2));
  });

  test('crear un lote no se repite: avisa que la acción pudo haberse hecho', () async {
    final c = cliente();
    await expectLater(
      c.api.crearLote(codigo: 'L1', cultivo: 'cafe', temporadaId: 't', estado: 'pergamino', kg: 10, entregas: ['e1']),
      throwsA(isA<ApiError>().having((e) => e.mensaje, 'mensaje', contains('pudo haberse hecho'))),
    );
    expect(c.llamadas, hasLength(1));
  });

  test('si se corta dos veces, da un mensaje claro en vez del error técnico', () async {
    final c = cliente(cortes: 2);
    await expectLater(
      c.api.chequearFinca('f1'),
      throwsA(isA<ApiError>().having((e) => e.mensaje, 'mensaje', startsWith('Se cortó la conexión'))),
    );
    expect(c.llamadas, hasLength(2));
  });
}

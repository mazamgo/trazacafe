import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trazacafe/services/api_client.dart';
import 'package:trazacafe/services/auth_service.dart';

/// Sesión controlable desde las pruebas.
class AuthFalso implements AuthService {
  AuthFalso({Sesion? inicial}) : _actual = inicial;

  final _sesiones = StreamController<Sesion?>.broadcast();
  Sesion? _actual;
  Exception? errorAlEntrar;
  Sesion? alEntrar;
  int cierres = 0;
  int refrescos = 0;

  @override
  Stream<Sesion?> observarSesion() async* {
    yield _actual;
    yield* _sesiones.stream;
  }

  void emitir(Sesion? s) {
    _actual = s;
    _sesiones.add(s);
  }

  @override
  Future<void> entrarConGoogle() async {
    if (errorAlEntrar != null) throw errorAlEntrar!;
    emitir(alEntrar);
  }

  @override
  Future<void> cerrarSesion() async {
    cierres++;
    emitir(null);
  }

  @override
  Future<String?> token({bool refrescar = false}) async {
    if (refrescar) refrescos++;
    return _actual == null ? null : 'token';
  }
}

/// API falsa: responde según "MÉTODO /ruta" y guarda las peticiones.
class ApiFalsa {
  ApiFalsa(this.respuestas);

  final Map<String, (int, Object?)> respuestas;
  final peticiones = <http.Request>[];

  ApiClient cliente(AuthService auth) => ApiClient(
        token: auth.token,
        baseUrl: 'https://api.test',
        cliente: MockClient((req) async {
          peticiones.add(req);
          final (status, cuerpo) =
              respuestas['${req.method} ${Uri.decodeComponent(req.url.path)}'] ?? (404, null);
          return http.Response(cuerpo == null ? '' : jsonEncode(cuerpo), status,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );
}

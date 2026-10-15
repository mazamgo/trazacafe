import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL de la API. En el emulador de Android, 10.0.2.2 es el localhost de la
/// computadora. Para Cloud Run: `flutter run --dart-define=API_URL=https://...`
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

class Invitacion {
  Invitacion({required this.email, required this.rol, required this.activa});

  factory Invitacion.desdeJson(Map<String, dynamic> j) => Invitacion(
        email: j['email'] as String,
        rol: j['rol'] as String,
        activa: j['usuarioUid'] != null,
      );

  final String email;

  /// `admin` o `tecnico`.
  final String rol;

  /// `true` cuando la persona ya entró con Google y activó su acceso.
  final bool activa;
}

class ApiClient {
  ApiClient({required this.token, http.Client? cliente, String baseUrl = apiUrl})
      : _cliente = cliente ?? http.Client(),
        _base = Uri.parse(baseUrl);

  final Future<String?> Function() token;
  final http.Client _cliente;
  final Uri _base;

  /// Envía un lote de registros a `POST /v1/sync`.
  Future<Map<String, dynamic>> sync(Map<String, dynamic> payload) =>
      _pedir('POST', '/v1/sync', payload);

  /// Activa la invitación del correo con el que se inició sesión. Lleva `{}`
  /// porque el frontal de Cloud Run rechaza POST sin cuerpo (411).
  Future<void> activar() => _pedir('POST', '/v1/activar', const <String, dynamic>{});

  Future<List<Invitacion>> invitaciones() async {
    final r = await _pedir('GET', '/v1/invitaciones');
    return [
      for (final i in r['invitaciones'] as List) Invitacion.desdeJson(i as Map<String, dynamic>),
    ];
  }

  Future<void> invitar(String email, String rol) =>
      _pedir('POST', '/v1/invitaciones', {'email': email, 'rol': rol});

  Future<void> quitarAcceso(String email) =>
      _pedir('DELETE', '/v1/invitaciones/${Uri.encodeComponent(email)}');

  Future<Map<String, dynamic>> _pedir(String metodo, String ruta, [Object? cuerpo]) async {
    final t = await token();
    if (t == null) throw ApiError(401, 'Inicia sesión para continuar.');

    final req = http.Request(metodo, _base.resolve(ruta))..headers['Authorization'] = 'Bearer $t';
    if (cuerpo != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(cuerpo);
    }
    final res = await http.Response.fromStream(await _cliente.send(req));
    final json = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 300) throw ApiError(res.statusCode, _mensaje(res.statusCode, json));
    return json;
  }

  static String _mensaje(int status, Map<String, dynamic> cuerpo) {
    final propio = cuerpo['mensaje'] as String?;
    final detalles = (cuerpo['detalles'] as List?)
        ?.map((d) => (d as Map)['message'])
        .whereType<String>()
        .toSet()
        .join('; ');
    return switch (status) {
      401 => 'La sesión venció. Vuelve a iniciar sesión.',
      403 || 409 => propio ?? cuerpo['error'] as String? ?? 'Sin permiso.',
      404 => 'No encontrado.',
      422 => propio ?? 'Datos rechazados: ${detalles ?? cuerpo['error']}',
      _ => 'Error del servidor ($status).',
    };
  }
}

class ApiError implements Exception {
  ApiError(this.status, this.mensaje);
  final int status;
  final String mensaje;

  @override
  String toString() => mensaje;
}

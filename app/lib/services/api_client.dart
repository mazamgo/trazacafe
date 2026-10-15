import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL de la API. En el emulador de Android, 10.0.2.2 es el localhost de la
/// computadora. Para Cloud Run: `flutter run --dart-define=API_URL=https://...`
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

class ApiClient {
  ApiClient({required this.token, http.Client? cliente, String baseUrl = apiUrl})
      : _cliente = cliente ?? http.Client(),
        _base = Uri.parse(baseUrl);

  final Future<String?> Function() token;
  final http.Client _cliente;
  final Uri _base;

  /// Envía un lote de registros a `POST /v1/sync`.
  Future<Map<String, dynamic>> sync(Map<String, dynamic> payload) async {
    final t = await token();
    if (t == null) throw ApiError(401, 'Inicia sesión para sincronizar.');

    final res = await _cliente.post(
      _base.resolve('/v1/sync'),
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final cuerpo = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw ApiError(res.statusCode, _mensaje(res.statusCode, cuerpo));
    }
    return cuerpo;
  }

  static String _mensaje(int status, Map<String, dynamic> cuerpo) {
    final detalles = (cuerpo['detalles'] as List?)
        ?.map((d) => (d as Map)['message'])
        .whereType<String>()
        .toSet()
        .join('; ');
    return switch (status) {
      401 => 'La sesión venció. Vuelve a iniciar sesión.',
      403 => cuerpo['error'] as String? ?? 'Sin permiso para esta cooperativa.',
      422 => 'Datos rechazados: ${detalles ?? cuerpo['error']}',
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

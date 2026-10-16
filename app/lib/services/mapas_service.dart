import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../mapas_config.dart';

/// Sesión de Google Map Tiles: satélite con calles encima. Una sesión dura
/// unas dos semanas; se guarda en el celular para no pedir una nueva cada
/// vez (y para que los mosaicos ya vistos, cacheados por su URL, sirvan sin
/// señal mientras la sesión siga vigente).
class SesionMapa {
  SesionMapa(this.token, this.vence);
  final String token;
  final DateTime vence;

  String get urlMosaicos =>
      'https://tile.googleapis.com/v1/2dtiles/{z}/{x}/{y}?session=$token&key=$googleMapsKey';
}

class MapasService {
  MapasService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  static const _kToken = 'mapa.sesion';
  static const _kVence = 'mapa.vence';

  /// Encabezados que exige la key restringida a la app Android.
  static const encabezados = {
    'X-Android-Package': androidPackage,
    'X-Android-Cert': androidCertSha1,
  };

  /// Sesión guardada si le queda más de un día; si no, pide una nueva. Sin
  /// señal devuelve la guardada aunque esté por vencer, o `null`.
  Future<SesionMapa?> sesion() async {
    final prefs = await SharedPreferences.getInstance();
    final guardada = _leer(prefs);
    if (guardada != null && guardada.vence.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      return guardada;
    }
    try {
      final res = await _cliente.post(
        Uri.parse('https://tile.googleapis.com/v1/createSession?key=$googleMapsKey'),
        headers: {...encabezados, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'mapType': 'satellite',
          'language': 'es-419',
          'region': 'NI',
          'layerTypes': ['layerRoadmap'],
        }),
      );
      if (res.statusCode != 200) return guardada;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final nueva = SesionMapa(
        j['session'] as String,
        DateTime.fromMillisecondsSinceEpoch(int.parse('${j['expiry']}') * 1000),
      );
      await prefs.setString(_kToken, nueva.token);
      await prefs.setInt(_kVence, nueva.vence.millisecondsSinceEpoch);
      return nueva;
    } catch (_) {
      return guardada;
    }
  }

  /// Texto de atribución de las imágenes visibles (lo exige Google).
  Future<String?> atribucion(SesionMapa s, {required int zoom, required double norte,
      required double sur, required double este, required double oeste}) async {
    try {
      final res = await _cliente.get(
        Uri.parse('https://tile.googleapis.com/tile/v1/viewport').replace(queryParameters: {
          'session': s.token,
          'key': googleMapsKey,
          'zoom': '$zoom',
          'north': '$norte',
          'south': '$sur',
          'east': '$este',
          'west': '$oeste',
        }),
        headers: encabezados,
      );
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['copyright'] as String?;
    } catch (_) {
      return null;
    }
  }

  static SesionMapa? _leer(SharedPreferences prefs) {
    final token = prefs.getString(_kToken);
    final vence = prefs.getInt(_kVence);
    if (token == null || vence == null) return null;
    return SesionMapa(token, DateTime.fromMillisecondsSinceEpoch(vence));
  }
}

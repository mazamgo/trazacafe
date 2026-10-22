import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../domain/busqueda_lugar.dart';
import '../domain/geo.dart';

/// Finca ya registrada, para buscarla y dibujarla de referencia en el mapa.
class FincaReferencia {
  FincaReferencia(this.finca, this.productor)
    : puntos = desdeGeoJsonCoords(finca.coordenadasJson);

  final Finca finca;
  final Productor productor;
  final List<LatLng> puntos;

  LatLng get centro => LatLng(
    puntos.map((p) => p.latitude).reduce((a, b) => a + b) / puntos.length,
    puntos.map((p) => p.longitude).reduce((a, b) => a + b) / puntos.length,
  );
}

/// Última vista del mapa de "Nueva finca": el próximo registro abre ahí.
typedef VistaMapa = ({LatLng centro, double zoom});

/// Lugares de Nicaragua (incluidos en la app, sirven sin señal) y lo que
/// ayuda a ubicar una finca en el mapa.
class LugaresService {
  LugaresService({AssetBundle? bundle, http.Client? cliente})
    : _bundle = bundle ?? rootBundle,
      _cliente = cliente ?? http.Client();

  final AssetBundle _bundle;
  final http.Client _cliente;
  Future<List<Lugar>>? _lugares;

  static const asset = 'assets/lugares_ni.json';
  static const _kVista = 'mapa.ultimaVista';

  /// Se lee una sola vez, fuera del hilo de la pantalla.
  Future<List<Lugar>> lugares() => _lugares ??= _bundle
      .loadString(asset)
      .then((json) => compute(parsearLugares, json));

  Future<VistaMapa?> ultimaVista() async {
    final partes = (await SharedPreferences.getInstance())
        .getString(_kVista)
        ?.split(',')
        .map(double.tryParse)
        .toList();
    if (partes == null || partes.length != 3 || partes.contains(null)) {
      return null;
    }
    return (centro: LatLng(partes[0]!, partes[1]!), zoom: partes[2]!);
  }

  Future<void> guardarVista(LatLng centro, double zoom) async =>
      (await SharedPreferences.getInstance()).setString(
        _kVista,
        '${centro.latitude},${centro.longitude},$zoom',
      );

  /// Abre un enlace corto de Google Maps (necesita señal) y saca las
  /// coordenadas de la dirección a la que lleva. `null` si no se pudo.
  Future<LatLng?> resolverEnlace(String texto) async {
    var url = Uri.tryParse(texto.trim().split(RegExp(r'\s')).first);
    try {
      for (var i = 0; url != null && i < 4; i++) {
        final res = await _cliente
            .send(http.Request('GET', url)..followRedirects = false)
            .timeout(const Duration(seconds: 8));
        final destino = res.headers['location'];
        if (destino == null) return null;
        final punto = parsearCoordenadas(destino);
        if (punto != null) return punto;
        url = url.resolve(destino);
      }
    } on Exception {
      return null;
    }
    return null;
  }
}

/// Fincas cuyo nombre, productor o comunidad contienen lo buscado.
List<FincaReferencia> buscarFincas(
  List<FincaReferencia> fincas,
  String texto, {
  int max = 10,
}) {
  final q = normalizar(texto);
  if (q.length < 2) return const [];
  final palabras = q.split(' ');
  return fincas
      .where((f) {
        final clave = normalizar(
          '${f.finca.nombre} ${f.productor.nombre} ${f.productor.comunidad ?? ''}',
        );
        return palabras.every(clave.contains);
      })
      .take(max)
      .toList();
}

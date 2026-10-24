import 'dart:convert';
import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'verificador_service.dart' show verificadorUrl;

/// Mapa satelital de una zona para usar sin señal: imágenes Sentinel-2 de
/// Copernicus (10 m por píxel), en un archivo MBTiles que se descarga con
/// Wi-Fi. Google no permite guardar su mapa para usarlo sin conexión; este
/// sí (ver `backend/scripts/mapa-sentinel.ts`, que lo genera).
class PaqueteMapa {
  const PaqueteMapa({
    required this.id,
    required this.nombre,
    required this.archivo,
    required this.bytes,
    required this.limites,
    required this.maxZoom,
    required this.atribucion,
    required this.imagenes,
  });

  factory PaqueteMapa.desdeJson(Map<String, dynamic> j) {
    final b = (j['bounds'] as List).map((n) => (n as num).toDouble()).toList();
    return PaqueteMapa(
      id: j['id'] as String,
      nombre: j['nombre'] as String,
      archivo: j['archivo'] as String,
      bytes: (j['bytes'] as num).toInt(),
      limites: LatLngBounds(LatLng(b[1], b[0]), LatLng(b[3], b[2])),
      maxZoom: (j['maxzoom'] as num).toInt(),
      atribucion: j['atribucion'] as String,
      imagenes: j['imagenes'] as String? ?? '',
    );
  }

  final String id;
  final String nombre;
  final String archivo;
  final int bytes;
  final LatLngBounds limites;
  final int maxZoom;
  final String atribucion;

  /// Fechas de las imágenes (época seca), p. ej. "2025-12-01 a 2026-05-15".
  final String imagenes;

  Map<String, dynamic> aJson() => {
    'id': id,
    'nombre': nombre,
    'archivo': archivo,
    'bytes': bytes,
    'bounds': [
      limites.west,
      limites.south,
      limites.east,
      limites.north,
    ],
    'maxzoom': maxZoom,
    'atribucion': atribucion,
    'imagenes': imagenes,
  };

  String get tamano => '${(bytes / 1e6).toStringAsFixed(0)} MB';
}

/// Un paquete ya descargado en el celular.
class MapaDescargado {
  MapaDescargado(this.paquete, this.ruta);
  final PaqueteMapa paquete;
  final String ruta;
}

class MapasSinSenal {
  MapasSinSenal({http.Client? cliente, Future<Directory> Function()? carpeta})
    : _cliente = cliente ?? http.Client(),
      _carpeta = carpeta ?? _carpetaPorDefecto;

  final http.Client _cliente;
  final Future<Directory> Function() _carpeta;

  static const indice = '$verificadorUrl/mapas/indice.json';

  static Future<Directory> _carpetaPorDefecto() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/mapas');

  /// Zonas que se pueden descargar (necesita señal).
  Future<List<PaqueteMapa>> disponibles() async {
    final res = await _cliente
        .get(Uri.parse(indice))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('No se pudo leer la lista de mapas (${res.statusCode}).');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final p in (j['paquetes'] as List).cast<Map<String, dynamic>>())
        PaqueteMapa.desdeJson(p),
    ];
  }

  /// Los que ya están en el celular (sirven sin señal).
  Future<List<MapaDescargado>> descargados() async {
    final dir = await _carpeta();
    if (!await dir.exists()) return const [];
    final lista = <MapaDescargado>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final ruta = f.path.replaceAll(RegExp(r'\.json$'), '.mbtiles');
      if (!await File(ruta).exists()) continue;
      final p = PaqueteMapa.desdeJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
      lista.add(MapaDescargado(p, ruta));
    }
    lista.sort((a, b) => a.paquete.nombre.compareTo(b.paquete.nombre));
    return lista;
  }

  /// Descarga el paquete; [avance] recibe de 0 a 1. Se escribe en un archivo
  /// temporal y se renombra al terminar: una descarga cortada no deja un mapa
  /// a medias.
  Future<MapaDescargado> descargar(
    PaqueteMapa p, {
    void Function(double)? avance,
  }) async {
    final dir = await _carpeta();
    await dir.create(recursive: true);
    final ruta = '${dir.path}/${p.id}.mbtiles';
    final parcial = File('$ruta.parcial');
    final res = await _cliente.send(
      http.Request(
        'GET',
        Uri.parse('$verificadorUrl/mapas/${p.archivo}'),
      ),
    );
    if (res.statusCode != 200) {
      throw HttpException('No se pudo descargar el mapa (${res.statusCode}).');
    }
    final total = res.contentLength ?? p.bytes;
    var recibidos = 0;
    final salida = parcial.openWrite();
    try {
      await for (final trozo in res.stream) {
        salida.add(trozo);
        recibidos += trozo.length;
        if (total > 0) avance?.call((recibidos / total).clamp(0, 1));
      }
      await salida.close();
    } catch (_) {
      await salida.close();
      if (await parcial.exists()) await parcial.delete();
      rethrow;
    }
    await parcial.rename(ruta);
    await File('${dir.path}/${p.id}.json').writeAsString(jsonEncode(p.aJson()));
    return MapaDescargado(p, ruta);
  }

  Future<void> borrar(String id) async {
    final dir = await _carpeta();
    for (final ext in ['mbtiles', 'json', 'mbtiles.parcial']) {
      final f = File('${dir.path}/$id.$ext');
      if (await f.exists()) await f.delete();
    }
  }
}

import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sqlite3/sqlite3.dart';

/// Mosaicos leídos de un MBTiles en el celular (filas TMS, de sur a norte).
class MbTilesTileProvider extends TileProvider {
  MbTilesTileProvider(String ruta)
    : _db = sqlite3.open(ruta, mode: OpenMode.readOnly);

  final Database _db;
  late final _consulta = _db.prepare(
    'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
  );

  /// Bytes del mosaico, o `null` si el paquete no lo tiene.
  Uint8List? leer(int z, int x, int y) {
    final filas = _consulta.select([z, x, (1 << z) - 1 - y]);
    return filas.isEmpty ? null : filas.first['tile_data'] as Uint8List;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final bytes = leer(coordinates.z, coordinates.x, coordinates.y);
    return MemoryImage(bytes ?? TileProvider.transparentImage);
  }

  /// `TileLayer` lo llama al quitar la capa del mapa.
  @override
  void dispose() {
    _consulta.close();
    _db.close();
    super.dispose();
  }
}

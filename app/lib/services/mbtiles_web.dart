import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// En la web (verificador y páginas públicas) no hay mapas sin señal: la
/// lectura de MBTiles usa sqlite3 nativo (`mbtiles_nativo.dart`).
class MbTilesTileProvider extends TileProvider {
  MbTilesTileProvider(String ruta);

  Uint8List? leer(int z, int x, int y) => null;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

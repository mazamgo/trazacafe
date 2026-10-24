// Lector de mapas sin señal (MBTiles): sqlite3 nativo en Android; en la web
// no existe dart:ffi y la capa no se usa.
export 'mbtiles_nativo.dart' if (dart.library.js_interop) 'mbtiles_web.dart';

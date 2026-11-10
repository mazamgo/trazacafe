// Descarga de archivos en el navegador (panel web). En Android no se usa: los
// archivos se comparten con el menú del sistema (`CompartidorSistema`).
export 'descarga_nativa.dart' if (dart.library.js_interop) 'descarga_web.dart';

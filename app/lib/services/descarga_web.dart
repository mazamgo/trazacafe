import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Guarda [bytes] como el archivo [nombre] en la carpeta de descargas del
/// navegador: un `Blob` y un enlace `<a download>` que se pulsa solo.
void descargarArchivo(String nombre, List<int> bytes, String tipo) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: tipo),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';
  web.document.body!.append(enlace);
  enlace.click();
  enlace.remove();
  // Algunos navegadores leen el enlace después del clic: se libera más tarde.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

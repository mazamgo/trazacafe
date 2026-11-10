// Configuración de Google Map Tiles (satélite con calles).
//
// La key solo funciona desde la app Android com.goproduction.trazacafe
// firmada con el certificado indicado (restricción en Google Cloud), y solo
// para tile.googleapis.com. Por eso puede estar en el repositorio. Para la
// versión de Play Store se compila con el SHA-1 de Play App Signing:
//   flutter build apk --dart-define=ANDROID_CERT_SHA1=<SHA1 sin dos puntos>
//
// El panel web usa otra key, restringida a los sitios del panel (referer):
//   flutter build web --dart-define=GOOGLE_MAPS_WEB_KEY=<key>

import 'package:flutter/foundation.dart' show kIsWeb;

const googleMapsKey = String.fromEnvironment(
  'GOOGLE_MAPS_KEY',
  defaultValue: 'AIzaSyBTwXv8OaXV-GFvtAyHKCrjn3r268mNndE',
);

const androidPackage = 'com.goproduction.trazacafe';

/// SHA-1 del certificado que firma el APK (por defecto, el de depuración).
const androidCertSha1 = String.fromEnvironment(
  'ANDROID_CERT_SHA1',
  defaultValue: 'A5F0249A42CB1D027841058E797690ACCC82CF83',
);

/// Key de Map Tiles del panel web. Vacía = las fincas se ven sin el satélite.
const googleMapsWebKey = String.fromEnvironment('GOOGLE_MAPS_WEB_KEY');

/// La key de esta plataforma.
const claveMapas = kIsWeb ? googleMapsWebKey : googleMapsKey;

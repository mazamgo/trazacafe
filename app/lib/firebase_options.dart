// Configuración del proyecto Firebase `trazacafe-dev`.
// Estas claves identifican la app ante Firebase; no son secretas. La
// seguridad la dan las reglas de Firebase y la validación del token en el
// backend.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Cliente OAuth "Web" que Firebase crea al activar el proveedor Google.
/// En Android, Google Sign-In lo necesita para emitir el idToken que
/// Firebase Auth acepta.
const googleWebClientId =
    '85528878949-ui35bc8b4tvpgab6jhfom8nc99oc4p7d.apps.googleusercontent.com';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('TrazaCafé solo está configurado para Android y Web.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBo-G_vEiQyk8EbIPWneh8Xesq7n73743o',
    appId: '1:85528878949:android:15e87427c4ad8ad5b68b8c',
    messagingSenderId: '85528878949',
    projectId: 'trazacafe-dev',
    storageBucket: 'trazacafe-dev.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_43VWuFyOudjRFw-NnK2P0FVKXKOLZFU',
    appId: '1:85528878949:web:bcd6462fb1ffe5b5b68b8c',
    messagingSenderId: '85528878949',
    projectId: 'trazacafe-dev',
    authDomain: 'trazacafe-dev.firebaseapp.com',
    storageBucket: 'trazacafe-dev.firebasestorage.app',
  );
}

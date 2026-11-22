import 'package:firebase_messaging/firebase_messaging.dart';

/// Aviso push recibido: título, texto y la pantalla que abre al tocarlo.
typedef AvisoPush = ({String? titulo, String? cuerpo, String? pantalla});

/// Pantallas que puede abrir un aviso (las manda la API en `data.pantalla`).
const pantallasDeAviso = {
  'clientes',
  'proveedores',
  'observaciones',
  'lotes',
  'reportes',
};

/// Notificaciones push (FCM) del celular. En pruebas se usa una falsa.
abstract class Mensajeria {
  /// Pide el permiso de mostrar avisos (Android 13 o más); `true` si se dio.
  Future<bool> pedirPermiso();

  /// Pide el token a FCM; llega (y cada vez que se renueva) por [tokens].
  Future<void> registrarse();
  Stream<String> get tokens;

  /// Avisos que llegan con la app abierta (Android no los muestra solo).
  Stream<AvisoPush> get enPrimerPlano;

  /// Avisos tocados con la app en segundo plano.
  Stream<AvisoPush> get abiertos;

  /// El aviso que abrió la app desde cerrada, si lo hubo.
  Future<AvisoPush?> inicial();
}

AvisoPush _aviso(RemoteMessage m) => (
  titulo: m.notification?.title,
  cuerpo: m.notification?.body,
  pantalla: pantallasDeAviso.contains(m.data['pantalla'])
      ? m.data['pantalla'] as String
      : null,
);

class MensajeriaFirebase implements Mensajeria {
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<bool> pedirPermiso() async {
    final s = await _fcm.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> registrarse() => _fcm.register();

  @override
  Stream<String> get tokens => _fcm.onRegistered;

  @override
  Stream<AvisoPush> get enPrimerPlano =>
      FirebaseMessaging.onMessage.map(_aviso);

  @override
  Stream<AvisoPush> get abiertos =>
      FirebaseMessaging.onMessageOpenedApp.map(_aviso);

  @override
  Future<AvisoPush?> inicial() async {
    final m = await _fcm.getInitialMessage();
    return m == null ? null : _aviso(m);
  }
}

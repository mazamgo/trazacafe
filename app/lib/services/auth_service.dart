import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

/// Persona con sesión de Google. `organizacionId` y `rol` vienen de su token
/// y faltan hasta que activa una invitación (ver backend `/v1/activar`).
class Sesion {
  const Sesion({
    required this.uid,
    required this.email,
    this.organizacionId,
    this.rol,
  });

  final String uid;
  final String email;
  final String? organizacionId;
  final String? rol;

  bool get activa => organizacionId != null && rol != null;
  bool get esAdmin => rol == 'admin';
}

abstract class AuthService {
  Stream<Sesion?> observarSesion();

  /// Abre el selector de cuentas de Google. Lanza [AuthCancelado] si la
  /// persona lo cierra y [AuthError] si falla.
  Future<void> entrarConGoogle();
  Future<void> cerrarSesion();

  /// Token para la API; con [refrescar] pide uno nuevo con los permisos
  /// actualizados.
  Future<String?> token({bool refrescar = false});
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _inicializado;

  static const _kUid = 'sesion.uid';
  static const _kOrg = 'sesion.organizacionId';
  static const _kRol = 'sesion.rol';

  @override
  Stream<Sesion?> observarSesion() =>
      _auth.idTokenChanges().asyncMap(_leerSesion);

  /// Lee organización y rol del token. Sin señal y con el token vencido no se
  /// puede renovar, así que se usan los últimos permisos guardados: el técnico
  /// sigue trabajando en la finca y la API vuelve a validar al sincronizar.
  Future<Sesion?> _leerSesion(User? u) async {
    if (u == null) return null;
    final prefs = await SharedPreferences.getInstance();
    try {
      final claims = (await u.getIdTokenResult()).claims ?? const {};
      final org = claims['organizacionId'] as String?;
      final rol = claims['rol'] as String?;
      await prefs.setString(_kUid, u.uid);
      await _guardar(prefs, _kOrg, org);
      await _guardar(prefs, _kRol, rol);
      return Sesion(
        uid: u.uid,
        email: u.email ?? '',
        organizacionId: org,
        rol: rol,
      );
    } on FirebaseAuthException {
      final mismo = prefs.getString(_kUid) == u.uid;
      return Sesion(
        uid: u.uid,
        email: u.email ?? '',
        organizacionId: mismo ? prefs.getString(_kOrg) : null,
        rol: mismo ? prefs.getString(_kRol) : null,
      );
    }
  }

  static Future<void> _guardar(
    SharedPreferences prefs,
    String clave,
    String? valor,
  ) => valor == null ? prefs.remove(clave) : prefs.setString(clave, valor);

  @override
  Future<void> entrarConGoogle() async {
    _inicializado ??= _google.initialize(serverClientId: googleWebClientId);
    await _inicializado;
    try {
      final cuenta = await _google.authenticate();
      final idToken = cuenta.authentication.idToken;
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw AuthCancelado();
      throw AuthError(switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'El inicio de sesión con Google no está configurado en esta app.',
        _ => 'No se pudo iniciar sesión con Google. Revisa tu conexión.',
      });
    } on FirebaseAuthException catch (e) {
      throw AuthError(switch (e.code) {
        'network-request-failed' =>
          'Sin conexión. Inicia sesión cuando tengas señal.',
        'user-disabled' => 'Esta cuenta está desactivada.',
        _ => 'No se pudo iniciar sesión (${e.code}).',
      });
    }
  }

  @override
  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kUid),
      prefs.remove(_kOrg),
      prefs.remove(_kRol),
    ]);
    await _auth.signOut();
    if (_inicializado != null) await _google.signOut();
  }

  @override
  Future<String?> token({bool refrescar = false}) async =>
      _auth.currentUser?.getIdToken(refrescar);
}

class AuthError implements Exception {
  AuthError(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// La persona cerró el selector de cuentas; no es un error que mostrar.
class AuthCancelado implements Exception {}

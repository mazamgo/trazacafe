import 'package:firebase_auth/firebase_auth.dart';

/// Sesión del técnico de campo. Las cuentas las crea el administrador
/// (backend/scripts/crear-tecnico.ts) con la cooperativa como custom claim;
/// en la app no hay registro abierto.
abstract class AuthService {
  Stream<String?> observarUsuario();
  Future<void> iniciarSesion(String correo, String clave);
  Future<void> recuperarClave(String correo);
  Future<void> cerrarSesion();

  /// Token de Firebase para la API, o `null` si no hay sesión.
  Future<String?> token();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<String?> observarUsuario() => _auth.authStateChanges().map((u) => u?.email);

  @override
  Future<void> iniciarSesion(String correo, String clave) async {
    try {
      await _auth.signInWithEmailAndPassword(email: correo, password: clave);
    } on FirebaseAuthException catch (e) {
      throw AuthError(_mensaje(e.code));
    }
  }

  @override
  Future<void> recuperarClave(String correo) async {
    try {
      await _auth.sendPasswordResetEmail(email: correo);
    } on FirebaseAuthException catch (e) {
      throw AuthError(_mensaje(e.code));
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<String?> token() async => _auth.currentUser?.getIdToken();

  static String _mensaje(String codigo) => switch (codigo) {
        'invalid-email' => 'El correo no es válido.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Correo o contraseña incorrectos.',
        'user-disabled' => 'Esta cuenta está desactivada.',
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
        'network-request-failed' => 'Sin conexión. Inicia sesión cuando tengas señal.',
        _ => 'No se pudo iniciar sesión ($codigo).',
      };
}

class AuthError implements Exception {
  AuthError(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

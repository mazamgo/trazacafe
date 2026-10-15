import 'api_client.dart';
import 'auth_service.dart';

/// Pide a la API la organización y el rol de la invitación, y refresca el
/// token para que la app los vea. Si el correo no está invitado, cierra la
/// sesión (para que pueda probar con otra cuenta) y lanza [AuthError].
Future<void> activar(AuthService auth, ApiClient api) async {
  try {
    await api.activar();
    await auth.token(refrescar: true);
  } on ApiError catch (e) {
    if (e.status == 403 || e.status == 409) {
      await auth.cerrarSesion();
      throw AuthError(e.mensaje);
    }
    rethrow;
  }
}

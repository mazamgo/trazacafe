import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/fincas_service.dart';
import 'services/fotos_service.dart';
import 'services/sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());

/// Sesión actual, o `null` si nadie ha iniciado sesión.
final sesionProvider = StreamProvider<Sesion?>(
  (ref) => ref.watch(authServiceProvider).observarSesion(),
);

/// Mensaje para la pantalla de login, por ejemplo "tu cuenta no está
/// autorizada" después de que la activación cerró la sesión.
final avisoAccesoProvider = NotifierProvider<AvisoAcceso, String?>(AvisoAcceso.new);

class AvisoAcceso extends Notifier<String?> {
  @override
  String? build() => null;

  void mostrar(String? mensaje) => state = mensaje;
}

final apiProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return ApiClient(token: auth.token);
});

final fotosServiceProvider = Provider<FotosService>((ref) => FotosService());

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(databaseProvider), ref.watch(apiProvider)),
);

final fincasServiceProvider = Provider<FincasService>(
  (ref) => FincasService(ref.watch(databaseProvider), ref.watch(apiProvider)),
);

final productoresProvider = StreamProvider<List<ProductorConFincas>>(
  (ref) => ref.watch(databaseProvider).observarProductores(),
);

final fincasDeProductorProvider = StreamProvider.family<List<Finca>, String>(
  (ref, productorId) => ref.watch(databaseProvider).observarFincas(productorId: productorId),
);

final pendientesProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).observarTotalPendientes(),
);

/// Equipo de la organización (solo administradores; requiere señal).
final invitacionesProvider = FutureProvider.autoDispose<List<Invitacion>>(
  (ref) => ref.watch(apiProvider).invitaciones(),
);

/// Sincroniza solo cada vez que vuelve la señal. Los errores se ignoran
/// aquí: el botón de sincronizar los muestra.
final autoSyncProvider = Provider<void>((ref) {
  final sync = ref.watch(syncServiceProvider);
  final sub = Connectivity().onConnectivityChanged.listen((estado) {
    if (estado.any((c) => c != ConnectivityResult.none)) {
      unawaited(sync.sincronizar().then((_) {}, onError: (_) {}));
    }
  });
  ref.onDispose(sub.cancel);
});

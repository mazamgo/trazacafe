import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/fotos_service.dart';
import 'services/sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());

/// Correo del técnico con sesión iniciada, o `null`.
final usuarioProvider = StreamProvider<String?>(
  (ref) => ref.watch(authServiceProvider).observarUsuario(),
);

final fotosServiceProvider = Provider<FotosService>((ref) => FotosService());

final syncServiceProvider = Provider<SyncService>((ref) {
  final auth = ref.watch(authServiceProvider);
  return SyncService(ref.watch(databaseProvider), ApiClient(token: auth.token));
});

final productoresProvider = StreamProvider<List<ProductorConFincas>>(
  (ref) => ref.watch(databaseProvider).observarProductores(),
);

final fincasDeProductorProvider = StreamProvider.family<List<Finca>, String>(
  (ref, productorId) => ref.watch(databaseProvider).observarFincas(productorId: productorId),
);

final pendientesProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).observarTotalPendientes(),
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

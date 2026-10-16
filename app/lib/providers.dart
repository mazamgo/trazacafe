import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/fincas_service.dart';
import 'services/fotos_service.dart';
import 'services/mapas_service.dart';
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

/// Sube a Firebase Storage. Las reglas (storage.rules) solo dejan escribir en
/// la carpeta de la organización del token y nunca reemplazar un archivo.
class FirebaseSubidor implements SubidorArchivos {
  @override
  Future<void> subir(String rutaStorage, File archivo) async {
    await FirebaseStorage.instance
        .ref(rutaStorage)
        .putFile(archivo, SettableMetadata(contentType: 'image/jpeg'));
  }
}

final subidorProvider = Provider<SubidorArchivos>((ref) => FirebaseSubidor());

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(databaseProvider),
    ref.watch(apiProvider),
    ref.watch(subidorProvider),
    () => ref.read(sesionProvider).value?.organizacionId,
  ),
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

final mapasServiceProvider = Provider<MapasService>((ref) => MapasService());

/// Sesión de mapas de Google, o `null` si no hay señal ni sesión guardada.
final sesionMapaProvider = FutureProvider<SesionMapa?>(
  (ref) => ref.watch(mapasServiceProvider).sesion(),
);

final fincaProvider = StreamProvider.family<Finca?, String>(
  (ref, id) => ref.watch(databaseProvider).observarFinca(id),
);

/// Fotos de un productor o una finca: `(entidadTipo, entidadId)`.
final fotosProvider = StreamProvider.family<List<Foto>, (String, String)>(
  (ref, entidad) => ref.watch(databaseProvider).observarFotos(entidad.$1, entidad.$2),
);

final entregasProvider = StreamProvider.family<List<Entrega>, String>(
  (ref, fincaId) => ref.watch(databaseProvider).observarEntregas(fincaId),
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

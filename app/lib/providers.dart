import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final fincasProvider = StreamProvider<List<Finca>>(
  (ref) => ref.watch(databaseProvider).observarFincas(),
);

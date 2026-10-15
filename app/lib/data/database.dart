import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Base de datos local (SQLite) de la app de campo.
///
/// Todo se guarda primero aquí para trabajar sin señal; la columna
/// `sincronizado` marca lo que ya se envió a la API en Cloud Run.

class Productores extends Table {
  TextColumn get id => text()();
  TextColumn get nombre => text()();
  TextColumn get cedula => text().nullable()();
  TextColumn get comunidad => text().nullable()();
  BoolColumn get consentimientoFirmado =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Fincas extends Table {
  TextColumn get id => text()();
  TextColumn get productorId => text().references(Productores, #id)();
  TextColumn get nombre => text()();

  /// Coordenadas en GeoJSON: `[[lon, lat], ...]`. Un solo punto si la finca
  /// mide menos de 4 ha; polígono cerrado si mide 4 ha o más (regla EUDR).
  TextColumn get coordenadasJson => text()();
  RealColumn get areaHa => real()();

  /// Hash SHA-256 de las coordenadas canónicas; es lo que va a la blockchain.
  TextColumn get geoHash => text()();

  /// UID de la attestation en EAS, cuando el backend ya la firmó.
  TextColumn get attestationUid => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Entregas extends Table {
  TextColumn get id => text()();
  TextColumn get fincaId => text().references(Fincas, #id)();
  RealColumn get kg => real()();

  /// `uva` (café maduro) o `pergamino`.
  TextColumn get estado => text()();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get attestationUid => text().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Productores, Fincas, Entregas])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(
          name: 'trazacafe',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));

  @override
  int get schemaVersion => 1;

  Stream<List<Finca>> observarFincas() =>
      (select(fincas)..orderBy([(f) => OrderingTerm.desc(f.creadoEn)])).watch();

  Future<List<Finca>> fincasPendientes() =>
      (select(fincas)..where((f) => f.sincronizado.equals(false))).get();
}

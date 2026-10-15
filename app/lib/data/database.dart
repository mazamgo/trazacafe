import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Base de datos local (SQLite) de la app de campo.
///
/// Todo se guarda primero aquÃ­ para trabajar sin seÃ±al; la columna
/// `sincronizado` marca lo que ya se enviÃ³ a la API en Cloud Run.

@DataClassName('Productor')
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
  /// mide menos de 4 ha; polÃ­gono cerrado si mide 4 ha o mÃ¡s (regla EUDR).
  TextColumn get coordenadasJson => text()();
  RealColumn get areaHa => real()();

  /// Hash SHA-256 de las coordenadas canÃ³nicas; es lo que va a la blockchain.
  TextColumn get geoHash => text()();

  /// UID de la attestation en EAS, cuando el backend ya la firmÃ³.
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

  /// `uva` (cafÃ© maduro) o `pergamino`.
  TextColumn get estado => text()();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get attestationUid => text().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fotos tomadas en campo (consentimiento firmado, finca, documentos).
/// El archivo queda en el celular; a la API solo viaja su hash por ahora.
class Fotos extends Table {
  TextColumn get id => text()();

  /// `productor` o `finca`.
  TextColumn get entidadTipo => text()();
  TextColumn get entidadId => text()();

  /// `consentimiento`, `finca` o `documento`.
  TextColumn get tipo => text()();
  TextColumn get ruta => text()();
  TextColumn get sha256 => text()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Productor con la cantidad de fincas registradas, para la lista principal.
class ProductorConFincas {
  ProductorConFincas(this.productor, this.fincas);
  final Productor productor;
  final int fincas;
}

/// Todo lo que falta enviar a la API.
class Pendientes {
  Pendientes(this.productores, this.fincas, this.fotos);
  final List<Productor> productores;
  final List<Finca> fincas;
  final List<Foto> fotos;

  bool get vacio => productores.isEmpty && fincas.isEmpty && fotos.isEmpty;
  int get total => productores.length + fincas.length + fotos.length;
}

@DriftDatabase(tables: [Productores, Fincas, Entregas, Fotos])
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(fotos);
        },
      );

  Stream<List<ProductorConFincas>> observarProductores() {
    final conteo = fincas.id.count();
    final query = select(productores).join([
      leftOuterJoin(fincas, fincas.productorId.equalsExp(productores.id)),
    ])
      ..groupBy([productores.id])
      ..addColumns([conteo])
      ..orderBy([OrderingTerm.asc(productores.nombre)]);
    return query.watch().map((filas) => [
          for (final f in filas)
            ProductorConFincas(f.readTable(productores), f.read(conteo) ?? 0),
        ]);
  }

  Stream<List<Finca>> observarFincas({String? productorId}) {
    final q = select(fincas)..orderBy([(f) => OrderingTerm.desc(f.creadoEn)]);
    if (productorId != null) q.where((f) => f.productorId.equals(productorId));
    return q.watch();
  }

  Future<List<Finca>> fincasPendientes() =>
      (select(fincas)..where((f) => f.sincronizado.equals(false))).get();

  Future<Pendientes> pendientes() async => Pendientes(
        await (select(productores)..where((p) => p.sincronizado.equals(false))).get(),
        await fincasPendientes(),
        await (select(fotos)..where((f) => f.sincronizado.equals(false))).get(),
      );

  Stream<int> observarTotalPendientes() => customSelect(
        'SELECT '
        '(SELECT COUNT(*) FROM productores WHERE sincronizado = 0) + '
        '(SELECT COUNT(*) FROM fincas WHERE sincronizado = 0) + '
        '(SELECT COUNT(*) FROM fotos WHERE sincronizado = 0) AS total',
        readsFrom: {productores, fincas, fotos},
      ).watchSingle().map((fila) => fila.read<int>('total'));

  /// Marca como enviados exactamente los registros que viajaron en [enviados].
  Future<void> marcarSincronizados(Pendientes enviados) => transaction(() async {
        const hecho = Value(true);
        await (update(productores)
              ..where((t) => t.id.isIn(enviados.productores.map((e) => e.id))))
            .write(const ProductoresCompanion(sincronizado: hecho));
        await (update(fincas)..where((t) => t.id.isIn(enviados.fincas.map((e) => e.id))))
            .write(const FincasCompanion(sincronizado: hecho));
        await (update(fotos)..where((t) => t.id.isIn(enviados.fotos.map((e) => e.id))))
            .write(const FotosCompanion(sincronizado: hecho));
      });
}

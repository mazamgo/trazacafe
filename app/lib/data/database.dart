import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Base de datos local (SQLite) de la app de campo.
///
/// Todo se guarda primero aquí para trabajar sin señal; la columna
/// `sincronizado` marca lo que ya se envió a la API en Cloud Run.

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
  /// mide menos de 4 ha; polígono cerrado si mide 4 ha o más (regla EUDR).
  TextColumn get coordenadasJson => text()();
  RealColumn get areaHa => real()();

  /// Área que calcula el servidor (PostGIS, sobre el elipsoide). Es la que
  /// va al paquete EUDR; llega al sincronizar.
  RealColumn get areaOficialHa => real().nullable()();

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
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fotos tomadas en campo (consentimiento firmado, finca, documentos).
/// Primero viaja el hash (`sincronizado`); después el archivo a Cloud
/// Storage (`subida`), que la API confirma comparando el hash.
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
  BoolColumn get subida => boolean().withDefault(const Constant(false))();

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
  Pendientes(this.productores, this.fincas, this.entregas, this.fotos);
  final List<Productor> productores;
  final List<Finca> fincas;
  final List<Entrega> entregas;
  final List<Foto> fotos;

  bool get vacio => total == 0;
  int get total => productores.length + fincas.length + entregas.length + fotos.length;
}

@DriftDatabase(tables: [Productores, Fincas, Entregas, Fotos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'trazacafe',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(fotos);
          if (from < 3) {
            await m.addColumn(fotos, fotos.subida);
            await m.addColumn(fincas, fincas.areaOficialHa);
            await m.addColumn(entregas, entregas.creadoEn);
          }
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

  Stream<Finca?> observarFinca(String id) =>
      (select(fincas)..where((f) => f.id.equals(id))).watchSingleOrNull();

  Stream<List<Entrega>> observarEntregas(String fincaId) => (select(entregas)
        ..where((e) => e.fincaId.equals(fincaId))
        ..orderBy([(e) => OrderingTerm.desc(e.fecha)]))
      .watch();

  Stream<List<Foto>> observarFotos(String entidadTipo, String entidadId) => (select(fotos)
        ..where((f) => f.entidadTipo.equals(entidadTipo) & f.entidadId.equals(entidadId))
        ..orderBy([(f) => OrderingTerm.asc(f.creadoEn)]))
      .watch();

  Future<List<Finca>> fincasPendientes() =>
      (select(fincas)..where((f) => f.sincronizado.equals(false))).get();

  Future<Pendientes> pendientes() async => Pendientes(
        await (select(productores)..where((p) => p.sincronizado.equals(false))).get(),
        await fincasPendientes(),
        await (select(entregas)..where((e) => e.sincronizado.equals(false))).get(),
        await (select(fotos)..where((f) => f.sincronizado.equals(false))).get(),
      );

  /// Fotos cuyo hash ya está en la API pero el archivo no se ha subido.
  Future<List<Foto>> fotosPorSubir() =>
      (select(fotos)..where((f) => f.sincronizado.equals(true) & f.subida.equals(false))).get();

  Future<void> marcarFotoSubida(String id) => (update(fotos)..where((f) => f.id.equals(id)))
      .write(const FotosCompanion(subida: Value(true)));

  /// Registros sin enviar más fotos sin subir: lo que muestra el botón de sincronizar.
  Stream<int> observarTotalPendientes() => customSelect(
        'SELECT '
        '(SELECT COUNT(*) FROM productores WHERE sincronizado = 0) + '
        '(SELECT COUNT(*) FROM fincas WHERE sincronizado = 0) + '
        '(SELECT COUNT(*) FROM entregas WHERE sincronizado = 0) + '
        '(SELECT COUNT(*) FROM fotos WHERE sincronizado = 0 OR subida = 0) AS total',
        readsFrom: {productores, fincas, entregas, fotos},
      ).watchSingle().map((fila) => fila.read<int>('total'));

  /// Borra la finca, sus entregas y sus fotos del celular. Devuelve las rutas
  /// de los archivos de foto para borrarlos también.
  Future<List<String>> eliminarFincaLocal(String fincaId) => transaction(() async {
        final fotosFinca = await (select(fotos)
              ..where((f) => f.entidadTipo.equals('finca') & f.entidadId.equals(fincaId)))
            .get();
        await (delete(fotos)
              ..where((f) => f.entidadTipo.equals('finca') & f.entidadId.equals(fincaId)))
            .go();
        await (delete(entregas)..where((e) => e.fincaId.equals(fincaId))).go();
        await (delete(fincas)..where((f) => f.id.equals(fincaId))).go();
        return [for (final f in fotosFinca) f.ruta];
      });

  /// Marca como enviados exactamente los registros que viajaron en [enviados].
  Future<void> marcarSincronizados(Pendientes enviados) => transaction(() async {
        const hecho = Value(true);
        await (update(productores)
              ..where((t) => t.id.isIn(enviados.productores.map((e) => e.id))))
            .write(const ProductoresCompanion(sincronizado: hecho));
        await (update(fincas)..where((t) => t.id.isIn(enviados.fincas.map((e) => e.id))))
            .write(const FincasCompanion(sincronizado: hecho));
        await (update(entregas)..where((t) => t.id.isIn(enviados.entregas.map((e) => e.id))))
            .write(const EntregasCompanion(sincronizado: hecho));
        await (update(fotos)..where((t) => t.id.isIn(enviados.fotos.map((e) => e.id))))
            .write(const FotosCompanion(sincronizado: hecho));
      });

  /// Aplica lo que devuelve `GET /v1/datos`: agrega o actualiza lo del equipo
  /// sin tocar lo que este celular aún no envió, y quita las fincas y
  /// entregas que ya no existen en el servidor (borradas por otro técnico).
  /// Devuelve las rutas de fotos locales que quedaron sin finca.
  Future<List<String>> aplicarDatosServidor(DatosServidor d) => transaction(() async {
        final sinEnviar = (await pendientes());
        final productoresLocales = {for (final p in sinEnviar.productores) p.id};
        final fincasLocales = {for (final f in sinEnviar.fincas) f.id};
        final entregasLocales = {for (final e in sinEnviar.entregas) e.id};

        for (final p in d.productores) {
          if (productoresLocales.contains(p.id.value)) continue;
          await into(productores).insertOnConflictUpdate(p);
        }
        for (final f in d.fincas) {
          if (fincasLocales.contains(f.id.value)) continue;
          await into(fincas).insertOnConflictUpdate(f);
        }
        for (final e in d.entregas) {
          if (entregasLocales.contains(e.id.value)) continue;
          await into(entregas).insertOnConflictUpdate(e);
        }

        final fincasServidor = {for (final f in d.fincas) f.id.value};
        final entregasServidor = {for (final e in d.entregas) e.id.value};
        await (delete(entregas)
              ..where((e) => e.sincronizado.equals(true) & e.id.isNotIn(entregasServidor)))
            .go();
        final borradas = await (select(fincas)
              ..where((f) => f.sincronizado.equals(true) & f.id.isNotIn(fincasServidor)))
            .get();
        final rutas = <String>[];
        for (final f in borradas) {
          rutas.addAll(await eliminarFincaLocal(f.id));
        }
        return rutas;
      });
}

/// Datos de la organización ya convertidos a filas locales.
class DatosServidor {
  DatosServidor(this.productores, this.fincas, this.entregas);
  final List<ProductoresCompanion> productores;
  final List<FincasCompanion> fincas;
  final List<EntregasCompanion> entregas;
}

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

  /// Pidió que borraran sus datos: quedan fincas sin datos personales que el
  /// EUDR obliga a guardar (llega del servidor).
  BoolColumn get anonimizado => boolean().withDefault(const Constant(false))();

  /// Hasta cuándo se guardan esas fincas (5 años desde la exportación).
  DateTimeColumn get conservarHasta => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Fincas extends Table {
  TextColumn get id => text()();
  TextColumn get productorId => text().references(Productores, #id)();
  TextColumn get nombre => text()();

  /// Id de `schemas/cultivos.json` (`cafe`, `cacao`). Define los estados de
  /// sus entregas y qué temporada les toca.
  TextColumn get cultivo => text().withDefault(const Constant('cafe'))();

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

  /// Versión del lindero vigente (sube con cada lindero nuevo).
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// Último chequeo satelital: `pendiente`, `verde`, `amarillo` o `rojo`.
  TextColumn get deforestacion =>
      text().withDefault(const Constant('pendiente'))();
  DateTimeColumn get ultimoChequeo => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Temporadas de cosecha que define la organización (llegan del servidor).
class Temporadas extends Table {
  TextColumn get id => text()();
  TextColumn get nombre => text()();

  /// Días de calendario en Nicaragua, ambos incluidos.
  DateTimeColumn get inicio => dateTime()();
  DateTimeColumn get fin => dateTime()();

  /// Cultivo al que aplica; `null` = a todos los de la organización.
  TextColumn get cultivo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cultivos con los que trabaja la organización (llegan del servidor). Vacía
/// mientras no se haya sincronizado: entonces se asume solo café.
class CultivosOrganizacion extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Datos sueltos de la organización que llegan del servidor (ver [ClaveAjuste]).
class Ajustes extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text().nullable()();

  @override
  Set<Column> get primaryKey => {clave};
}

/// Claves de la tabla [Ajustes].
abstract final class ClaveAjuste {
  /// Fecha (ISO) en que se eliminará la organización, si el administrador lo pidió.
  static const eliminacionProgramada = 'eliminacionProgramada';

  /// Solicitudes de eliminación de productores sin responder (solo administradores).
  static const solicitudesPendientes = 'solicitudesPendientes';

  /// Organización dueña de los datos del celular (la anota la app al entrar;
  /// ver `DatosCelular`).
  static const organizacionDatos = 'organizacionDatos';
}

/// Lindero nuevo de una finca ya enviada, pendiente de enviar. Al enviarse
/// la finca ya tiene esas coordenadas; la API guarda el historial.
class VersionesFinca extends Table {
  TextColumn get fincaId => text().references(Fincas, #id)();
  IntColumn get version => integer()();
  TextColumn get coordenadasJson => text()();
  RealColumn get areaHa => real()();
  TextColumn get geoHash => text()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {fincaId, version};
}

/// Visita de verificación de una finca en una temporada.
@DataClassName('Verificacion')
class Verificaciones extends Table {
  TextColumn get id => text()();
  TextColumn get fincaId => text().references(Fincas, #id)();

  /// La asigna el servidor por la fecha; en el celular se calcula igual.
  TextColumn get temporadaId => text().nullable()();
  DateTimeColumn get fecha => dateTime()();
  BoolColumn get linderoCambio =>
      boolean().withDefault(const Constant(false))();
  IntColumn get versionFinca => integer()();
  TextColumn get nota => text().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Entregas extends Table {
  TextColumn get id => text()();
  TextColumn get fincaId => text().references(Fincas, #id)();
  TextColumn get temporadaId => text().nullable()();
  RealColumn get kg => real()();

  /// Uno de los estados del cultivo de la finca (`cultivos.json`).
  TextColumn get estado => text()();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get attestationUid => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  /// Lote en que va (llega del servidor). En un lote ya no se corrige.
  TextColumn get loteCodigo => text().nullable()();

  /// Tiene correcciones en el historial del servidor.
  BoolColumn get corregida => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fotos tomadas en campo (consentimiento firmado, finca, documentos).
/// Primero viaja el hash (`sincronizado`); después el archivo a Cloud
/// Storage (`subida`), que la API confirma comparando el hash.
class Fotos extends Table {
  TextColumn get id => text()();

  /// `productor`, `finca` o `verificacion`.
  TextColumn get entidadTipo => text()();
  TextColumn get entidadId => text()();

  /// `consentimiento`, `finca`, `documento` o `verificacion`.
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
  Pendientes(
    this.productores,
    this.fincas,
    this.versionesFinca,
    this.verificaciones,
    this.entregas,
    this.fotos,
  );
  final List<Productor> productores;
  final List<Finca> fincas;
  final List<VersionesFincaData> versionesFinca;
  final List<Verificacion> verificaciones;
  final List<Entrega> entregas;
  final List<Foto> fotos;

  bool get vacio => total == 0;
  int get total =>
      productores.length +
      fincas.length +
      versionesFinca.length +
      verificaciones.length +
      entregas.length +
      fotos.length;
}

@DriftDatabase(
  tables: [
    Productores,
    Fincas,
    Temporadas,
    CultivosOrganizacion,
    Ajustes,
    VersionesFinca,
    Verificaciones,
    Entregas,
    Fotos,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'trazacafe',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(fotos);
      if (from < 3) {
        await m.addColumn(fotos, fotos.subida);
        await m.addColumn(fincas, fincas.areaOficialHa);
        await m.addColumn(entregas, entregas.creadoEn);
      }
      if (from < 4) {
        // Columnas nuevas con valor por defecto constante o vacías:
        // SQLite no acepta defaults calculados en ADD COLUMN.
        await m.addColumn(fincas, fincas.version);
        await m.addColumn(fincas, fincas.deforestacion);
        await m.addColumn(fincas, fincas.ultimoChequeo);
        await m.addColumn(entregas, entregas.temporadaId);
        await m.createTable(temporadas);
        await m.createTable(versionesFinca);
        await m.createTable(verificaciones);
      }
      if (from < 5) {
        await m.addColumn(fincas, fincas.cultivo);
        // Si venía de v3, createTable(temporadas) ya la creó con la columna.
        if (from >= 4) await m.addColumn(temporadas, temporadas.cultivo);
        await m.createTable(cultivosOrganizacion);
      }
      if (from < 6) {
        await m.addColumn(entregas, entregas.loteCodigo);
        await m.addColumn(entregas, entregas.corregida);
      }
      if (from < 7) {
        await m.addColumn(productores, productores.anonimizado);
        await m.addColumn(productores, productores.conservarHasta);
        await m.createTable(ajustes);
      }
    },
  );

  /// Temporada de [cultivo] que contiene [fecha] (por día de calendario), o
  /// `null`. Si hay una propia del cultivo, gana sobre la general (igual que
  /// `TEMPORADA_DE` en backend/src/repo.ts).
  Future<Temporada?> temporadaDe(DateTime fecha, {required String cultivo}) =>
      (select(temporadas)
            ..where((t) {
              final dia = DateTime(fecha.year, fecha.month, fecha.day);
              return t.inicio.isSmallerOrEqualValue(dia) &
                  t.fin.isBiggerOrEqualValue(dia) &
                  (t.cultivo.isNull() | t.cultivo.equals(cultivo));
            })
            ..orderBy([(t) => OrderingTerm.asc(t.cultivo.isNull())])
            ..limit(1))
          .getSingleOrNull();

  /// Cultivos de la organización; solo café hasta la primera sincronización.
  Stream<List<String>> observarCultivosOrganizacion() =>
      select(cultivosOrganizacion).watch().map(
        (filas) =>
            filas.isEmpty ? const ['cafe'] : [for (final f in filas) f.id],
      );

  Stream<List<Temporada>> observarTemporadas() => (select(
    temporadas,
  )..orderBy([(t) => OrderingTerm.desc(t.inicio)])).watch();

  /// Visitas de una finca, de la más reciente a la más antigua.
  Stream<List<Verificacion>> observarVerificaciones(String fincaId) =>
      (select(verificaciones)
            ..where((v) => v.fincaId.equals(fincaId))
            ..orderBy([(v) => OrderingTerm.desc(v.fecha)]))
          .watch();

  /// ¿La finca tiene al menos una visita en la temporada de [hoy]?
  Future<bool> verificadaEnTemporadaActual(
    String fincaId, {
    DateTime? hoy,
  }) async {
    final finca = await (select(
      fincas,
    )..where((f) => f.id.equals(fincaId))).getSingleOrNull();
    if (finca == null) return false;
    final t = await temporadaDe(hoy ?? DateTime.now(), cultivo: finca.cultivo);
    if (t == null) return false;
    final v =
        await (select(verificaciones)
              ..where(
                (x) => x.fincaId.equals(fincaId) & x.temporadaId.equals(t.id),
              )
              ..limit(1))
            .getSingleOrNull();
    return v != null;
  }

  /// Guarda una visita (y su lindero nuevo, si cambió) con sus fotos.
  /// Si la finca aún no se envió, el lindero nuevo reemplaza al que tenía:
  /// todavía no hay historial en el servidor que conservar.
  Future<void> guardarVisita({
    required Finca finca,
    required VerificacionesCompanion visita,
    required List<FotosCompanion> fotosVisita,
    ({String coordenadasJson, double areaHa, String geoHash})? linderoNuevo,
  }) => transaction(() async {
    var version = finca.version;
    if (linderoNuevo != null) {
      if (finca.sincronizado) {
        version = finca.version + 1;
        await into(versionesFinca).insert(
          VersionesFincaCompanion.insert(
            fincaId: finca.id,
            version: version,
            coordenadasJson: linderoNuevo.coordenadasJson,
            areaHa: linderoNuevo.areaHa,
            geoHash: linderoNuevo.geoHash,
          ),
        );
      }
      await (update(fincas)..where((f) => f.id.equals(finca.id))).write(
        FincasCompanion(
          coordenadasJson: Value(linderoNuevo.coordenadasJson),
          areaHa: Value(linderoNuevo.areaHa),
          geoHash: Value(linderoNuevo.geoHash),
          version: Value(version),
          areaOficialHa: const Value(null),
          deforestacion: const Value('pendiente'),
        ),
      );
    }
    final temporada = await temporadaDe(
      visita.fecha.value,
      cultivo: finca.cultivo,
    );
    await into(verificaciones).insert(
      visita.copyWith(
        versionFinca: Value(version),
        temporadaId: Value(temporada?.id),
      ),
    );
    for (final f in fotosVisita) {
      await into(fotos).insert(f);
    }
  });

  /// Cambia el cultivo de la finca y vuelve a asignar sus visitas a la
  /// temporada que les toca con el cultivo nuevo (igual que la API).
  Future<void> cambiarCultivoLocal(String fincaId, String cultivo) =>
      transaction(() async {
        await (update(fincas)..where((f) => f.id.equals(fincaId))).write(
          FincasCompanion(cultivo: Value(cultivo)),
        );
        final visitas = await (select(
          verificaciones,
        )..where((v) => v.fincaId.equals(fincaId))).get();
        for (final v in visitas) {
          final t = await temporadaDe(v.fecha, cultivo: cultivo);
          await (update(verificaciones)..where((x) => x.id.equals(v.id))).write(
            VerificacionesCompanion(temporadaId: Value(t?.id)),
          );
        }
      });

  Stream<List<ProductorConFincas>> observarProductores() {
    final conteo = fincas.id.count();
    final query =
        select(productores).join([
            leftOuterJoin(fincas, fincas.productorId.equalsExp(productores.id)),
          ])
          ..groupBy([productores.id])
          ..addColumns([conteo])
          ..orderBy([OrderingTerm.asc(productores.nombre)]);
    return query.watch().map(
      (filas) => [
        for (final f in filas)
          ProductorConFincas(f.readTable(productores), f.read(conteo) ?? 0),
      ],
    );
  }

  Stream<List<Finca>> observarFincas({String? productorId}) {
    final q = select(fincas)..orderBy([(f) => OrderingTerm.desc(f.creadoEn)]);
    if (productorId != null) q.where((f) => f.productorId.equals(productorId));
    return q.watch();
  }

  /// Todas las fincas con su productor (las anonimizadas no: no tienen
  /// nombre que buscar).
  Stream<List<(Finca, Productor)>> observarFincasConProductor() {
    final query = select(fincas).join([
      innerJoin(productores, productores.id.equalsExp(fincas.productorId)),
    ])..where(productores.anonimizado.equals(false));
    return query.watch().map(
      (filas) => [
        for (final f in filas) (f.readTable(fincas), f.readTable(productores)),
      ],
    );
  }

  Stream<Finca?> observarFinca(String id) =>
      (select(fincas)..where((f) => f.id.equals(id))).watchSingleOrNull();

  Stream<List<Entrega>> observarEntregas(String fincaId) =>
      (select(entregas)
            ..where((e) => e.fincaId.equals(fincaId))
            ..orderBy([(e) => OrderingTerm.desc(e.fecha)]))
          .watch();

  Stream<List<Foto>> observarFotos(String entidadTipo, String entidadId) =>
      (select(fotos)
            ..where(
              (f) =>
                  f.entidadTipo.equals(entidadTipo) &
                  f.entidadId.equals(entidadId),
            )
            ..orderBy([(f) => OrderingTerm.asc(f.creadoEn)]))
          .watch();

  Future<List<Finca>> fincasPendientes() =>
      (select(fincas)..where((f) => f.sincronizado.equals(false))).get();

  Future<Pendientes> pendientes() async => Pendientes(
    await (select(
      productores,
    )..where((p) => p.sincronizado.equals(false))).get(),
    await fincasPendientes(),
    await (select(versionesFinca)
          ..where((v) => v.sincronizado.equals(false))
          ..orderBy([(v) => OrderingTerm.asc(v.version)]))
        .get(),
    await (select(
      verificaciones,
    )..where((v) => v.sincronizado.equals(false))).get(),
    await (select(entregas)..where((e) => e.sincronizado.equals(false))).get(),
    await (select(fotos)..where((f) => f.sincronizado.equals(false))).get(),
  );

  /// Fotos cuyo hash ya está en la API pero el archivo no se ha subido.
  Future<List<Foto>> fotosPorSubir() => (select(
    fotos,
  )..where((f) => f.sincronizado.equals(true) & f.subida.equals(false))).get();

  Future<void> marcarFotoSubida(String id) =>
      (update(fotos)..where((f) => f.id.equals(id))).write(
        const FotosCompanion(subida: Value(true)),
      );

  /// Registros sin enviar más fotos sin subir: lo que muestra el botón de sincronizar.
  Stream<int> observarTotalPendientes() => customSelect(
    'SELECT '
    '(SELECT COUNT(*) FROM productores WHERE sincronizado = 0) + '
    '(SELECT COUNT(*) FROM fincas WHERE sincronizado = 0) + '
    '(SELECT COUNT(*) FROM versiones_finca WHERE sincronizado = 0) + '
    '(SELECT COUNT(*) FROM verificaciones WHERE sincronizado = 0) + '
    '(SELECT COUNT(*) FROM entregas WHERE sincronizado = 0) + '
    '(SELECT COUNT(*) FROM fotos WHERE sincronizado = 0 OR subida = 0) AS total',
    readsFrom: {
      productores,
      fincas,
      versionesFinca,
      verificaciones,
      entregas,
      fotos,
    },
  ).watchSingle().map((fila) => fila.read<int>('total'));

  /// Borra la finca con sus entregas, visitas, versiones y fotos del celular.
  /// Devuelve las rutas de los archivos de foto para borrarlos también.
  Future<List<String>> eliminarFincaLocal(String fincaId) =>
      transaction(() async {
        final visitas = [
          for (final v in await (select(
            verificaciones,
          )..where((v) => v.fincaId.equals(fincaId))).get())
            v.id,
        ];
        Expression<bool> deLaFinca(Fotos f) =>
            (f.entidadTipo.equals('finca') & f.entidadId.equals(fincaId)) |
            (f.entidadTipo.equals('verificacion') & f.entidadId.isIn(visitas));
        final fotosFinca = await (select(fotos)..where(deLaFinca)).get();
        await (delete(fotos)..where(deLaFinca)).go();
        await (delete(entregas)..where((e) => e.fincaId.equals(fincaId))).go();
        await (delete(
          verificaciones,
        )..where((v) => v.fincaId.equals(fincaId))).go();
        await (delete(
          versionesFinca,
        )..where((v) => v.fincaId.equals(fincaId))).go();
        await (delete(fincas)..where((f) => f.id.equals(fincaId))).go();
        return [for (final f in fotosFinca) f.ruta];
      });

  /// Fotos del productor, de sus fincas y de las visitas de esas fincas.
  Future<List<Foto>> _fotosDelProductor(String productorId) async {
    final fincasIds = [
      for (final f in await (select(
        fincas,
      )..where((f) => f.productorId.equals(productorId))).get())
        f.id,
    ];
    final visitas = [
      for (final v in await (select(
        verificaciones,
      )..where((v) => v.fincaId.isIn(fincasIds))).get())
        v.id,
    ];
    return (select(fotos)..where(
          (f) =>
              (f.entidadTipo.equals('productor') &
                  f.entidadId.equals(productorId)) |
              (f.entidadTipo.equals('finca') & f.entidadId.isIn(fincasIds)) |
              (f.entidadTipo.equals('verificacion') &
                  f.entidadId.isIn(visitas)),
        ))
        .get();
  }

  /// Borra del celular todo lo de la organización (al eliminar la cuenta).
  /// Devuelve las rutas de las fotos para borrar los archivos también.
  Future<List<String>> borrarTodoLocal() => transaction(() async {
    final rutas = [for (final f in await select(fotos).get()) f.ruta];
    for (final tabla in <TableInfo>[
      fotos,
      entregas,
      verificaciones,
      versionesFinca,
      fincas,
      productores,
      temporadas,
      cultivosOrganizacion,
      ajustes,
    ]) {
      await delete(tabla).go();
    }
    return rutas;
  });

  Future<String?> leerAjuste(String clave) async =>
      (await (select(
        ajustes,
      )..where((a) => a.clave.equals(clave))).getSingleOrNull())?.valor;

  Future<void> guardarAjuste(String clave, String? valor) => into(ajustes)
      .insertOnConflictUpdate(
        AjustesCompanion.insert(clave: clave, valor: Value(valor)),
      );

  Stream<String?> observarAjuste(String clave) =>
      (select(ajustes)..where((a) => a.clave.equals(clave)))
          .watchSingleOrNull()
          .map((a) => a?.valor);

  /// Marca como enviados exactamente los registros que viajaron en [enviados].
  Future<void> marcarSincronizados(Pendientes enviados) => transaction(
    () async {
      const hecho = Value(true);
      await (update(productores)
            ..where((t) => t.id.isIn(enviados.productores.map((e) => e.id))))
          .write(const ProductoresCompanion(sincronizado: hecho));
      await (update(fincas)
            ..where((t) => t.id.isIn(enviados.fincas.map((e) => e.id))))
          .write(const FincasCompanion(sincronizado: hecho));
      for (final v in enviados.versionesFinca) {
        await (update(versionesFinca)..where(
              (t) => t.fincaId.equals(v.fincaId) & t.version.equals(v.version),
            ))
            .write(const VersionesFincaCompanion(sincronizado: hecho));
      }
      await (update(verificaciones)
            ..where((t) => t.id.isIn(enviados.verificaciones.map((e) => e.id))))
          .write(const VerificacionesCompanion(sincronizado: hecho));
      await (update(entregas)
            ..where((t) => t.id.isIn(enviados.entregas.map((e) => e.id))))
          .write(const EntregasCompanion(sincronizado: hecho));
      await (update(fotos)
            ..where((t) => t.id.isIn(enviados.fotos.map((e) => e.id))))
          .write(const FotosCompanion(sincronizado: hecho));
    },
  );

  /// Aplica lo que devuelve `GET /v1/datos`: agrega o actualiza lo del equipo
  /// sin tocar lo que este celular aún no envió, y quita las fincas y
  /// entregas que ya no existen en el servidor (borradas por otro técnico).
  /// Devuelve las rutas de fotos locales que quedaron sin finca.
  Future<List<String>> aplicarDatosServidor(DatosServidor d) => transaction(
    () async {
      final sinEnviar = (await pendientes());
      final productoresLocales = {for (final p in sinEnviar.productores) p.id};
      // Una finca con lindero nuevo sin enviar tampoco se pisa con la del servidor.
      final fincasLocales = {
        for (final f in sinEnviar.fincas) f.id,
        for (final v in sinEnviar.versionesFinca) v.fincaId,
      };
      final visitasLocales = {for (final v in sinEnviar.verificaciones) v.id};
      final entregasLocales = {for (final e in sinEnviar.entregas) e.id};

      // Las temporadas y los cultivos solo los define el servidor: se
      // reemplazan todos.
      await delete(temporadas).go();
      for (final t in d.temporadas) {
        await into(temporadas).insert(t);
      }
      if (d.cultivos != null) {
        await delete(cultivosOrganizacion).go();
        for (final c in d.cultivos!) {
          await into(cultivosOrganizacion)
              .insert(CultivosOrganizacionCompanion.insert(id: c));
        }
      }
      for (final MapEntry(key: clave, value: valor)
          in (d.ajustes ?? const <String, String?>{}).entries) {
        await into(ajustes).insertOnConflictUpdate(
          AjustesCompanion.insert(clave: clave, valor: Value(valor)),
        );
      }
      for (final p in d.productores) {
        if (productoresLocales.contains(p.id.value)) continue;
        await into(productores).insertOnConflictUpdate(p);
      }
      for (final f in d.fincas) {
        if (fincasLocales.contains(f.id.value)) continue;
        await into(fincas).insertOnConflictUpdate(f);
      }
      for (final v in d.verificaciones) {
        if (visitasLocales.contains(v.id.value)) continue;
        await into(verificaciones).insertOnConflictUpdate(v);
      }
      for (final e in d.entregas) {
        if (entregasLocales.contains(e.id.value)) continue;
        await into(entregas).insertOnConflictUpdate(e);
      }

      final fincasServidor = {for (final f in d.fincas) f.id.value};
      final entregasServidor = {for (final e in d.entregas) e.id.value};
      final visitasServidor = {for (final v in d.verificaciones) v.id.value};
      await (delete(entregas)..where(
            (e) => e.sincronizado.equals(true) & e.id.isNotIn(entregasServidor),
          ))
          .go();
      await (delete(verificaciones)..where(
            (v) => v.sincronizado.equals(true) & v.id.isNotIn(visitasServidor),
          ))
          .go();
      final borradas =
          await (select(fincas)..where(
                (f) =>
                    f.sincronizado.equals(true) & f.id.isNotIn(fincasServidor),
              ))
              .get();
      final rutas = <String>[];
      for (final f in borradas) {
        rutas.addAll(await eliminarFincaLocal(f.id));
      }

      // Productores que se eliminaron en el servidor: fuera del celular con
      // sus fotos. A los anonimizados se les borran las fotos que quedaban
      // en el celular (en el servidor ya no tienen archivo).
      final productoresServidor = {for (final p in d.productores) p.id.value};
      final anonimizados = {
        for (final p in d.productores)
          if (p.anonimizado.present && p.anonimizado.value) p.id.value,
      };
      final eliminados =
          await (select(productores)..where(
                (p) =>
                    p.sincronizado.equals(true) &
                    p.id.isNotIn(productoresServidor),
              ))
              .get();
      for (final p in [...eliminados.map((p) => p.id), ...anonimizados]) {
        final suyas = await _fotosDelProductor(p);
        rutas.addAll(suyas.map((f) => f.ruta));
        await (delete(
          fotos,
        )..where((f) => f.id.isIn(suyas.map((x) => x.id)))).go();
      }
      for (final p in eliminados) {
        for (final f in await (select(
          fincas,
        )..where((f) => f.productorId.equals(p.id))).get()) {
          rutas.addAll(await eliminarFincaLocal(f.id));
        }
        await (delete(productores)..where((x) => x.id.equals(p.id))).go();
      }
      return rutas;
    },
  );
}

/// Datos de la organización ya convertidos a filas locales.
class DatosServidor {
  DatosServidor({
    required this.temporadas,
    required this.productores,
    required this.fincas,
    required this.verificaciones,
    required this.entregas,
    this.cultivos,
    this.ajustes,
  });

  /// Valores para [Ajustes]; `null` si la respuesta no los trae (API anterior).
  final Map<String, String?>? ajustes;

  /// Cultivos de la organización; `null` si la respuesta no los trae.
  final List<String>? cultivos;
  final List<TemporadasCompanion> temporadas;
  final List<ProductoresCompanion> productores;
  final List<FincasCompanion> fincas;
  final List<VerificacionesCompanion> verificaciones;
  final List<EntregasCompanion> entregas;
}

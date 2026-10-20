// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProductoresTable extends Productores
    with TableInfo<$ProductoresTable, Productor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cedulaMeta = const VerificationMeta('cedula');
  @override
  late final GeneratedColumn<String> cedula = GeneratedColumn<String>(
    'cedula',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _comunidadMeta = const VerificationMeta(
    'comunidad',
  );
  @override
  late final GeneratedColumn<String> comunidad = GeneratedColumn<String>(
    'comunidad',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consentimientoFirmadoMeta =
      const VerificationMeta('consentimientoFirmado');
  @override
  late final GeneratedColumn<bool> consentimientoFirmado =
      GeneratedColumn<bool>(
        'consentimiento_firmado',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("consentimiento_firmado" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombre,
    cedula,
    comunidad,
    consentimientoFirmado,
    creadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'productores';
  @override
  VerificationContext validateIntegrity(
    Insertable<Productor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('cedula')) {
      context.handle(
        _cedulaMeta,
        cedula.isAcceptableOrUnknown(data['cedula']!, _cedulaMeta),
      );
    }
    if (data.containsKey('comunidad')) {
      context.handle(
        _comunidadMeta,
        comunidad.isAcceptableOrUnknown(data['comunidad']!, _comunidadMeta),
      );
    }
    if (data.containsKey('consentimiento_firmado')) {
      context.handle(
        _consentimientoFirmadoMeta,
        consentimientoFirmado.isAcceptableOrUnknown(
          data['consentimiento_firmado']!,
          _consentimientoFirmadoMeta,
        ),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Productor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Productor(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      cedula: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cedula'],
      ),
      comunidad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comunidad'],
      ),
      consentimientoFirmado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}consentimiento_firmado'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $ProductoresTable createAlias(String alias) {
    return $ProductoresTable(attachedDatabase, alias);
  }
}

class Productor extends DataClass implements Insertable<Productor> {
  final String id;
  final String nombre;
  final String? cedula;
  final String? comunidad;
  final bool consentimientoFirmado;
  final DateTime creadoEn;
  final bool sincronizado;
  const Productor({
    required this.id,
    required this.nombre,
    this.cedula,
    this.comunidad,
    required this.consentimientoFirmado,
    required this.creadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre'] = Variable<String>(nombre);
    if (!nullToAbsent || cedula != null) {
      map['cedula'] = Variable<String>(cedula);
    }
    if (!nullToAbsent || comunidad != null) {
      map['comunidad'] = Variable<String>(comunidad);
    }
    map['consentimiento_firmado'] = Variable<bool>(consentimientoFirmado);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  ProductoresCompanion toCompanion(bool nullToAbsent) {
    return ProductoresCompanion(
      id: Value(id),
      nombre: Value(nombre),
      cedula: cedula == null && nullToAbsent
          ? const Value.absent()
          : Value(cedula),
      comunidad: comunidad == null && nullToAbsent
          ? const Value.absent()
          : Value(comunidad),
      consentimientoFirmado: Value(consentimientoFirmado),
      creadoEn: Value(creadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory Productor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Productor(
      id: serializer.fromJson<String>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      cedula: serializer.fromJson<String?>(json['cedula']),
      comunidad: serializer.fromJson<String?>(json['comunidad']),
      consentimientoFirmado: serializer.fromJson<bool>(
        json['consentimientoFirmado'],
      ),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombre': serializer.toJson<String>(nombre),
      'cedula': serializer.toJson<String?>(cedula),
      'comunidad': serializer.toJson<String?>(comunidad),
      'consentimientoFirmado': serializer.toJson<bool>(consentimientoFirmado),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Productor copyWith({
    String? id,
    String? nombre,
    Value<String?> cedula = const Value.absent(),
    Value<String?> comunidad = const Value.absent(),
    bool? consentimientoFirmado,
    DateTime? creadoEn,
    bool? sincronizado,
  }) => Productor(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    cedula: cedula.present ? cedula.value : this.cedula,
    comunidad: comunidad.present ? comunidad.value : this.comunidad,
    consentimientoFirmado: consentimientoFirmado ?? this.consentimientoFirmado,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Productor copyWithCompanion(ProductoresCompanion data) {
    return Productor(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      cedula: data.cedula.present ? data.cedula.value : this.cedula,
      comunidad: data.comunidad.present ? data.comunidad.value : this.comunidad,
      consentimientoFirmado: data.consentimientoFirmado.present
          ? data.consentimientoFirmado.value
          : this.consentimientoFirmado,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Productor(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('cedula: $cedula, ')
          ..write('comunidad: $comunidad, ')
          ..write('consentimientoFirmado: $consentimientoFirmado, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nombre,
    cedula,
    comunidad,
    consentimientoFirmado,
    creadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Productor &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.cedula == this.cedula &&
          other.comunidad == this.comunidad &&
          other.consentimientoFirmado == this.consentimientoFirmado &&
          other.creadoEn == this.creadoEn &&
          other.sincronizado == this.sincronizado);
}

class ProductoresCompanion extends UpdateCompanion<Productor> {
  final Value<String> id;
  final Value<String> nombre;
  final Value<String?> cedula;
  final Value<String?> comunidad;
  final Value<bool> consentimientoFirmado;
  final Value<DateTime> creadoEn;
  final Value<bool> sincronizado;
  final Value<int> rowid;
  const ProductoresCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.cedula = const Value.absent(),
    this.comunidad = const Value.absent(),
    this.consentimientoFirmado = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductoresCompanion.insert({
    required String id,
    required String nombre,
    this.cedula = const Value.absent(),
    this.comunidad = const Value.absent(),
    this.consentimientoFirmado = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombre = Value(nombre);
  static Insertable<Productor> custom({
    Expression<String>? id,
    Expression<String>? nombre,
    Expression<String>? cedula,
    Expression<String>? comunidad,
    Expression<bool>? consentimientoFirmado,
    Expression<DateTime>? creadoEn,
    Expression<bool>? sincronizado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (cedula != null) 'cedula': cedula,
      if (comunidad != null) 'comunidad': comunidad,
      if (consentimientoFirmado != null)
        'consentimiento_firmado': consentimientoFirmado,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductoresCompanion copyWith({
    Value<String>? id,
    Value<String>? nombre,
    Value<String?>? cedula,
    Value<String?>? comunidad,
    Value<bool>? consentimientoFirmado,
    Value<DateTime>? creadoEn,
    Value<bool>? sincronizado,
    Value<int>? rowid,
  }) {
    return ProductoresCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cedula: cedula ?? this.cedula,
      comunidad: comunidad ?? this.comunidad,
      consentimientoFirmado:
          consentimientoFirmado ?? this.consentimientoFirmado,
      creadoEn: creadoEn ?? this.creadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (cedula.present) {
      map['cedula'] = Variable<String>(cedula.value);
    }
    if (comunidad.present) {
      map['comunidad'] = Variable<String>(comunidad.value);
    }
    if (consentimientoFirmado.present) {
      map['consentimiento_firmado'] = Variable<bool>(
        consentimientoFirmado.value,
      );
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductoresCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('cedula: $cedula, ')
          ..write('comunidad: $comunidad, ')
          ..write('consentimientoFirmado: $consentimientoFirmado, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FincasTable extends Fincas with TableInfo<$FincasTable, Finca> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FincasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productorIdMeta = const VerificationMeta(
    'productorId',
  );
  @override
  late final GeneratedColumn<String> productorId = GeneratedColumn<String>(
    'productor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES productores (id)',
    ),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cultivoMeta = const VerificationMeta(
    'cultivo',
  );
  @override
  late final GeneratedColumn<String> cultivo = GeneratedColumn<String>(
    'cultivo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cafe'),
  );
  static const VerificationMeta _coordenadasJsonMeta = const VerificationMeta(
    'coordenadasJson',
  );
  @override
  late final GeneratedColumn<String> coordenadasJson = GeneratedColumn<String>(
    'coordenadas_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaHaMeta = const VerificationMeta('areaHa');
  @override
  late final GeneratedColumn<double> areaHa = GeneratedColumn<double>(
    'area_ha',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaOficialHaMeta = const VerificationMeta(
    'areaOficialHa',
  );
  @override
  late final GeneratedColumn<double> areaOficialHa = GeneratedColumn<double>(
    'area_oficial_ha',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoHashMeta = const VerificationMeta(
    'geoHash',
  );
  @override
  late final GeneratedColumn<String> geoHash = GeneratedColumn<String>(
    'geo_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attestationUidMeta = const VerificationMeta(
    'attestationUid',
  );
  @override
  late final GeneratedColumn<String> attestationUid = GeneratedColumn<String>(
    'attestation_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deforestacionMeta = const VerificationMeta(
    'deforestacion',
  );
  @override
  late final GeneratedColumn<String> deforestacion = GeneratedColumn<String>(
    'deforestacion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pendiente'),
  );
  static const VerificationMeta _ultimoChequeoMeta = const VerificationMeta(
    'ultimoChequeo',
  );
  @override
  late final GeneratedColumn<DateTime> ultimoChequeo =
      GeneratedColumn<DateTime>(
        'ultimo_chequeo',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productorId,
    nombre,
    cultivo,
    coordenadasJson,
    areaHa,
    areaOficialHa,
    geoHash,
    attestationUid,
    creadoEn,
    sincronizado,
    version,
    deforestacion,
    ultimoChequeo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fincas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Finca> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('productor_id')) {
      context.handle(
        _productorIdMeta,
        productorId.isAcceptableOrUnknown(
          data['productor_id']!,
          _productorIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productorIdMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('cultivo')) {
      context.handle(
        _cultivoMeta,
        cultivo.isAcceptableOrUnknown(data['cultivo']!, _cultivoMeta),
      );
    }
    if (data.containsKey('coordenadas_json')) {
      context.handle(
        _coordenadasJsonMeta,
        coordenadasJson.isAcceptableOrUnknown(
          data['coordenadas_json']!,
          _coordenadasJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coordenadasJsonMeta);
    }
    if (data.containsKey('area_ha')) {
      context.handle(
        _areaHaMeta,
        areaHa.isAcceptableOrUnknown(data['area_ha']!, _areaHaMeta),
      );
    } else if (isInserting) {
      context.missing(_areaHaMeta);
    }
    if (data.containsKey('area_oficial_ha')) {
      context.handle(
        _areaOficialHaMeta,
        areaOficialHa.isAcceptableOrUnknown(
          data['area_oficial_ha']!,
          _areaOficialHaMeta,
        ),
      );
    }
    if (data.containsKey('geo_hash')) {
      context.handle(
        _geoHashMeta,
        geoHash.isAcceptableOrUnknown(data['geo_hash']!, _geoHashMeta),
      );
    } else if (isInserting) {
      context.missing(_geoHashMeta);
    }
    if (data.containsKey('attestation_uid')) {
      context.handle(
        _attestationUidMeta,
        attestationUid.isAcceptableOrUnknown(
          data['attestation_uid']!,
          _attestationUidMeta,
        ),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deforestacion')) {
      context.handle(
        _deforestacionMeta,
        deforestacion.isAcceptableOrUnknown(
          data['deforestacion']!,
          _deforestacionMeta,
        ),
      );
    }
    if (data.containsKey('ultimo_chequeo')) {
      context.handle(
        _ultimoChequeoMeta,
        ultimoChequeo.isAcceptableOrUnknown(
          data['ultimo_chequeo']!,
          _ultimoChequeoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Finca map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Finca(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}productor_id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      cultivo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cultivo'],
      )!,
      coordenadasJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coordenadas_json'],
      )!,
      areaHa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_ha'],
      )!,
      areaOficialHa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_oficial_ha'],
      ),
      geoHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geo_hash'],
      )!,
      attestationUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attestation_uid'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deforestacion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deforestacion'],
      )!,
      ultimoChequeo: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ultimo_chequeo'],
      ),
    );
  }

  @override
  $FincasTable createAlias(String alias) {
    return $FincasTable(attachedDatabase, alias);
  }
}

class Finca extends DataClass implements Insertable<Finca> {
  final String id;
  final String productorId;
  final String nombre;

  /// Id de `schemas/cultivos.json` (`cafe`, `cacao`). Define los estados de
  /// sus entregas y qué temporada les toca.
  final String cultivo;

  /// Coordenadas en GeoJSON: `[[lon, lat], ...]`. Un solo punto si la finca
  /// mide menos de 4 ha; polígono cerrado si mide 4 ha o más (regla EUDR).
  final String coordenadasJson;
  final double areaHa;

  /// Área que calcula el servidor (PostGIS, sobre el elipsoide). Es la que
  /// va al paquete EUDR; llega al sincronizar.
  final double? areaOficialHa;

  /// Hash SHA-256 de las coordenadas canónicas; es lo que va a la blockchain.
  final String geoHash;

  /// UID de la attestation en EAS, cuando el backend ya la firmó.
  final String? attestationUid;
  final DateTime creadoEn;
  final bool sincronizado;

  /// Versión del lindero vigente (sube con cada lindero nuevo).
  final int version;

  /// Último chequeo satelital: `pendiente`, `verde`, `amarillo` o `rojo`.
  final String deforestacion;
  final DateTime? ultimoChequeo;
  const Finca({
    required this.id,
    required this.productorId,
    required this.nombre,
    required this.cultivo,
    required this.coordenadasJson,
    required this.areaHa,
    this.areaOficialHa,
    required this.geoHash,
    this.attestationUid,
    required this.creadoEn,
    required this.sincronizado,
    required this.version,
    required this.deforestacion,
    this.ultimoChequeo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['productor_id'] = Variable<String>(productorId);
    map['nombre'] = Variable<String>(nombre);
    map['cultivo'] = Variable<String>(cultivo);
    map['coordenadas_json'] = Variable<String>(coordenadasJson);
    map['area_ha'] = Variable<double>(areaHa);
    if (!nullToAbsent || areaOficialHa != null) {
      map['area_oficial_ha'] = Variable<double>(areaOficialHa);
    }
    map['geo_hash'] = Variable<String>(geoHash);
    if (!nullToAbsent || attestationUid != null) {
      map['attestation_uid'] = Variable<String>(attestationUid);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    map['version'] = Variable<int>(version);
    map['deforestacion'] = Variable<String>(deforestacion);
    if (!nullToAbsent || ultimoChequeo != null) {
      map['ultimo_chequeo'] = Variable<DateTime>(ultimoChequeo);
    }
    return map;
  }

  FincasCompanion toCompanion(bool nullToAbsent) {
    return FincasCompanion(
      id: Value(id),
      productorId: Value(productorId),
      nombre: Value(nombre),
      cultivo: Value(cultivo),
      coordenadasJson: Value(coordenadasJson),
      areaHa: Value(areaHa),
      areaOficialHa: areaOficialHa == null && nullToAbsent
          ? const Value.absent()
          : Value(areaOficialHa),
      geoHash: Value(geoHash),
      attestationUid: attestationUid == null && nullToAbsent
          ? const Value.absent()
          : Value(attestationUid),
      creadoEn: Value(creadoEn),
      sincronizado: Value(sincronizado),
      version: Value(version),
      deforestacion: Value(deforestacion),
      ultimoChequeo: ultimoChequeo == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimoChequeo),
    );
  }

  factory Finca.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Finca(
      id: serializer.fromJson<String>(json['id']),
      productorId: serializer.fromJson<String>(json['productorId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      cultivo: serializer.fromJson<String>(json['cultivo']),
      coordenadasJson: serializer.fromJson<String>(json['coordenadasJson']),
      areaHa: serializer.fromJson<double>(json['areaHa']),
      areaOficialHa: serializer.fromJson<double?>(json['areaOficialHa']),
      geoHash: serializer.fromJson<String>(json['geoHash']),
      attestationUid: serializer.fromJson<String?>(json['attestationUid']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
      version: serializer.fromJson<int>(json['version']),
      deforestacion: serializer.fromJson<String>(json['deforestacion']),
      ultimoChequeo: serializer.fromJson<DateTime?>(json['ultimoChequeo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productorId': serializer.toJson<String>(productorId),
      'nombre': serializer.toJson<String>(nombre),
      'cultivo': serializer.toJson<String>(cultivo),
      'coordenadasJson': serializer.toJson<String>(coordenadasJson),
      'areaHa': serializer.toJson<double>(areaHa),
      'areaOficialHa': serializer.toJson<double?>(areaOficialHa),
      'geoHash': serializer.toJson<String>(geoHash),
      'attestationUid': serializer.toJson<String?>(attestationUid),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
      'version': serializer.toJson<int>(version),
      'deforestacion': serializer.toJson<String>(deforestacion),
      'ultimoChequeo': serializer.toJson<DateTime?>(ultimoChequeo),
    };
  }

  Finca copyWith({
    String? id,
    String? productorId,
    String? nombre,
    String? cultivo,
    String? coordenadasJson,
    double? areaHa,
    Value<double?> areaOficialHa = const Value.absent(),
    String? geoHash,
    Value<String?> attestationUid = const Value.absent(),
    DateTime? creadoEn,
    bool? sincronizado,
    int? version,
    String? deforestacion,
    Value<DateTime?> ultimoChequeo = const Value.absent(),
  }) => Finca(
    id: id ?? this.id,
    productorId: productorId ?? this.productorId,
    nombre: nombre ?? this.nombre,
    cultivo: cultivo ?? this.cultivo,
    coordenadasJson: coordenadasJson ?? this.coordenadasJson,
    areaHa: areaHa ?? this.areaHa,
    areaOficialHa: areaOficialHa.present
        ? areaOficialHa.value
        : this.areaOficialHa,
    geoHash: geoHash ?? this.geoHash,
    attestationUid: attestationUid.present
        ? attestationUid.value
        : this.attestationUid,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
    version: version ?? this.version,
    deforestacion: deforestacion ?? this.deforestacion,
    ultimoChequeo: ultimoChequeo.present
        ? ultimoChequeo.value
        : this.ultimoChequeo,
  );
  Finca copyWithCompanion(FincasCompanion data) {
    return Finca(
      id: data.id.present ? data.id.value : this.id,
      productorId: data.productorId.present
          ? data.productorId.value
          : this.productorId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      cultivo: data.cultivo.present ? data.cultivo.value : this.cultivo,
      coordenadasJson: data.coordenadasJson.present
          ? data.coordenadasJson.value
          : this.coordenadasJson,
      areaHa: data.areaHa.present ? data.areaHa.value : this.areaHa,
      areaOficialHa: data.areaOficialHa.present
          ? data.areaOficialHa.value
          : this.areaOficialHa,
      geoHash: data.geoHash.present ? data.geoHash.value : this.geoHash,
      attestationUid: data.attestationUid.present
          ? data.attestationUid.value
          : this.attestationUid,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
      version: data.version.present ? data.version.value : this.version,
      deforestacion: data.deforestacion.present
          ? data.deforestacion.value
          : this.deforestacion,
      ultimoChequeo: data.ultimoChequeo.present
          ? data.ultimoChequeo.value
          : this.ultimoChequeo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Finca(')
          ..write('id: $id, ')
          ..write('productorId: $productorId, ')
          ..write('nombre: $nombre, ')
          ..write('cultivo: $cultivo, ')
          ..write('coordenadasJson: $coordenadasJson, ')
          ..write('areaHa: $areaHa, ')
          ..write('areaOficialHa: $areaOficialHa, ')
          ..write('geoHash: $geoHash, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('version: $version, ')
          ..write('deforestacion: $deforestacion, ')
          ..write('ultimoChequeo: $ultimoChequeo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productorId,
    nombre,
    cultivo,
    coordenadasJson,
    areaHa,
    areaOficialHa,
    geoHash,
    attestationUid,
    creadoEn,
    sincronizado,
    version,
    deforestacion,
    ultimoChequeo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Finca &&
          other.id == this.id &&
          other.productorId == this.productorId &&
          other.nombre == this.nombre &&
          other.cultivo == this.cultivo &&
          other.coordenadasJson == this.coordenadasJson &&
          other.areaHa == this.areaHa &&
          other.areaOficialHa == this.areaOficialHa &&
          other.geoHash == this.geoHash &&
          other.attestationUid == this.attestationUid &&
          other.creadoEn == this.creadoEn &&
          other.sincronizado == this.sincronizado &&
          other.version == this.version &&
          other.deforestacion == this.deforestacion &&
          other.ultimoChequeo == this.ultimoChequeo);
}

class FincasCompanion extends UpdateCompanion<Finca> {
  final Value<String> id;
  final Value<String> productorId;
  final Value<String> nombre;
  final Value<String> cultivo;
  final Value<String> coordenadasJson;
  final Value<double> areaHa;
  final Value<double?> areaOficialHa;
  final Value<String> geoHash;
  final Value<String?> attestationUid;
  final Value<DateTime> creadoEn;
  final Value<bool> sincronizado;
  final Value<int> version;
  final Value<String> deforestacion;
  final Value<DateTime?> ultimoChequeo;
  final Value<int> rowid;
  const FincasCompanion({
    this.id = const Value.absent(),
    this.productorId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.cultivo = const Value.absent(),
    this.coordenadasJson = const Value.absent(),
    this.areaHa = const Value.absent(),
    this.areaOficialHa = const Value.absent(),
    this.geoHash = const Value.absent(),
    this.attestationUid = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.version = const Value.absent(),
    this.deforestacion = const Value.absent(),
    this.ultimoChequeo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FincasCompanion.insert({
    required String id,
    required String productorId,
    required String nombre,
    this.cultivo = const Value.absent(),
    required String coordenadasJson,
    required double areaHa,
    this.areaOficialHa = const Value.absent(),
    required String geoHash,
    this.attestationUid = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.version = const Value.absent(),
    this.deforestacion = const Value.absent(),
    this.ultimoChequeo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productorId = Value(productorId),
       nombre = Value(nombre),
       coordenadasJson = Value(coordenadasJson),
       areaHa = Value(areaHa),
       geoHash = Value(geoHash);
  static Insertable<Finca> custom({
    Expression<String>? id,
    Expression<String>? productorId,
    Expression<String>? nombre,
    Expression<String>? cultivo,
    Expression<String>? coordenadasJson,
    Expression<double>? areaHa,
    Expression<double>? areaOficialHa,
    Expression<String>? geoHash,
    Expression<String>? attestationUid,
    Expression<DateTime>? creadoEn,
    Expression<bool>? sincronizado,
    Expression<int>? version,
    Expression<String>? deforestacion,
    Expression<DateTime>? ultimoChequeo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productorId != null) 'productor_id': productorId,
      if (nombre != null) 'nombre': nombre,
      if (cultivo != null) 'cultivo': cultivo,
      if (coordenadasJson != null) 'coordenadas_json': coordenadasJson,
      if (areaHa != null) 'area_ha': areaHa,
      if (areaOficialHa != null) 'area_oficial_ha': areaOficialHa,
      if (geoHash != null) 'geo_hash': geoHash,
      if (attestationUid != null) 'attestation_uid': attestationUid,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (version != null) 'version': version,
      if (deforestacion != null) 'deforestacion': deforestacion,
      if (ultimoChequeo != null) 'ultimo_chequeo': ultimoChequeo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FincasCompanion copyWith({
    Value<String>? id,
    Value<String>? productorId,
    Value<String>? nombre,
    Value<String>? cultivo,
    Value<String>? coordenadasJson,
    Value<double>? areaHa,
    Value<double?>? areaOficialHa,
    Value<String>? geoHash,
    Value<String?>? attestationUid,
    Value<DateTime>? creadoEn,
    Value<bool>? sincronizado,
    Value<int>? version,
    Value<String>? deforestacion,
    Value<DateTime?>? ultimoChequeo,
    Value<int>? rowid,
  }) {
    return FincasCompanion(
      id: id ?? this.id,
      productorId: productorId ?? this.productorId,
      nombre: nombre ?? this.nombre,
      cultivo: cultivo ?? this.cultivo,
      coordenadasJson: coordenadasJson ?? this.coordenadasJson,
      areaHa: areaHa ?? this.areaHa,
      areaOficialHa: areaOficialHa ?? this.areaOficialHa,
      geoHash: geoHash ?? this.geoHash,
      attestationUid: attestationUid ?? this.attestationUid,
      creadoEn: creadoEn ?? this.creadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
      version: version ?? this.version,
      deforestacion: deforestacion ?? this.deforestacion,
      ultimoChequeo: ultimoChequeo ?? this.ultimoChequeo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productorId.present) {
      map['productor_id'] = Variable<String>(productorId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (cultivo.present) {
      map['cultivo'] = Variable<String>(cultivo.value);
    }
    if (coordenadasJson.present) {
      map['coordenadas_json'] = Variable<String>(coordenadasJson.value);
    }
    if (areaHa.present) {
      map['area_ha'] = Variable<double>(areaHa.value);
    }
    if (areaOficialHa.present) {
      map['area_oficial_ha'] = Variable<double>(areaOficialHa.value);
    }
    if (geoHash.present) {
      map['geo_hash'] = Variable<String>(geoHash.value);
    }
    if (attestationUid.present) {
      map['attestation_uid'] = Variable<String>(attestationUid.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deforestacion.present) {
      map['deforestacion'] = Variable<String>(deforestacion.value);
    }
    if (ultimoChequeo.present) {
      map['ultimo_chequeo'] = Variable<DateTime>(ultimoChequeo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FincasCompanion(')
          ..write('id: $id, ')
          ..write('productorId: $productorId, ')
          ..write('nombre: $nombre, ')
          ..write('cultivo: $cultivo, ')
          ..write('coordenadasJson: $coordenadasJson, ')
          ..write('areaHa: $areaHa, ')
          ..write('areaOficialHa: $areaOficialHa, ')
          ..write('geoHash: $geoHash, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('version: $version, ')
          ..write('deforestacion: $deforestacion, ')
          ..write('ultimoChequeo: $ultimoChequeo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TemporadasTable extends Temporadas
    with TableInfo<$TemporadasTable, Temporada> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemporadasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inicioMeta = const VerificationMeta('inicio');
  @override
  late final GeneratedColumn<DateTime> inicio = GeneratedColumn<DateTime>(
    'inicio',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finMeta = const VerificationMeta('fin');
  @override
  late final GeneratedColumn<DateTime> fin = GeneratedColumn<DateTime>(
    'fin',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cultivoMeta = const VerificationMeta(
    'cultivo',
  );
  @override
  late final GeneratedColumn<String> cultivo = GeneratedColumn<String>(
    'cultivo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nombre, inicio, fin, cultivo];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'temporadas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Temporada> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('inicio')) {
      context.handle(
        _inicioMeta,
        inicio.isAcceptableOrUnknown(data['inicio']!, _inicioMeta),
      );
    } else if (isInserting) {
      context.missing(_inicioMeta);
    }
    if (data.containsKey('fin')) {
      context.handle(
        _finMeta,
        fin.isAcceptableOrUnknown(data['fin']!, _finMeta),
      );
    } else if (isInserting) {
      context.missing(_finMeta);
    }
    if (data.containsKey('cultivo')) {
      context.handle(
        _cultivoMeta,
        cultivo.isAcceptableOrUnknown(data['cultivo']!, _cultivoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Temporada map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Temporada(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      inicio: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}inicio'],
      )!,
      fin: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fin'],
      )!,
      cultivo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cultivo'],
      ),
    );
  }

  @override
  $TemporadasTable createAlias(String alias) {
    return $TemporadasTable(attachedDatabase, alias);
  }
}

class Temporada extends DataClass implements Insertable<Temporada> {
  final String id;
  final String nombre;

  /// Días de calendario en Nicaragua, ambos incluidos.
  final DateTime inicio;
  final DateTime fin;

  /// Cultivo al que aplica; `null` = a todos los de la organización.
  final String? cultivo;
  const Temporada({
    required this.id,
    required this.nombre,
    required this.inicio,
    required this.fin,
    this.cultivo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre'] = Variable<String>(nombre);
    map['inicio'] = Variable<DateTime>(inicio);
    map['fin'] = Variable<DateTime>(fin);
    if (!nullToAbsent || cultivo != null) {
      map['cultivo'] = Variable<String>(cultivo);
    }
    return map;
  }

  TemporadasCompanion toCompanion(bool nullToAbsent) {
    return TemporadasCompanion(
      id: Value(id),
      nombre: Value(nombre),
      inicio: Value(inicio),
      fin: Value(fin),
      cultivo: cultivo == null && nullToAbsent
          ? const Value.absent()
          : Value(cultivo),
    );
  }

  factory Temporada.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Temporada(
      id: serializer.fromJson<String>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      inicio: serializer.fromJson<DateTime>(json['inicio']),
      fin: serializer.fromJson<DateTime>(json['fin']),
      cultivo: serializer.fromJson<String?>(json['cultivo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombre': serializer.toJson<String>(nombre),
      'inicio': serializer.toJson<DateTime>(inicio),
      'fin': serializer.toJson<DateTime>(fin),
      'cultivo': serializer.toJson<String?>(cultivo),
    };
  }

  Temporada copyWith({
    String? id,
    String? nombre,
    DateTime? inicio,
    DateTime? fin,
    Value<String?> cultivo = const Value.absent(),
  }) => Temporada(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    inicio: inicio ?? this.inicio,
    fin: fin ?? this.fin,
    cultivo: cultivo.present ? cultivo.value : this.cultivo,
  );
  Temporada copyWithCompanion(TemporadasCompanion data) {
    return Temporada(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      inicio: data.inicio.present ? data.inicio.value : this.inicio,
      fin: data.fin.present ? data.fin.value : this.fin,
      cultivo: data.cultivo.present ? data.cultivo.value : this.cultivo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Temporada(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('inicio: $inicio, ')
          ..write('fin: $fin, ')
          ..write('cultivo: $cultivo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, inicio, fin, cultivo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Temporada &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.inicio == this.inicio &&
          other.fin == this.fin &&
          other.cultivo == this.cultivo);
}

class TemporadasCompanion extends UpdateCompanion<Temporada> {
  final Value<String> id;
  final Value<String> nombre;
  final Value<DateTime> inicio;
  final Value<DateTime> fin;
  final Value<String?> cultivo;
  final Value<int> rowid;
  const TemporadasCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.inicio = const Value.absent(),
    this.fin = const Value.absent(),
    this.cultivo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TemporadasCompanion.insert({
    required String id,
    required String nombre,
    required DateTime inicio,
    required DateTime fin,
    this.cultivo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombre = Value(nombre),
       inicio = Value(inicio),
       fin = Value(fin);
  static Insertable<Temporada> custom({
    Expression<String>? id,
    Expression<String>? nombre,
    Expression<DateTime>? inicio,
    Expression<DateTime>? fin,
    Expression<String>? cultivo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (inicio != null) 'inicio': inicio,
      if (fin != null) 'fin': fin,
      if (cultivo != null) 'cultivo': cultivo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TemporadasCompanion copyWith({
    Value<String>? id,
    Value<String>? nombre,
    Value<DateTime>? inicio,
    Value<DateTime>? fin,
    Value<String?>? cultivo,
    Value<int>? rowid,
  }) {
    return TemporadasCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      inicio: inicio ?? this.inicio,
      fin: fin ?? this.fin,
      cultivo: cultivo ?? this.cultivo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (inicio.present) {
      map['inicio'] = Variable<DateTime>(inicio.value);
    }
    if (fin.present) {
      map['fin'] = Variable<DateTime>(fin.value);
    }
    if (cultivo.present) {
      map['cultivo'] = Variable<String>(cultivo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemporadasCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('inicio: $inicio, ')
          ..write('fin: $fin, ')
          ..write('cultivo: $cultivo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CultivosOrganizacionTable extends CultivosOrganizacion
    with TableInfo<$CultivosOrganizacionTable, CultivosOrganizacionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CultivosOrganizacionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cultivos_organizacion';
  @override
  VerificationContext validateIntegrity(
    Insertable<CultivosOrganizacionData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CultivosOrganizacionData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CultivosOrganizacionData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $CultivosOrganizacionTable createAlias(String alias) {
    return $CultivosOrganizacionTable(attachedDatabase, alias);
  }
}

class CultivosOrganizacionData extends DataClass
    implements Insertable<CultivosOrganizacionData> {
  final String id;
  const CultivosOrganizacionData({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    return map;
  }

  CultivosOrganizacionCompanion toCompanion(bool nullToAbsent) {
    return CultivosOrganizacionCompanion(id: Value(id));
  }

  factory CultivosOrganizacionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CultivosOrganizacionData(
      id: serializer.fromJson<String>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<String>(id)};
  }

  CultivosOrganizacionData copyWith({String? id}) =>
      CultivosOrganizacionData(id: id ?? this.id);
  CultivosOrganizacionData copyWithCompanion(
    CultivosOrganizacionCompanion data,
  ) {
    return CultivosOrganizacionData(
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CultivosOrganizacionData(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CultivosOrganizacionData && other.id == this.id);
}

class CultivosOrganizacionCompanion
    extends UpdateCompanion<CultivosOrganizacionData> {
  final Value<String> id;
  final Value<int> rowid;
  const CultivosOrganizacionCompanion({
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CultivosOrganizacionCompanion.insert({
    required String id,
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<CultivosOrganizacionData> custom({
    Expression<String>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CultivosOrganizacionCompanion copyWith({
    Value<String>? id,
    Value<int>? rowid,
  }) {
    return CultivosOrganizacionCompanion(
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CultivosOrganizacionCompanion(')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VersionesFincaTable extends VersionesFinca
    with TableInfo<$VersionesFincaTable, VersionesFincaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VersionesFincaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fincaIdMeta = const VerificationMeta(
    'fincaId',
  );
  @override
  late final GeneratedColumn<String> fincaId = GeneratedColumn<String>(
    'finca_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES fincas (id)',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coordenadasJsonMeta = const VerificationMeta(
    'coordenadasJson',
  );
  @override
  late final GeneratedColumn<String> coordenadasJson = GeneratedColumn<String>(
    'coordenadas_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaHaMeta = const VerificationMeta('areaHa');
  @override
  late final GeneratedColumn<double> areaHa = GeneratedColumn<double>(
    'area_ha',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geoHashMeta = const VerificationMeta(
    'geoHash',
  );
  @override
  late final GeneratedColumn<String> geoHash = GeneratedColumn<String>(
    'geo_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fincaId,
    version,
    coordenadasJson,
    areaHa,
    geoHash,
    creadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'versiones_finca';
  @override
  VerificationContext validateIntegrity(
    Insertable<VersionesFincaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('finca_id')) {
      context.handle(
        _fincaIdMeta,
        fincaId.isAcceptableOrUnknown(data['finca_id']!, _fincaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fincaIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('coordenadas_json')) {
      context.handle(
        _coordenadasJsonMeta,
        coordenadasJson.isAcceptableOrUnknown(
          data['coordenadas_json']!,
          _coordenadasJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coordenadasJsonMeta);
    }
    if (data.containsKey('area_ha')) {
      context.handle(
        _areaHaMeta,
        areaHa.isAcceptableOrUnknown(data['area_ha']!, _areaHaMeta),
      );
    } else if (isInserting) {
      context.missing(_areaHaMeta);
    }
    if (data.containsKey('geo_hash')) {
      context.handle(
        _geoHashMeta,
        geoHash.isAcceptableOrUnknown(data['geo_hash']!, _geoHashMeta),
      );
    } else if (isInserting) {
      context.missing(_geoHashMeta);
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fincaId, version};
  @override
  VersionesFincaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VersionesFincaData(
      fincaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finca_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      coordenadasJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coordenadas_json'],
      )!,
      areaHa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_ha'],
      )!,
      geoHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geo_hash'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $VersionesFincaTable createAlias(String alias) {
    return $VersionesFincaTable(attachedDatabase, alias);
  }
}

class VersionesFincaData extends DataClass
    implements Insertable<VersionesFincaData> {
  final String fincaId;
  final int version;
  final String coordenadasJson;
  final double areaHa;
  final String geoHash;
  final DateTime creadoEn;
  final bool sincronizado;
  const VersionesFincaData({
    required this.fincaId,
    required this.version,
    required this.coordenadasJson,
    required this.areaHa,
    required this.geoHash,
    required this.creadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['finca_id'] = Variable<String>(fincaId);
    map['version'] = Variable<int>(version);
    map['coordenadas_json'] = Variable<String>(coordenadasJson);
    map['area_ha'] = Variable<double>(areaHa);
    map['geo_hash'] = Variable<String>(geoHash);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  VersionesFincaCompanion toCompanion(bool nullToAbsent) {
    return VersionesFincaCompanion(
      fincaId: Value(fincaId),
      version: Value(version),
      coordenadasJson: Value(coordenadasJson),
      areaHa: Value(areaHa),
      geoHash: Value(geoHash),
      creadoEn: Value(creadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory VersionesFincaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VersionesFincaData(
      fincaId: serializer.fromJson<String>(json['fincaId']),
      version: serializer.fromJson<int>(json['version']),
      coordenadasJson: serializer.fromJson<String>(json['coordenadasJson']),
      areaHa: serializer.fromJson<double>(json['areaHa']),
      geoHash: serializer.fromJson<String>(json['geoHash']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fincaId': serializer.toJson<String>(fincaId),
      'version': serializer.toJson<int>(version),
      'coordenadasJson': serializer.toJson<String>(coordenadasJson),
      'areaHa': serializer.toJson<double>(areaHa),
      'geoHash': serializer.toJson<String>(geoHash),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  VersionesFincaData copyWith({
    String? fincaId,
    int? version,
    String? coordenadasJson,
    double? areaHa,
    String? geoHash,
    DateTime? creadoEn,
    bool? sincronizado,
  }) => VersionesFincaData(
    fincaId: fincaId ?? this.fincaId,
    version: version ?? this.version,
    coordenadasJson: coordenadasJson ?? this.coordenadasJson,
    areaHa: areaHa ?? this.areaHa,
    geoHash: geoHash ?? this.geoHash,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  VersionesFincaData copyWithCompanion(VersionesFincaCompanion data) {
    return VersionesFincaData(
      fincaId: data.fincaId.present ? data.fincaId.value : this.fincaId,
      version: data.version.present ? data.version.value : this.version,
      coordenadasJson: data.coordenadasJson.present
          ? data.coordenadasJson.value
          : this.coordenadasJson,
      areaHa: data.areaHa.present ? data.areaHa.value : this.areaHa,
      geoHash: data.geoHash.present ? data.geoHash.value : this.geoHash,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VersionesFincaData(')
          ..write('fincaId: $fincaId, ')
          ..write('version: $version, ')
          ..write('coordenadasJson: $coordenadasJson, ')
          ..write('areaHa: $areaHa, ')
          ..write('geoHash: $geoHash, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fincaId,
    version,
    coordenadasJson,
    areaHa,
    geoHash,
    creadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VersionesFincaData &&
          other.fincaId == this.fincaId &&
          other.version == this.version &&
          other.coordenadasJson == this.coordenadasJson &&
          other.areaHa == this.areaHa &&
          other.geoHash == this.geoHash &&
          other.creadoEn == this.creadoEn &&
          other.sincronizado == this.sincronizado);
}

class VersionesFincaCompanion extends UpdateCompanion<VersionesFincaData> {
  final Value<String> fincaId;
  final Value<int> version;
  final Value<String> coordenadasJson;
  final Value<double> areaHa;
  final Value<String> geoHash;
  final Value<DateTime> creadoEn;
  final Value<bool> sincronizado;
  final Value<int> rowid;
  const VersionesFincaCompanion({
    this.fincaId = const Value.absent(),
    this.version = const Value.absent(),
    this.coordenadasJson = const Value.absent(),
    this.areaHa = const Value.absent(),
    this.geoHash = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VersionesFincaCompanion.insert({
    required String fincaId,
    required int version,
    required String coordenadasJson,
    required double areaHa,
    required String geoHash,
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fincaId = Value(fincaId),
       version = Value(version),
       coordenadasJson = Value(coordenadasJson),
       areaHa = Value(areaHa),
       geoHash = Value(geoHash);
  static Insertable<VersionesFincaData> custom({
    Expression<String>? fincaId,
    Expression<int>? version,
    Expression<String>? coordenadasJson,
    Expression<double>? areaHa,
    Expression<String>? geoHash,
    Expression<DateTime>? creadoEn,
    Expression<bool>? sincronizado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fincaId != null) 'finca_id': fincaId,
      if (version != null) 'version': version,
      if (coordenadasJson != null) 'coordenadas_json': coordenadasJson,
      if (areaHa != null) 'area_ha': areaHa,
      if (geoHash != null) 'geo_hash': geoHash,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VersionesFincaCompanion copyWith({
    Value<String>? fincaId,
    Value<int>? version,
    Value<String>? coordenadasJson,
    Value<double>? areaHa,
    Value<String>? geoHash,
    Value<DateTime>? creadoEn,
    Value<bool>? sincronizado,
    Value<int>? rowid,
  }) {
    return VersionesFincaCompanion(
      fincaId: fincaId ?? this.fincaId,
      version: version ?? this.version,
      coordenadasJson: coordenadasJson ?? this.coordenadasJson,
      areaHa: areaHa ?? this.areaHa,
      geoHash: geoHash ?? this.geoHash,
      creadoEn: creadoEn ?? this.creadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fincaId.present) {
      map['finca_id'] = Variable<String>(fincaId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (coordenadasJson.present) {
      map['coordenadas_json'] = Variable<String>(coordenadasJson.value);
    }
    if (areaHa.present) {
      map['area_ha'] = Variable<double>(areaHa.value);
    }
    if (geoHash.present) {
      map['geo_hash'] = Variable<String>(geoHash.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VersionesFincaCompanion(')
          ..write('fincaId: $fincaId, ')
          ..write('version: $version, ')
          ..write('coordenadasJson: $coordenadasJson, ')
          ..write('areaHa: $areaHa, ')
          ..write('geoHash: $geoHash, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VerificacionesTable extends Verificaciones
    with TableInfo<$VerificacionesTable, Verificacion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VerificacionesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fincaIdMeta = const VerificationMeta(
    'fincaId',
  );
  @override
  late final GeneratedColumn<String> fincaId = GeneratedColumn<String>(
    'finca_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES fincas (id)',
    ),
  );
  static const VerificationMeta _temporadaIdMeta = const VerificationMeta(
    'temporadaId',
  );
  @override
  late final GeneratedColumn<String> temporadaId = GeneratedColumn<String>(
    'temporada_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<DateTime> fecha = GeneratedColumn<DateTime>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linderoCambioMeta = const VerificationMeta(
    'linderoCambio',
  );
  @override
  late final GeneratedColumn<bool> linderoCambio = GeneratedColumn<bool>(
    'lindero_cambio',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lindero_cambio" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionFincaMeta = const VerificationMeta(
    'versionFinca',
  );
  @override
  late final GeneratedColumn<int> versionFinca = GeneratedColumn<int>(
    'version_finca',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notaMeta = const VerificationMeta('nota');
  @override
  late final GeneratedColumn<String> nota = GeneratedColumn<String>(
    'nota',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fincaId,
    temporadaId,
    fecha,
    linderoCambio,
    versionFinca,
    nota,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'verificaciones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Verificacion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('finca_id')) {
      context.handle(
        _fincaIdMeta,
        fincaId.isAcceptableOrUnknown(data['finca_id']!, _fincaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fincaIdMeta);
    }
    if (data.containsKey('temporada_id')) {
      context.handle(
        _temporadaIdMeta,
        temporadaId.isAcceptableOrUnknown(
          data['temporada_id']!,
          _temporadaIdMeta,
        ),
      );
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('lindero_cambio')) {
      context.handle(
        _linderoCambioMeta,
        linderoCambio.isAcceptableOrUnknown(
          data['lindero_cambio']!,
          _linderoCambioMeta,
        ),
      );
    }
    if (data.containsKey('version_finca')) {
      context.handle(
        _versionFincaMeta,
        versionFinca.isAcceptableOrUnknown(
          data['version_finca']!,
          _versionFincaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionFincaMeta);
    }
    if (data.containsKey('nota')) {
      context.handle(
        _notaMeta,
        nota.isAcceptableOrUnknown(data['nota']!, _notaMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Verificacion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Verificacion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fincaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finca_id'],
      )!,
      temporadaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporada_id'],
      ),
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha'],
      )!,
      linderoCambio: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lindero_cambio'],
      )!,
      versionFinca: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version_finca'],
      )!,
      nota: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nota'],
      ),
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $VerificacionesTable createAlias(String alias) {
    return $VerificacionesTable(attachedDatabase, alias);
  }
}

class Verificacion extends DataClass implements Insertable<Verificacion> {
  final String id;
  final String fincaId;

  /// La asigna el servidor por la fecha; en el celular se calcula igual.
  final String? temporadaId;
  final DateTime fecha;
  final bool linderoCambio;
  final int versionFinca;
  final String? nota;
  final bool sincronizado;
  const Verificacion({
    required this.id,
    required this.fincaId,
    this.temporadaId,
    required this.fecha,
    required this.linderoCambio,
    required this.versionFinca,
    this.nota,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['finca_id'] = Variable<String>(fincaId);
    if (!nullToAbsent || temporadaId != null) {
      map['temporada_id'] = Variable<String>(temporadaId);
    }
    map['fecha'] = Variable<DateTime>(fecha);
    map['lindero_cambio'] = Variable<bool>(linderoCambio);
    map['version_finca'] = Variable<int>(versionFinca);
    if (!nullToAbsent || nota != null) {
      map['nota'] = Variable<String>(nota);
    }
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  VerificacionesCompanion toCompanion(bool nullToAbsent) {
    return VerificacionesCompanion(
      id: Value(id),
      fincaId: Value(fincaId),
      temporadaId: temporadaId == null && nullToAbsent
          ? const Value.absent()
          : Value(temporadaId),
      fecha: Value(fecha),
      linderoCambio: Value(linderoCambio),
      versionFinca: Value(versionFinca),
      nota: nota == null && nullToAbsent ? const Value.absent() : Value(nota),
      sincronizado: Value(sincronizado),
    );
  }

  factory Verificacion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Verificacion(
      id: serializer.fromJson<String>(json['id']),
      fincaId: serializer.fromJson<String>(json['fincaId']),
      temporadaId: serializer.fromJson<String?>(json['temporadaId']),
      fecha: serializer.fromJson<DateTime>(json['fecha']),
      linderoCambio: serializer.fromJson<bool>(json['linderoCambio']),
      versionFinca: serializer.fromJson<int>(json['versionFinca']),
      nota: serializer.fromJson<String?>(json['nota']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fincaId': serializer.toJson<String>(fincaId),
      'temporadaId': serializer.toJson<String?>(temporadaId),
      'fecha': serializer.toJson<DateTime>(fecha),
      'linderoCambio': serializer.toJson<bool>(linderoCambio),
      'versionFinca': serializer.toJson<int>(versionFinca),
      'nota': serializer.toJson<String?>(nota),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Verificacion copyWith({
    String? id,
    String? fincaId,
    Value<String?> temporadaId = const Value.absent(),
    DateTime? fecha,
    bool? linderoCambio,
    int? versionFinca,
    Value<String?> nota = const Value.absent(),
    bool? sincronizado,
  }) => Verificacion(
    id: id ?? this.id,
    fincaId: fincaId ?? this.fincaId,
    temporadaId: temporadaId.present ? temporadaId.value : this.temporadaId,
    fecha: fecha ?? this.fecha,
    linderoCambio: linderoCambio ?? this.linderoCambio,
    versionFinca: versionFinca ?? this.versionFinca,
    nota: nota.present ? nota.value : this.nota,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Verificacion copyWithCompanion(VerificacionesCompanion data) {
    return Verificacion(
      id: data.id.present ? data.id.value : this.id,
      fincaId: data.fincaId.present ? data.fincaId.value : this.fincaId,
      temporadaId: data.temporadaId.present
          ? data.temporadaId.value
          : this.temporadaId,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      linderoCambio: data.linderoCambio.present
          ? data.linderoCambio.value
          : this.linderoCambio,
      versionFinca: data.versionFinca.present
          ? data.versionFinca.value
          : this.versionFinca,
      nota: data.nota.present ? data.nota.value : this.nota,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Verificacion(')
          ..write('id: $id, ')
          ..write('fincaId: $fincaId, ')
          ..write('temporadaId: $temporadaId, ')
          ..write('fecha: $fecha, ')
          ..write('linderoCambio: $linderoCambio, ')
          ..write('versionFinca: $versionFinca, ')
          ..write('nota: $nota, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fincaId,
    temporadaId,
    fecha,
    linderoCambio,
    versionFinca,
    nota,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Verificacion &&
          other.id == this.id &&
          other.fincaId == this.fincaId &&
          other.temporadaId == this.temporadaId &&
          other.fecha == this.fecha &&
          other.linderoCambio == this.linderoCambio &&
          other.versionFinca == this.versionFinca &&
          other.nota == this.nota &&
          other.sincronizado == this.sincronizado);
}

class VerificacionesCompanion extends UpdateCompanion<Verificacion> {
  final Value<String> id;
  final Value<String> fincaId;
  final Value<String?> temporadaId;
  final Value<DateTime> fecha;
  final Value<bool> linderoCambio;
  final Value<int> versionFinca;
  final Value<String?> nota;
  final Value<bool> sincronizado;
  final Value<int> rowid;
  const VerificacionesCompanion({
    this.id = const Value.absent(),
    this.fincaId = const Value.absent(),
    this.temporadaId = const Value.absent(),
    this.fecha = const Value.absent(),
    this.linderoCambio = const Value.absent(),
    this.versionFinca = const Value.absent(),
    this.nota = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VerificacionesCompanion.insert({
    required String id,
    required String fincaId,
    this.temporadaId = const Value.absent(),
    required DateTime fecha,
    this.linderoCambio = const Value.absent(),
    required int versionFinca,
    this.nota = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fincaId = Value(fincaId),
       fecha = Value(fecha),
       versionFinca = Value(versionFinca);
  static Insertable<Verificacion> custom({
    Expression<String>? id,
    Expression<String>? fincaId,
    Expression<String>? temporadaId,
    Expression<DateTime>? fecha,
    Expression<bool>? linderoCambio,
    Expression<int>? versionFinca,
    Expression<String>? nota,
    Expression<bool>? sincronizado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fincaId != null) 'finca_id': fincaId,
      if (temporadaId != null) 'temporada_id': temporadaId,
      if (fecha != null) 'fecha': fecha,
      if (linderoCambio != null) 'lindero_cambio': linderoCambio,
      if (versionFinca != null) 'version_finca': versionFinca,
      if (nota != null) 'nota': nota,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VerificacionesCompanion copyWith({
    Value<String>? id,
    Value<String>? fincaId,
    Value<String?>? temporadaId,
    Value<DateTime>? fecha,
    Value<bool>? linderoCambio,
    Value<int>? versionFinca,
    Value<String?>? nota,
    Value<bool>? sincronizado,
    Value<int>? rowid,
  }) {
    return VerificacionesCompanion(
      id: id ?? this.id,
      fincaId: fincaId ?? this.fincaId,
      temporadaId: temporadaId ?? this.temporadaId,
      fecha: fecha ?? this.fecha,
      linderoCambio: linderoCambio ?? this.linderoCambio,
      versionFinca: versionFinca ?? this.versionFinca,
      nota: nota ?? this.nota,
      sincronizado: sincronizado ?? this.sincronizado,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fincaId.present) {
      map['finca_id'] = Variable<String>(fincaId.value);
    }
    if (temporadaId.present) {
      map['temporada_id'] = Variable<String>(temporadaId.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<DateTime>(fecha.value);
    }
    if (linderoCambio.present) {
      map['lindero_cambio'] = Variable<bool>(linderoCambio.value);
    }
    if (versionFinca.present) {
      map['version_finca'] = Variable<int>(versionFinca.value);
    }
    if (nota.present) {
      map['nota'] = Variable<String>(nota.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VerificacionesCompanion(')
          ..write('id: $id, ')
          ..write('fincaId: $fincaId, ')
          ..write('temporadaId: $temporadaId, ')
          ..write('fecha: $fecha, ')
          ..write('linderoCambio: $linderoCambio, ')
          ..write('versionFinca: $versionFinca, ')
          ..write('nota: $nota, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntregasTable extends Entregas with TableInfo<$EntregasTable, Entrega> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntregasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fincaIdMeta = const VerificationMeta(
    'fincaId',
  );
  @override
  late final GeneratedColumn<String> fincaId = GeneratedColumn<String>(
    'finca_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES fincas (id)',
    ),
  );
  static const VerificationMeta _temporadaIdMeta = const VerificationMeta(
    'temporadaId',
  );
  @override
  late final GeneratedColumn<String> temporadaId = GeneratedColumn<String>(
    'temporada_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kgMeta = const VerificationMeta('kg');
  @override
  late final GeneratedColumn<double> kg = GeneratedColumn<double>(
    'kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<DateTime> fecha = GeneratedColumn<DateTime>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attestationUidMeta = const VerificationMeta(
    'attestationUid',
  );
  @override
  late final GeneratedColumn<String> attestationUid = GeneratedColumn<String>(
    'attestation_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _loteCodigoMeta = const VerificationMeta(
    'loteCodigo',
  );
  @override
  late final GeneratedColumn<String> loteCodigo = GeneratedColumn<String>(
    'lote_codigo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _corregidaMeta = const VerificationMeta(
    'corregida',
  );
  @override
  late final GeneratedColumn<bool> corregida = GeneratedColumn<bool>(
    'corregida',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("corregida" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fincaId,
    temporadaId,
    kg,
    estado,
    fecha,
    attestationUid,
    creadoEn,
    sincronizado,
    loteCodigo,
    corregida,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entregas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entrega> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('finca_id')) {
      context.handle(
        _fincaIdMeta,
        fincaId.isAcceptableOrUnknown(data['finca_id']!, _fincaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fincaIdMeta);
    }
    if (data.containsKey('temporada_id')) {
      context.handle(
        _temporadaIdMeta,
        temporadaId.isAcceptableOrUnknown(
          data['temporada_id']!,
          _temporadaIdMeta,
        ),
      );
    }
    if (data.containsKey('kg')) {
      context.handle(_kgMeta, kg.isAcceptableOrUnknown(data['kg']!, _kgMeta));
    } else if (isInserting) {
      context.missing(_kgMeta);
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    } else if (isInserting) {
      context.missing(_estadoMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('attestation_uid')) {
      context.handle(
        _attestationUidMeta,
        attestationUid.isAcceptableOrUnknown(
          data['attestation_uid']!,
          _attestationUidMeta,
        ),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    if (data.containsKey('lote_codigo')) {
      context.handle(
        _loteCodigoMeta,
        loteCodigo.isAcceptableOrUnknown(data['lote_codigo']!, _loteCodigoMeta),
      );
    }
    if (data.containsKey('corregida')) {
      context.handle(
        _corregidaMeta,
        corregida.isAcceptableOrUnknown(data['corregida']!, _corregidaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entrega map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entrega(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fincaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finca_id'],
      )!,
      temporadaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporada_id'],
      ),
      kg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kg'],
      )!,
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha'],
      )!,
      attestationUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attestation_uid'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
      loteCodigo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lote_codigo'],
      ),
      corregida: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}corregida'],
      )!,
    );
  }

  @override
  $EntregasTable createAlias(String alias) {
    return $EntregasTable(attachedDatabase, alias);
  }
}

class Entrega extends DataClass implements Insertable<Entrega> {
  final String id;
  final String fincaId;
  final String? temporadaId;
  final double kg;

  /// Uno de los estados del cultivo de la finca (`cultivos.json`).
  final String estado;
  final DateTime fecha;
  final String? attestationUid;
  final DateTime creadoEn;
  final bool sincronizado;

  /// Lote en que va (llega del servidor). En un lote ya no se corrige.
  final String? loteCodigo;

  /// Tiene correcciones en el historial del servidor.
  final bool corregida;
  const Entrega({
    required this.id,
    required this.fincaId,
    this.temporadaId,
    required this.kg,
    required this.estado,
    required this.fecha,
    this.attestationUid,
    required this.creadoEn,
    required this.sincronizado,
    this.loteCodigo,
    required this.corregida,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['finca_id'] = Variable<String>(fincaId);
    if (!nullToAbsent || temporadaId != null) {
      map['temporada_id'] = Variable<String>(temporadaId);
    }
    map['kg'] = Variable<double>(kg);
    map['estado'] = Variable<String>(estado);
    map['fecha'] = Variable<DateTime>(fecha);
    if (!nullToAbsent || attestationUid != null) {
      map['attestation_uid'] = Variable<String>(attestationUid);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    if (!nullToAbsent || loteCodigo != null) {
      map['lote_codigo'] = Variable<String>(loteCodigo);
    }
    map['corregida'] = Variable<bool>(corregida);
    return map;
  }

  EntregasCompanion toCompanion(bool nullToAbsent) {
    return EntregasCompanion(
      id: Value(id),
      fincaId: Value(fincaId),
      temporadaId: temporadaId == null && nullToAbsent
          ? const Value.absent()
          : Value(temporadaId),
      kg: Value(kg),
      estado: Value(estado),
      fecha: Value(fecha),
      attestationUid: attestationUid == null && nullToAbsent
          ? const Value.absent()
          : Value(attestationUid),
      creadoEn: Value(creadoEn),
      sincronizado: Value(sincronizado),
      loteCodigo: loteCodigo == null && nullToAbsent
          ? const Value.absent()
          : Value(loteCodigo),
      corregida: Value(corregida),
    );
  }

  factory Entrega.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entrega(
      id: serializer.fromJson<String>(json['id']),
      fincaId: serializer.fromJson<String>(json['fincaId']),
      temporadaId: serializer.fromJson<String?>(json['temporadaId']),
      kg: serializer.fromJson<double>(json['kg']),
      estado: serializer.fromJson<String>(json['estado']),
      fecha: serializer.fromJson<DateTime>(json['fecha']),
      attestationUid: serializer.fromJson<String?>(json['attestationUid']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
      loteCodigo: serializer.fromJson<String?>(json['loteCodigo']),
      corregida: serializer.fromJson<bool>(json['corregida']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fincaId': serializer.toJson<String>(fincaId),
      'temporadaId': serializer.toJson<String?>(temporadaId),
      'kg': serializer.toJson<double>(kg),
      'estado': serializer.toJson<String>(estado),
      'fecha': serializer.toJson<DateTime>(fecha),
      'attestationUid': serializer.toJson<String?>(attestationUid),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
      'loteCodigo': serializer.toJson<String?>(loteCodigo),
      'corregida': serializer.toJson<bool>(corregida),
    };
  }

  Entrega copyWith({
    String? id,
    String? fincaId,
    Value<String?> temporadaId = const Value.absent(),
    double? kg,
    String? estado,
    DateTime? fecha,
    Value<String?> attestationUid = const Value.absent(),
    DateTime? creadoEn,
    bool? sincronizado,
    Value<String?> loteCodigo = const Value.absent(),
    bool? corregida,
  }) => Entrega(
    id: id ?? this.id,
    fincaId: fincaId ?? this.fincaId,
    temporadaId: temporadaId.present ? temporadaId.value : this.temporadaId,
    kg: kg ?? this.kg,
    estado: estado ?? this.estado,
    fecha: fecha ?? this.fecha,
    attestationUid: attestationUid.present
        ? attestationUid.value
        : this.attestationUid,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
    loteCodigo: loteCodigo.present ? loteCodigo.value : this.loteCodigo,
    corregida: corregida ?? this.corregida,
  );
  Entrega copyWithCompanion(EntregasCompanion data) {
    return Entrega(
      id: data.id.present ? data.id.value : this.id,
      fincaId: data.fincaId.present ? data.fincaId.value : this.fincaId,
      temporadaId: data.temporadaId.present
          ? data.temporadaId.value
          : this.temporadaId,
      kg: data.kg.present ? data.kg.value : this.kg,
      estado: data.estado.present ? data.estado.value : this.estado,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      attestationUid: data.attestationUid.present
          ? data.attestationUid.value
          : this.attestationUid,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
      loteCodigo: data.loteCodigo.present
          ? data.loteCodigo.value
          : this.loteCodigo,
      corregida: data.corregida.present ? data.corregida.value : this.corregida,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entrega(')
          ..write('id: $id, ')
          ..write('fincaId: $fincaId, ')
          ..write('temporadaId: $temporadaId, ')
          ..write('kg: $kg, ')
          ..write('estado: $estado, ')
          ..write('fecha: $fecha, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('loteCodigo: $loteCodigo, ')
          ..write('corregida: $corregida')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fincaId,
    temporadaId,
    kg,
    estado,
    fecha,
    attestationUid,
    creadoEn,
    sincronizado,
    loteCodigo,
    corregida,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entrega &&
          other.id == this.id &&
          other.fincaId == this.fincaId &&
          other.temporadaId == this.temporadaId &&
          other.kg == this.kg &&
          other.estado == this.estado &&
          other.fecha == this.fecha &&
          other.attestationUid == this.attestationUid &&
          other.creadoEn == this.creadoEn &&
          other.sincronizado == this.sincronizado &&
          other.loteCodigo == this.loteCodigo &&
          other.corregida == this.corregida);
}

class EntregasCompanion extends UpdateCompanion<Entrega> {
  final Value<String> id;
  final Value<String> fincaId;
  final Value<String?> temporadaId;
  final Value<double> kg;
  final Value<String> estado;
  final Value<DateTime> fecha;
  final Value<String?> attestationUid;
  final Value<DateTime> creadoEn;
  final Value<bool> sincronizado;
  final Value<String?> loteCodigo;
  final Value<bool> corregida;
  final Value<int> rowid;
  const EntregasCompanion({
    this.id = const Value.absent(),
    this.fincaId = const Value.absent(),
    this.temporadaId = const Value.absent(),
    this.kg = const Value.absent(),
    this.estado = const Value.absent(),
    this.fecha = const Value.absent(),
    this.attestationUid = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.loteCodigo = const Value.absent(),
    this.corregida = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntregasCompanion.insert({
    required String id,
    required String fincaId,
    this.temporadaId = const Value.absent(),
    required double kg,
    required String estado,
    required DateTime fecha,
    this.attestationUid = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.loteCodigo = const Value.absent(),
    this.corregida = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fincaId = Value(fincaId),
       kg = Value(kg),
       estado = Value(estado),
       fecha = Value(fecha);
  static Insertable<Entrega> custom({
    Expression<String>? id,
    Expression<String>? fincaId,
    Expression<String>? temporadaId,
    Expression<double>? kg,
    Expression<String>? estado,
    Expression<DateTime>? fecha,
    Expression<String>? attestationUid,
    Expression<DateTime>? creadoEn,
    Expression<bool>? sincronizado,
    Expression<String>? loteCodigo,
    Expression<bool>? corregida,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fincaId != null) 'finca_id': fincaId,
      if (temporadaId != null) 'temporada_id': temporadaId,
      if (kg != null) 'kg': kg,
      if (estado != null) 'estado': estado,
      if (fecha != null) 'fecha': fecha,
      if (attestationUid != null) 'attestation_uid': attestationUid,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (loteCodigo != null) 'lote_codigo': loteCodigo,
      if (corregida != null) 'corregida': corregida,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntregasCompanion copyWith({
    Value<String>? id,
    Value<String>? fincaId,
    Value<String?>? temporadaId,
    Value<double>? kg,
    Value<String>? estado,
    Value<DateTime>? fecha,
    Value<String?>? attestationUid,
    Value<DateTime>? creadoEn,
    Value<bool>? sincronizado,
    Value<String?>? loteCodigo,
    Value<bool>? corregida,
    Value<int>? rowid,
  }) {
    return EntregasCompanion(
      id: id ?? this.id,
      fincaId: fincaId ?? this.fincaId,
      temporadaId: temporadaId ?? this.temporadaId,
      kg: kg ?? this.kg,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
      attestationUid: attestationUid ?? this.attestationUid,
      creadoEn: creadoEn ?? this.creadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
      loteCodigo: loteCodigo ?? this.loteCodigo,
      corregida: corregida ?? this.corregida,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fincaId.present) {
      map['finca_id'] = Variable<String>(fincaId.value);
    }
    if (temporadaId.present) {
      map['temporada_id'] = Variable<String>(temporadaId.value);
    }
    if (kg.present) {
      map['kg'] = Variable<double>(kg.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<DateTime>(fecha.value);
    }
    if (attestationUid.present) {
      map['attestation_uid'] = Variable<String>(attestationUid.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    if (loteCodigo.present) {
      map['lote_codigo'] = Variable<String>(loteCodigo.value);
    }
    if (corregida.present) {
      map['corregida'] = Variable<bool>(corregida.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntregasCompanion(')
          ..write('id: $id, ')
          ..write('fincaId: $fincaId, ')
          ..write('temporadaId: $temporadaId, ')
          ..write('kg: $kg, ')
          ..write('estado: $estado, ')
          ..write('fecha: $fecha, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('loteCodigo: $loteCodigo, ')
          ..write('corregida: $corregida, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FotosTable extends Fotos with TableInfo<$FotosTable, Foto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entidadTipoMeta = const VerificationMeta(
    'entidadTipo',
  );
  @override
  late final GeneratedColumn<String> entidadTipo = GeneratedColumn<String>(
    'entidad_tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entidadIdMeta = const VerificationMeta(
    'entidadId',
  );
  @override
  late final GeneratedColumn<String> entidadId = GeneratedColumn<String>(
    'entidad_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rutaMeta = const VerificationMeta('ruta');
  @override
  late final GeneratedColumn<String> ruta = GeneratedColumn<String>(
    'ruta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _subidaMeta = const VerificationMeta('subida');
  @override
  late final GeneratedColumn<bool> subida = GeneratedColumn<bool>(
    'subida',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("subida" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entidadTipo,
    entidadId,
    tipo,
    ruta,
    sha256,
    creadoEn,
    sincronizado,
    subida,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fotos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Foto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entidad_tipo')) {
      context.handle(
        _entidadTipoMeta,
        entidadTipo.isAcceptableOrUnknown(
          data['entidad_tipo']!,
          _entidadTipoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entidadTipoMeta);
    }
    if (data.containsKey('entidad_id')) {
      context.handle(
        _entidadIdMeta,
        entidadId.isAcceptableOrUnknown(data['entidad_id']!, _entidadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entidadIdMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('ruta')) {
      context.handle(
        _rutaMeta,
        ruta.isAcceptableOrUnknown(data['ruta']!, _rutaMeta),
      );
    } else if (isInserting) {
      context.missing(_rutaMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    if (data.containsKey('subida')) {
      context.handle(
        _subidaMeta,
        subida.isAcceptableOrUnknown(data['subida']!, _subidaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Foto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Foto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entidadTipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entidad_tipo'],
      )!,
      entidadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entidad_id'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      ruta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ruta'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
      subida: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}subida'],
      )!,
    );
  }

  @override
  $FotosTable createAlias(String alias) {
    return $FotosTable(attachedDatabase, alias);
  }
}

class Foto extends DataClass implements Insertable<Foto> {
  final String id;

  /// `productor`, `finca` o `verificacion`.
  final String entidadTipo;
  final String entidadId;

  /// `consentimiento`, `finca`, `documento` o `verificacion`.
  final String tipo;
  final String ruta;
  final String sha256;
  final DateTime creadoEn;
  final bool sincronizado;
  final bool subida;
  const Foto({
    required this.id,
    required this.entidadTipo,
    required this.entidadId,
    required this.tipo,
    required this.ruta,
    required this.sha256,
    required this.creadoEn,
    required this.sincronizado,
    required this.subida,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entidad_tipo'] = Variable<String>(entidadTipo);
    map['entidad_id'] = Variable<String>(entidadId);
    map['tipo'] = Variable<String>(tipo);
    map['ruta'] = Variable<String>(ruta);
    map['sha256'] = Variable<String>(sha256);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    map['subida'] = Variable<bool>(subida);
    return map;
  }

  FotosCompanion toCompanion(bool nullToAbsent) {
    return FotosCompanion(
      id: Value(id),
      entidadTipo: Value(entidadTipo),
      entidadId: Value(entidadId),
      tipo: Value(tipo),
      ruta: Value(ruta),
      sha256: Value(sha256),
      creadoEn: Value(creadoEn),
      sincronizado: Value(sincronizado),
      subida: Value(subida),
    );
  }

  factory Foto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Foto(
      id: serializer.fromJson<String>(json['id']),
      entidadTipo: serializer.fromJson<String>(json['entidadTipo']),
      entidadId: serializer.fromJson<String>(json['entidadId']),
      tipo: serializer.fromJson<String>(json['tipo']),
      ruta: serializer.fromJson<String>(json['ruta']),
      sha256: serializer.fromJson<String>(json['sha256']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
      subida: serializer.fromJson<bool>(json['subida']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entidadTipo': serializer.toJson<String>(entidadTipo),
      'entidadId': serializer.toJson<String>(entidadId),
      'tipo': serializer.toJson<String>(tipo),
      'ruta': serializer.toJson<String>(ruta),
      'sha256': serializer.toJson<String>(sha256),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
      'subida': serializer.toJson<bool>(subida),
    };
  }

  Foto copyWith({
    String? id,
    String? entidadTipo,
    String? entidadId,
    String? tipo,
    String? ruta,
    String? sha256,
    DateTime? creadoEn,
    bool? sincronizado,
    bool? subida,
  }) => Foto(
    id: id ?? this.id,
    entidadTipo: entidadTipo ?? this.entidadTipo,
    entidadId: entidadId ?? this.entidadId,
    tipo: tipo ?? this.tipo,
    ruta: ruta ?? this.ruta,
    sha256: sha256 ?? this.sha256,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
    subida: subida ?? this.subida,
  );
  Foto copyWithCompanion(FotosCompanion data) {
    return Foto(
      id: data.id.present ? data.id.value : this.id,
      entidadTipo: data.entidadTipo.present
          ? data.entidadTipo.value
          : this.entidadTipo,
      entidadId: data.entidadId.present ? data.entidadId.value : this.entidadId,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      ruta: data.ruta.present ? data.ruta.value : this.ruta,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
      subida: data.subida.present ? data.subida.value : this.subida,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Foto(')
          ..write('id: $id, ')
          ..write('entidadTipo: $entidadTipo, ')
          ..write('entidadId: $entidadId, ')
          ..write('tipo: $tipo, ')
          ..write('ruta: $ruta, ')
          ..write('sha256: $sha256, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('subida: $subida')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entidadTipo,
    entidadId,
    tipo,
    ruta,
    sha256,
    creadoEn,
    sincronizado,
    subida,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Foto &&
          other.id == this.id &&
          other.entidadTipo == this.entidadTipo &&
          other.entidadId == this.entidadId &&
          other.tipo == this.tipo &&
          other.ruta == this.ruta &&
          other.sha256 == this.sha256 &&
          other.creadoEn == this.creadoEn &&
          other.sincronizado == this.sincronizado &&
          other.subida == this.subida);
}

class FotosCompanion extends UpdateCompanion<Foto> {
  final Value<String> id;
  final Value<String> entidadTipo;
  final Value<String> entidadId;
  final Value<String> tipo;
  final Value<String> ruta;
  final Value<String> sha256;
  final Value<DateTime> creadoEn;
  final Value<bool> sincronizado;
  final Value<bool> subida;
  final Value<int> rowid;
  const FotosCompanion({
    this.id = const Value.absent(),
    this.entidadTipo = const Value.absent(),
    this.entidadId = const Value.absent(),
    this.tipo = const Value.absent(),
    this.ruta = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.subida = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FotosCompanion.insert({
    required String id,
    required String entidadTipo,
    required String entidadId,
    required String tipo,
    required String ruta,
    required String sha256,
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.subida = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entidadTipo = Value(entidadTipo),
       entidadId = Value(entidadId),
       tipo = Value(tipo),
       ruta = Value(ruta),
       sha256 = Value(sha256);
  static Insertable<Foto> custom({
    Expression<String>? id,
    Expression<String>? entidadTipo,
    Expression<String>? entidadId,
    Expression<String>? tipo,
    Expression<String>? ruta,
    Expression<String>? sha256,
    Expression<DateTime>? creadoEn,
    Expression<bool>? sincronizado,
    Expression<bool>? subida,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entidadTipo != null) 'entidad_tipo': entidadTipo,
      if (entidadId != null) 'entidad_id': entidadId,
      if (tipo != null) 'tipo': tipo,
      if (ruta != null) 'ruta': ruta,
      if (sha256 != null) 'sha256': sha256,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (subida != null) 'subida': subida,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FotosCompanion copyWith({
    Value<String>? id,
    Value<String>? entidadTipo,
    Value<String>? entidadId,
    Value<String>? tipo,
    Value<String>? ruta,
    Value<String>? sha256,
    Value<DateTime>? creadoEn,
    Value<bool>? sincronizado,
    Value<bool>? subida,
    Value<int>? rowid,
  }) {
    return FotosCompanion(
      id: id ?? this.id,
      entidadTipo: entidadTipo ?? this.entidadTipo,
      entidadId: entidadId ?? this.entidadId,
      tipo: tipo ?? this.tipo,
      ruta: ruta ?? this.ruta,
      sha256: sha256 ?? this.sha256,
      creadoEn: creadoEn ?? this.creadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
      subida: subida ?? this.subida,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entidadTipo.present) {
      map['entidad_tipo'] = Variable<String>(entidadTipo.value);
    }
    if (entidadId.present) {
      map['entidad_id'] = Variable<String>(entidadId.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (ruta.present) {
      map['ruta'] = Variable<String>(ruta.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    if (subida.present) {
      map['subida'] = Variable<bool>(subida.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FotosCompanion(')
          ..write('id: $id, ')
          ..write('entidadTipo: $entidadTipo, ')
          ..write('entidadId: $entidadId, ')
          ..write('tipo: $tipo, ')
          ..write('ruta: $ruta, ')
          ..write('sha256: $sha256, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('subida: $subida, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProductoresTable productores = $ProductoresTable(this);
  late final $FincasTable fincas = $FincasTable(this);
  late final $TemporadasTable temporadas = $TemporadasTable(this);
  late final $CultivosOrganizacionTable cultivosOrganizacion =
      $CultivosOrganizacionTable(this);
  late final $VersionesFincaTable versionesFinca = $VersionesFincaTable(this);
  late final $VerificacionesTable verificaciones = $VerificacionesTable(this);
  late final $EntregasTable entregas = $EntregasTable(this);
  late final $FotosTable fotos = $FotosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    productores,
    fincas,
    temporadas,
    cultivosOrganizacion,
    versionesFinca,
    verificaciones,
    entregas,
    fotos,
  ];
}

typedef $$ProductoresTableCreateCompanionBuilder =
    ProductoresCompanion Function({
      required String id,
      required String nombre,
      Value<String?> cedula,
      Value<String?> comunidad,
      Value<bool> consentimientoFirmado,
      Value<DateTime> creadoEn,
      Value<bool> sincronizado,
      Value<int> rowid,
    });
typedef $$ProductoresTableUpdateCompanionBuilder =
    ProductoresCompanion Function({
      Value<String> id,
      Value<String> nombre,
      Value<String?> cedula,
      Value<String?> comunidad,
      Value<bool> consentimientoFirmado,
      Value<DateTime> creadoEn,
      Value<bool> sincronizado,
      Value<int> rowid,
    });

final class $$ProductoresTableReferences
    extends BaseReferences<_$AppDatabase, $ProductoresTable, Productor> {
  $$ProductoresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FincasTable, List<Finca>> _fincasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.fincas,
    aliasName: 'productores__id__fincas__productor_id',
  );

  $$FincasTableProcessedTableManager get fincasRefs {
    final manager = $$FincasTableTableManager(
      $_db,
      $_db.fincas,
    ).filter((f) => f.productorId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fincasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductoresTableFilterComposer
    extends Composer<_$AppDatabase, $ProductoresTable> {
  $$ProductoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cedula => $composableBuilder(
    column: $table.cedula,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comunidad => $composableBuilder(
    column: $table.comunidad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get consentimientoFirmado => $composableBuilder(
    column: $table.consentimientoFirmado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> fincasRefs(
    Expression<bool> Function($$FincasTableFilterComposer f) f,
  ) {
    final $$FincasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.productorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableFilterComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductoresTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductoresTable> {
  $$ProductoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cedula => $composableBuilder(
    column: $table.cedula,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comunidad => $composableBuilder(
    column: $table.comunidad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get consentimientoFirmado => $composableBuilder(
    column: $table.consentimientoFirmado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductoresTable> {
  $$ProductoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get cedula =>
      $composableBuilder(column: $table.cedula, builder: (column) => column);

  GeneratedColumn<String> get comunidad =>
      $composableBuilder(column: $table.comunidad, builder: (column) => column);

  GeneratedColumn<bool> get consentimientoFirmado => $composableBuilder(
    column: $table.consentimientoFirmado,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  Expression<T> fincasRefs<T extends Object>(
    Expression<T> Function($$FincasTableAnnotationComposer a) f,
  ) {
    final $$FincasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.productorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableAnnotationComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductoresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductoresTable,
          Productor,
          $$ProductoresTableFilterComposer,
          $$ProductoresTableOrderingComposer,
          $$ProductoresTableAnnotationComposer,
          $$ProductoresTableCreateCompanionBuilder,
          $$ProductoresTableUpdateCompanionBuilder,
          (Productor, $$ProductoresTableReferences),
          Productor,
          PrefetchHooks Function({bool fincasRefs})
        > {
  $$ProductoresTableTableManager(_$AppDatabase db, $ProductoresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String?> cedula = const Value.absent(),
                Value<String?> comunidad = const Value.absent(),
                Value<bool> consentimientoFirmado = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductoresCompanion(
                id: id,
                nombre: nombre,
                cedula: cedula,
                comunidad: comunidad,
                consentimientoFirmado: consentimientoFirmado,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombre,
                Value<String?> cedula = const Value.absent(),
                Value<String?> comunidad = const Value.absent(),
                Value<bool> consentimientoFirmado = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductoresCompanion.insert(
                id: id,
                nombre: nombre,
                cedula: cedula,
                comunidad: comunidad,
                consentimientoFirmado: consentimientoFirmado,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductoresTable, Productor>(table),
                  $$ProductoresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fincasRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (fincasRefs) db.fincas],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (fincasRefs)
                    await $_getPrefetchedData<
                      Productor,
                      $ProductoresTable,
                      Finca
                    >(
                      currentTable: table,
                      referencedTable: $$ProductoresTableReferences
                          ._fincasRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProductoresTableReferences(
                            db,
                            table,
                            p0,
                          ).fincasRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.productorId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProductoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductoresTable,
      Productor,
      $$ProductoresTableFilterComposer,
      $$ProductoresTableOrderingComposer,
      $$ProductoresTableAnnotationComposer,
      $$ProductoresTableCreateCompanionBuilder,
      $$ProductoresTableUpdateCompanionBuilder,
      (Productor, $$ProductoresTableReferences),
      Productor,
      PrefetchHooks Function({bool fincasRefs})
    >;
typedef $$FincasTableCreateCompanionBuilder = FincasCompanion Function({
  required String id,
  required String productorId,
  required String nombre,
  Value<String> cultivo,
  required String coordenadasJson,
  required double areaHa,
  Value<double?> areaOficialHa,
  required String geoHash,
  Value<String?> attestationUid,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
  Value<int> version,
  Value<String> deforestacion,
  Value<DateTime?> ultimoChequeo,
  Value<int> rowid,
});
typedef $$FincasTableUpdateCompanionBuilder = FincasCompanion Function({
  Value<String> id,
  Value<String> productorId,
  Value<String> nombre,
  Value<String> cultivo,
  Value<String> coordenadasJson,
  Value<double> areaHa,
  Value<double?> areaOficialHa,
  Value<String> geoHash,
  Value<String?> attestationUid,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
  Value<int> version,
  Value<String> deforestacion,
  Value<DateTime?> ultimoChequeo,
  Value<int> rowid,
});

final class $$FincasTableReferences
    extends BaseReferences<_$AppDatabase, $FincasTable, Finca> {
  $$FincasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductoresTable _productorIdTable(_$AppDatabase db) =>
      db.productores.createAlias('fincas__productor_id__productores__id');

  $$ProductoresTableProcessedTableManager get productorId {
    final $_column = $_itemColumn<String>('productor_id')!;

    final manager = $$ProductoresTableTableManager(
      $_db,
      $_db.productores,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$VersionesFincaTable, List<VersionesFincaData>>
  _versionesFincaRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.versionesFinca,
    aliasName: 'fincas__id__versiones_finca__finca_id',
  );

  $$VersionesFincaTableProcessedTableManager get versionesFincaRefs {
    final manager = $$VersionesFincaTableTableManager(
      $_db,
      $_db.versionesFinca,
    ).filter((f) => f.fincaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_versionesFincaRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VerificacionesTable, List<Verificacion>>
  _verificacionesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.verificaciones,
    aliasName: 'fincas__id__verificaciones__finca_id',
  );

  $$VerificacionesTableProcessedTableManager get verificacionesRefs {
    final manager = $$VerificacionesTableTableManager(
      $_db,
      $_db.verificaciones,
    ).filter((f) => f.fincaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_verificacionesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntregasTable, List<Entrega>> _entregasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entregas,
    aliasName: 'fincas__id__entregas__finca_id',
  );

  $$EntregasTableProcessedTableManager get entregasRefs {
    final manager = $$EntregasTableTableManager(
      $_db,
      $_db.entregas,
    ).filter((f) => f.fincaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_entregasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FincasTableFilterComposer
    extends Composer<_$AppDatabase, $FincasTable> {
  $$FincasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cultivo => $composableBuilder(
    column: $table.cultivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coordenadasJson => $composableBuilder(
    column: $table.coordenadasJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaHa => $composableBuilder(
    column: $table.areaHa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaOficialHa => $composableBuilder(
    column: $table.areaOficialHa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geoHash => $composableBuilder(
    column: $table.geoHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attestationUid => $composableBuilder(
    column: $table.attestationUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deforestacion => $composableBuilder(
    column: $table.deforestacion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ultimoChequeo => $composableBuilder(
    column: $table.ultimoChequeo,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductoresTableFilterComposer get productorId {
    final $$ProductoresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productorId,
      referencedTable: $db.productores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductoresTableFilterComposer(
            $db: $db,
            $table: $db.productores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> versionesFincaRefs(
    Expression<bool> Function($$VersionesFincaTableFilterComposer f) f,
  ) {
    final $$VersionesFincaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.versionesFinca,
      getReferencedColumn: (t) => t.fincaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VersionesFincaTableFilterComposer(
            $db: $db,
            $table: $db.versionesFinca,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> verificacionesRefs(
    Expression<bool> Function($$VerificacionesTableFilterComposer f) f,
  ) {
    final $$VerificacionesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.verificaciones,
      getReferencedColumn: (t) => t.fincaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VerificacionesTableFilterComposer(
            $db: $db,
            $table: $db.verificaciones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entregasRefs(
    Expression<bool> Function($$EntregasTableFilterComposer f) f,
  ) {
    final $$EntregasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.fincaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableFilterComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FincasTableOrderingComposer
    extends Composer<_$AppDatabase, $FincasTable> {
  $$FincasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cultivo => $composableBuilder(
    column: $table.cultivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coordenadasJson => $composableBuilder(
    column: $table.coordenadasJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaHa => $composableBuilder(
    column: $table.areaHa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaOficialHa => $composableBuilder(
    column: $table.areaOficialHa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geoHash => $composableBuilder(
    column: $table.geoHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attestationUid => $composableBuilder(
    column: $table.attestationUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deforestacion => $composableBuilder(
    column: $table.deforestacion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ultimoChequeo => $composableBuilder(
    column: $table.ultimoChequeo,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductoresTableOrderingComposer get productorId {
    final $$ProductoresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productorId,
      referencedTable: $db.productores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductoresTableOrderingComposer(
            $db: $db,
            $table: $db.productores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FincasTableAnnotationComposer
    extends Composer<_$AppDatabase, $FincasTable> {
  $$FincasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get cultivo =>
      $composableBuilder(column: $table.cultivo, builder: (column) => column);

  GeneratedColumn<String> get coordenadasJson => $composableBuilder(
    column: $table.coordenadasJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get areaHa =>
      $composableBuilder(column: $table.areaHa, builder: (column) => column);

  GeneratedColumn<double> get areaOficialHa => $composableBuilder(
    column: $table.areaOficialHa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get geoHash =>
      $composableBuilder(column: $table.geoHash, builder: (column) => column);

  GeneratedColumn<String> get attestationUid => $composableBuilder(
    column: $table.attestationUid,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get deforestacion => $composableBuilder(
    column: $table.deforestacion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get ultimoChequeo => $composableBuilder(
    column: $table.ultimoChequeo,
    builder: (column) => column,
  );

  $$ProductoresTableAnnotationComposer get productorId {
    final $$ProductoresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productorId,
      referencedTable: $db.productores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductoresTableAnnotationComposer(
            $db: $db,
            $table: $db.productores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> versionesFincaRefs<T extends Object>(
    Expression<T> Function($$VersionesFincaTableAnnotationComposer a) f,
  ) {
    final $$VersionesFincaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.versionesFinca,
      getReferencedColumn: (t) => t.fincaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VersionesFincaTableAnnotationComposer(
            $db: $db,
            $table: $db.versionesFinca,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> verificacionesRefs<T extends Object>(
    Expression<T> Function($$VerificacionesTableAnnotationComposer a) f,
  ) {
    final $$VerificacionesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.verificaciones,
      getReferencedColumn: (t) => t.fincaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VerificacionesTableAnnotationComposer(
            $db: $db,
            $table: $db.verificaciones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entregasRefs<T extends Object>(
    Expression<T> Function($$EntregasTableAnnotationComposer a) f,
  ) {
    final $$EntregasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.fincaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableAnnotationComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FincasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FincasTable,
          Finca,
          $$FincasTableFilterComposer,
          $$FincasTableOrderingComposer,
          $$FincasTableAnnotationComposer,
          $$FincasTableCreateCompanionBuilder,
          $$FincasTableUpdateCompanionBuilder,
          (Finca, $$FincasTableReferences),
          Finca,
          PrefetchHooks Function({
            bool productorId,
            bool versionesFincaRefs,
            bool verificacionesRefs,
            bool entregasRefs,
          })
        > {
  $$FincasTableTableManager(_$AppDatabase db, $FincasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FincasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FincasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FincasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productorId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> cultivo = const Value.absent(),
                Value<String> coordenadasJson = const Value.absent(),
                Value<double> areaHa = const Value.absent(),
                Value<double?> areaOficialHa = const Value.absent(),
                Value<String> geoHash = const Value.absent(),
                Value<String?> attestationUid = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> deforestacion = const Value.absent(),
                Value<DateTime?> ultimoChequeo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FincasCompanion(
                id: id,
                productorId: productorId,
                nombre: nombre,
                cultivo: cultivo,
                coordenadasJson: coordenadasJson,
                areaHa: areaHa,
                areaOficialHa: areaOficialHa,
                geoHash: geoHash,
                attestationUid: attestationUid,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                version: version,
                deforestacion: deforestacion,
                ultimoChequeo: ultimoChequeo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productorId,
                required String nombre,
                Value<String> cultivo = const Value.absent(),
                required String coordenadasJson,
                required double areaHa,
                Value<double?> areaOficialHa = const Value.absent(),
                required String geoHash,
                Value<String?> attestationUid = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> deforestacion = const Value.absent(),
                Value<DateTime?> ultimoChequeo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FincasCompanion.insert(
                id: id,
                productorId: productorId,
                nombre: nombre,
                cultivo: cultivo,
                coordenadasJson: coordenadasJson,
                areaHa: areaHa,
                areaOficialHa: areaOficialHa,
                geoHash: geoHash,
                attestationUid: attestationUid,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                version: version,
                deforestacion: deforestacion,
                ultimoChequeo: ultimoChequeo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FincasTable, Finca>(table),
                  $$FincasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                productorId = false,
                versionesFincaRefs = false,
                verificacionesRefs = false,
                entregasRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (versionesFincaRefs) db.versionesFinca,
                    if (verificacionesRefs) db.verificaciones,
                    if (entregasRefs) db.entregas,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (productorId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.productorId,
                            referencedTable: $$FincasTableReferences
                                ._productorIdTable(db),
                            referencedColumn: $$FincasTableReferences
                                ._productorIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (versionesFincaRefs)
                        await $_getPrefetchedData<
                          Finca,
                          $FincasTable,
                          VersionesFincaData
                        >(
                          currentTable: table,
                          referencedTable: $$FincasTableReferences
                              ._versionesFincaRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FincasTableReferences(
                                db,
                                table,
                                p0,
                              ).versionesFincaRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.fincaId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (verificacionesRefs)
                        await $_getPrefetchedData<
                          Finca,
                          $FincasTable,
                          Verificacion
                        >(
                          currentTable: table,
                          referencedTable: $$FincasTableReferences
                              ._verificacionesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FincasTableReferences(
                                db,
                                table,
                                p0,
                              ).verificacionesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.fincaId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (entregasRefs)
                        await $_getPrefetchedData<Finca, $FincasTable, Entrega>(
                          currentTable: table,
                          referencedTable: $$FincasTableReferences
                              ._entregasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FincasTableReferences(
                                db,
                                table,
                                p0,
                              ).entregasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.fincaId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FincasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FincasTable,
      Finca,
      $$FincasTableFilterComposer,
      $$FincasTableOrderingComposer,
      $$FincasTableAnnotationComposer,
      $$FincasTableCreateCompanionBuilder,
      $$FincasTableUpdateCompanionBuilder,
      (Finca, $$FincasTableReferences),
      Finca,
      PrefetchHooks Function({
        bool productorId,
        bool versionesFincaRefs,
        bool verificacionesRefs,
        bool entregasRefs,
      })
    >;
typedef $$TemporadasTableCreateCompanionBuilder = TemporadasCompanion Function({
  required String id,
  required String nombre,
  required DateTime inicio,
  required DateTime fin,
  Value<String?> cultivo,
  Value<int> rowid,
});
typedef $$TemporadasTableUpdateCompanionBuilder = TemporadasCompanion Function({
  Value<String> id,
  Value<String> nombre,
  Value<DateTime> inicio,
  Value<DateTime> fin,
  Value<String?> cultivo,
  Value<int> rowid,
});

class $$TemporadasTableFilterComposer
    extends Composer<_$AppDatabase, $TemporadasTable> {
  $$TemporadasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get inicio => $composableBuilder(
    column: $table.inicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fin => $composableBuilder(
    column: $table.fin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cultivo => $composableBuilder(
    column: $table.cultivo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TemporadasTableOrderingComposer
    extends Composer<_$AppDatabase, $TemporadasTable> {
  $$TemporadasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get inicio => $composableBuilder(
    column: $table.inicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fin => $composableBuilder(
    column: $table.fin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cultivo => $composableBuilder(
    column: $table.cultivo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TemporadasTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemporadasTable> {
  $$TemporadasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<DateTime> get inicio =>
      $composableBuilder(column: $table.inicio, builder: (column) => column);

  GeneratedColumn<DateTime> get fin =>
      $composableBuilder(column: $table.fin, builder: (column) => column);

  GeneratedColumn<String> get cultivo =>
      $composableBuilder(column: $table.cultivo, builder: (column) => column);
}

class $$TemporadasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TemporadasTable,
          Temporada,
          $$TemporadasTableFilterComposer,
          $$TemporadasTableOrderingComposer,
          $$TemporadasTableAnnotationComposer,
          $$TemporadasTableCreateCompanionBuilder,
          $$TemporadasTableUpdateCompanionBuilder,
          (
            Temporada,
            BaseReferences<_$AppDatabase, $TemporadasTable, Temporada>,
          ),
          Temporada,
          PrefetchHooks Function()
        > {
  $$TemporadasTableTableManager(_$AppDatabase db, $TemporadasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemporadasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemporadasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemporadasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<DateTime> inicio = const Value.absent(),
                Value<DateTime> fin = const Value.absent(),
                Value<String?> cultivo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemporadasCompanion(
                id: id,
                nombre: nombre,
                inicio: inicio,
                fin: fin,
                cultivo: cultivo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombre,
                required DateTime inicio,
                required DateTime fin,
                Value<String?> cultivo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemporadasCompanion.insert(
                id: id,
                nombre: nombre,
                inicio: inicio,
                fin: fin,
                cultivo: cultivo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TemporadasTable, Temporada>(table),
                  BaseReferences<_$AppDatabase, $TemporadasTable, Temporada>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TemporadasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TemporadasTable,
      Temporada,
      $$TemporadasTableFilterComposer,
      $$TemporadasTableOrderingComposer,
      $$TemporadasTableAnnotationComposer,
      $$TemporadasTableCreateCompanionBuilder,
      $$TemporadasTableUpdateCompanionBuilder,
      (Temporada, BaseReferences<_$AppDatabase, $TemporadasTable, Temporada>),
      Temporada,
      PrefetchHooks Function()
    >;
typedef $$CultivosOrganizacionTableCreateCompanionBuilder =
    CultivosOrganizacionCompanion Function({
      required String id,
      Value<int> rowid,
    });
typedef $$CultivosOrganizacionTableUpdateCompanionBuilder =
    CultivosOrganizacionCompanion Function({
      Value<String> id,
      Value<int> rowid,
    });

class $$CultivosOrganizacionTableFilterComposer
    extends Composer<_$AppDatabase, $CultivosOrganizacionTable> {
  $$CultivosOrganizacionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CultivosOrganizacionTableOrderingComposer
    extends Composer<_$AppDatabase, $CultivosOrganizacionTable> {
  $$CultivosOrganizacionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CultivosOrganizacionTableAnnotationComposer
    extends Composer<_$AppDatabase, $CultivosOrganizacionTable> {
  $$CultivosOrganizacionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$CultivosOrganizacionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CultivosOrganizacionTable,
          CultivosOrganizacionData,
          $$CultivosOrganizacionTableFilterComposer,
          $$CultivosOrganizacionTableOrderingComposer,
          $$CultivosOrganizacionTableAnnotationComposer,
          $$CultivosOrganizacionTableCreateCompanionBuilder,
          $$CultivosOrganizacionTableUpdateCompanionBuilder,
          (
            CultivosOrganizacionData,
            BaseReferences<
              _$AppDatabase,
              $CultivosOrganizacionTable,
              CultivosOrganizacionData
            >,
          ),
          CultivosOrganizacionData,
          PrefetchHooks Function()
        > {
  $$CultivosOrganizacionTableTableManager(
    _$AppDatabase db,
    $CultivosOrganizacionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CultivosOrganizacionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CultivosOrganizacionTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CultivosOrganizacionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CultivosOrganizacionCompanion(id: id, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            Value<int> rowid = const Value.absent(),
          }) => CultivosOrganizacionCompanion.insert(id: id, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CultivosOrganizacionTable,
                    CultivosOrganizacionData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CultivosOrganizacionTable,
                    CultivosOrganizacionData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CultivosOrganizacionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CultivosOrganizacionTable,
      CultivosOrganizacionData,
      $$CultivosOrganizacionTableFilterComposer,
      $$CultivosOrganizacionTableOrderingComposer,
      $$CultivosOrganizacionTableAnnotationComposer,
      $$CultivosOrganizacionTableCreateCompanionBuilder,
      $$CultivosOrganizacionTableUpdateCompanionBuilder,
      (
        CultivosOrganizacionData,
        BaseReferences<
          _$AppDatabase,
          $CultivosOrganizacionTable,
          CultivosOrganizacionData
        >,
      ),
      CultivosOrganizacionData,
      PrefetchHooks Function()
    >;
typedef $$VersionesFincaTableCreateCompanionBuilder =
    VersionesFincaCompanion Function({
      required String fincaId,
      required int version,
      required String coordenadasJson,
      required double areaHa,
      required String geoHash,
      Value<DateTime> creadoEn,
      Value<bool> sincronizado,
      Value<int> rowid,
    });
typedef $$VersionesFincaTableUpdateCompanionBuilder =
    VersionesFincaCompanion Function({
      Value<String> fincaId,
      Value<int> version,
      Value<String> coordenadasJson,
      Value<double> areaHa,
      Value<String> geoHash,
      Value<DateTime> creadoEn,
      Value<bool> sincronizado,
      Value<int> rowid,
    });

final class $$VersionesFincaTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $VersionesFincaTable,
          VersionesFincaData
        > {
  $$VersionesFincaTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FincasTable _fincaIdTable(_$AppDatabase db) =>
      db.fincas.createAlias('versiones_finca__finca_id__fincas__id');

  $$FincasTableProcessedTableManager get fincaId {
    final $_column = $_itemColumn<String>('finca_id')!;

    final manager = $$FincasTableTableManager(
      $_db,
      $_db.fincas,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fincaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VersionesFincaTableFilterComposer
    extends Composer<_$AppDatabase, $VersionesFincaTable> {
  $$VersionesFincaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coordenadasJson => $composableBuilder(
    column: $table.coordenadasJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaHa => $composableBuilder(
    column: $table.areaHa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geoHash => $composableBuilder(
    column: $table.geoHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  $$FincasTableFilterComposer get fincaId {
    final $$FincasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableFilterComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VersionesFincaTableOrderingComposer
    extends Composer<_$AppDatabase, $VersionesFincaTable> {
  $$VersionesFincaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coordenadasJson => $composableBuilder(
    column: $table.coordenadasJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaHa => $composableBuilder(
    column: $table.areaHa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geoHash => $composableBuilder(
    column: $table.geoHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  $$FincasTableOrderingComposer get fincaId {
    final $$FincasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableOrderingComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VersionesFincaTableAnnotationComposer
    extends Composer<_$AppDatabase, $VersionesFincaTable> {
  $$VersionesFincaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get coordenadasJson => $composableBuilder(
    column: $table.coordenadasJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get areaHa =>
      $composableBuilder(column: $table.areaHa, builder: (column) => column);

  GeneratedColumn<String> get geoHash =>
      $composableBuilder(column: $table.geoHash, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  $$FincasTableAnnotationComposer get fincaId {
    final $$FincasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableAnnotationComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VersionesFincaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VersionesFincaTable,
          VersionesFincaData,
          $$VersionesFincaTableFilterComposer,
          $$VersionesFincaTableOrderingComposer,
          $$VersionesFincaTableAnnotationComposer,
          $$VersionesFincaTableCreateCompanionBuilder,
          $$VersionesFincaTableUpdateCompanionBuilder,
          (VersionesFincaData, $$VersionesFincaTableReferences),
          VersionesFincaData,
          PrefetchHooks Function({bool fincaId})
        > {
  $$VersionesFincaTableTableManager(
    _$AppDatabase db,
    $VersionesFincaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VersionesFincaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VersionesFincaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VersionesFincaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fincaId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> coordenadasJson = const Value.absent(),
                Value<double> areaHa = const Value.absent(),
                Value<String> geoHash = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VersionesFincaCompanion(
                fincaId: fincaId,
                version: version,
                coordenadasJson: coordenadasJson,
                areaHa: areaHa,
                geoHash: geoHash,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fincaId,
                required int version,
                required String coordenadasJson,
                required double areaHa,
                required String geoHash,
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VersionesFincaCompanion.insert(
                fincaId: fincaId,
                version: version,
                coordenadasJson: coordenadasJson,
                areaHa: areaHa,
                geoHash: geoHash,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VersionesFincaTable, VersionesFincaData>(table),
                  $$VersionesFincaTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fincaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (fincaId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.fincaId,
                        referencedTable: $$VersionesFincaTableReferences
                            ._fincaIdTable(db),
                        referencedColumn: $$VersionesFincaTableReferences
                            ._fincaIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$VersionesFincaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VersionesFincaTable,
      VersionesFincaData,
      $$VersionesFincaTableFilterComposer,
      $$VersionesFincaTableOrderingComposer,
      $$VersionesFincaTableAnnotationComposer,
      $$VersionesFincaTableCreateCompanionBuilder,
      $$VersionesFincaTableUpdateCompanionBuilder,
      (VersionesFincaData, $$VersionesFincaTableReferences),
      VersionesFincaData,
      PrefetchHooks Function({bool fincaId})
    >;
typedef $$VerificacionesTableCreateCompanionBuilder =
    VerificacionesCompanion Function({
      required String id,
      required String fincaId,
      Value<String?> temporadaId,
      required DateTime fecha,
      Value<bool> linderoCambio,
      required int versionFinca,
      Value<String?> nota,
      Value<bool> sincronizado,
      Value<int> rowid,
    });
typedef $$VerificacionesTableUpdateCompanionBuilder =
    VerificacionesCompanion Function({
      Value<String> id,
      Value<String> fincaId,
      Value<String?> temporadaId,
      Value<DateTime> fecha,
      Value<bool> linderoCambio,
      Value<int> versionFinca,
      Value<String?> nota,
      Value<bool> sincronizado,
      Value<int> rowid,
    });

final class $$VerificacionesTableReferences
    extends BaseReferences<_$AppDatabase, $VerificacionesTable, Verificacion> {
  $$VerificacionesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FincasTable _fincaIdTable(_$AppDatabase db) =>
      db.fincas.createAlias('verificaciones__finca_id__fincas__id');

  $$FincasTableProcessedTableManager get fincaId {
    final $_column = $_itemColumn<String>('finca_id')!;

    final manager = $$FincasTableTableManager(
      $_db,
      $_db.fincas,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fincaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VerificacionesTableFilterComposer
    extends Composer<_$AppDatabase, $VerificacionesTable> {
  $$VerificacionesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporadaId => $composableBuilder(
    column: $table.temporadaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get linderoCambio => $composableBuilder(
    column: $table.linderoCambio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versionFinca => $composableBuilder(
    column: $table.versionFinca,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nota => $composableBuilder(
    column: $table.nota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  $$FincasTableFilterComposer get fincaId {
    final $$FincasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableFilterComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VerificacionesTableOrderingComposer
    extends Composer<_$AppDatabase, $VerificacionesTable> {
  $$VerificacionesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporadaId => $composableBuilder(
    column: $table.temporadaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get linderoCambio => $composableBuilder(
    column: $table.linderoCambio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versionFinca => $composableBuilder(
    column: $table.versionFinca,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nota => $composableBuilder(
    column: $table.nota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  $$FincasTableOrderingComposer get fincaId {
    final $$FincasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableOrderingComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VerificacionesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VerificacionesTable> {
  $$VerificacionesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get temporadaId => $composableBuilder(
    column: $table.temporadaId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<bool> get linderoCambio => $composableBuilder(
    column: $table.linderoCambio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get versionFinca => $composableBuilder(
    column: $table.versionFinca,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nota =>
      $composableBuilder(column: $table.nota, builder: (column) => column);

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  $$FincasTableAnnotationComposer get fincaId {
    final $$FincasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableAnnotationComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VerificacionesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VerificacionesTable,
          Verificacion,
          $$VerificacionesTableFilterComposer,
          $$VerificacionesTableOrderingComposer,
          $$VerificacionesTableAnnotationComposer,
          $$VerificacionesTableCreateCompanionBuilder,
          $$VerificacionesTableUpdateCompanionBuilder,
          (Verificacion, $$VerificacionesTableReferences),
          Verificacion,
          PrefetchHooks Function({bool fincaId})
        > {
  $$VerificacionesTableTableManager(
    _$AppDatabase db,
    $VerificacionesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VerificacionesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VerificacionesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VerificacionesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fincaId = const Value.absent(),
                Value<String?> temporadaId = const Value.absent(),
                Value<DateTime> fecha = const Value.absent(),
                Value<bool> linderoCambio = const Value.absent(),
                Value<int> versionFinca = const Value.absent(),
                Value<String?> nota = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VerificacionesCompanion(
                id: id,
                fincaId: fincaId,
                temporadaId: temporadaId,
                fecha: fecha,
                linderoCambio: linderoCambio,
                versionFinca: versionFinca,
                nota: nota,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fincaId,
                Value<String?> temporadaId = const Value.absent(),
                required DateTime fecha,
                Value<bool> linderoCambio = const Value.absent(),
                required int versionFinca,
                Value<String?> nota = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VerificacionesCompanion.insert(
                id: id,
                fincaId: fincaId,
                temporadaId: temporadaId,
                fecha: fecha,
                linderoCambio: linderoCambio,
                versionFinca: versionFinca,
                nota: nota,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VerificacionesTable, Verificacion>(table),
                  $$VerificacionesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fincaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (fincaId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.fincaId,
                        referencedTable: $$VerificacionesTableReferences
                            ._fincaIdTable(db),
                        referencedColumn: $$VerificacionesTableReferences
                            ._fincaIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$VerificacionesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VerificacionesTable,
      Verificacion,
      $$VerificacionesTableFilterComposer,
      $$VerificacionesTableOrderingComposer,
      $$VerificacionesTableAnnotationComposer,
      $$VerificacionesTableCreateCompanionBuilder,
      $$VerificacionesTableUpdateCompanionBuilder,
      (Verificacion, $$VerificacionesTableReferences),
      Verificacion,
      PrefetchHooks Function({bool fincaId})
    >;
typedef $$EntregasTableCreateCompanionBuilder = EntregasCompanion Function({
  required String id,
  required String fincaId,
  Value<String?> temporadaId,
  required double kg,
  required String estado,
  required DateTime fecha,
  Value<String?> attestationUid,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
  Value<String?> loteCodigo,
  Value<bool> corregida,
  Value<int> rowid,
});
typedef $$EntregasTableUpdateCompanionBuilder = EntregasCompanion Function({
  Value<String> id,
  Value<String> fincaId,
  Value<String?> temporadaId,
  Value<double> kg,
  Value<String> estado,
  Value<DateTime> fecha,
  Value<String?> attestationUid,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
  Value<String?> loteCodigo,
  Value<bool> corregida,
  Value<int> rowid,
});

final class $$EntregasTableReferences
    extends BaseReferences<_$AppDatabase, $EntregasTable, Entrega> {
  $$EntregasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FincasTable _fincaIdTable(_$AppDatabase db) =>
      db.fincas.createAlias('entregas__finca_id__fincas__id');

  $$FincasTableProcessedTableManager get fincaId {
    final $_column = $_itemColumn<String>('finca_id')!;

    final manager = $$FincasTableTableManager(
      $_db,
      $_db.fincas,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fincaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntregasTableFilterComposer
    extends Composer<_$AppDatabase, $EntregasTable> {
  $$EntregasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporadaId => $composableBuilder(
    column: $table.temporadaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kg => $composableBuilder(
    column: $table.kg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attestationUid => $composableBuilder(
    column: $table.attestationUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loteCodigo => $composableBuilder(
    column: $table.loteCodigo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get corregida => $composableBuilder(
    column: $table.corregida,
    builder: (column) => ColumnFilters(column),
  );

  $$FincasTableFilterComposer get fincaId {
    final $$FincasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableFilterComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntregasTableOrderingComposer
    extends Composer<_$AppDatabase, $EntregasTable> {
  $$EntregasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporadaId => $composableBuilder(
    column: $table.temporadaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kg => $composableBuilder(
    column: $table.kg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attestationUid => $composableBuilder(
    column: $table.attestationUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loteCodigo => $composableBuilder(
    column: $table.loteCodigo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get corregida => $composableBuilder(
    column: $table.corregida,
    builder: (column) => ColumnOrderings(column),
  );

  $$FincasTableOrderingComposer get fincaId {
    final $$FincasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableOrderingComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntregasTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntregasTable> {
  $$EntregasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get temporadaId => $composableBuilder(
    column: $table.temporadaId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kg =>
      $composableBuilder(column: $table.kg, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<DateTime> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<String> get attestationUid => $composableBuilder(
    column: $table.attestationUid,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loteCodigo => $composableBuilder(
    column: $table.loteCodigo,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get corregida =>
      $composableBuilder(column: $table.corregida, builder: (column) => column);

  $$FincasTableAnnotationComposer get fincaId {
    final $$FincasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fincaId,
      referencedTable: $db.fincas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FincasTableAnnotationComposer(
            $db: $db,
            $table: $db.fincas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntregasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntregasTable,
          Entrega,
          $$EntregasTableFilterComposer,
          $$EntregasTableOrderingComposer,
          $$EntregasTableAnnotationComposer,
          $$EntregasTableCreateCompanionBuilder,
          $$EntregasTableUpdateCompanionBuilder,
          (Entrega, $$EntregasTableReferences),
          Entrega,
          PrefetchHooks Function({bool fincaId})
        > {
  $$EntregasTableTableManager(_$AppDatabase db, $EntregasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntregasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntregasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntregasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fincaId = const Value.absent(),
                Value<String?> temporadaId = const Value.absent(),
                Value<double> kg = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<DateTime> fecha = const Value.absent(),
                Value<String?> attestationUid = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<String?> loteCodigo = const Value.absent(),
                Value<bool> corregida = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntregasCompanion(
                id: id,
                fincaId: fincaId,
                temporadaId: temporadaId,
                kg: kg,
                estado: estado,
                fecha: fecha,
                attestationUid: attestationUid,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                loteCodigo: loteCodigo,
                corregida: corregida,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fincaId,
                Value<String?> temporadaId = const Value.absent(),
                required double kg,
                required String estado,
                required DateTime fecha,
                Value<String?> attestationUid = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<String?> loteCodigo = const Value.absent(),
                Value<bool> corregida = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntregasCompanion.insert(
                id: id,
                fincaId: fincaId,
                temporadaId: temporadaId,
                kg: kg,
                estado: estado,
                fecha: fecha,
                attestationUid: attestationUid,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                loteCodigo: loteCodigo,
                corregida: corregida,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntregasTable, Entrega>(table),
                  $$EntregasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fincaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (fincaId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.fincaId,
                        referencedTable: $$EntregasTableReferences
                            ._fincaIdTable(db),
                        referencedColumn: $$EntregasTableReferences
                            ._fincaIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntregasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntregasTable,
      Entrega,
      $$EntregasTableFilterComposer,
      $$EntregasTableOrderingComposer,
      $$EntregasTableAnnotationComposer,
      $$EntregasTableCreateCompanionBuilder,
      $$EntregasTableUpdateCompanionBuilder,
      (Entrega, $$EntregasTableReferences),
      Entrega,
      PrefetchHooks Function({bool fincaId})
    >;
typedef $$FotosTableCreateCompanionBuilder = FotosCompanion Function({
  required String id,
  required String entidadTipo,
  required String entidadId,
  required String tipo,
  required String ruta,
  required String sha256,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
  Value<bool> subida,
  Value<int> rowid,
});
typedef $$FotosTableUpdateCompanionBuilder = FotosCompanion Function({
  Value<String> id,
  Value<String> entidadTipo,
  Value<String> entidadId,
  Value<String> tipo,
  Value<String> ruta,
  Value<String> sha256,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
  Value<bool> subida,
  Value<int> rowid,
});

class $$FotosTableFilterComposer extends Composer<_$AppDatabase, $FotosTable> {
  $$FotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entidadTipo => $composableBuilder(
    column: $table.entidadTipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entidadId => $composableBuilder(
    column: $table.entidadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruta => $composableBuilder(
    column: $table.ruta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get subida => $composableBuilder(
    column: $table.subida,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FotosTableOrderingComposer
    extends Composer<_$AppDatabase, $FotosTable> {
  $$FotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entidadTipo => $composableBuilder(
    column: $table.entidadTipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entidadId => $composableBuilder(
    column: $table.entidadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruta => $composableBuilder(
    column: $table.ruta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get subida => $composableBuilder(
    column: $table.subida,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $FotosTable> {
  $$FotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entidadTipo => $composableBuilder(
    column: $table.entidadTipo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entidadId =>
      $composableBuilder(column: $table.entidadId, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get ruta =>
      $composableBuilder(column: $table.ruta, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get subida =>
      $composableBuilder(column: $table.subida, builder: (column) => column);
}

class $$FotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FotosTable,
          Foto,
          $$FotosTableFilterComposer,
          $$FotosTableOrderingComposer,
          $$FotosTableAnnotationComposer,
          $$FotosTableCreateCompanionBuilder,
          $$FotosTableUpdateCompanionBuilder,
          (Foto, BaseReferences<_$AppDatabase, $FotosTable, Foto>),
          Foto,
          PrefetchHooks Function()
        > {
  $$FotosTableTableManager(_$AppDatabase db, $FotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entidadTipo = const Value.absent(),
                Value<String> entidadId = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> ruta = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<bool> subida = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FotosCompanion(
                id: id,
                entidadTipo: entidadTipo,
                entidadId: entidadId,
                tipo: tipo,
                ruta: ruta,
                sha256: sha256,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                subida: subida,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entidadTipo,
                required String entidadId,
                required String tipo,
                required String ruta,
                required String sha256,
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<bool> subida = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FotosCompanion.insert(
                id: id,
                entidadTipo: entidadTipo,
                entidadId: entidadId,
                tipo: tipo,
                ruta: ruta,
                sha256: sha256,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                subida: subida,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FotosTable, Foto>(table),
                  BaseReferences<_$AppDatabase, $FotosTable, Foto>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FotosTable,
      Foto,
      $$FotosTableFilterComposer,
      $$FotosTableOrderingComposer,
      $$FotosTableAnnotationComposer,
      $$FotosTableCreateCompanionBuilder,
      $$FotosTableUpdateCompanionBuilder,
      (Foto, BaseReferences<_$AppDatabase, $FotosTable, Foto>),
      Foto,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProductoresTableTableManager get productores =>
      $$ProductoresTableTableManager(_db, _db.productores);
  $$FincasTableTableManager get fincas =>
      $$FincasTableTableManager(_db, _db.fincas);
  $$TemporadasTableTableManager get temporadas =>
      $$TemporadasTableTableManager(_db, _db.temporadas);
  $$CultivosOrganizacionTableTableManager get cultivosOrganizacion =>
      $$CultivosOrganizacionTableTableManager(_db, _db.cultivosOrganizacion);
  $$VersionesFincaTableTableManager get versionesFinca =>
      $$VersionesFincaTableTableManager(_db, _db.versionesFinca);
  $$VerificacionesTableTableManager get verificaciones =>
      $$VerificacionesTableTableManager(_db, _db.verificaciones);
  $$EntregasTableTableManager get entregas =>
      $$EntregasTableTableManager(_db, _db.entregas);
  $$FotosTableTableManager get fotos =>
      $$FotosTableTableManager(_db, _db.fotos);
}

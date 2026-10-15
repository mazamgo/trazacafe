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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productorId,
    nombre,
    coordenadasJson,
    areaHa,
    geoHash,
    attestationUid,
    creadoEn,
    sincronizado,
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

  /// Coordenadas en GeoJSON: `[[lon, lat], ...]`. Un solo punto si la finca
  /// mide menos de 4 ha; polÃ­gono cerrado si mide 4 ha o mÃ¡s (regla EUDR).
  final String coordenadasJson;
  final double areaHa;

  /// Hash SHA-256 de las coordenadas canÃ³nicas; es lo que va a la blockchain.
  final String geoHash;

  /// UID de la attestation en EAS, cuando el backend ya la firmÃ³.
  final String? attestationUid;
  final DateTime creadoEn;
  final bool sincronizado;
  const Finca({
    required this.id,
    required this.productorId,
    required this.nombre,
    required this.coordenadasJson,
    required this.areaHa,
    required this.geoHash,
    this.attestationUid,
    required this.creadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['productor_id'] = Variable<String>(productorId);
    map['nombre'] = Variable<String>(nombre);
    map['coordenadas_json'] = Variable<String>(coordenadasJson);
    map['area_ha'] = Variable<double>(areaHa);
    map['geo_hash'] = Variable<String>(geoHash);
    if (!nullToAbsent || attestationUid != null) {
      map['attestation_uid'] = Variable<String>(attestationUid);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  FincasCompanion toCompanion(bool nullToAbsent) {
    return FincasCompanion(
      id: Value(id),
      productorId: Value(productorId),
      nombre: Value(nombre),
      coordenadasJson: Value(coordenadasJson),
      areaHa: Value(areaHa),
      geoHash: Value(geoHash),
      attestationUid: attestationUid == null && nullToAbsent
          ? const Value.absent()
          : Value(attestationUid),
      creadoEn: Value(creadoEn),
      sincronizado: Value(sincronizado),
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
      coordenadasJson: serializer.fromJson<String>(json['coordenadasJson']),
      areaHa: serializer.fromJson<double>(json['areaHa']),
      geoHash: serializer.fromJson<String>(json['geoHash']),
      attestationUid: serializer.fromJson<String?>(json['attestationUid']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productorId': serializer.toJson<String>(productorId),
      'nombre': serializer.toJson<String>(nombre),
      'coordenadasJson': serializer.toJson<String>(coordenadasJson),
      'areaHa': serializer.toJson<double>(areaHa),
      'geoHash': serializer.toJson<String>(geoHash),
      'attestationUid': serializer.toJson<String?>(attestationUid),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Finca copyWith({
    String? id,
    String? productorId,
    String? nombre,
    String? coordenadasJson,
    double? areaHa,
    String? geoHash,
    Value<String?> attestationUid = const Value.absent(),
    DateTime? creadoEn,
    bool? sincronizado,
  }) => Finca(
    id: id ?? this.id,
    productorId: productorId ?? this.productorId,
    nombre: nombre ?? this.nombre,
    coordenadasJson: coordenadasJson ?? this.coordenadasJson,
    areaHa: areaHa ?? this.areaHa,
    geoHash: geoHash ?? this.geoHash,
    attestationUid: attestationUid.present
        ? attestationUid.value
        : this.attestationUid,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Finca copyWithCompanion(FincasCompanion data) {
    return Finca(
      id: data.id.present ? data.id.value : this.id,
      productorId: data.productorId.present
          ? data.productorId.value
          : this.productorId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      coordenadasJson: data.coordenadasJson.present
          ? data.coordenadasJson.value
          : this.coordenadasJson,
      areaHa: data.areaHa.present ? data.areaHa.value : this.areaHa,
      geoHash: data.geoHash.present ? data.geoHash.value : this.geoHash,
      attestationUid: data.attestationUid.present
          ? data.attestationUid.value
          : this.attestationUid,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Finca(')
          ..write('id: $id, ')
          ..write('productorId: $productorId, ')
          ..write('nombre: $nombre, ')
          ..write('coordenadasJson: $coordenadasJson, ')
          ..write('areaHa: $areaHa, ')
          ..write('geoHash: $geoHash, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productorId,
    nombre,
    coordenadasJson,
    areaHa,
    geoHash,
    attestationUid,
    creadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Finca &&
          other.id == this.id &&
          other.productorId == this.productorId &&
          other.nombre == this.nombre &&
          other.coordenadasJson == this.coordenadasJson &&
          other.areaHa == this.areaHa &&
          other.geoHash == this.geoHash &&
          other.attestationUid == this.attestationUid &&
          other.creadoEn == this.creadoEn &&
          other.sincronizado == this.sincronizado);
}

class FincasCompanion extends UpdateCompanion<Finca> {
  final Value<String> id;
  final Value<String> productorId;
  final Value<String> nombre;
  final Value<String> coordenadasJson;
  final Value<double> areaHa;
  final Value<String> geoHash;
  final Value<String?> attestationUid;
  final Value<DateTime> creadoEn;
  final Value<bool> sincronizado;
  final Value<int> rowid;
  const FincasCompanion({
    this.id = const Value.absent(),
    this.productorId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.coordenadasJson = const Value.absent(),
    this.areaHa = const Value.absent(),
    this.geoHash = const Value.absent(),
    this.attestationUid = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FincasCompanion.insert({
    required String id,
    required String productorId,
    required String nombre,
    required String coordenadasJson,
    required double areaHa,
    required String geoHash,
    this.attestationUid = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
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
    Expression<String>? coordenadasJson,
    Expression<double>? areaHa,
    Expression<String>? geoHash,
    Expression<String>? attestationUid,
    Expression<DateTime>? creadoEn,
    Expression<bool>? sincronizado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productorId != null) 'productor_id': productorId,
      if (nombre != null) 'nombre': nombre,
      if (coordenadasJson != null) 'coordenadas_json': coordenadasJson,
      if (areaHa != null) 'area_ha': areaHa,
      if (geoHash != null) 'geo_hash': geoHash,
      if (attestationUid != null) 'attestation_uid': attestationUid,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FincasCompanion copyWith({
    Value<String>? id,
    Value<String>? productorId,
    Value<String>? nombre,
    Value<String>? coordenadasJson,
    Value<double>? areaHa,
    Value<String>? geoHash,
    Value<String?>? attestationUid,
    Value<DateTime>? creadoEn,
    Value<bool>? sincronizado,
    Value<int>? rowid,
  }) {
    return FincasCompanion(
      id: id ?? this.id,
      productorId: productorId ?? this.productorId,
      nombre: nombre ?? this.nombre,
      coordenadasJson: coordenadasJson ?? this.coordenadasJson,
      areaHa: areaHa ?? this.areaHa,
      geoHash: geoHash ?? this.geoHash,
      attestationUid: attestationUid ?? this.attestationUid,
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
    if (productorId.present) {
      map['productor_id'] = Variable<String>(productorId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
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
    if (attestationUid.present) {
      map['attestation_uid'] = Variable<String>(attestationUid.value);
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
    return (StringBuffer('FincasCompanion(')
          ..write('id: $id, ')
          ..write('productorId: $productorId, ')
          ..write('nombre: $nombre, ')
          ..write('coordenadasJson: $coordenadasJson, ')
          ..write('areaHa: $areaHa, ')
          ..write('geoHash: $geoHash, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('creadoEn: $creadoEn, ')
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
    kg,
    estado,
    fecha,
    attestationUid,
    sincronizado,
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
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
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
  final double kg;

  /// `uva` (cafÃ© maduro) o `pergamino`.
  final String estado;
  final DateTime fecha;
  final String? attestationUid;
  final bool sincronizado;
  const Entrega({
    required this.id,
    required this.fincaId,
    required this.kg,
    required this.estado,
    required this.fecha,
    this.attestationUid,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['finca_id'] = Variable<String>(fincaId);
    map['kg'] = Variable<double>(kg);
    map['estado'] = Variable<String>(estado);
    map['fecha'] = Variable<DateTime>(fecha);
    if (!nullToAbsent || attestationUid != null) {
      map['attestation_uid'] = Variable<String>(attestationUid);
    }
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  EntregasCompanion toCompanion(bool nullToAbsent) {
    return EntregasCompanion(
      id: Value(id),
      fincaId: Value(fincaId),
      kg: Value(kg),
      estado: Value(estado),
      fecha: Value(fecha),
      attestationUid: attestationUid == null && nullToAbsent
          ? const Value.absent()
          : Value(attestationUid),
      sincronizado: Value(sincronizado),
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
      kg: serializer.fromJson<double>(json['kg']),
      estado: serializer.fromJson<String>(json['estado']),
      fecha: serializer.fromJson<DateTime>(json['fecha']),
      attestationUid: serializer.fromJson<String?>(json['attestationUid']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fincaId': serializer.toJson<String>(fincaId),
      'kg': serializer.toJson<double>(kg),
      'estado': serializer.toJson<String>(estado),
      'fecha': serializer.toJson<DateTime>(fecha),
      'attestationUid': serializer.toJson<String?>(attestationUid),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Entrega copyWith({
    String? id,
    String? fincaId,
    double? kg,
    String? estado,
    DateTime? fecha,
    Value<String?> attestationUid = const Value.absent(),
    bool? sincronizado,
  }) => Entrega(
    id: id ?? this.id,
    fincaId: fincaId ?? this.fincaId,
    kg: kg ?? this.kg,
    estado: estado ?? this.estado,
    fecha: fecha ?? this.fecha,
    attestationUid: attestationUid.present
        ? attestationUid.value
        : this.attestationUid,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Entrega copyWithCompanion(EntregasCompanion data) {
    return Entrega(
      id: data.id.present ? data.id.value : this.id,
      fincaId: data.fincaId.present ? data.fincaId.value : this.fincaId,
      kg: data.kg.present ? data.kg.value : this.kg,
      estado: data.estado.present ? data.estado.value : this.estado,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      attestationUid: data.attestationUid.present
          ? data.attestationUid.value
          : this.attestationUid,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entrega(')
          ..write('id: $id, ')
          ..write('fincaId: $fincaId, ')
          ..write('kg: $kg, ')
          ..write('estado: $estado, ')
          ..write('fecha: $fecha, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, fincaId, kg, estado, fecha, attestationUid, sincronizado);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entrega &&
          other.id == this.id &&
          other.fincaId == this.fincaId &&
          other.kg == this.kg &&
          other.estado == this.estado &&
          other.fecha == this.fecha &&
          other.attestationUid == this.attestationUid &&
          other.sincronizado == this.sincronizado);
}

class EntregasCompanion extends UpdateCompanion<Entrega> {
  final Value<String> id;
  final Value<String> fincaId;
  final Value<double> kg;
  final Value<String> estado;
  final Value<DateTime> fecha;
  final Value<String?> attestationUid;
  final Value<bool> sincronizado;
  final Value<int> rowid;
  const EntregasCompanion({
    this.id = const Value.absent(),
    this.fincaId = const Value.absent(),
    this.kg = const Value.absent(),
    this.estado = const Value.absent(),
    this.fecha = const Value.absent(),
    this.attestationUid = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntregasCompanion.insert({
    required String id,
    required String fincaId,
    required double kg,
    required String estado,
    required DateTime fecha,
    this.attestationUid = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fincaId = Value(fincaId),
       kg = Value(kg),
       estado = Value(estado),
       fecha = Value(fecha);
  static Insertable<Entrega> custom({
    Expression<String>? id,
    Expression<String>? fincaId,
    Expression<double>? kg,
    Expression<String>? estado,
    Expression<DateTime>? fecha,
    Expression<String>? attestationUid,
    Expression<bool>? sincronizado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fincaId != null) 'finca_id': fincaId,
      if (kg != null) 'kg': kg,
      if (estado != null) 'estado': estado,
      if (fecha != null) 'fecha': fecha,
      if (attestationUid != null) 'attestation_uid': attestationUid,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntregasCompanion copyWith({
    Value<String>? id,
    Value<String>? fincaId,
    Value<double>? kg,
    Value<String>? estado,
    Value<DateTime>? fecha,
    Value<String?>? attestationUid,
    Value<bool>? sincronizado,
    Value<int>? rowid,
  }) {
    return EntregasCompanion(
      id: id ?? this.id,
      fincaId: fincaId ?? this.fincaId,
      kg: kg ?? this.kg,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
      attestationUid: attestationUid ?? this.attestationUid,
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
    return (StringBuffer('EntregasCompanion(')
          ..write('id: $id, ')
          ..write('fincaId: $fincaId, ')
          ..write('kg: $kg, ')
          ..write('estado: $estado, ')
          ..write('fecha: $fecha, ')
          ..write('attestationUid: $attestationUid, ')
          ..write('sincronizado: $sincronizado, ')
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
    );
  }

  @override
  $FotosTable createAlias(String alias) {
    return $FotosTable(attachedDatabase, alias);
  }
}

class Foto extends DataClass implements Insertable<Foto> {
  final String id;

  /// `productor` o `finca`.
  final String entidadTipo;
  final String entidadId;

  /// `consentimiento`, `finca` o `documento`.
  final String tipo;
  final String ruta;
  final String sha256;
  final DateTime creadoEn;
  final bool sincronizado;
  const Foto({
    required this.id,
    required this.entidadTipo,
    required this.entidadId,
    required this.tipo,
    required this.ruta,
    required this.sha256,
    required this.creadoEn,
    required this.sincronizado,
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
  }) => Foto(
    id: id ?? this.id,
    entidadTipo: entidadTipo ?? this.entidadTipo,
    entidadId: entidadId ?? this.entidadId,
    tipo: tipo ?? this.tipo,
    ruta: ruta ?? this.ruta,
    sha256: sha256 ?? this.sha256,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
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
          ..write('sincronizado: $sincronizado')
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
          other.sincronizado == this.sincronizado);
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
  late final $EntregasTable entregas = $EntregasTable(this);
  late final $FotosTable fotos = $FotosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    productores,
    fincas,
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
  required String coordenadasJson,
  required double areaHa,
  required String geoHash,
  Value<String?> attestationUid,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
  Value<int> rowid,
});
typedef $$FincasTableUpdateCompanionBuilder = FincasCompanion Function({
  Value<String> id,
  Value<String> productorId,
  Value<String> nombre,
  Value<String> coordenadasJson,
  Value<double> areaHa,
  Value<String> geoHash,
  Value<String?> attestationUid,
  Value<DateTime> creadoEn,
  Value<bool> sincronizado,
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

  GeneratedColumn<String> get coordenadasJson => $composableBuilder(
    column: $table.coordenadasJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get areaHa =>
      $composableBuilder(column: $table.areaHa, builder: (column) => column);

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
          PrefetchHooks Function({bool productorId, bool entregasRefs})
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
                Value<String> coordenadasJson = const Value.absent(),
                Value<double> areaHa = const Value.absent(),
                Value<String> geoHash = const Value.absent(),
                Value<String?> attestationUid = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FincasCompanion(
                id: id,
                productorId: productorId,
                nombre: nombre,
                coordenadasJson: coordenadasJson,
                areaHa: areaHa,
                geoHash: geoHash,
                attestationUid: attestationUid,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productorId,
                required String nombre,
                required String coordenadasJson,
                required double areaHa,
                required String geoHash,
                Value<String?> attestationUid = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FincasCompanion.insert(
                id: id,
                productorId: productorId,
                nombre: nombre,
                coordenadasJson: coordenadasJson,
                areaHa: areaHa,
                geoHash: geoHash,
                attestationUid: attestationUid,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
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
          prefetchHooksCallback: ({productorId = false, entregasRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entregasRefs) db.entregas],
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
                  if (entregasRefs)
                    await $_getPrefetchedData<Finca, $FincasTable, Entrega>(
                      currentTable: table,
                      referencedTable: $$FincasTableReferences
                          ._entregasRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FincasTableReferences(db, table, p0).entregasRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.fincaId == item.id),
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
      PrefetchHooks Function({bool productorId, bool entregasRefs})
    >;
typedef $$EntregasTableCreateCompanionBuilder = EntregasCompanion Function({
  required String id,
  required String fincaId,
  required double kg,
  required String estado,
  required DateTime fecha,
  Value<String?> attestationUid,
  Value<bool> sincronizado,
  Value<int> rowid,
});
typedef $$EntregasTableUpdateCompanionBuilder = EntregasCompanion Function({
  Value<String> id,
  Value<String> fincaId,
  Value<double> kg,
  Value<String> estado,
  Value<DateTime> fecha,
  Value<String?> attestationUid,
  Value<bool> sincronizado,
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
                Value<double> kg = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<DateTime> fecha = const Value.absent(),
                Value<String?> attestationUid = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntregasCompanion(
                id: id,
                fincaId: fincaId,
                kg: kg,
                estado: estado,
                fecha: fecha,
                attestationUid: attestationUid,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fincaId,
                required double kg,
                required String estado,
                required DateTime fecha,
                Value<String?> attestationUid = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntregasCompanion.insert(
                id: id,
                fincaId: fincaId,
                kg: kg,
                estado: estado,
                fecha: fecha,
                attestationUid: attestationUid,
                sincronizado: sincronizado,
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
  $$EntregasTableTableManager get entregas =>
      $$EntregasTableTableManager(_db, _db.entregas);
  $$FotosTableTableManager get fotos =>
      $$FotosTableTableManager(_db, _db.fotos);
}

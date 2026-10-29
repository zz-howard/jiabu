// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class Spaces extends Table with TableInfo<Spaces, Space> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Spaces(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _accentColorMeta = const VerificationMeta(
    'accentColor',
  );
  late final GeneratedColumn<String> accentColor = GeneratedColumn<String>(
    'accent_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  late final GeneratedColumn<int> isDefault = GeneratedColumn<int>(
    'is_default',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _joinEpochMeta = const VerificationMeta(
    'joinEpoch',
  );
  late final GeneratedColumn<int> joinEpoch = GeneratedColumn<int>(
    'join_epoch',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _modulesMeta = const VerificationMeta(
    'modules',
  );
  late final GeneratedColumn<String> modules = GeneratedColumn<String>(
    'modules',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _localGenerationMeta = const VerificationMeta(
    'localGeneration',
  );
  late final GeneratedColumn<int> localGeneration = GeneratedColumn<int>(
    'local_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    name,
    accentColor,
    currency,
    timezone,
    isDefault,
    version,
    changeSeq,
    role,
    memberId,
    joinEpoch,
    modules,
    localGeneration,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<Space> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('accent_color')) {
      context.handle(
        _accentColorMeta,
        accentColor.isAcceptableOrUnknown(
          data['accent_color']!,
          _accentColorMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('join_epoch')) {
      context.handle(
        _joinEpochMeta,
        joinEpoch.isAcceptableOrUnknown(data['join_epoch']!, _joinEpochMeta),
      );
    }
    if (data.containsKey('modules')) {
      context.handle(
        _modulesMeta,
        modules.isAcceptableOrUnknown(data['modules']!, _modulesMeta),
      );
    }
    if (data.containsKey('local_generation')) {
      context.handle(
        _localGenerationMeta,
        localGeneration.isAcceptableOrUnknown(
          data['local_generation']!,
          _localGenerationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  Space map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Space(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      accentColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accent_color'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_default'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      joinEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}join_epoch'],
      ),
      modules: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}modules'],
      ),
      localGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_generation'],
      )!,
    );
  }

  @override
  Spaces createAlias(String alias) {
    return Spaces(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(space_id, id)',
    'CHECK(space_id = id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class Space extends DataClass implements Insertable<Space> {
  final String? id;
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? name;
  final String? accentColor;
  final String? currency;
  final String? timezone;
  final int? isDefault;
  final int? version;
  final int? changeSeq;
  final String? role;
  final String? memberId;
  final int? joinEpoch;
  final String? modules;
  final int localGeneration;
  const Space({
    this.id,
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.name,
    this.accentColor,
    this.currency,
    this.timezone,
    this.isDefault,
    this.version,
    this.changeSeq,
    this.role,
    this.memberId,
    this.joinEpoch,
    this.modules,
    required this.localGeneration,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || accentColor != null) {
      map['accent_color'] = Variable<String>(accentColor);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || timezone != null) {
      map['timezone'] = Variable<String>(timezone);
    }
    if (!nullToAbsent || isDefault != null) {
      map['is_default'] = Variable<int>(isDefault);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    if (!nullToAbsent || joinEpoch != null) {
      map['join_epoch'] = Variable<int>(joinEpoch);
    }
    if (!nullToAbsent || modules != null) {
      map['modules'] = Variable<String>(modules);
    }
    map['local_generation'] = Variable<int>(localGeneration);
    return map;
  }

  SpacesCompanion toCompanion(bool nullToAbsent) {
    return SpacesCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      accentColor: accentColor == null && nullToAbsent
          ? const Value.absent()
          : Value(accentColor),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      timezone: timezone == null && nullToAbsent
          ? const Value.absent()
          : Value(timezone),
      isDefault: isDefault == null && nullToAbsent
          ? const Value.absent()
          : Value(isDefault),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      joinEpoch: joinEpoch == null && nullToAbsent
          ? const Value.absent()
          : Value(joinEpoch),
      modules: modules == null && nullToAbsent
          ? const Value.absent()
          : Value(modules),
      localGeneration: Value(localGeneration),
    );
  }

  factory Space.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Space(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      name: serializer.fromJson<String?>(json['name']),
      accentColor: serializer.fromJson<String?>(json['accent_color']),
      currency: serializer.fromJson<String?>(json['currency']),
      timezone: serializer.fromJson<String?>(json['timezone']),
      isDefault: serializer.fromJson<int?>(json['is_default']),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      role: serializer.fromJson<String?>(json['role']),
      memberId: serializer.fromJson<String?>(json['member_id']),
      joinEpoch: serializer.fromJson<int?>(json['join_epoch']),
      modules: serializer.fromJson<String?>(json['modules']),
      localGeneration: serializer.fromJson<int>(json['local_generation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'name': serializer.toJson<String?>(name),
      'accent_color': serializer.toJson<String?>(accentColor),
      'currency': serializer.toJson<String?>(currency),
      'timezone': serializer.toJson<String?>(timezone),
      'is_default': serializer.toJson<int?>(isDefault),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'role': serializer.toJson<String?>(role),
      'member_id': serializer.toJson<String?>(memberId),
      'join_epoch': serializer.toJson<int?>(joinEpoch),
      'modules': serializer.toJson<String?>(modules),
      'local_generation': serializer.toJson<int>(localGeneration),
    };
  }

  Space copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> name = const Value.absent(),
    Value<String?> accentColor = const Value.absent(),
    Value<String?> currency = const Value.absent(),
    Value<String?> timezone = const Value.absent(),
    Value<int?> isDefault = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<String?> memberId = const Value.absent(),
    Value<int?> joinEpoch = const Value.absent(),
    Value<String?> modules = const Value.absent(),
    int? localGeneration,
  }) => Space(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    name: name.present ? name.value : this.name,
    accentColor: accentColor.present ? accentColor.value : this.accentColor,
    currency: currency.present ? currency.value : this.currency,
    timezone: timezone.present ? timezone.value : this.timezone,
    isDefault: isDefault.present ? isDefault.value : this.isDefault,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    role: role.present ? role.value : this.role,
    memberId: memberId.present ? memberId.value : this.memberId,
    joinEpoch: joinEpoch.present ? joinEpoch.value : this.joinEpoch,
    modules: modules.present ? modules.value : this.modules,
    localGeneration: localGeneration ?? this.localGeneration,
  );
  Space copyWithCompanion(SpacesCompanion data) {
    return Space(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      name: data.name.present ? data.name.value : this.name,
      accentColor: data.accentColor.present
          ? data.accentColor.value
          : this.accentColor,
      currency: data.currency.present ? data.currency.value : this.currency,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      role: data.role.present ? data.role.value : this.role,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      joinEpoch: data.joinEpoch.present ? data.joinEpoch.value : this.joinEpoch,
      modules: data.modules.present ? data.modules.value : this.modules,
      localGeneration: data.localGeneration.present
          ? data.localGeneration.value
          : this.localGeneration,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Space(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('name: $name, ')
          ..write('accentColor: $accentColor, ')
          ..write('currency: $currency, ')
          ..write('timezone: $timezone, ')
          ..write('isDefault: $isDefault, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('role: $role, ')
          ..write('memberId: $memberId, ')
          ..write('joinEpoch: $joinEpoch, ')
          ..write('modules: $modules, ')
          ..write('localGeneration: $localGeneration')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    name,
    accentColor,
    currency,
    timezone,
    isDefault,
    version,
    changeSeq,
    role,
    memberId,
    joinEpoch,
    modules,
    localGeneration,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Space &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.name == this.name &&
          other.accentColor == this.accentColor &&
          other.currency == this.currency &&
          other.timezone == this.timezone &&
          other.isDefault == this.isDefault &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq &&
          other.role == this.role &&
          other.memberId == this.memberId &&
          other.joinEpoch == this.joinEpoch &&
          other.modules == this.modules &&
          other.localGeneration == this.localGeneration);
}

class SpacesCompanion extends UpdateCompanion<Space> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> name;
  final Value<String?> accentColor;
  final Value<String?> currency;
  final Value<String?> timezone;
  final Value<int?> isDefault;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<String?> role;
  final Value<String?> memberId;
  final Value<int?> joinEpoch;
  final Value<String?> modules;
  final Value<int> localGeneration;
  final Value<int> rowid;
  const SpacesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.name = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.currency = const Value.absent(),
    this.timezone = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.role = const Value.absent(),
    this.memberId = const Value.absent(),
    this.joinEpoch = const Value.absent(),
    this.modules = const Value.absent(),
    this.localGeneration = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpacesCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.name = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.currency = const Value.absent(),
    this.timezone = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.role = const Value.absent(),
    this.memberId = const Value.absent(),
    this.joinEpoch = const Value.absent(),
    this.modules = const Value.absent(),
    this.localGeneration = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<Space> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? name,
    Expression<String>? accentColor,
    Expression<String>? currency,
    Expression<String>? timezone,
    Expression<int>? isDefault,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<String>? role,
    Expression<String>? memberId,
    Expression<int>? joinEpoch,
    Expression<String>? modules,
    Expression<int>? localGeneration,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (name != null) 'name': name,
      if (accentColor != null) 'accent_color': accentColor,
      if (currency != null) 'currency': currency,
      if (timezone != null) 'timezone': timezone,
      if (isDefault != null) 'is_default': isDefault,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (role != null) 'role': role,
      if (memberId != null) 'member_id': memberId,
      if (joinEpoch != null) 'join_epoch': joinEpoch,
      if (modules != null) 'modules': modules,
      if (localGeneration != null) 'local_generation': localGeneration,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpacesCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? name,
    Value<String?>? accentColor,
    Value<String?>? currency,
    Value<String?>? timezone,
    Value<int?>? isDefault,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<String?>? role,
    Value<String?>? memberId,
    Value<int?>? joinEpoch,
    Value<String?>? modules,
    Value<int>? localGeneration,
    Value<int>? rowid,
  }) {
    return SpacesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      name: name ?? this.name,
      accentColor: accentColor ?? this.accentColor,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      isDefault: isDefault ?? this.isDefault,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      role: role ?? this.role,
      memberId: memberId ?? this.memberId,
      joinEpoch: joinEpoch ?? this.joinEpoch,
      modules: modules ?? this.modules,
      localGeneration: localGeneration ?? this.localGeneration,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (accentColor.present) {
      map['accent_color'] = Variable<String>(accentColor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<int>(isDefault.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (joinEpoch.present) {
      map['join_epoch'] = Variable<int>(joinEpoch.value);
    }
    if (modules.present) {
      map['modules'] = Variable<String>(modules.value);
    }
    if (localGeneration.present) {
      map['local_generation'] = Variable<int>(localGeneration.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpacesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('name: $name, ')
          ..write('accentColor: $accentColor, ')
          ..write('currency: $currency, ')
          ..write('timezone: $timezone, ')
          ..write('isDefault: $isDefault, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('role: $role, ')
          ..write('memberId: $memberId, ')
          ..write('joinEpoch: $joinEpoch, ')
          ..write('modules: $modules, ')
          ..write('localGeneration: $localGeneration, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SpaceMembers extends Table with TableInfo<SpaceMembers, SpaceMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SpaceMembers(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _joinEpochMeta = const VerificationMeta(
    'joinEpoch',
  );
  late final GeneratedColumn<int> joinEpoch = GeneratedColumn<int>(
    'join_epoch',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  late final GeneratedColumn<String> joinedAt = GeneratedColumn<String>(
    'joined_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _leftAtMeta = const VerificationMeta('leftAt');
  late final GeneratedColumn<String> leftAt = GeneratedColumn<String>(
    'left_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _leftReasonMeta = const VerificationMeta(
    'leftReason',
  );
  late final GeneratedColumn<String> leftReason = GeneratedColumn<String>(
    'left_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    displayName,
    role,
    status,
    joinEpoch,
    joinedAt,
    leftAt,
    leftReason,
    version,
    changeSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'space_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpaceMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('join_epoch')) {
      context.handle(
        _joinEpochMeta,
        joinEpoch.isAcceptableOrUnknown(data['join_epoch']!, _joinEpochMeta),
      );
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    }
    if (data.containsKey('left_at')) {
      context.handle(
        _leftAtMeta,
        leftAt.isAcceptableOrUnknown(data['left_at']!, _leftAtMeta),
      );
    }
    if (data.containsKey('left_reason')) {
      context.handle(
        _leftReasonMeta,
        leftReason.isAcceptableOrUnknown(data['left_reason']!, _leftReasonMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  SpaceMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpaceMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      joinEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}join_epoch'],
      ),
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}joined_at'],
      ),
      leftAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}left_at'],
      ),
      leftReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}left_reason'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
    );
  }

  @override
  SpaceMembers createAlias(String alias) {
    return SpaceMembers(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class SpaceMember extends DataClass implements Insertable<SpaceMember> {
  final String? id;
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? displayName;
  final String? role;
  final String? status;
  final int? joinEpoch;
  final String? joinedAt;
  final String? leftAt;
  final String? leftReason;
  final int? version;
  final int? changeSeq;
  const SpaceMember({
    this.id,
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.displayName,
    this.role,
    this.status,
    this.joinEpoch,
    this.joinedAt,
    this.leftAt,
    this.leftReason,
    this.version,
    this.changeSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || joinEpoch != null) {
      map['join_epoch'] = Variable<int>(joinEpoch);
    }
    if (!nullToAbsent || joinedAt != null) {
      map['joined_at'] = Variable<String>(joinedAt);
    }
    if (!nullToAbsent || leftAt != null) {
      map['left_at'] = Variable<String>(leftAt);
    }
    if (!nullToAbsent || leftReason != null) {
      map['left_reason'] = Variable<String>(leftReason);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    return map;
  }

  SpaceMembersCompanion toCompanion(bool nullToAbsent) {
    return SpaceMembersCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      joinEpoch: joinEpoch == null && nullToAbsent
          ? const Value.absent()
          : Value(joinEpoch),
      joinedAt: joinedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(joinedAt),
      leftAt: leftAt == null && nullToAbsent
          ? const Value.absent()
          : Value(leftAt),
      leftReason: leftReason == null && nullToAbsent
          ? const Value.absent()
          : Value(leftReason),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
    );
  }

  factory SpaceMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpaceMember(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      displayName: serializer.fromJson<String?>(json['display_name']),
      role: serializer.fromJson<String?>(json['role']),
      status: serializer.fromJson<String?>(json['status']),
      joinEpoch: serializer.fromJson<int?>(json['join_epoch']),
      joinedAt: serializer.fromJson<String?>(json['joined_at']),
      leftAt: serializer.fromJson<String?>(json['left_at']),
      leftReason: serializer.fromJson<String?>(json['left_reason']),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'display_name': serializer.toJson<String?>(displayName),
      'role': serializer.toJson<String?>(role),
      'status': serializer.toJson<String?>(status),
      'join_epoch': serializer.toJson<int?>(joinEpoch),
      'joined_at': serializer.toJson<String?>(joinedAt),
      'left_at': serializer.toJson<String?>(leftAt),
      'left_reason': serializer.toJson<String?>(leftReason),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
    };
  }

  SpaceMember copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> displayName = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<int?> joinEpoch = const Value.absent(),
    Value<String?> joinedAt = const Value.absent(),
    Value<String?> leftAt = const Value.absent(),
    Value<String?> leftReason = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
  }) => SpaceMember(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    displayName: displayName.present ? displayName.value : this.displayName,
    role: role.present ? role.value : this.role,
    status: status.present ? status.value : this.status,
    joinEpoch: joinEpoch.present ? joinEpoch.value : this.joinEpoch,
    joinedAt: joinedAt.present ? joinedAt.value : this.joinedAt,
    leftAt: leftAt.present ? leftAt.value : this.leftAt,
    leftReason: leftReason.present ? leftReason.value : this.leftReason,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
  );
  SpaceMember copyWithCompanion(SpaceMembersCompanion data) {
    return SpaceMember(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      joinEpoch: data.joinEpoch.present ? data.joinEpoch.value : this.joinEpoch,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      leftAt: data.leftAt.present ? data.leftAt.value : this.leftAt,
      leftReason: data.leftReason.present
          ? data.leftReason.value
          : this.leftReason,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMember(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('joinEpoch: $joinEpoch, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('leftAt: $leftAt, ')
          ..write('leftReason: $leftReason, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    displayName,
    role,
    status,
    joinEpoch,
    joinedAt,
    leftAt,
    leftReason,
    version,
    changeSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpaceMember &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.displayName == this.displayName &&
          other.role == this.role &&
          other.status == this.status &&
          other.joinEpoch == this.joinEpoch &&
          other.joinedAt == this.joinedAt &&
          other.leftAt == this.leftAt &&
          other.leftReason == this.leftReason &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq);
}

class SpaceMembersCompanion extends UpdateCompanion<SpaceMember> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> displayName;
  final Value<String?> role;
  final Value<String?> status;
  final Value<int?> joinEpoch;
  final Value<String?> joinedAt;
  final Value<String?> leftAt;
  final Value<String?> leftReason;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<int> rowid;
  const SpaceMembersCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.displayName = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.joinEpoch = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.leftReason = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpaceMembersCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.displayName = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.joinEpoch = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.leftReason = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<SpaceMember> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? displayName,
    Expression<String>? role,
    Expression<String>? status,
    Expression<int>? joinEpoch,
    Expression<String>? joinedAt,
    Expression<String>? leftAt,
    Expression<String>? leftReason,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (displayName != null) 'display_name': displayName,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (joinEpoch != null) 'join_epoch': joinEpoch,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (leftAt != null) 'left_at': leftAt,
      if (leftReason != null) 'left_reason': leftReason,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpaceMembersCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? displayName,
    Value<String?>? role,
    Value<String?>? status,
    Value<int?>? joinEpoch,
    Value<String?>? joinedAt,
    Value<String?>? leftAt,
    Value<String?>? leftReason,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<int>? rowid,
  }) {
    return SpaceMembersCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      status: status ?? this.status,
      joinEpoch: joinEpoch ?? this.joinEpoch,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      leftReason: leftReason ?? this.leftReason,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (joinEpoch.present) {
      map['join_epoch'] = Variable<int>(joinEpoch.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<String>(joinedAt.value);
    }
    if (leftAt.present) {
      map['left_at'] = Variable<String>(leftAt.value);
    }
    if (leftReason.present) {
      map['left_reason'] = Variable<String>(leftReason.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpaceMembersCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('joinEpoch: $joinEpoch, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('leftAt: $leftAt, ')
          ..write('leftReason: $leftReason, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class MemberGrants extends Table with TableInfo<MemberGrants, MemberGrant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MemberGrants(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    spaceId,
    syncState,
    dataJson,
    memberId,
    module,
    level,
    changeSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'member_grants';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemberGrant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, memberId, module};
  @override
  MemberGrant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemberGrant(
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
    );
  }

  @override
  MemberGrants createAlias(String alias) {
    return MemberGrants(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(space_id, member_id, module)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class MemberGrant extends DataClass implements Insertable<MemberGrant> {
  final String spaceId;
  final String syncState;
  final String dataJson;
  final String? memberId;
  final String? module;
  final String? level;
  final int? changeSeq;
  const MemberGrant({
    required this.spaceId,
    required this.syncState,
    required this.dataJson,
    this.memberId,
    this.module,
    this.level,
    this.changeSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<String>(level);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    return map;
  }

  MemberGrantsCompanion toCompanion(bool nullToAbsent) {
    return MemberGrantsCompanion(
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      dataJson: Value(dataJson),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
      level: level == null && nullToAbsent
          ? const Value.absent()
          : Value(level),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
    );
  }

  factory MemberGrant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemberGrant(
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      memberId: serializer.fromJson<String?>(json['member_id']),
      module: serializer.fromJson<String?>(json['module']),
      level: serializer.fromJson<String?>(json['level']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'data_json': serializer.toJson<String>(dataJson),
      'member_id': serializer.toJson<String?>(memberId),
      'module': serializer.toJson<String?>(module),
      'level': serializer.toJson<String?>(level),
      'change_seq': serializer.toJson<int?>(changeSeq),
    };
  }

  MemberGrant copyWith({
    String? spaceId,
    String? syncState,
    String? dataJson,
    Value<String?> memberId = const Value.absent(),
    Value<String?> module = const Value.absent(),
    Value<String?> level = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
  }) => MemberGrant(
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    dataJson: dataJson ?? this.dataJson,
    memberId: memberId.present ? memberId.value : this.memberId,
    module: module.present ? module.value : this.module,
    level: level.present ? level.value : this.level,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
  );
  MemberGrant copyWithCompanion(MemberGrantsCompanion data) {
    return MemberGrant(
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      module: data.module.present ? data.module.value : this.module,
      level: data.level.present ? data.level.value : this.level,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemberGrant(')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('memberId: $memberId, ')
          ..write('module: $module, ')
          ..write('level: $level, ')
          ..write('changeSeq: $changeSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    spaceId,
    syncState,
    dataJson,
    memberId,
    module,
    level,
    changeSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemberGrant &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.dataJson == this.dataJson &&
          other.memberId == this.memberId &&
          other.module == this.module &&
          other.level == this.level &&
          other.changeSeq == this.changeSeq);
}

class MemberGrantsCompanion extends UpdateCompanion<MemberGrant> {
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<String> dataJson;
  final Value<String?> memberId;
  final Value<String?> module;
  final Value<String?> level;
  final Value<int?> changeSeq;
  final Value<int> rowid;
  const MemberGrantsCompanion({
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.memberId = const Value.absent(),
    this.module = const Value.absent(),
    this.level = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemberGrantsCompanion.insert({
    required String spaceId,
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.memberId = const Value.absent(),
    this.module = const Value.absent(),
    this.level = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<MemberGrant> custom({
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<String>? dataJson,
    Expression<String>? memberId,
    Expression<String>? module,
    Expression<String>? level,
    Expression<int>? changeSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (dataJson != null) 'data_json': dataJson,
      if (memberId != null) 'member_id': memberId,
      if (module != null) 'module': module,
      if (level != null) 'level': level,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemberGrantsCompanion copyWith({
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<String>? dataJson,
    Value<String?>? memberId,
    Value<String?>? module,
    Value<String?>? level,
    Value<int?>? changeSeq,
    Value<int>? rowid,
  }) {
    return MemberGrantsCompanion(
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      dataJson: dataJson ?? this.dataJson,
      memberId: memberId ?? this.memberId,
      module: module ?? this.module,
      level: level ?? this.level,
      changeSeq: changeSeq ?? this.changeSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemberGrantsCompanion(')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('memberId: $memberId, ')
          ..write('module: $module, ')
          ..write('level: $level, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Accounts extends Table with TableInfo<Accounts, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Accounts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _isReserveMeta = const VerificationMeta(
    'isReserve',
  );
  late final GeneratedColumn<int> isReserve = GeneratedColumn<int>(
    'is_reserve',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _openingBalanceMinorMeta =
      const VerificationMeta('openingBalanceMinor');
  late final GeneratedColumn<int> openingBalanceMinor = GeneratedColumn<int>(
    'opening_balance_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _openingOnMeta = const VerificationMeta(
    'openingOn',
  );
  late final GeneratedColumn<String> openingOn = GeneratedColumn<String>(
    'opening_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  late final GeneratedColumn<int> sortKey = GeneratedColumn<int>(
    'sort_key',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMemberIdMeta = const VerificationMeta(
    'createdByMemberId',
  );
  late final GeneratedColumn<String> createdByMemberId =
      GeneratedColumn<String>(
        'created_by_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    kind,
    name,
    isReserve,
    openingBalanceMinor,
    openingOn,
    sortKey,
    createdByMemberId,
    archivedAt,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('is_reserve')) {
      context.handle(
        _isReserveMeta,
        isReserve.isAcceptableOrUnknown(data['is_reserve']!, _isReserveMeta),
      );
    }
    if (data.containsKey('opening_balance_minor')) {
      context.handle(
        _openingBalanceMinorMeta,
        openingBalanceMinor.isAcceptableOrUnknown(
          data['opening_balance_minor']!,
          _openingBalanceMinorMeta,
        ),
      );
    }
    if (data.containsKey('opening_on')) {
      context.handle(
        _openingOnMeta,
        openingOn.isAcceptableOrUnknown(data['opening_on']!, _openingOnMeta),
      );
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    }
    if (data.containsKey('created_by_member_id')) {
      context.handle(
        _createdByMemberIdMeta,
        createdByMemberId.isAcceptableOrUnknown(
          data['created_by_member_id']!,
          _createdByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      isReserve: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_reserve'],
      ),
      openingBalanceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_balance_minor'],
      ),
      openingOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opening_on'],
      ),
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_key'],
      ),
      createdByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_member_id'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  Accounts createAlias(String alias) {
    return Accounts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class Account extends DataClass implements Insertable<Account> {
  final String? id;
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? module;
  final String? visibility;
  final String? kind;
  final String? name;
  final int? isReserve;
  final int? openingBalanceMinor;
  final String? openingOn;
  final int? sortKey;
  final String? createdByMemberId;
  final String? archivedAt;
  final int? version;
  final int? changeSeq;
  final String? createdAt;
  final String? updatedAt;
  const Account({
    this.id,
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.module,
    this.visibility,
    this.kind,
    this.name,
    this.isReserve,
    this.openingBalanceMinor,
    this.openingOn,
    this.sortKey,
    this.createdByMemberId,
    this.archivedAt,
    this.version,
    this.changeSeq,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || visibility != null) {
      map['visibility'] = Variable<String>(visibility);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || isReserve != null) {
      map['is_reserve'] = Variable<int>(isReserve);
    }
    if (!nullToAbsent || openingBalanceMinor != null) {
      map['opening_balance_minor'] = Variable<int>(openingBalanceMinor);
    }
    if (!nullToAbsent || openingOn != null) {
      map['opening_on'] = Variable<String>(openingOn);
    }
    if (!nullToAbsent || sortKey != null) {
      map['sort_key'] = Variable<int>(sortKey);
    }
    if (!nullToAbsent || createdByMemberId != null) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
      visibility: visibility == null && nullToAbsent
          ? const Value.absent()
          : Value(visibility),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      isReserve: isReserve == null && nullToAbsent
          ? const Value.absent()
          : Value(isReserve),
      openingBalanceMinor: openingBalanceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(openingBalanceMinor),
      openingOn: openingOn == null && nullToAbsent
          ? const Value.absent()
          : Value(openingOn),
      sortKey: sortKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sortKey),
      createdByMemberId: createdByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByMemberId),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      module: serializer.fromJson<String?>(json['module']),
      visibility: serializer.fromJson<String?>(json['visibility']),
      kind: serializer.fromJson<String?>(json['kind']),
      name: serializer.fromJson<String?>(json['name']),
      isReserve: serializer.fromJson<int?>(json['is_reserve']),
      openingBalanceMinor: serializer.fromJson<int?>(
        json['opening_balance_minor'],
      ),
      openingOn: serializer.fromJson<String?>(json['opening_on']),
      sortKey: serializer.fromJson<int?>(json['sort_key']),
      createdByMemberId: serializer.fromJson<String?>(
        json['created_by_member_id'],
      ),
      archivedAt: serializer.fromJson<String?>(json['archived_at']),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'module': serializer.toJson<String?>(module),
      'visibility': serializer.toJson<String?>(visibility),
      'kind': serializer.toJson<String?>(kind),
      'name': serializer.toJson<String?>(name),
      'is_reserve': serializer.toJson<int?>(isReserve),
      'opening_balance_minor': serializer.toJson<int?>(openingBalanceMinor),
      'opening_on': serializer.toJson<String?>(openingOn),
      'sort_key': serializer.toJson<int?>(sortKey),
      'created_by_member_id': serializer.toJson<String?>(createdByMemberId),
      'archived_at': serializer.toJson<String?>(archivedAt),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'created_at': serializer.toJson<String?>(createdAt),
      'updated_at': serializer.toJson<String?>(updatedAt),
    };
  }

  Account copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> module = const Value.absent(),
    Value<String?> visibility = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<int?> isReserve = const Value.absent(),
    Value<int?> openingBalanceMinor = const Value.absent(),
    Value<String?> openingOn = const Value.absent(),
    Value<int?> sortKey = const Value.absent(),
    Value<String?> createdByMemberId = const Value.absent(),
    Value<String?> archivedAt = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => Account(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    module: module.present ? module.value : this.module,
    visibility: visibility.present ? visibility.value : this.visibility,
    kind: kind.present ? kind.value : this.kind,
    name: name.present ? name.value : this.name,
    isReserve: isReserve.present ? isReserve.value : this.isReserve,
    openingBalanceMinor: openingBalanceMinor.present
        ? openingBalanceMinor.value
        : this.openingBalanceMinor,
    openingOn: openingOn.present ? openingOn.value : this.openingOn,
    sortKey: sortKey.present ? sortKey.value : this.sortKey,
    createdByMemberId: createdByMemberId.present
        ? createdByMemberId.value
        : this.createdByMemberId,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      module: data.module.present ? data.module.value : this.module,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      isReserve: data.isReserve.present ? data.isReserve.value : this.isReserve,
      openingBalanceMinor: data.openingBalanceMinor.present
          ? data.openingBalanceMinor.value
          : this.openingBalanceMinor,
      openingOn: data.openingOn.present ? data.openingOn.value : this.openingOn,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      createdByMemberId: data.createdByMemberId.present
          ? data.createdByMemberId.value
          : this.createdByMemberId,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('isReserve: $isReserve, ')
          ..write('openingBalanceMinor: $openingBalanceMinor, ')
          ..write('openingOn: $openingOn, ')
          ..write('sortKey: $sortKey, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    kind,
    name,
    isReserve,
    openingBalanceMinor,
    openingOn,
    sortKey,
    createdByMemberId,
    archivedAt,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.module == this.module &&
          other.visibility == this.visibility &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.isReserve == this.isReserve &&
          other.openingBalanceMinor == this.openingBalanceMinor &&
          other.openingOn == this.openingOn &&
          other.sortKey == this.sortKey &&
          other.createdByMemberId == this.createdByMemberId &&
          other.archivedAt == this.archivedAt &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> module;
  final Value<String?> visibility;
  final Value<String?> kind;
  final Value<String?> name;
  final Value<int?> isReserve;
  final Value<int?> openingBalanceMinor;
  final Value<String?> openingOn;
  final Value<int?> sortKey;
  final Value<String?> createdByMemberId;
  final Value<String?> archivedAt;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.isReserve = const Value.absent(),
    this.openingBalanceMinor = const Value.absent(),
    this.openingOn = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.isReserve = const Value.absent(),
    this.openingBalanceMinor = const Value.absent(),
    this.openingOn = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? module,
    Expression<String>? visibility,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? isReserve,
    Expression<int>? openingBalanceMinor,
    Expression<String>? openingOn,
    Expression<int>? sortKey,
    Expression<String>? createdByMemberId,
    Expression<String>? archivedAt,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (module != null) 'module': module,
      if (visibility != null) 'visibility': visibility,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (isReserve != null) 'is_reserve': isReserve,
      if (openingBalanceMinor != null)
        'opening_balance_minor': openingBalanceMinor,
      if (openingOn != null) 'opening_on': openingOn,
      if (sortKey != null) 'sort_key': sortKey,
      if (createdByMemberId != null) 'created_by_member_id': createdByMemberId,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? module,
    Value<String?>? visibility,
    Value<String?>? kind,
    Value<String?>? name,
    Value<int?>? isReserve,
    Value<int?>? openingBalanceMinor,
    Value<String?>? openingOn,
    Value<int?>? sortKey,
    Value<String?>? createdByMemberId,
    Value<String?>? archivedAt,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      module: module ?? this.module,
      visibility: visibility ?? this.visibility,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      isReserve: isReserve ?? this.isReserve,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      openingOn: openingOn ?? this.openingOn,
      sortKey: sortKey ?? this.sortKey,
      createdByMemberId: createdByMemberId ?? this.createdByMemberId,
      archivedAt: archivedAt ?? this.archivedAt,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isReserve.present) {
      map['is_reserve'] = Variable<int>(isReserve.value);
    }
    if (openingBalanceMinor.present) {
      map['opening_balance_minor'] = Variable<int>(openingBalanceMinor.value);
    }
    if (openingOn.present) {
      map['opening_on'] = Variable<String>(openingOn.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<int>(sortKey.value);
    }
    if (createdByMemberId.present) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('isReserve: $isReserve, ')
          ..write('openingBalanceMinor: $openingBalanceMinor, ')
          ..write('openingOn: $openingOn, ')
          ..write('sortKey: $sortKey, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AllocationPlans extends Table
    with TableInfo<AllocationPlans, AllocationPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AllocationPlans(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  late final GeneratedColumn<int> enabled = GeneratedColumn<int>(
    'enabled',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _nextRunOnMeta = const VerificationMeta(
    'nextRunOn',
  );
  late final GeneratedColumn<String> nextRunOn = GeneratedColumn<String>(
    'next_run_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastRunMonthMeta = const VerificationMeta(
    'lastRunMonth',
  );
  late final GeneratedColumn<String> lastRunMonth = GeneratedColumn<String>(
    'last_run_month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    accountId,
    amountMinor,
    dayOfMonth,
    enabled,
    nextRunOn,
    lastRunMonth,
    version,
    changeSeq,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'allocation_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<AllocationPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('next_run_on')) {
      context.handle(
        _nextRunOnMeta,
        nextRunOn.isAcceptableOrUnknown(data['next_run_on']!, _nextRunOnMeta),
      );
    }
    if (data.containsKey('last_run_month')) {
      context.handle(
        _lastRunMonthMeta,
        lastRunMonth.isAcceptableOrUnknown(
          data['last_run_month']!,
          _lastRunMonthMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, accountId};
  @override
  AllocationPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllocationPlan(
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      ),
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enabled'],
      ),
      nextRunOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_run_on'],
      ),
      lastRunMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_run_month'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  AllocationPlans createAlias(String alias) {
    return AllocationPlans(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(space_id, account_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class AllocationPlan extends DataClass implements Insertable<AllocationPlan> {
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? accountId;
  final int? amountMinor;
  final int? dayOfMonth;
  final int? enabled;
  final String? nextRunOn;
  final String? lastRunMonth;
  final int? version;
  final int? changeSeq;
  final String? updatedAt;
  const AllocationPlan({
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.accountId,
    this.amountMinor,
    this.dayOfMonth,
    this.enabled,
    this.nextRunOn,
    this.lastRunMonth,
    this.version,
    this.changeSeq,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || amountMinor != null) {
      map['amount_minor'] = Variable<int>(amountMinor);
    }
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    if (!nullToAbsent || enabled != null) {
      map['enabled'] = Variable<int>(enabled);
    }
    if (!nullToAbsent || nextRunOn != null) {
      map['next_run_on'] = Variable<String>(nextRunOn);
    }
    if (!nullToAbsent || lastRunMonth != null) {
      map['last_run_month'] = Variable<String>(lastRunMonth);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  AllocationPlansCompanion toCompanion(bool nullToAbsent) {
    return AllocationPlansCompanion(
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      amountMinor: amountMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(amountMinor),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      enabled: enabled == null && nullToAbsent
          ? const Value.absent()
          : Value(enabled),
      nextRunOn: nextRunOn == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRunOn),
      lastRunMonth: lastRunMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRunMonth),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AllocationPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllocationPlan(
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      accountId: serializer.fromJson<String?>(json['account_id']),
      amountMinor: serializer.fromJson<int?>(json['amount_minor']),
      dayOfMonth: serializer.fromJson<int?>(json['day_of_month']),
      enabled: serializer.fromJson<int?>(json['enabled']),
      nextRunOn: serializer.fromJson<String?>(json['next_run_on']),
      lastRunMonth: serializer.fromJson<String?>(json['last_run_month']),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'account_id': serializer.toJson<String?>(accountId),
      'amount_minor': serializer.toJson<int?>(amountMinor),
      'day_of_month': serializer.toJson<int?>(dayOfMonth),
      'enabled': serializer.toJson<int?>(enabled),
      'next_run_on': serializer.toJson<String?>(nextRunOn),
      'last_run_month': serializer.toJson<String?>(lastRunMonth),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'updated_at': serializer.toJson<String?>(updatedAt),
    };
  }

  AllocationPlan copyWith({
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> accountId = const Value.absent(),
    Value<int?> amountMinor = const Value.absent(),
    Value<int?> dayOfMonth = const Value.absent(),
    Value<int?> enabled = const Value.absent(),
    Value<String?> nextRunOn = const Value.absent(),
    Value<String?> lastRunMonth = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => AllocationPlan(
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    accountId: accountId.present ? accountId.value : this.accountId,
    amountMinor: amountMinor.present ? amountMinor.value : this.amountMinor,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    enabled: enabled.present ? enabled.value : this.enabled,
    nextRunOn: nextRunOn.present ? nextRunOn.value : this.nextRunOn,
    lastRunMonth: lastRunMonth.present ? lastRunMonth.value : this.lastRunMonth,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  AllocationPlan copyWithCompanion(AllocationPlansCompanion data) {
    return AllocationPlan(
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      nextRunOn: data.nextRunOn.present ? data.nextRunOn.value : this.nextRunOn,
      lastRunMonth: data.lastRunMonth.present
          ? data.lastRunMonth.value
          : this.lastRunMonth,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllocationPlan(')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('accountId: $accountId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('enabled: $enabled, ')
          ..write('nextRunOn: $nextRunOn, ')
          ..write('lastRunMonth: $lastRunMonth, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    accountId,
    amountMinor,
    dayOfMonth,
    enabled,
    nextRunOn,
    lastRunMonth,
    version,
    changeSeq,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllocationPlan &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.accountId == this.accountId &&
          other.amountMinor == this.amountMinor &&
          other.dayOfMonth == this.dayOfMonth &&
          other.enabled == this.enabled &&
          other.nextRunOn == this.nextRunOn &&
          other.lastRunMonth == this.lastRunMonth &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq &&
          other.updatedAt == this.updatedAt);
}

class AllocationPlansCompanion extends UpdateCompanion<AllocationPlan> {
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> accountId;
  final Value<int?> amountMinor;
  final Value<int?> dayOfMonth;
  final Value<int?> enabled;
  final Value<String?> nextRunOn;
  final Value<String?> lastRunMonth;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const AllocationPlansCompanion({
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.accountId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.enabled = const Value.absent(),
    this.nextRunOn = const Value.absent(),
    this.lastRunMonth = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AllocationPlansCompanion.insert({
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.accountId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.enabled = const Value.absent(),
    this.nextRunOn = const Value.absent(),
    this.lastRunMonth = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<AllocationPlan> custom({
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? accountId,
    Expression<int>? amountMinor,
    Expression<int>? dayOfMonth,
    Expression<int>? enabled,
    Expression<String>? nextRunOn,
    Expression<String>? lastRunMonth,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (accountId != null) 'account_id': accountId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (enabled != null) 'enabled': enabled,
      if (nextRunOn != null) 'next_run_on': nextRunOn,
      if (lastRunMonth != null) 'last_run_month': lastRunMonth,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AllocationPlansCompanion copyWith({
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? accountId,
    Value<int?>? amountMinor,
    Value<int?>? dayOfMonth,
    Value<int?>? enabled,
    Value<String?>? nextRunOn,
    Value<String?>? lastRunMonth,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return AllocationPlansCompanion(
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      accountId: accountId ?? this.accountId,
      amountMinor: amountMinor ?? this.amountMinor,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      enabled: enabled ?? this.enabled,
      nextRunOn: nextRunOn ?? this.nextRunOn,
      lastRunMonth: lastRunMonth ?? this.lastRunMonth,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<int>(enabled.value);
    }
    if (nextRunOn.present) {
      map['next_run_on'] = Variable<String>(nextRunOn.value);
    }
    if (lastRunMonth.present) {
      map['last_run_month'] = Variable<String>(lastRunMonth.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllocationPlansCompanion(')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('accountId: $accountId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('enabled: $enabled, ')
          ..write('nextRunOn: $nextRunOn, ')
          ..write('lastRunMonth: $lastRunMonth, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Tags extends Table with TableInfo<Tags, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _presetKeyMeta = const VerificationMeta(
    'presetKey',
  );
  late final GeneratedColumn<String> presetKey = GeneratedColumn<String>(
    'preset_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMemberIdMeta = const VerificationMeta(
    'createdByMemberId',
  );
  late final GeneratedColumn<String> createdByMemberId =
      GeneratedColumn<String>(
        'created_by_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    presetKey,
    name,
    createdByMemberId,
    deletedAt,
    version,
    changeSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    if (data.containsKey('preset_key')) {
      context.handle(
        _presetKeyMeta,
        presetKey.isAcceptableOrUnknown(data['preset_key']!, _presetKeyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('created_by_member_id')) {
      context.handle(
        _createdByMemberIdMeta,
        createdByMemberId.isAcceptableOrUnknown(
          data['created_by_member_id']!,
          _createdByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
      presetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_key'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      createdByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_member_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
    );
  }

  @override
  Tags createAlias(String alias) {
    return Tags(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class Tag extends DataClass implements Insertable<Tag> {
  final String? id;
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? module;
  final String? presetKey;
  final String? name;
  final String? createdByMemberId;
  final String? deletedAt;
  final int? version;
  final int? changeSeq;
  const Tag({
    this.id,
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.module,
    this.presetKey,
    this.name,
    this.createdByMemberId,
    this.deletedAt,
    this.version,
    this.changeSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || presetKey != null) {
      map['preset_key'] = Variable<String>(presetKey);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || createdByMemberId != null) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
      presetKey: presetKey == null && nullToAbsent
          ? const Value.absent()
          : Value(presetKey),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      createdByMemberId: createdByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByMemberId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      module: serializer.fromJson<String?>(json['module']),
      presetKey: serializer.fromJson<String?>(json['preset_key']),
      name: serializer.fromJson<String?>(json['name']),
      createdByMemberId: serializer.fromJson<String?>(
        json['created_by_member_id'],
      ),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'module': serializer.toJson<String?>(module),
      'preset_key': serializer.toJson<String?>(presetKey),
      'name': serializer.toJson<String?>(name),
      'created_by_member_id': serializer.toJson<String?>(createdByMemberId),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
    };
  }

  Tag copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> module = const Value.absent(),
    Value<String?> presetKey = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> createdByMemberId = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
  }) => Tag(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    module: module.present ? module.value : this.module,
    presetKey: presetKey.present ? presetKey.value : this.presetKey,
    name: name.present ? name.value : this.name,
    createdByMemberId: createdByMemberId.present
        ? createdByMemberId.value
        : this.createdByMemberId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      module: data.module.present ? data.module.value : this.module,
      presetKey: data.presetKey.present ? data.presetKey.value : this.presetKey,
      name: data.name.present ? data.name.value : this.name,
      createdByMemberId: data.createdByMemberId.present
          ? data.createdByMemberId.value
          : this.createdByMemberId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('presetKey: $presetKey, ')
          ..write('name: $name, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    presetKey,
    name,
    createdByMemberId,
    deletedAt,
    version,
    changeSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.module == this.module &&
          other.presetKey == this.presetKey &&
          other.name == this.name &&
          other.createdByMemberId == this.createdByMemberId &&
          other.deletedAt == this.deletedAt &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> module;
  final Value<String?> presetKey;
  final Value<String?> name;
  final Value<String?> createdByMemberId;
  final Value<String?> deletedAt;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.presetKey = const Value.absent(),
    this.name = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.presetKey = const Value.absent(),
    this.name = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? module,
    Expression<String>? presetKey,
    Expression<String>? name,
    Expression<String>? createdByMemberId,
    Expression<String>? deletedAt,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (module != null) 'module': module,
      if (presetKey != null) 'preset_key': presetKey,
      if (name != null) 'name': name,
      if (createdByMemberId != null) 'created_by_member_id': createdByMemberId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? module,
    Value<String?>? presetKey,
    Value<String?>? name,
    Value<String?>? createdByMemberId,
    Value<String?>? deletedAt,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      module: module ?? this.module,
      presetKey: presetKey ?? this.presetKey,
      name: name ?? this.name,
      createdByMemberId: createdByMemberId ?? this.createdByMemberId,
      deletedAt: deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (presetKey.present) {
      map['preset_key'] = Variable<String>(presetKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdByMemberId.present) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('presetKey: $presetKey, ')
          ..write('name: $name, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Records extends Table with TableInfo<Records, Record> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Records(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _occurredOnMeta = const VerificationMeta(
    'occurredOn',
  );
  late final GeneratedColumn<String> occurredOn = GeneratedColumn<String>(
    'occurred_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _purposeIdMeta = const VerificationMeta(
    'purposeId',
  );
  late final GeneratedColumn<String> purposeId = GeneratedColumn<String>(
    'purpose_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _toPurposeIdMeta = const VerificationMeta(
    'toPurposeId',
  );
  late final GeneratedColumn<String> toPurposeId = GeneratedColumn<String>(
    'to_purpose_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _refundOfIdMeta = const VerificationMeta(
    'refundOfId',
  );
  late final GeneratedColumn<String> refundOfId = GeneratedColumn<String>(
    'refund_of_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _tagIdsMeta = const VerificationMeta('tagIds');
  late final GeneratedColumn<String> tagIds = GeneratedColumn<String>(
    'tag_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _attachmentsMeta = const VerificationMeta(
    'attachments',
  );
  late final GeneratedColumn<String> attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMemberIdMeta = const VerificationMeta(
    'createdByMemberId',
  );
  late final GeneratedColumn<String> createdByMemberId =
      GeneratedColumn<String>(
        'created_by_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _updatedByMemberIdMeta = const VerificationMeta(
    'updatedByMemberId',
  );
  late final GeneratedColumn<String> updatedByMemberId =
      GeneratedColumn<String>(
        'updated_by_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    kind,
    amountMinor,
    occurredOn,
    accountId,
    toAccountId,
    purposeId,
    toPurposeId,
    refundOfId,
    tagIds,
    note,
    attachments,
    status,
    voidReason,
    origin,
    runId,
    createdByMemberId,
    updatedByMemberId,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<Record> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    }
    if (data.containsKey('occurred_on')) {
      context.handle(
        _occurredOnMeta,
        occurredOn.isAcceptableOrUnknown(data['occurred_on']!, _occurredOnMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('purpose_id')) {
      context.handle(
        _purposeIdMeta,
        purposeId.isAcceptableOrUnknown(data['purpose_id']!, _purposeIdMeta),
      );
    }
    if (data.containsKey('to_purpose_id')) {
      context.handle(
        _toPurposeIdMeta,
        toPurposeId.isAcceptableOrUnknown(
          data['to_purpose_id']!,
          _toPurposeIdMeta,
        ),
      );
    }
    if (data.containsKey('refund_of_id')) {
      context.handle(
        _refundOfIdMeta,
        refundOfId.isAcceptableOrUnknown(
          data['refund_of_id']!,
          _refundOfIdMeta,
        ),
      );
    }
    if (data.containsKey('tag_ids')) {
      context.handle(
        _tagIdsMeta,
        tagIds.isAcceptableOrUnknown(data['tag_ids']!, _tagIdsMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('attachments')) {
      context.handle(
        _attachmentsMeta,
        attachments.isAcceptableOrUnknown(
          data['attachments']!,
          _attachmentsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('created_by_member_id')) {
      context.handle(
        _createdByMemberIdMeta,
        createdByMemberId.isAcceptableOrUnknown(
          data['created_by_member_id']!,
          _createdByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_by_member_id')) {
      context.handle(
        _updatedByMemberIdMeta,
        updatedByMemberId.isAcceptableOrUnknown(
          data['updated_by_member_id']!,
          _updatedByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  Record map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Record(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      ),
      occurredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_on'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      purposeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose_id'],
      ),
      toPurposeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_purpose_id'],
      ),
      refundOfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refund_of_id'],
      ),
      tagIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_ids'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      attachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      createdByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_member_id'],
      ),
      updatedByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by_member_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  Records createAlias(String alias) {
    return Records(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class Record extends DataClass implements Insertable<Record> {
  final String? id;
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? module;
  final String? visibility;
  final String? kind;
  final int? amountMinor;
  final String? occurredOn;
  final String? accountId;
  final String? toAccountId;
  final String? purposeId;
  final String? toPurposeId;
  final String? refundOfId;
  final String? tagIds;
  final String? note;
  final String? attachments;
  final String? status;
  final String? voidReason;
  final String? origin;
  final String? runId;
  final String? createdByMemberId;
  final String? updatedByMemberId;
  final int? version;
  final int? changeSeq;
  final String? createdAt;
  final String? updatedAt;
  const Record({
    this.id,
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.module,
    this.visibility,
    this.kind,
    this.amountMinor,
    this.occurredOn,
    this.accountId,
    this.toAccountId,
    this.purposeId,
    this.toPurposeId,
    this.refundOfId,
    this.tagIds,
    this.note,
    this.attachments,
    this.status,
    this.voidReason,
    this.origin,
    this.runId,
    this.createdByMemberId,
    this.updatedByMemberId,
    this.version,
    this.changeSeq,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || visibility != null) {
      map['visibility'] = Variable<String>(visibility);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || amountMinor != null) {
      map['amount_minor'] = Variable<int>(amountMinor);
    }
    if (!nullToAbsent || occurredOn != null) {
      map['occurred_on'] = Variable<String>(occurredOn);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    if (!nullToAbsent || purposeId != null) {
      map['purpose_id'] = Variable<String>(purposeId);
    }
    if (!nullToAbsent || toPurposeId != null) {
      map['to_purpose_id'] = Variable<String>(toPurposeId);
    }
    if (!nullToAbsent || refundOfId != null) {
      map['refund_of_id'] = Variable<String>(refundOfId);
    }
    if (!nullToAbsent || tagIds != null) {
      map['tag_ids'] = Variable<String>(tagIds);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || attachments != null) {
      map['attachments'] = Variable<String>(attachments);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    if (!nullToAbsent || createdByMemberId != null) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId);
    }
    if (!nullToAbsent || updatedByMemberId != null) {
      map['updated_by_member_id'] = Variable<String>(updatedByMemberId);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
      visibility: visibility == null && nullToAbsent
          ? const Value.absent()
          : Value(visibility),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      amountMinor: amountMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(amountMinor),
      occurredOn: occurredOn == null && nullToAbsent
          ? const Value.absent()
          : Value(occurredOn),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      purposeId: purposeId == null && nullToAbsent
          ? const Value.absent()
          : Value(purposeId),
      toPurposeId: toPurposeId == null && nullToAbsent
          ? const Value.absent()
          : Value(toPurposeId),
      refundOfId: refundOfId == null && nullToAbsent
          ? const Value.absent()
          : Value(refundOfId),
      tagIds: tagIds == null && nullToAbsent
          ? const Value.absent()
          : Value(tagIds),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      attachments: attachments == null && nullToAbsent
          ? const Value.absent()
          : Value(attachments),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      createdByMemberId: createdByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByMemberId),
      updatedByMemberId: updatedByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedByMemberId),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Record.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Record(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      module: serializer.fromJson<String?>(json['module']),
      visibility: serializer.fromJson<String?>(json['visibility']),
      kind: serializer.fromJson<String?>(json['kind']),
      amountMinor: serializer.fromJson<int?>(json['amount_minor']),
      occurredOn: serializer.fromJson<String?>(json['occurred_on']),
      accountId: serializer.fromJson<String?>(json['account_id']),
      toAccountId: serializer.fromJson<String?>(json['to_account_id']),
      purposeId: serializer.fromJson<String?>(json['purpose_id']),
      toPurposeId: serializer.fromJson<String?>(json['to_purpose_id']),
      refundOfId: serializer.fromJson<String?>(json['refund_of_id']),
      tagIds: serializer.fromJson<String?>(json['tag_ids']),
      note: serializer.fromJson<String?>(json['note']),
      attachments: serializer.fromJson<String?>(json['attachments']),
      status: serializer.fromJson<String?>(json['status']),
      voidReason: serializer.fromJson<String?>(json['void_reason']),
      origin: serializer.fromJson<String?>(json['origin']),
      runId: serializer.fromJson<String?>(json['run_id']),
      createdByMemberId: serializer.fromJson<String?>(
        json['created_by_member_id'],
      ),
      updatedByMemberId: serializer.fromJson<String?>(
        json['updated_by_member_id'],
      ),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'module': serializer.toJson<String?>(module),
      'visibility': serializer.toJson<String?>(visibility),
      'kind': serializer.toJson<String?>(kind),
      'amount_minor': serializer.toJson<int?>(amountMinor),
      'occurred_on': serializer.toJson<String?>(occurredOn),
      'account_id': serializer.toJson<String?>(accountId),
      'to_account_id': serializer.toJson<String?>(toAccountId),
      'purpose_id': serializer.toJson<String?>(purposeId),
      'to_purpose_id': serializer.toJson<String?>(toPurposeId),
      'refund_of_id': serializer.toJson<String?>(refundOfId),
      'tag_ids': serializer.toJson<String?>(tagIds),
      'note': serializer.toJson<String?>(note),
      'attachments': serializer.toJson<String?>(attachments),
      'status': serializer.toJson<String?>(status),
      'void_reason': serializer.toJson<String?>(voidReason),
      'origin': serializer.toJson<String?>(origin),
      'run_id': serializer.toJson<String?>(runId),
      'created_by_member_id': serializer.toJson<String?>(createdByMemberId),
      'updated_by_member_id': serializer.toJson<String?>(updatedByMemberId),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'created_at': serializer.toJson<String?>(createdAt),
      'updated_at': serializer.toJson<String?>(updatedAt),
    };
  }

  Record copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> module = const Value.absent(),
    Value<String?> visibility = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    Value<int?> amountMinor = const Value.absent(),
    Value<String?> occurredOn = const Value.absent(),
    Value<String?> accountId = const Value.absent(),
    Value<String?> toAccountId = const Value.absent(),
    Value<String?> purposeId = const Value.absent(),
    Value<String?> toPurposeId = const Value.absent(),
    Value<String?> refundOfId = const Value.absent(),
    Value<String?> tagIds = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> attachments = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> runId = const Value.absent(),
    Value<String?> createdByMemberId = const Value.absent(),
    Value<String?> updatedByMemberId = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => Record(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    module: module.present ? module.value : this.module,
    visibility: visibility.present ? visibility.value : this.visibility,
    kind: kind.present ? kind.value : this.kind,
    amountMinor: amountMinor.present ? amountMinor.value : this.amountMinor,
    occurredOn: occurredOn.present ? occurredOn.value : this.occurredOn,
    accountId: accountId.present ? accountId.value : this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    purposeId: purposeId.present ? purposeId.value : this.purposeId,
    toPurposeId: toPurposeId.present ? toPurposeId.value : this.toPurposeId,
    refundOfId: refundOfId.present ? refundOfId.value : this.refundOfId,
    tagIds: tagIds.present ? tagIds.value : this.tagIds,
    note: note.present ? note.value : this.note,
    attachments: attachments.present ? attachments.value : this.attachments,
    status: status.present ? status.value : this.status,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    origin: origin.present ? origin.value : this.origin,
    runId: runId.present ? runId.value : this.runId,
    createdByMemberId: createdByMemberId.present
        ? createdByMemberId.value
        : this.createdByMemberId,
    updatedByMemberId: updatedByMemberId.present
        ? updatedByMemberId.value
        : this.updatedByMemberId,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Record copyWithCompanion(RecordsCompanion data) {
    return Record(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      module: data.module.present ? data.module.value : this.module,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      occurredOn: data.occurredOn.present
          ? data.occurredOn.value
          : this.occurredOn,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      purposeId: data.purposeId.present ? data.purposeId.value : this.purposeId,
      toPurposeId: data.toPurposeId.present
          ? data.toPurposeId.value
          : this.toPurposeId,
      refundOfId: data.refundOfId.present
          ? data.refundOfId.value
          : this.refundOfId,
      tagIds: data.tagIds.present ? data.tagIds.value : this.tagIds,
      note: data.note.present ? data.note.value : this.note,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      status: data.status.present ? data.status.value : this.status,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      origin: data.origin.present ? data.origin.value : this.origin,
      runId: data.runId.present ? data.runId.value : this.runId,
      createdByMemberId: data.createdByMemberId.present
          ? data.createdByMemberId.value
          : this.createdByMemberId,
      updatedByMemberId: data.updatedByMemberId.present
          ? data.updatedByMemberId.value
          : this.updatedByMemberId,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Record(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('kind: $kind, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('purposeId: $purposeId, ')
          ..write('toPurposeId: $toPurposeId, ')
          ..write('refundOfId: $refundOfId, ')
          ..write('tagIds: $tagIds, ')
          ..write('note: $note, ')
          ..write('attachments: $attachments, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('origin: $origin, ')
          ..write('runId: $runId, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('updatedByMemberId: $updatedByMemberId, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    kind,
    amountMinor,
    occurredOn,
    accountId,
    toAccountId,
    purposeId,
    toPurposeId,
    refundOfId,
    tagIds,
    note,
    attachments,
    status,
    voidReason,
    origin,
    runId,
    createdByMemberId,
    updatedByMemberId,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Record &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.module == this.module &&
          other.visibility == this.visibility &&
          other.kind == this.kind &&
          other.amountMinor == this.amountMinor &&
          other.occurredOn == this.occurredOn &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.purposeId == this.purposeId &&
          other.toPurposeId == this.toPurposeId &&
          other.refundOfId == this.refundOfId &&
          other.tagIds == this.tagIds &&
          other.note == this.note &&
          other.attachments == this.attachments &&
          other.status == this.status &&
          other.voidReason == this.voidReason &&
          other.origin == this.origin &&
          other.runId == this.runId &&
          other.createdByMemberId == this.createdByMemberId &&
          other.updatedByMemberId == this.updatedByMemberId &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecordsCompanion extends UpdateCompanion<Record> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> module;
  final Value<String?> visibility;
  final Value<String?> kind;
  final Value<int?> amountMinor;
  final Value<String?> occurredOn;
  final Value<String?> accountId;
  final Value<String?> toAccountId;
  final Value<String?> purposeId;
  final Value<String?> toPurposeId;
  final Value<String?> refundOfId;
  final Value<String?> tagIds;
  final Value<String?> note;
  final Value<String?> attachments;
  final Value<String?> status;
  final Value<String?> voidReason;
  final Value<String?> origin;
  final Value<String?> runId;
  final Value<String?> createdByMemberId;
  final Value<String?> updatedByMemberId;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.occurredOn = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.purposeId = const Value.absent(),
    this.toPurposeId = const Value.absent(),
    this.refundOfId = const Value.absent(),
    this.tagIds = const Value.absent(),
    this.note = const Value.absent(),
    this.attachments = const Value.absent(),
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.origin = const Value.absent(),
    this.runId = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.updatedByMemberId = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.occurredOn = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.purposeId = const Value.absent(),
    this.toPurposeId = const Value.absent(),
    this.refundOfId = const Value.absent(),
    this.tagIds = const Value.absent(),
    this.note = const Value.absent(),
    this.attachments = const Value.absent(),
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.origin = const Value.absent(),
    this.runId = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.updatedByMemberId = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<Record> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? module,
    Expression<String>? visibility,
    Expression<String>? kind,
    Expression<int>? amountMinor,
    Expression<String>? occurredOn,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<String>? purposeId,
    Expression<String>? toPurposeId,
    Expression<String>? refundOfId,
    Expression<String>? tagIds,
    Expression<String>? note,
    Expression<String>? attachments,
    Expression<String>? status,
    Expression<String>? voidReason,
    Expression<String>? origin,
    Expression<String>? runId,
    Expression<String>? createdByMemberId,
    Expression<String>? updatedByMemberId,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (module != null) 'module': module,
      if (visibility != null) 'visibility': visibility,
      if (kind != null) 'kind': kind,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (occurredOn != null) 'occurred_on': occurredOn,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (purposeId != null) 'purpose_id': purposeId,
      if (toPurposeId != null) 'to_purpose_id': toPurposeId,
      if (refundOfId != null) 'refund_of_id': refundOfId,
      if (tagIds != null) 'tag_ids': tagIds,
      if (note != null) 'note': note,
      if (attachments != null) 'attachments': attachments,
      if (status != null) 'status': status,
      if (voidReason != null) 'void_reason': voidReason,
      if (origin != null) 'origin': origin,
      if (runId != null) 'run_id': runId,
      if (createdByMemberId != null) 'created_by_member_id': createdByMemberId,
      if (updatedByMemberId != null) 'updated_by_member_id': updatedByMemberId,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? module,
    Value<String?>? visibility,
    Value<String?>? kind,
    Value<int?>? amountMinor,
    Value<String?>? occurredOn,
    Value<String?>? accountId,
    Value<String?>? toAccountId,
    Value<String?>? purposeId,
    Value<String?>? toPurposeId,
    Value<String?>? refundOfId,
    Value<String?>? tagIds,
    Value<String?>? note,
    Value<String?>? attachments,
    Value<String?>? status,
    Value<String?>? voidReason,
    Value<String?>? origin,
    Value<String?>? runId,
    Value<String?>? createdByMemberId,
    Value<String?>? updatedByMemberId,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      module: module ?? this.module,
      visibility: visibility ?? this.visibility,
      kind: kind ?? this.kind,
      amountMinor: amountMinor ?? this.amountMinor,
      occurredOn: occurredOn ?? this.occurredOn,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      purposeId: purposeId ?? this.purposeId,
      toPurposeId: toPurposeId ?? this.toPurposeId,
      refundOfId: refundOfId ?? this.refundOfId,
      tagIds: tagIds ?? this.tagIds,
      note: note ?? this.note,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      origin: origin ?? this.origin,
      runId: runId ?? this.runId,
      createdByMemberId: createdByMemberId ?? this.createdByMemberId,
      updatedByMemberId: updatedByMemberId ?? this.updatedByMemberId,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (occurredOn.present) {
      map['occurred_on'] = Variable<String>(occurredOn.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (purposeId.present) {
      map['purpose_id'] = Variable<String>(purposeId.value);
    }
    if (toPurposeId.present) {
      map['to_purpose_id'] = Variable<String>(toPurposeId.value);
    }
    if (refundOfId.present) {
      map['refund_of_id'] = Variable<String>(refundOfId.value);
    }
    if (tagIds.present) {
      map['tag_ids'] = Variable<String>(tagIds.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(attachments.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (createdByMemberId.present) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId.value);
    }
    if (updatedByMemberId.present) {
      map['updated_by_member_id'] = Variable<String>(updatedByMemberId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('kind: $kind, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('purposeId: $purposeId, ')
          ..write('toPurposeId: $toPurposeId, ')
          ..write('refundOfId: $refundOfId, ')
          ..write('tagIds: $tagIds, ')
          ..write('note: $note, ')
          ..write('attachments: $attachments, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('origin: $origin, ')
          ..write('runId: $runId, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('updatedByMemberId: $updatedByMemberId, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Subjects extends Table with TableInfo<Subjects, Subject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Subjects(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMemberIdMeta = const VerificationMeta(
    'createdByMemberId',
  );
  late final GeneratedColumn<String> createdByMemberId =
      GeneratedColumn<String>(
        'created_by_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    kind,
    name,
    memberId,
    archivedAt,
    deletedAt,
    createdByMemberId,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('created_by_member_id')) {
      context.handle(
        _createdByMemberIdMeta,
        createdByMemberId.isAcceptableOrUnknown(
          data['created_by_member_id']!,
          _createdByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  Subject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      createdByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_member_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  Subjects createAlias(String alias) {
    return Subjects(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class Subject extends DataClass implements Insertable<Subject> {
  final String? id;
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? module;
  final String? visibility;
  final String? kind;
  final String? name;
  final String? memberId;
  final String? archivedAt;
  final String? deletedAt;
  final String? createdByMemberId;
  final int? version;
  final int? changeSeq;
  final String? createdAt;
  final String? updatedAt;
  const Subject({
    this.id,
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.module,
    this.visibility,
    this.kind,
    this.name,
    this.memberId,
    this.archivedAt,
    this.deletedAt,
    this.createdByMemberId,
    this.version,
    this.changeSeq,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || visibility != null) {
      map['visibility'] = Variable<String>(visibility);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || createdByMemberId != null) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
      visibility: visibility == null && nullToAbsent
          ? const Value.absent()
          : Value(visibility),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdByMemberId: createdByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByMemberId),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Subject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subject(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      module: serializer.fromJson<String?>(json['module']),
      visibility: serializer.fromJson<String?>(json['visibility']),
      kind: serializer.fromJson<String?>(json['kind']),
      name: serializer.fromJson<String?>(json['name']),
      memberId: serializer.fromJson<String?>(json['member_id']),
      archivedAt: serializer.fromJson<String?>(json['archived_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      createdByMemberId: serializer.fromJson<String?>(
        json['created_by_member_id'],
      ),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'module': serializer.toJson<String?>(module),
      'visibility': serializer.toJson<String?>(visibility),
      'kind': serializer.toJson<String?>(kind),
      'name': serializer.toJson<String?>(name),
      'member_id': serializer.toJson<String?>(memberId),
      'archived_at': serializer.toJson<String?>(archivedAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'created_by_member_id': serializer.toJson<String?>(createdByMemberId),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'created_at': serializer.toJson<String?>(createdAt),
      'updated_at': serializer.toJson<String?>(updatedAt),
    };
  }

  Subject copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> module = const Value.absent(),
    Value<String?> visibility = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> memberId = const Value.absent(),
    Value<String?> archivedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> createdByMemberId = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => Subject(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    module: module.present ? module.value : this.module,
    visibility: visibility.present ? visibility.value : this.visibility,
    kind: kind.present ? kind.value : this.kind,
    name: name.present ? name.value : this.name,
    memberId: memberId.present ? memberId.value : this.memberId,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdByMemberId: createdByMemberId.present
        ? createdByMemberId.value
        : this.createdByMemberId,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Subject copyWithCompanion(SubjectsCompanion data) {
    return Subject(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      module: data.module.present ? data.module.value : this.module,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdByMemberId: data.createdByMemberId.present
          ? data.createdByMemberId.value
          : this.createdByMemberId,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subject(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('memberId: $memberId, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    kind,
    name,
    memberId,
    archivedAt,
    deletedAt,
    createdByMemberId,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subject &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.module == this.module &&
          other.visibility == this.visibility &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.memberId == this.memberId &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.createdByMemberId == this.createdByMemberId &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> module;
  final Value<String?> visibility;
  final Value<String?> kind;
  final Value<String?> name;
  final Value<String?> memberId;
  final Value<String?> archivedAt;
  final Value<String?> deletedAt;
  final Value<String?> createdByMemberId;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.memberId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.memberId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<Subject> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? module,
    Expression<String>? visibility,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? memberId,
    Expression<String>? archivedAt,
    Expression<String>? deletedAt,
    Expression<String>? createdByMemberId,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (module != null) 'module': module,
      if (visibility != null) 'visibility': visibility,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (memberId != null) 'member_id': memberId,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdByMemberId != null) 'created_by_member_id': createdByMemberId,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectsCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? module,
    Value<String?>? visibility,
    Value<String?>? kind,
    Value<String?>? name,
    Value<String?>? memberId,
    Value<String?>? archivedAt,
    Value<String?>? deletedAt,
    Value<String?>? createdByMemberId,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      module: module ?? this.module,
      visibility: visibility ?? this.visibility,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      memberId: memberId ?? this.memberId,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdByMemberId: createdByMemberId ?? this.createdByMemberId,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (createdByMemberId.present) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('memberId: $memberId, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Documents extends Table with TableInfo<Documents, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Documents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _templateVersionMeta = const VerificationMeta(
    'templateVersion',
  );
  late final GeneratedColumn<int> templateVersion = GeneratedColumn<int>(
    'template_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  late final GeneratedColumn<String> eventDate = GeneratedColumn<String>(
    'event_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _subjectIdsMeta = const VerificationMeta(
    'subjectIds',
  );
  late final GeneratedColumn<String> subjectIds = GeneratedColumn<String>(
    'subject_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMemberIdMeta = const VerificationMeta(
    'createdByMemberId',
  );
  late final GeneratedColumn<String> createdByMemberId =
      GeneratedColumn<String>(
        'created_by_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _updatedByMemberIdMeta = const VerificationMeta(
    'updatedByMemberId',
  );
  late final GeneratedColumn<String> updatedByMemberId =
      GeneratedColumn<String>(
        'updated_by_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    templateId,
    templateVersion,
    title,
    eventDate,
    subjectIds,
    content,
    status,
    origin,
    runId,
    createdByMemberId,
    updatedByMemberId,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('template_version')) {
      context.handle(
        _templateVersionMeta,
        templateVersion.isAcceptableOrUnknown(
          data['template_version']!,
          _templateVersionMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    }
    if (data.containsKey('subject_ids')) {
      context.handle(
        _subjectIdsMeta,
        subjectIds.isAcceptableOrUnknown(data['subject_ids']!, _subjectIdsMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('created_by_member_id')) {
      context.handle(
        _createdByMemberIdMeta,
        createdByMemberId.isAcceptableOrUnknown(
          data['created_by_member_id']!,
          _createdByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_by_member_id')) {
      context.handle(
        _updatedByMemberIdMeta,
        updatedByMemberId.isAcceptableOrUnknown(
          data['updated_by_member_id']!,
          _updatedByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      ),
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
      templateVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_version'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_date'],
      ),
      subjectIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_ids'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      createdByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_member_id'],
      ),
      updatedByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by_member_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  Documents createAlias(String alias) {
    return Documents(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class Document extends DataClass implements Insertable<Document> {
  final String? id;
  final String spaceId;
  final String syncState;
  final int? baseVersion;
  final String dataJson;
  final String? module;
  final String? visibility;
  final String? templateId;
  final int? templateVersion;
  final String? title;
  final String? eventDate;
  final String? subjectIds;
  final String? content;
  final String? status;
  final String? origin;
  final String? runId;
  final String? createdByMemberId;
  final String? updatedByMemberId;
  final int? version;
  final int? changeSeq;
  final String? createdAt;
  final String? updatedAt;
  const Document({
    this.id,
    required this.spaceId,
    required this.syncState,
    this.baseVersion,
    required this.dataJson,
    this.module,
    this.visibility,
    this.templateId,
    this.templateVersion,
    this.title,
    this.eventDate,
    this.subjectIds,
    this.content,
    this.status,
    this.origin,
    this.runId,
    this.createdByMemberId,
    this.updatedByMemberId,
    this.version,
    this.changeSeq,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || visibility != null) {
      map['visibility'] = Variable<String>(visibility);
    }
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    if (!nullToAbsent || templateVersion != null) {
      map['template_version'] = Variable<int>(templateVersion);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || eventDate != null) {
      map['event_date'] = Variable<String>(eventDate);
    }
    if (!nullToAbsent || subjectIds != null) {
      map['subject_ids'] = Variable<String>(subjectIds);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    if (!nullToAbsent || createdByMemberId != null) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId);
    }
    if (!nullToAbsent || updatedByMemberId != null) {
      map['updated_by_member_id'] = Variable<String>(updatedByMemberId);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      dataJson: Value(dataJson),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
      visibility: visibility == null && nullToAbsent
          ? const Value.absent()
          : Value(visibility),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      templateVersion: templateVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(templateVersion),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      eventDate: eventDate == null && nullToAbsent
          ? const Value.absent()
          : Value(eventDate),
      subjectIds: subjectIds == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectIds),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      createdByMemberId: createdByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByMemberId),
      updatedByMemberId: updatedByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedByMemberId),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      baseVersion: serializer.fromJson<int?>(json['base_version']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      module: serializer.fromJson<String?>(json['module']),
      visibility: serializer.fromJson<String?>(json['visibility']),
      templateId: serializer.fromJson<String?>(json['template_id']),
      templateVersion: serializer.fromJson<int?>(json['template_version']),
      title: serializer.fromJson<String?>(json['title']),
      eventDate: serializer.fromJson<String?>(json['event_date']),
      subjectIds: serializer.fromJson<String?>(json['subject_ids']),
      content: serializer.fromJson<String?>(json['content']),
      status: serializer.fromJson<String?>(json['status']),
      origin: serializer.fromJson<String?>(json['origin']),
      runId: serializer.fromJson<String?>(json['run_id']),
      createdByMemberId: serializer.fromJson<String?>(
        json['created_by_member_id'],
      ),
      updatedByMemberId: serializer.fromJson<String?>(
        json['updated_by_member_id'],
      ),
      version: serializer.fromJson<int?>(json['version']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'base_version': serializer.toJson<int?>(baseVersion),
      'data_json': serializer.toJson<String>(dataJson),
      'module': serializer.toJson<String?>(module),
      'visibility': serializer.toJson<String?>(visibility),
      'template_id': serializer.toJson<String?>(templateId),
      'template_version': serializer.toJson<int?>(templateVersion),
      'title': serializer.toJson<String?>(title),
      'event_date': serializer.toJson<String?>(eventDate),
      'subject_ids': serializer.toJson<String?>(subjectIds),
      'content': serializer.toJson<String?>(content),
      'status': serializer.toJson<String?>(status),
      'origin': serializer.toJson<String?>(origin),
      'run_id': serializer.toJson<String?>(runId),
      'created_by_member_id': serializer.toJson<String?>(createdByMemberId),
      'updated_by_member_id': serializer.toJson<String?>(updatedByMemberId),
      'version': serializer.toJson<int?>(version),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'created_at': serializer.toJson<String?>(createdAt),
      'updated_at': serializer.toJson<String?>(updatedAt),
    };
  }

  Document copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    Value<int?> baseVersion = const Value.absent(),
    String? dataJson,
    Value<String?> module = const Value.absent(),
    Value<String?> visibility = const Value.absent(),
    Value<String?> templateId = const Value.absent(),
    Value<int?> templateVersion = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> eventDate = const Value.absent(),
    Value<String?> subjectIds = const Value.absent(),
    Value<String?> content = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> runId = const Value.absent(),
    Value<String?> createdByMemberId = const Value.absent(),
    Value<String?> updatedByMemberId = const Value.absent(),
    Value<int?> version = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => Document(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    dataJson: dataJson ?? this.dataJson,
    module: module.present ? module.value : this.module,
    visibility: visibility.present ? visibility.value : this.visibility,
    templateId: templateId.present ? templateId.value : this.templateId,
    templateVersion: templateVersion.present
        ? templateVersion.value
        : this.templateVersion,
    title: title.present ? title.value : this.title,
    eventDate: eventDate.present ? eventDate.value : this.eventDate,
    subjectIds: subjectIds.present ? subjectIds.value : this.subjectIds,
    content: content.present ? content.value : this.content,
    status: status.present ? status.value : this.status,
    origin: origin.present ? origin.value : this.origin,
    runId: runId.present ? runId.value : this.runId,
    createdByMemberId: createdByMemberId.present
        ? createdByMemberId.value
        : this.createdByMemberId,
    updatedByMemberId: updatedByMemberId.present
        ? updatedByMemberId.value
        : this.updatedByMemberId,
    version: version.present ? version.value : this.version,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      module: data.module.present ? data.module.value : this.module,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      templateVersion: data.templateVersion.present
          ? data.templateVersion.value
          : this.templateVersion,
      title: data.title.present ? data.title.value : this.title,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      subjectIds: data.subjectIds.present
          ? data.subjectIds.value
          : this.subjectIds,
      content: data.content.present ? data.content.value : this.content,
      status: data.status.present ? data.status.value : this.status,
      origin: data.origin.present ? data.origin.value : this.origin,
      runId: data.runId.present ? data.runId.value : this.runId,
      createdByMemberId: data.createdByMemberId.present
          ? data.createdByMemberId.value
          : this.createdByMemberId,
      updatedByMemberId: data.updatedByMemberId.present
          ? data.updatedByMemberId.value
          : this.updatedByMemberId,
      version: data.version.present ? data.version.value : this.version,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('title: $title, ')
          ..write('eventDate: $eventDate, ')
          ..write('subjectIds: $subjectIds, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('runId: $runId, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('updatedByMemberId: $updatedByMemberId, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    spaceId,
    syncState,
    baseVersion,
    dataJson,
    module,
    visibility,
    templateId,
    templateVersion,
    title,
    eventDate,
    subjectIds,
    content,
    status,
    origin,
    runId,
    createdByMemberId,
    updatedByMemberId,
    version,
    changeSeq,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.baseVersion == this.baseVersion &&
          other.dataJson == this.dataJson &&
          other.module == this.module &&
          other.visibility == this.visibility &&
          other.templateId == this.templateId &&
          other.templateVersion == this.templateVersion &&
          other.title == this.title &&
          other.eventDate == this.eventDate &&
          other.subjectIds == this.subjectIds &&
          other.content == this.content &&
          other.status == this.status &&
          other.origin == this.origin &&
          other.runId == this.runId &&
          other.createdByMemberId == this.createdByMemberId &&
          other.updatedByMemberId == this.updatedByMemberId &&
          other.version == this.version &&
          other.changeSeq == this.changeSeq &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<int?> baseVersion;
  final Value<String> dataJson;
  final Value<String?> module;
  final Value<String?> visibility;
  final Value<String?> templateId;
  final Value<int?> templateVersion;
  final Value<String?> title;
  final Value<String?> eventDate;
  final Value<String?> subjectIds;
  final Value<String?> content;
  final Value<String?> status;
  final Value<String?> origin;
  final Value<String?> runId;
  final Value<String?> createdByMemberId;
  final Value<String?> updatedByMemberId;
  final Value<int?> version;
  final Value<int?> changeSeq;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.templateId = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.title = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.subjectIds = const Value.absent(),
    this.content = const Value.absent(),
    this.status = const Value.absent(),
    this.origin = const Value.absent(),
    this.runId = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.updatedByMemberId = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.module = const Value.absent(),
    this.visibility = const Value.absent(),
    this.templateId = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.title = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.subjectIds = const Value.absent(),
    this.content = const Value.absent(),
    this.status = const Value.absent(),
    this.origin = const Value.absent(),
    this.runId = const Value.absent(),
    this.createdByMemberId = const Value.absent(),
    this.updatedByMemberId = const Value.absent(),
    this.version = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<Document> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<int>? baseVersion,
    Expression<String>? dataJson,
    Expression<String>? module,
    Expression<String>? visibility,
    Expression<String>? templateId,
    Expression<int>? templateVersion,
    Expression<String>? title,
    Expression<String>? eventDate,
    Expression<String>? subjectIds,
    Expression<String>? content,
    Expression<String>? status,
    Expression<String>? origin,
    Expression<String>? runId,
    Expression<String>? createdByMemberId,
    Expression<String>? updatedByMemberId,
    Expression<int>? version,
    Expression<int>? changeSeq,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (baseVersion != null) 'base_version': baseVersion,
      if (dataJson != null) 'data_json': dataJson,
      if (module != null) 'module': module,
      if (visibility != null) 'visibility': visibility,
      if (templateId != null) 'template_id': templateId,
      if (templateVersion != null) 'template_version': templateVersion,
      if (title != null) 'title': title,
      if (eventDate != null) 'event_date': eventDate,
      if (subjectIds != null) 'subject_ids': subjectIds,
      if (content != null) 'content': content,
      if (status != null) 'status': status,
      if (origin != null) 'origin': origin,
      if (runId != null) 'run_id': runId,
      if (createdByMemberId != null) 'created_by_member_id': createdByMemberId,
      if (updatedByMemberId != null) 'updated_by_member_id': updatedByMemberId,
      if (version != null) 'version': version,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<int?>? baseVersion,
    Value<String>? dataJson,
    Value<String?>? module,
    Value<String?>? visibility,
    Value<String?>? templateId,
    Value<int?>? templateVersion,
    Value<String?>? title,
    Value<String?>? eventDate,
    Value<String?>? subjectIds,
    Value<String?>? content,
    Value<String?>? status,
    Value<String?>? origin,
    Value<String?>? runId,
    Value<String?>? createdByMemberId,
    Value<String?>? updatedByMemberId,
    Value<int?>? version,
    Value<int?>? changeSeq,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      baseVersion: baseVersion ?? this.baseVersion,
      dataJson: dataJson ?? this.dataJson,
      module: module ?? this.module,
      visibility: visibility ?? this.visibility,
      templateId: templateId ?? this.templateId,
      templateVersion: templateVersion ?? this.templateVersion,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      subjectIds: subjectIds ?? this.subjectIds,
      content: content ?? this.content,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      runId: runId ?? this.runId,
      createdByMemberId: createdByMemberId ?? this.createdByMemberId,
      updatedByMemberId: updatedByMemberId ?? this.updatedByMemberId,
      version: version ?? this.version,
      changeSeq: changeSeq ?? this.changeSeq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (templateVersion.present) {
      map['template_version'] = Variable<int>(templateVersion.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<String>(eventDate.value);
    }
    if (subjectIds.present) {
      map['subject_ids'] = Variable<String>(subjectIds.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (createdByMemberId.present) {
      map['created_by_member_id'] = Variable<String>(createdByMemberId.value);
    }
    if (updatedByMemberId.present) {
      map['updated_by_member_id'] = Variable<String>(updatedByMemberId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('dataJson: $dataJson, ')
          ..write('module: $module, ')
          ..write('visibility: $visibility, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('title: $title, ')
          ..write('eventDate: $eventDate, ')
          ..write('subjectIds: $subjectIds, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('runId: $runId, ')
          ..write('createdByMemberId: $createdByMemberId, ')
          ..write('updatedByMemberId: $updatedByMemberId, ')
          ..write('version: $version, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class EntityEvents extends Table with TableInfo<EntityEvents, EntityEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EntityEvents(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _entityKindMeta = const VerificationMeta(
    'entityKind',
  );
  late final GeneratedColumn<String> entityKind = GeneratedColumn<String>(
    'entity_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _beforeMeta = const VerificationMeta('before');
  late final GeneratedColumn<String> before = GeneratedColumn<String>(
    'before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _afterMeta = const VerificationMeta('after');
  late final GeneratedColumn<String> after = GeneratedColumn<String>(
    'after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _actorMemberIdMeta = const VerificationMeta(
    'actorMemberId',
  );
  late final GeneratedColumn<String> actorMemberId = GeneratedColumn<String>(
    'actor_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _viaApiKeyIdMeta = const VerificationMeta(
    'viaApiKeyId',
  );
  late final GeneratedColumn<String> viaApiKeyId = GeneratedColumn<String>(
    'via_api_key_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _viaApiKeyNameMeta = const VerificationMeta(
    'viaApiKeyName',
  );
  late final GeneratedColumn<String> viaApiKeyName = GeneratedColumn<String>(
    'via_api_key_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
    'at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    dataJson,
    entityKind,
    entityId,
    kind,
    before,
    after,
    actorMemberId,
    viaApiKeyId,
    viaApiKeyName,
    runId,
    requestId,
    at,
    changeSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entity_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntityEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('entity_kind')) {
      context.handle(
        _entityKindMeta,
        entityKind.isAcceptableOrUnknown(data['entity_kind']!, _entityKindMeta),
      );
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('before')) {
      context.handle(
        _beforeMeta,
        before.isAcceptableOrUnknown(data['before']!, _beforeMeta),
      );
    }
    if (data.containsKey('after')) {
      context.handle(
        _afterMeta,
        after.isAcceptableOrUnknown(data['after']!, _afterMeta),
      );
    }
    if (data.containsKey('actor_member_id')) {
      context.handle(
        _actorMemberIdMeta,
        actorMemberId.isAcceptableOrUnknown(
          data['actor_member_id']!,
          _actorMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('via_api_key_id')) {
      context.handle(
        _viaApiKeyIdMeta,
        viaApiKeyId.isAcceptableOrUnknown(
          data['via_api_key_id']!,
          _viaApiKeyIdMeta,
        ),
      );
    }
    if (data.containsKey('via_api_key_name')) {
      context.handle(
        _viaApiKeyNameMeta,
        viaApiKeyName.isAcceptableOrUnknown(
          data['via_api_key_name']!,
          _viaApiKeyNameMeta,
        ),
      );
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  EntityEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntityEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      entityKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_kind'],
      ),
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      before: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before'],
      ),
      after: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after'],
      ),
      actorMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_member_id'],
      ),
      viaApiKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}via_api_key_id'],
      ),
      viaApiKeyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}via_api_key_name'],
      ),
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}at'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
    );
  }

  @override
  EntityEvents createAlias(String alias) {
    return EntityEvents(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class EntityEvent extends DataClass implements Insertable<EntityEvent> {
  final int? id;
  final String spaceId;
  final String syncState;
  final String dataJson;
  final String? entityKind;
  final String? entityId;
  final String? kind;
  final String? before;
  final String? after;
  final String? actorMemberId;
  final String? viaApiKeyId;
  final String? viaApiKeyName;
  final String? runId;
  final String? requestId;
  final String? at;
  final int? changeSeq;
  const EntityEvent({
    this.id,
    required this.spaceId,
    required this.syncState,
    required this.dataJson,
    this.entityKind,
    this.entityId,
    this.kind,
    this.before,
    this.after,
    this.actorMemberId,
    this.viaApiKeyId,
    this.viaApiKeyName,
    this.runId,
    this.requestId,
    this.at,
    this.changeSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || entityKind != null) {
      map['entity_kind'] = Variable<String>(entityKind);
    }
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || before != null) {
      map['before'] = Variable<String>(before);
    }
    if (!nullToAbsent || after != null) {
      map['after'] = Variable<String>(after);
    }
    if (!nullToAbsent || actorMemberId != null) {
      map['actor_member_id'] = Variable<String>(actorMemberId);
    }
    if (!nullToAbsent || viaApiKeyId != null) {
      map['via_api_key_id'] = Variable<String>(viaApiKeyId);
    }
    if (!nullToAbsent || viaApiKeyName != null) {
      map['via_api_key_name'] = Variable<String>(viaApiKeyName);
    }
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    if (!nullToAbsent || at != null) {
      map['at'] = Variable<String>(at);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    return map;
  }

  EntityEventsCompanion toCompanion(bool nullToAbsent) {
    return EntityEventsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      dataJson: Value(dataJson),
      entityKind: entityKind == null && nullToAbsent
          ? const Value.absent()
          : Value(entityKind),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      before: before == null && nullToAbsent
          ? const Value.absent()
          : Value(before),
      after: after == null && nullToAbsent
          ? const Value.absent()
          : Value(after),
      actorMemberId: actorMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorMemberId),
      viaApiKeyId: viaApiKeyId == null && nullToAbsent
          ? const Value.absent()
          : Value(viaApiKeyId),
      viaApiKeyName: viaApiKeyName == null && nullToAbsent
          ? const Value.absent()
          : Value(viaApiKeyName),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      at: at == null && nullToAbsent ? const Value.absent() : Value(at),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
    );
  }

  factory EntityEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntityEvent(
      id: serializer.fromJson<int?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      entityKind: serializer.fromJson<String?>(json['entity_kind']),
      entityId: serializer.fromJson<String?>(json['entity_id']),
      kind: serializer.fromJson<String?>(json['kind']),
      before: serializer.fromJson<String?>(json['before']),
      after: serializer.fromJson<String?>(json['after']),
      actorMemberId: serializer.fromJson<String?>(json['actor_member_id']),
      viaApiKeyId: serializer.fromJson<String?>(json['via_api_key_id']),
      viaApiKeyName: serializer.fromJson<String?>(json['via_api_key_name']),
      runId: serializer.fromJson<String?>(json['run_id']),
      requestId: serializer.fromJson<String?>(json['request_id']),
      at: serializer.fromJson<String?>(json['at']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'data_json': serializer.toJson<String>(dataJson),
      'entity_kind': serializer.toJson<String?>(entityKind),
      'entity_id': serializer.toJson<String?>(entityId),
      'kind': serializer.toJson<String?>(kind),
      'before': serializer.toJson<String?>(before),
      'after': serializer.toJson<String?>(after),
      'actor_member_id': serializer.toJson<String?>(actorMemberId),
      'via_api_key_id': serializer.toJson<String?>(viaApiKeyId),
      'via_api_key_name': serializer.toJson<String?>(viaApiKeyName),
      'run_id': serializer.toJson<String?>(runId),
      'request_id': serializer.toJson<String?>(requestId),
      'at': serializer.toJson<String?>(at),
      'change_seq': serializer.toJson<int?>(changeSeq),
    };
  }

  EntityEvent copyWith({
    Value<int?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    String? dataJson,
    Value<String?> entityKind = const Value.absent(),
    Value<String?> entityId = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    Value<String?> before = const Value.absent(),
    Value<String?> after = const Value.absent(),
    Value<String?> actorMemberId = const Value.absent(),
    Value<String?> viaApiKeyId = const Value.absent(),
    Value<String?> viaApiKeyName = const Value.absent(),
    Value<String?> runId = const Value.absent(),
    Value<String?> requestId = const Value.absent(),
    Value<String?> at = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
  }) => EntityEvent(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    dataJson: dataJson ?? this.dataJson,
    entityKind: entityKind.present ? entityKind.value : this.entityKind,
    entityId: entityId.present ? entityId.value : this.entityId,
    kind: kind.present ? kind.value : this.kind,
    before: before.present ? before.value : this.before,
    after: after.present ? after.value : this.after,
    actorMemberId: actorMemberId.present
        ? actorMemberId.value
        : this.actorMemberId,
    viaApiKeyId: viaApiKeyId.present ? viaApiKeyId.value : this.viaApiKeyId,
    viaApiKeyName: viaApiKeyName.present
        ? viaApiKeyName.value
        : this.viaApiKeyName,
    runId: runId.present ? runId.value : this.runId,
    requestId: requestId.present ? requestId.value : this.requestId,
    at: at.present ? at.value : this.at,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
  );
  EntityEvent copyWithCompanion(EntityEventsCompanion data) {
    return EntityEvent(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      entityKind: data.entityKind.present
          ? data.entityKind.value
          : this.entityKind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      kind: data.kind.present ? data.kind.value : this.kind,
      before: data.before.present ? data.before.value : this.before,
      after: data.after.present ? data.after.value : this.after,
      actorMemberId: data.actorMemberId.present
          ? data.actorMemberId.value
          : this.actorMemberId,
      viaApiKeyId: data.viaApiKeyId.present
          ? data.viaApiKeyId.value
          : this.viaApiKeyId,
      viaApiKeyName: data.viaApiKeyName.present
          ? data.viaApiKeyName.value
          : this.viaApiKeyName,
      runId: data.runId.present ? data.runId.value : this.runId,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      at: data.at.present ? data.at.value : this.at,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntityEvent(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('kind: $kind, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('actorMemberId: $actorMemberId, ')
          ..write('viaApiKeyId: $viaApiKeyId, ')
          ..write('viaApiKeyName: $viaApiKeyName, ')
          ..write('runId: $runId, ')
          ..write('requestId: $requestId, ')
          ..write('at: $at, ')
          ..write('changeSeq: $changeSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    dataJson,
    entityKind,
    entityId,
    kind,
    before,
    after,
    actorMemberId,
    viaApiKeyId,
    viaApiKeyName,
    runId,
    requestId,
    at,
    changeSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntityEvent &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.dataJson == this.dataJson &&
          other.entityKind == this.entityKind &&
          other.entityId == this.entityId &&
          other.kind == this.kind &&
          other.before == this.before &&
          other.after == this.after &&
          other.actorMemberId == this.actorMemberId &&
          other.viaApiKeyId == this.viaApiKeyId &&
          other.viaApiKeyName == this.viaApiKeyName &&
          other.runId == this.runId &&
          other.requestId == this.requestId &&
          other.at == this.at &&
          other.changeSeq == this.changeSeq);
}

class EntityEventsCompanion extends UpdateCompanion<EntityEvent> {
  final Value<int?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<String> dataJson;
  final Value<String?> entityKind;
  final Value<String?> entityId;
  final Value<String?> kind;
  final Value<String?> before;
  final Value<String?> after;
  final Value<String?> actorMemberId;
  final Value<String?> viaApiKeyId;
  final Value<String?> viaApiKeyName;
  final Value<String?> runId;
  final Value<String?> requestId;
  final Value<String?> at;
  final Value<int?> changeSeq;
  final Value<int> rowid;
  const EntityEventsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.kind = const Value.absent(),
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.actorMemberId = const Value.absent(),
    this.viaApiKeyId = const Value.absent(),
    this.viaApiKeyName = const Value.absent(),
    this.runId = const Value.absent(),
    this.requestId = const Value.absent(),
    this.at = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntityEventsCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.kind = const Value.absent(),
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.actorMemberId = const Value.absent(),
    this.viaApiKeyId = const Value.absent(),
    this.viaApiKeyName = const Value.absent(),
    this.runId = const Value.absent(),
    this.requestId = const Value.absent(),
    this.at = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<EntityEvent> custom({
    Expression<int>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<String>? dataJson,
    Expression<String>? entityKind,
    Expression<String>? entityId,
    Expression<String>? kind,
    Expression<String>? before,
    Expression<String>? after,
    Expression<String>? actorMemberId,
    Expression<String>? viaApiKeyId,
    Expression<String>? viaApiKeyName,
    Expression<String>? runId,
    Expression<String>? requestId,
    Expression<String>? at,
    Expression<int>? changeSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (dataJson != null) 'data_json': dataJson,
      if (entityKind != null) 'entity_kind': entityKind,
      if (entityId != null) 'entity_id': entityId,
      if (kind != null) 'kind': kind,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
      if (actorMemberId != null) 'actor_member_id': actorMemberId,
      if (viaApiKeyId != null) 'via_api_key_id': viaApiKeyId,
      if (viaApiKeyName != null) 'via_api_key_name': viaApiKeyName,
      if (runId != null) 'run_id': runId,
      if (requestId != null) 'request_id': requestId,
      if (at != null) 'at': at,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntityEventsCompanion copyWith({
    Value<int?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<String>? dataJson,
    Value<String?>? entityKind,
    Value<String?>? entityId,
    Value<String?>? kind,
    Value<String?>? before,
    Value<String?>? after,
    Value<String?>? actorMemberId,
    Value<String?>? viaApiKeyId,
    Value<String?>? viaApiKeyName,
    Value<String?>? runId,
    Value<String?>? requestId,
    Value<String?>? at,
    Value<int?>? changeSeq,
    Value<int>? rowid,
  }) {
    return EntityEventsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      dataJson: dataJson ?? this.dataJson,
      entityKind: entityKind ?? this.entityKind,
      entityId: entityId ?? this.entityId,
      kind: kind ?? this.kind,
      before: before ?? this.before,
      after: after ?? this.after,
      actorMemberId: actorMemberId ?? this.actorMemberId,
      viaApiKeyId: viaApiKeyId ?? this.viaApiKeyId,
      viaApiKeyName: viaApiKeyName ?? this.viaApiKeyName,
      runId: runId ?? this.runId,
      requestId: requestId ?? this.requestId,
      at: at ?? this.at,
      changeSeq: changeSeq ?? this.changeSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(entityKind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (before.present) {
      map['before'] = Variable<String>(before.value);
    }
    if (after.present) {
      map['after'] = Variable<String>(after.value);
    }
    if (actorMemberId.present) {
      map['actor_member_id'] = Variable<String>(actorMemberId.value);
    }
    if (viaApiKeyId.present) {
      map['via_api_key_id'] = Variable<String>(viaApiKeyId.value);
    }
    if (viaApiKeyName.present) {
      map['via_api_key_name'] = Variable<String>(viaApiKeyName.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntityEventsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('kind: $kind, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('actorMemberId: $actorMemberId, ')
          ..write('viaApiKeyId: $viaApiKeyId, ')
          ..write('viaApiKeyName: $viaApiKeyName, ')
          ..write('runId: $runId, ')
          ..write('requestId: $requestId, ')
          ..write('at: $at, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Conversations extends Table with TableInfo<Conversations, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Conversations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _serverPayloadJsonMeta = const VerificationMeta(
    'serverPayloadJson',
  );
  late final GeneratedColumn<String> serverPayloadJson =
      GeneratedColumn<String>(
        'server_payload_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    dataJson,
    memberId,
    createdAt,
    changeSeq,
    serverPayloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('server_payload_json')) {
      context.handle(
        _serverPayloadJsonMeta,
        serverPayloadJson.isAcceptableOrUnknown(
          data['server_payload_json']!,
          _serverPayloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      serverPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_payload_json'],
      ),
    );
  }

  @override
  Conversations createAlias(String alias) {
    return Conversations(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String? id;
  final String spaceId;
  final String syncState;
  final String dataJson;
  final String? memberId;
  final String? createdAt;
  final int? changeSeq;
  final String? serverPayloadJson;
  const Conversation({
    this.id,
    required this.spaceId,
    required this.syncState,
    required this.dataJson,
    this.memberId,
    this.createdAt,
    this.changeSeq,
    this.serverPayloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || serverPayloadJson != null) {
      map['server_payload_json'] = Variable<String>(serverPayloadJson);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      dataJson: Value(dataJson),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      serverPayloadJson: serverPayloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(serverPayloadJson),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      memberId: serializer.fromJson<String?>(json['member_id']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      serverPayloadJson: serializer.fromJson<String?>(
        json['server_payload_json'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'data_json': serializer.toJson<String>(dataJson),
      'member_id': serializer.toJson<String?>(memberId),
      'created_at': serializer.toJson<String?>(createdAt),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'server_payload_json': serializer.toJson<String?>(serverPayloadJson),
    };
  }

  Conversation copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    String? dataJson,
    Value<String?> memberId = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> serverPayloadJson = const Value.absent(),
  }) => Conversation(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    dataJson: dataJson ?? this.dataJson,
    memberId: memberId.present ? memberId.value : this.memberId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    serverPayloadJson: serverPayloadJson.present
        ? serverPayloadJson.value
        : this.serverPayloadJson,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      serverPayloadJson: data.serverPayloadJson.present
          ? data.serverPayloadJson.value
          : this.serverPayloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('memberId: $memberId, ')
          ..write('createdAt: $createdAt, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('serverPayloadJson: $serverPayloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    dataJson,
    memberId,
    createdAt,
    changeSeq,
    serverPayloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.dataJson == this.dataJson &&
          other.memberId == this.memberId &&
          other.createdAt == this.createdAt &&
          other.changeSeq == this.changeSeq &&
          other.serverPayloadJson == this.serverPayloadJson);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<String> dataJson;
  final Value<String?> memberId;
  final Value<String?> createdAt;
  final Value<int?> changeSeq;
  final Value<String?> serverPayloadJson;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.memberId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.serverPayloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.memberId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.serverPayloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<String>? dataJson,
    Expression<String>? memberId,
    Expression<String>? createdAt,
    Expression<int>? changeSeq,
    Expression<String>? serverPayloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (dataJson != null) 'data_json': dataJson,
      if (memberId != null) 'member_id': memberId,
      if (createdAt != null) 'created_at': createdAt,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (serverPayloadJson != null) 'server_payload_json': serverPayloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<String>? dataJson,
    Value<String?>? memberId,
    Value<String?>? createdAt,
    Value<int?>? changeSeq,
    Value<String?>? serverPayloadJson,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      dataJson: dataJson ?? this.dataJson,
      memberId: memberId ?? this.memberId,
      createdAt: createdAt ?? this.createdAt,
      changeSeq: changeSeq ?? this.changeSeq,
      serverPayloadJson: serverPayloadJson ?? this.serverPayloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (serverPayloadJson.present) {
      map['server_payload_json'] = Variable<String>(serverPayloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('memberId: $memberId, ')
          ..write('createdAt: $createdAt, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('serverPayloadJson: $serverPayloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ChatEntries extends Table with TableInfo<ChatEntries, ChatEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ChatEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\' CHECK (sync_state IN (\'synced\', \'pending\', \'conflict\'))',
    defaultValue: const CustomExpression('\'synced\''),
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _agentRunIdMeta = const VerificationMeta(
    'agentRunId',
  );
  late final GeneratedColumn<String> agentRunId = GeneratedColumn<String>(
    'agent_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _protocolVersionMeta = const VerificationMeta(
    'protocolVersion',
  );
  late final GeneratedColumn<String> protocolVersion = GeneratedColumn<String>(
    'protocol_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fallbackTextMeta = const VerificationMeta(
    'fallbackText',
  );
  late final GeneratedColumn<String> fallbackText = GeneratedColumn<String>(
    'fallback_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _streamStatusMeta = const VerificationMeta(
    'streamStatus',
  );
  late final GeneratedColumn<String> streamStatus = GeneratedColumn<String>(
    'stream_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changeSeqMeta = const VerificationMeta(
    'changeSeq',
  );
  late final GeneratedColumn<int> changeSeq = GeneratedColumn<int>(
    'change_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _messageJsonMeta = const VerificationMeta(
    'messageJson',
  );
  late final GeneratedColumn<String> messageJson = GeneratedColumn<String>(
    'message_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _lastSeqMeta = const VerificationMeta(
    'lastSeq',
  );
  late final GeneratedColumn<int> lastSeq = GeneratedColumn<int>(
    'last_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _authoritativeMeta = const VerificationMeta(
    'authoritative',
  );
  late final GeneratedColumn<int> authoritative = GeneratedColumn<int>(
    'authoritative',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _serverPayloadJsonMeta = const VerificationMeta(
    'serverPayloadJson',
  );
  late final GeneratedColumn<String> serverPayloadJson =
      GeneratedColumn<String>(
        'server_payload_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    syncState,
    dataJson,
    memberId,
    conversationId,
    role,
    replyToId,
    agentRunId,
    protocolVersion,
    fallbackText,
    streamStatus,
    changeSeq,
    createdAt,
    updatedAt,
    messageJson,
    rev,
    lastSeq,
    authoritative,
    serverPayloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('agent_run_id')) {
      context.handle(
        _agentRunIdMeta,
        agentRunId.isAcceptableOrUnknown(
          data['agent_run_id']!,
          _agentRunIdMeta,
        ),
      );
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
        _protocolVersionMeta,
        protocolVersion.isAcceptableOrUnknown(
          data['protocol_version']!,
          _protocolVersionMeta,
        ),
      );
    }
    if (data.containsKey('fallback_text')) {
      context.handle(
        _fallbackTextMeta,
        fallbackText.isAcceptableOrUnknown(
          data['fallback_text']!,
          _fallbackTextMeta,
        ),
      );
    }
    if (data.containsKey('stream_status')) {
      context.handle(
        _streamStatusMeta,
        streamStatus.isAcceptableOrUnknown(
          data['stream_status']!,
          _streamStatusMeta,
        ),
      );
    }
    if (data.containsKey('change_seq')) {
      context.handle(
        _changeSeqMeta,
        changeSeq.isAcceptableOrUnknown(data['change_seq']!, _changeSeqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('message_json')) {
      context.handle(
        _messageJsonMeta,
        messageJson.isAcceptableOrUnknown(
          data['message_json']!,
          _messageJsonMeta,
        ),
      );
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
    if (data.containsKey('last_seq')) {
      context.handle(
        _lastSeqMeta,
        lastSeq.isAcceptableOrUnknown(data['last_seq']!, _lastSeqMeta),
      );
    }
    if (data.containsKey('authoritative')) {
      context.handle(
        _authoritativeMeta,
        authoritative.isAcceptableOrUnknown(
          data['authoritative']!,
          _authoritativeMeta,
        ),
      );
    }
    if (data.containsKey('server_payload_json')) {
      context.handle(
        _serverPayloadJsonMeta,
        serverPayloadJson.isAcceptableOrUnknown(
          data['server_payload_json']!,
          _serverPayloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, id};
  @override
  ChatEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      agentRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_run_id'],
      ),
      protocolVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protocol_version'],
      ),
      fallbackText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fallback_text'],
      ),
      streamStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_status'],
      ),
      changeSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_seq'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      messageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_json'],
      ),
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      lastSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seq'],
      )!,
      authoritative: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}authoritative'],
      )!,
      serverPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_payload_json'],
      ),
    );
  }

  @override
  ChatEntries createAlias(String alias) {
    return ChatEntries(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(space_id, id)'];
  @override
  bool get dontWriteConstraints => true;
}

class ChatEntry extends DataClass implements Insertable<ChatEntry> {
  final String? id;
  final String spaceId;
  final String syncState;
  final String dataJson;
  final String? memberId;
  final String? conversationId;
  final String? role;
  final String? replyToId;
  final String? agentRunId;
  final String? protocolVersion;
  final String? fallbackText;
  final String? streamStatus;
  final int? changeSeq;
  final String? createdAt;
  final String? updatedAt;
  final String? messageJson;
  final int rev;
  final int lastSeq;
  final int authoritative;
  final String? serverPayloadJson;
  const ChatEntry({
    this.id,
    required this.spaceId,
    required this.syncState,
    required this.dataJson,
    this.memberId,
    this.conversationId,
    this.role,
    this.replyToId,
    this.agentRunId,
    this.protocolVersion,
    this.fallbackText,
    this.streamStatus,
    this.changeSeq,
    this.createdAt,
    this.updatedAt,
    this.messageJson,
    required this.rev,
    required this.lastSeq,
    required this.authoritative,
    this.serverPayloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['sync_state'] = Variable<String>(syncState);
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    if (!nullToAbsent || agentRunId != null) {
      map['agent_run_id'] = Variable<String>(agentRunId);
    }
    if (!nullToAbsent || protocolVersion != null) {
      map['protocol_version'] = Variable<String>(protocolVersion);
    }
    if (!nullToAbsent || fallbackText != null) {
      map['fallback_text'] = Variable<String>(fallbackText);
    }
    if (!nullToAbsent || streamStatus != null) {
      map['stream_status'] = Variable<String>(streamStatus);
    }
    if (!nullToAbsent || changeSeq != null) {
      map['change_seq'] = Variable<int>(changeSeq);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || messageJson != null) {
      map['message_json'] = Variable<String>(messageJson);
    }
    map['rev'] = Variable<int>(rev);
    map['last_seq'] = Variable<int>(lastSeq);
    map['authoritative'] = Variable<int>(authoritative);
    if (!nullToAbsent || serverPayloadJson != null) {
      map['server_payload_json'] = Variable<String>(serverPayloadJson);
    }
    return map;
  }

  ChatEntriesCompanion toCompanion(bool nullToAbsent) {
    return ChatEntriesCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      syncState: Value(syncState),
      dataJson: Value(dataJson),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      agentRunId: agentRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(agentRunId),
      protocolVersion: protocolVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(protocolVersion),
      fallbackText: fallbackText == null && nullToAbsent
          ? const Value.absent()
          : Value(fallbackText),
      streamStatus: streamStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(streamStatus),
      changeSeq: changeSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(changeSeq),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      messageJson: messageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(messageJson),
      rev: Value(rev),
      lastSeq: Value(lastSeq),
      authoritative: Value(authoritative),
      serverPayloadJson: serverPayloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(serverPayloadJson),
    );
  }

  factory ChatEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatEntry(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      syncState: serializer.fromJson<String>(json['sync_state']),
      dataJson: serializer.fromJson<String>(json['data_json']),
      memberId: serializer.fromJson<String?>(json['member_id']),
      conversationId: serializer.fromJson<String?>(json['conversation_id']),
      role: serializer.fromJson<String?>(json['role']),
      replyToId: serializer.fromJson<String?>(json['reply_to_id']),
      agentRunId: serializer.fromJson<String?>(json['agent_run_id']),
      protocolVersion: serializer.fromJson<String?>(json['protocol_version']),
      fallbackText: serializer.fromJson<String?>(json['fallback_text']),
      streamStatus: serializer.fromJson<String?>(json['stream_status']),
      changeSeq: serializer.fromJson<int?>(json['change_seq']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
      messageJson: serializer.fromJson<String?>(json['message_json']),
      rev: serializer.fromJson<int>(json['rev']),
      lastSeq: serializer.fromJson<int>(json['last_seq']),
      authoritative: serializer.fromJson<int>(json['authoritative']),
      serverPayloadJson: serializer.fromJson<String?>(
        json['server_payload_json'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'sync_state': serializer.toJson<String>(syncState),
      'data_json': serializer.toJson<String>(dataJson),
      'member_id': serializer.toJson<String?>(memberId),
      'conversation_id': serializer.toJson<String?>(conversationId),
      'role': serializer.toJson<String?>(role),
      'reply_to_id': serializer.toJson<String?>(replyToId),
      'agent_run_id': serializer.toJson<String?>(agentRunId),
      'protocol_version': serializer.toJson<String?>(protocolVersion),
      'fallback_text': serializer.toJson<String?>(fallbackText),
      'stream_status': serializer.toJson<String?>(streamStatus),
      'change_seq': serializer.toJson<int?>(changeSeq),
      'created_at': serializer.toJson<String?>(createdAt),
      'updated_at': serializer.toJson<String?>(updatedAt),
      'message_json': serializer.toJson<String?>(messageJson),
      'rev': serializer.toJson<int>(rev),
      'last_seq': serializer.toJson<int>(lastSeq),
      'authoritative': serializer.toJson<int>(authoritative),
      'server_payload_json': serializer.toJson<String?>(serverPayloadJson),
    };
  }

  ChatEntry copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    String? syncState,
    String? dataJson,
    Value<String?> memberId = const Value.absent(),
    Value<String?> conversationId = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    Value<String?> agentRunId = const Value.absent(),
    Value<String?> protocolVersion = const Value.absent(),
    Value<String?> fallbackText = const Value.absent(),
    Value<String?> streamStatus = const Value.absent(),
    Value<int?> changeSeq = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> messageJson = const Value.absent(),
    int? rev,
    int? lastSeq,
    int? authoritative,
    Value<String?> serverPayloadJson = const Value.absent(),
  }) => ChatEntry(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    syncState: syncState ?? this.syncState,
    dataJson: dataJson ?? this.dataJson,
    memberId: memberId.present ? memberId.value : this.memberId,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    role: role.present ? role.value : this.role,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    agentRunId: agentRunId.present ? agentRunId.value : this.agentRunId,
    protocolVersion: protocolVersion.present
        ? protocolVersion.value
        : this.protocolVersion,
    fallbackText: fallbackText.present ? fallbackText.value : this.fallbackText,
    streamStatus: streamStatus.present ? streamStatus.value : this.streamStatus,
    changeSeq: changeSeq.present ? changeSeq.value : this.changeSeq,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    messageJson: messageJson.present ? messageJson.value : this.messageJson,
    rev: rev ?? this.rev,
    lastSeq: lastSeq ?? this.lastSeq,
    authoritative: authoritative ?? this.authoritative,
    serverPayloadJson: serverPayloadJson.present
        ? serverPayloadJson.value
        : this.serverPayloadJson,
  );
  ChatEntry copyWithCompanion(ChatEntriesCompanion data) {
    return ChatEntry(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      agentRunId: data.agentRunId.present
          ? data.agentRunId.value
          : this.agentRunId,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
      fallbackText: data.fallbackText.present
          ? data.fallbackText.value
          : this.fallbackText,
      streamStatus: data.streamStatus.present
          ? data.streamStatus.value
          : this.streamStatus,
      changeSeq: data.changeSeq.present ? data.changeSeq.value : this.changeSeq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      messageJson: data.messageJson.present
          ? data.messageJson.value
          : this.messageJson,
      rev: data.rev.present ? data.rev.value : this.rev,
      lastSeq: data.lastSeq.present ? data.lastSeq.value : this.lastSeq,
      authoritative: data.authoritative.present
          ? data.authoritative.value
          : this.authoritative,
      serverPayloadJson: data.serverPayloadJson.present
          ? data.serverPayloadJson.value
          : this.serverPayloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatEntry(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('memberId: $memberId, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('replyToId: $replyToId, ')
          ..write('agentRunId: $agentRunId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('fallbackText: $fallbackText, ')
          ..write('streamStatus: $streamStatus, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messageJson: $messageJson, ')
          ..write('rev: $rev, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('authoritative: $authoritative, ')
          ..write('serverPayloadJson: $serverPayloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    syncState,
    dataJson,
    memberId,
    conversationId,
    role,
    replyToId,
    agentRunId,
    protocolVersion,
    fallbackText,
    streamStatus,
    changeSeq,
    createdAt,
    updatedAt,
    messageJson,
    rev,
    lastSeq,
    authoritative,
    serverPayloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatEntry &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.syncState == this.syncState &&
          other.dataJson == this.dataJson &&
          other.memberId == this.memberId &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.replyToId == this.replyToId &&
          other.agentRunId == this.agentRunId &&
          other.protocolVersion == this.protocolVersion &&
          other.fallbackText == this.fallbackText &&
          other.streamStatus == this.streamStatus &&
          other.changeSeq == this.changeSeq &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.messageJson == this.messageJson &&
          other.rev == this.rev &&
          other.lastSeq == this.lastSeq &&
          other.authoritative == this.authoritative &&
          other.serverPayloadJson == this.serverPayloadJson);
}

class ChatEntriesCompanion extends UpdateCompanion<ChatEntry> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<String> syncState;
  final Value<String> dataJson;
  final Value<String?> memberId;
  final Value<String?> conversationId;
  final Value<String?> role;
  final Value<String?> replyToId;
  final Value<String?> agentRunId;
  final Value<String?> protocolVersion;
  final Value<String?> fallbackText;
  final Value<String?> streamStatus;
  final Value<int?> changeSeq;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> messageJson;
  final Value<int> rev;
  final Value<int> lastSeq;
  final Value<int> authoritative;
  final Value<String?> serverPayloadJson;
  final Value<int> rowid;
  const ChatEntriesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.memberId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.agentRunId = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.fallbackText = const Value.absent(),
    this.streamStatus = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.messageJson = const Value.absent(),
    this.rev = const Value.absent(),
    this.lastSeq = const Value.absent(),
    this.authoritative = const Value.absent(),
    this.serverPayloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    this.syncState = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.memberId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.agentRunId = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.fallbackText = const Value.absent(),
    this.streamStatus = const Value.absent(),
    this.changeSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.messageJson = const Value.absent(),
    this.rev = const Value.absent(),
    this.lastSeq = const Value.absent(),
    this.authoritative = const Value.absent(),
    this.serverPayloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId);
  static Insertable<ChatEntry> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? syncState,
    Expression<String>? dataJson,
    Expression<String>? memberId,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? replyToId,
    Expression<String>? agentRunId,
    Expression<String>? protocolVersion,
    Expression<String>? fallbackText,
    Expression<String>? streamStatus,
    Expression<int>? changeSeq,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? messageJson,
    Expression<int>? rev,
    Expression<int>? lastSeq,
    Expression<int>? authoritative,
    Expression<String>? serverPayloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (syncState != null) 'sync_state': syncState,
      if (dataJson != null) 'data_json': dataJson,
      if (memberId != null) 'member_id': memberId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (agentRunId != null) 'agent_run_id': agentRunId,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (fallbackText != null) 'fallback_text': fallbackText,
      if (streamStatus != null) 'stream_status': streamStatus,
      if (changeSeq != null) 'change_seq': changeSeq,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (messageJson != null) 'message_json': messageJson,
      if (rev != null) 'rev': rev,
      if (lastSeq != null) 'last_seq': lastSeq,
      if (authoritative != null) 'authoritative': authoritative,
      if (serverPayloadJson != null) 'server_payload_json': serverPayloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatEntriesCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<String>? syncState,
    Value<String>? dataJson,
    Value<String?>? memberId,
    Value<String?>? conversationId,
    Value<String?>? role,
    Value<String?>? replyToId,
    Value<String?>? agentRunId,
    Value<String?>? protocolVersion,
    Value<String?>? fallbackText,
    Value<String?>? streamStatus,
    Value<int?>? changeSeq,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? messageJson,
    Value<int>? rev,
    Value<int>? lastSeq,
    Value<int>? authoritative,
    Value<String?>? serverPayloadJson,
    Value<int>? rowid,
  }) {
    return ChatEntriesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      syncState: syncState ?? this.syncState,
      dataJson: dataJson ?? this.dataJson,
      memberId: memberId ?? this.memberId,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      replyToId: replyToId ?? this.replyToId,
      agentRunId: agentRunId ?? this.agentRunId,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      fallbackText: fallbackText ?? this.fallbackText,
      streamStatus: streamStatus ?? this.streamStatus,
      changeSeq: changeSeq ?? this.changeSeq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageJson: messageJson ?? this.messageJson,
      rev: rev ?? this.rev,
      lastSeq: lastSeq ?? this.lastSeq,
      authoritative: authoritative ?? this.authoritative,
      serverPayloadJson: serverPayloadJson ?? this.serverPayloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (agentRunId.present) {
      map['agent_run_id'] = Variable<String>(agentRunId.value);
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<String>(protocolVersion.value);
    }
    if (fallbackText.present) {
      map['fallback_text'] = Variable<String>(fallbackText.value);
    }
    if (streamStatus.present) {
      map['stream_status'] = Variable<String>(streamStatus.value);
    }
    if (changeSeq.present) {
      map['change_seq'] = Variable<int>(changeSeq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (messageJson.present) {
      map['message_json'] = Variable<String>(messageJson.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (lastSeq.present) {
      map['last_seq'] = Variable<int>(lastSeq.value);
    }
    if (authoritative.present) {
      map['authoritative'] = Variable<int>(authoritative.value);
    }
    if (serverPayloadJson.present) {
      map['server_payload_json'] = Variable<String>(serverPayloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatEntriesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('syncState: $syncState, ')
          ..write('dataJson: $dataJson, ')
          ..write('memberId: $memberId, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('replyToId: $replyToId, ')
          ..write('agentRunId: $agentRunId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('fallbackText: $fallbackText, ')
          ..write('streamStatus: $streamStatus, ')
          ..write('changeSeq: $changeSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messageJson: $messageJson, ')
          ..write('rev: $rev, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('authoritative: $authoritative, ')
          ..write('serverPayloadJson: $serverPayloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ChatClientStates extends Table
    with TableInfo<ChatClientStates, ChatClientState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ChatClientStates(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _stateJsonMeta = const VerificationMeta(
    'stateJson',
  );
  late final GeneratedColumn<String> stateJson = GeneratedColumn<String>(
    'state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  @override
  List<GeneratedColumn> get $columns => [spaceId, messageId, stateJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_client_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatClientState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('state_json')) {
      context.handle(
        _stateJsonMeta,
        stateJson.isAcceptableOrUnknown(data['state_json']!, _stateJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, messageId};
  @override
  ChatClientState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatClientState(
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      stateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_json'],
      )!,
    );
  }

  @override
  ChatClientStates createAlias(String alias) {
    return ChatClientStates(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(space_id, message_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class ChatClientState extends DataClass implements Insertable<ChatClientState> {
  final String spaceId;
  final String messageId;
  final String stateJson;
  const ChatClientState({
    required this.spaceId,
    required this.messageId,
    required this.stateJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['space_id'] = Variable<String>(spaceId);
    map['message_id'] = Variable<String>(messageId);
    map['state_json'] = Variable<String>(stateJson);
    return map;
  }

  ChatClientStatesCompanion toCompanion(bool nullToAbsent) {
    return ChatClientStatesCompanion(
      spaceId: Value(spaceId),
      messageId: Value(messageId),
      stateJson: Value(stateJson),
    );
  }

  factory ChatClientState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatClientState(
      spaceId: serializer.fromJson<String>(json['space_id']),
      messageId: serializer.fromJson<String>(json['message_id']),
      stateJson: serializer.fromJson<String>(json['state_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'space_id': serializer.toJson<String>(spaceId),
      'message_id': serializer.toJson<String>(messageId),
      'state_json': serializer.toJson<String>(stateJson),
    };
  }

  ChatClientState copyWith({
    String? spaceId,
    String? messageId,
    String? stateJson,
  }) => ChatClientState(
    spaceId: spaceId ?? this.spaceId,
    messageId: messageId ?? this.messageId,
    stateJson: stateJson ?? this.stateJson,
  );
  ChatClientState copyWithCompanion(ChatClientStatesCompanion data) {
    return ChatClientState(
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      stateJson: data.stateJson.present ? data.stateJson.value : this.stateJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatClientState(')
          ..write('spaceId: $spaceId, ')
          ..write('messageId: $messageId, ')
          ..write('stateJson: $stateJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(spaceId, messageId, stateJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatClientState &&
          other.spaceId == this.spaceId &&
          other.messageId == this.messageId &&
          other.stateJson == this.stateJson);
}

class ChatClientStatesCompanion extends UpdateCompanion<ChatClientState> {
  final Value<String> spaceId;
  final Value<String> messageId;
  final Value<String> stateJson;
  final Value<int> rowid;
  const ChatClientStatesCompanion({
    this.spaceId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.stateJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatClientStatesCompanion.insert({
    required String spaceId,
    required String messageId,
    this.stateJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId),
       messageId = Value(messageId);
  static Insertable<ChatClientState> custom({
    Expression<String>? spaceId,
    Expression<String>? messageId,
    Expression<String>? stateJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (spaceId != null) 'space_id': spaceId,
      if (messageId != null) 'message_id': messageId,
      if (stateJson != null) 'state_json': stateJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatClientStatesCompanion copyWith({
    Value<String>? spaceId,
    Value<String>? messageId,
    Value<String>? stateJson,
    Value<int>? rowid,
  }) {
    return ChatClientStatesCompanion(
      spaceId: spaceId ?? this.spaceId,
      messageId: messageId ?? this.messageId,
      stateJson: stateJson ?? this.stateJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (stateJson.present) {
      map['state_json'] = Variable<String>(stateJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatClientStatesCompanion(')
          ..write('spaceId: $spaceId, ')
          ..write('messageId: $messageId, ')
          ..write('stateJson: $stateJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Outbox extends Table with TableInfo<Outbox, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Outbox(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY',
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _joinEpochMeta = const VerificationMeta(
    'joinEpoch',
  );
  late final GeneratedColumn<int> joinEpoch = GeneratedColumn<int>(
    'join_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (kind IN (\'tool\', \'blob\', \'chat_send\', \'chat_action\', \'chat_retry\'))',
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityIdsMeta = const VerificationMeta(
    'entityIds',
  );
  late final GeneratedColumn<String> entityIds = GeneratedColumn<String>(
    'entity_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dependsOnMeta = const VerificationMeta(
    'dependsOn',
  );
  late final GeneratedColumn<String> dependsOn = GeneratedColumn<String>(
    'depends_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'pending\' CHECK (state IN (\'pending\', \'sending\', \'failed\', \'blocked\'))',
    defaultValue: const CustomExpression('\'pending\''),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    joinEpoch,
    kind,
    payloadJson,
    entityIds,
    dependsOn,
    requestId,
    createdAt,
    attempts,
    state,
    lastError,
    leaseUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('join_epoch')) {
      context.handle(
        _joinEpochMeta,
        joinEpoch.isAcceptableOrUnknown(data['join_epoch']!, _joinEpochMeta),
      );
    } else if (isInserting) {
      context.missing(_joinEpochMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('entity_ids')) {
      context.handle(
        _entityIdsMeta,
        entityIds.isAcceptableOrUnknown(data['entity_ids']!, _entityIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdsMeta);
    }
    if (data.containsKey('depends_on')) {
      context.handle(
        _dependsOnMeta,
        dependsOn.isAcceptableOrUnknown(data['depends_on']!, _dependsOnMeta),
      );
    } else if (isInserting) {
      context.missing(_dependsOnMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      ),
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      joinEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}join_epoch'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      entityIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_ids'],
      )!,
      dependsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}depends_on'],
      )!,
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_until'],
      ),
    );
  }

  @override
  Outbox createAlias(String alias) {
    return Outbox(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String? id;
  final String spaceId;
  final int joinEpoch;
  final String kind;
  final String payloadJson;
  final String entityIds;
  final String dependsOn;
  final String requestId;
  final int createdAt;
  final int attempts;
  final String state;
  final String? lastError;
  final int? leaseUntil;
  const OutboxData({
    this.id,
    required this.spaceId,
    required this.joinEpoch,
    required this.kind,
    required this.payloadJson,
    required this.entityIds,
    required this.dependsOn,
    required this.requestId,
    required this.createdAt,
    required this.attempts,
    required this.state,
    this.lastError,
    this.leaseUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['space_id'] = Variable<String>(spaceId);
    map['join_epoch'] = Variable<int>(joinEpoch);
    map['kind'] = Variable<String>(kind);
    map['payload_json'] = Variable<String>(payloadJson);
    map['entity_ids'] = Variable<String>(entityIds);
    map['depends_on'] = Variable<String>(dependsOn);
    map['request_id'] = Variable<String>(requestId);
    map['created_at'] = Variable<int>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<int>(leaseUntil);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      spaceId: Value(spaceId),
      joinEpoch: Value(joinEpoch),
      kind: Value(kind),
      payloadJson: Value(payloadJson),
      entityIds: Value(entityIds),
      dependsOn: Value(dependsOn),
      requestId: Value(requestId),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String?>(json['id']),
      spaceId: serializer.fromJson<String>(json['space_id']),
      joinEpoch: serializer.fromJson<int>(json['join_epoch']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadJson: serializer.fromJson<String>(json['payload_json']),
      entityIds: serializer.fromJson<String>(json['entity_ids']),
      dependsOn: serializer.fromJson<String>(json['depends_on']),
      requestId: serializer.fromJson<String>(json['request_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      attempts: serializer.fromJson<int>(json['attempts']),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['last_error']),
      leaseUntil: serializer.fromJson<int?>(json['lease_until']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'space_id': serializer.toJson<String>(spaceId),
      'join_epoch': serializer.toJson<int>(joinEpoch),
      'kind': serializer.toJson<String>(kind),
      'payload_json': serializer.toJson<String>(payloadJson),
      'entity_ids': serializer.toJson<String>(entityIds),
      'depends_on': serializer.toJson<String>(dependsOn),
      'request_id': serializer.toJson<String>(requestId),
      'created_at': serializer.toJson<int>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'state': serializer.toJson<String>(state),
      'last_error': serializer.toJson<String?>(lastError),
      'lease_until': serializer.toJson<int?>(leaseUntil),
    };
  }

  OutboxData copyWith({
    Value<String?> id = const Value.absent(),
    String? spaceId,
    int? joinEpoch,
    String? kind,
    String? payloadJson,
    String? entityIds,
    String? dependsOn,
    String? requestId,
    int? createdAt,
    int? attempts,
    String? state,
    Value<String?> lastError = const Value.absent(),
    Value<int?> leaseUntil = const Value.absent(),
  }) => OutboxData(
    id: id.present ? id.value : this.id,
    spaceId: spaceId ?? this.spaceId,
    joinEpoch: joinEpoch ?? this.joinEpoch,
    kind: kind ?? this.kind,
    payloadJson: payloadJson ?? this.payloadJson,
    entityIds: entityIds ?? this.entityIds,
    dependsOn: dependsOn ?? this.dependsOn,
    requestId: requestId ?? this.requestId,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      joinEpoch: data.joinEpoch.present ? data.joinEpoch.value : this.joinEpoch,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      entityIds: data.entityIds.present ? data.entityIds.value : this.entityIds,
      dependsOn: data.dependsOn.present ? data.dependsOn.value : this.dependsOn,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('joinEpoch: $joinEpoch, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('entityIds: $entityIds, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('requestId: $requestId, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('leaseUntil: $leaseUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    joinEpoch,
    kind,
    payloadJson,
    entityIds,
    dependsOn,
    requestId,
    createdAt,
    attempts,
    state,
    lastError,
    leaseUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.joinEpoch == this.joinEpoch &&
          other.kind == this.kind &&
          other.payloadJson == this.payloadJson &&
          other.entityIds == this.entityIds &&
          other.dependsOn == this.dependsOn &&
          other.requestId == this.requestId &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.state == this.state &&
          other.lastError == this.lastError &&
          other.leaseUntil == this.leaseUntil);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String?> id;
  final Value<String> spaceId;
  final Value<int> joinEpoch;
  final Value<String> kind;
  final Value<String> payloadJson;
  final Value<String> entityIds;
  final Value<String> dependsOn;
  final Value<String> requestId;
  final Value<int> createdAt;
  final Value<int> attempts;
  final Value<String> state;
  final Value<String?> lastError;
  final Value<int?> leaseUntil;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.joinEpoch = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.entityIds = const Value.absent(),
    this.dependsOn = const Value.absent(),
    this.requestId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String spaceId,
    required int joinEpoch,
    required String kind,
    required String payloadJson,
    required String entityIds,
    required String dependsOn,
    required String requestId,
    required int createdAt,
    this.attempts = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId),
       joinEpoch = Value(joinEpoch),
       kind = Value(kind),
       payloadJson = Value(payloadJson),
       entityIds = Value(entityIds),
       dependsOn = Value(dependsOn),
       requestId = Value(requestId),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<int>? joinEpoch,
    Expression<String>? kind,
    Expression<String>? payloadJson,
    Expression<String>? entityIds,
    Expression<String>? dependsOn,
    Expression<String>? requestId,
    Expression<int>? createdAt,
    Expression<int>? attempts,
    Expression<String>? state,
    Expression<String>? lastError,
    Expression<int>? leaseUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (joinEpoch != null) 'join_epoch': joinEpoch,
      if (kind != null) 'kind': kind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (entityIds != null) 'entity_ids': entityIds,
      if (dependsOn != null) 'depends_on': dependsOn,
      if (requestId != null) 'request_id': requestId,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String?>? id,
    Value<String>? spaceId,
    Value<int>? joinEpoch,
    Value<String>? kind,
    Value<String>? payloadJson,
    Value<String>? entityIds,
    Value<String>? dependsOn,
    Value<String>? requestId,
    Value<int>? createdAt,
    Value<int>? attempts,
    Value<String>? state,
    Value<String?>? lastError,
    Value<int?>? leaseUntil,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      joinEpoch: joinEpoch ?? this.joinEpoch,
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
      entityIds: entityIds ?? this.entityIds,
      dependsOn: dependsOn ?? this.dependsOn,
      requestId: requestId ?? this.requestId,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (joinEpoch.present) {
      map['join_epoch'] = Variable<int>(joinEpoch.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (entityIds.present) {
      map['entity_ids'] = Variable<String>(entityIds.value);
    }
    if (dependsOn.present) {
      map['depends_on'] = Variable<String>(dependsOn.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('joinEpoch: $joinEpoch, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('entityIds: $entityIds, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('requestId: $requestId, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncCursors extends Table with TableInfo<SyncCursors, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncCursors(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY',
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [spaceId, cursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      ),
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cursor'],
      )!,
    );
  }

  @override
  SyncCursors createAlias(String alias) {
    return SyncCursors(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String? spaceId;
  final int cursor;
  const SyncCursor({this.spaceId, required this.cursor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || spaceId != null) {
      map['space_id'] = Variable<String>(spaceId);
    }
    map['cursor'] = Variable<int>(cursor);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      spaceId: spaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(spaceId),
      cursor: Value(cursor),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      spaceId: serializer.fromJson<String?>(json['space_id']),
      cursor: serializer.fromJson<int>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'space_id': serializer.toJson<String?>(spaceId),
      'cursor': serializer.toJson<int>(cursor),
    };
  }

  SyncCursor copyWith({
    Value<String?> spaceId = const Value.absent(),
    int? cursor,
  }) => SyncCursor(
    spaceId: spaceId.present ? spaceId.value : this.spaceId,
    cursor: cursor ?? this.cursor,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('spaceId: $spaceId, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(spaceId, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.spaceId == this.spaceId &&
          other.cursor == this.cursor);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String?> spaceId;
  final Value<int> cursor;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.spaceId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    this.spaceId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<SyncCursor> custom({
    Expression<String>? spaceId,
    Expression<int>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (spaceId != null) 'space_id': spaceId,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String?>? spaceId,
    Value<int>? cursor,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      spaceId: spaceId ?? this.spaceId,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<int>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('spaceId: $spaceId, ')
          ..write('cursor: $cursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class EntityConflicts extends Table
    with TableInfo<EntityConflicts, EntityConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EntityConflicts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityKindMeta = const VerificationMeta(
    'entityKind',
  );
  late final GeneratedColumn<String> entityKind = GeneratedColumn<String>(
    'entity_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _mineJsonMeta = const VerificationMeta(
    'mineJson',
  );
  late final GeneratedColumn<String> mineJson = GeneratedColumn<String>(
    'mine_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _serverStatusMeta = const VerificationMeta(
    'serverStatus',
  );
  late final GeneratedColumn<String> serverStatus = GeneratedColumn<String>(
    'server_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  late final GeneratedColumn<int> detectedAt = GeneratedColumn<int>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    spaceId,
    entityKind,
    entityId,
    mineJson,
    serverVersion,
    serverStatus,
    detectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entity_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntityConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('entity_kind')) {
      context.handle(
        _entityKindMeta,
        entityKind.isAcceptableOrUnknown(data['entity_kind']!, _entityKindMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('mine_json')) {
      context.handle(
        _mineJsonMeta,
        mineJson.isAcceptableOrUnknown(data['mine_json']!, _mineJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_mineJsonMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverVersionMeta);
    }
    if (data.containsKey('server_status')) {
      context.handle(
        _serverStatusMeta,
        serverStatus.isAcceptableOrUnknown(
          data['server_status']!,
          _serverStatusMeta,
        ),
      );
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, entityKind, entityId};
  @override
  EntityConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntityConflict(
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      entityKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      mineJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mine_json'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      serverStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_status'],
      ),
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_at'],
      )!,
    );
  }

  @override
  EntityConflicts createAlias(String alias) {
    return EntityConflicts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(space_id, entity_kind, entity_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class EntityConflict extends DataClass implements Insertable<EntityConflict> {
  final String spaceId;
  final String entityKind;
  final String entityId;
  final String mineJson;
  final int serverVersion;
  final String? serverStatus;
  final int detectedAt;
  const EntityConflict({
    required this.spaceId,
    required this.entityKind,
    required this.entityId,
    required this.mineJson,
    required this.serverVersion,
    this.serverStatus,
    required this.detectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['space_id'] = Variable<String>(spaceId);
    map['entity_kind'] = Variable<String>(entityKind);
    map['entity_id'] = Variable<String>(entityId);
    map['mine_json'] = Variable<String>(mineJson);
    map['server_version'] = Variable<int>(serverVersion);
    if (!nullToAbsent || serverStatus != null) {
      map['server_status'] = Variable<String>(serverStatus);
    }
    map['detected_at'] = Variable<int>(detectedAt);
    return map;
  }

  EntityConflictsCompanion toCompanion(bool nullToAbsent) {
    return EntityConflictsCompanion(
      spaceId: Value(spaceId),
      entityKind: Value(entityKind),
      entityId: Value(entityId),
      mineJson: Value(mineJson),
      serverVersion: Value(serverVersion),
      serverStatus: serverStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(serverStatus),
      detectedAt: Value(detectedAt),
    );
  }

  factory EntityConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntityConflict(
      spaceId: serializer.fromJson<String>(json['space_id']),
      entityKind: serializer.fromJson<String>(json['entity_kind']),
      entityId: serializer.fromJson<String>(json['entity_id']),
      mineJson: serializer.fromJson<String>(json['mine_json']),
      serverVersion: serializer.fromJson<int>(json['server_version']),
      serverStatus: serializer.fromJson<String?>(json['server_status']),
      detectedAt: serializer.fromJson<int>(json['detected_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'space_id': serializer.toJson<String>(spaceId),
      'entity_kind': serializer.toJson<String>(entityKind),
      'entity_id': serializer.toJson<String>(entityId),
      'mine_json': serializer.toJson<String>(mineJson),
      'server_version': serializer.toJson<int>(serverVersion),
      'server_status': serializer.toJson<String?>(serverStatus),
      'detected_at': serializer.toJson<int>(detectedAt),
    };
  }

  EntityConflict copyWith({
    String? spaceId,
    String? entityKind,
    String? entityId,
    String? mineJson,
    int? serverVersion,
    Value<String?> serverStatus = const Value.absent(),
    int? detectedAt,
  }) => EntityConflict(
    spaceId: spaceId ?? this.spaceId,
    entityKind: entityKind ?? this.entityKind,
    entityId: entityId ?? this.entityId,
    mineJson: mineJson ?? this.mineJson,
    serverVersion: serverVersion ?? this.serverVersion,
    serverStatus: serverStatus.present ? serverStatus.value : this.serverStatus,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  EntityConflict copyWithCompanion(EntityConflictsCompanion data) {
    return EntityConflict(
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      entityKind: data.entityKind.present
          ? data.entityKind.value
          : this.entityKind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      mineJson: data.mineJson.present ? data.mineJson.value : this.mineJson,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      serverStatus: data.serverStatus.present
          ? data.serverStatus.value
          : this.serverStatus,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntityConflict(')
          ..write('spaceId: $spaceId, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('mineJson: $mineJson, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverStatus: $serverStatus, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    spaceId,
    entityKind,
    entityId,
    mineJson,
    serverVersion,
    serverStatus,
    detectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntityConflict &&
          other.spaceId == this.spaceId &&
          other.entityKind == this.entityKind &&
          other.entityId == this.entityId &&
          other.mineJson == this.mineJson &&
          other.serverVersion == this.serverVersion &&
          other.serverStatus == this.serverStatus &&
          other.detectedAt == this.detectedAt);
}

class EntityConflictsCompanion extends UpdateCompanion<EntityConflict> {
  final Value<String> spaceId;
  final Value<String> entityKind;
  final Value<String> entityId;
  final Value<String> mineJson;
  final Value<int> serverVersion;
  final Value<String?> serverStatus;
  final Value<int> detectedAt;
  final Value<int> rowid;
  const EntityConflictsCompanion({
    this.spaceId = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.mineJson = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.serverStatus = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntityConflictsCompanion.insert({
    required String spaceId,
    required String entityKind,
    required String entityId,
    required String mineJson,
    required int serverVersion,
    this.serverStatus = const Value.absent(),
    required int detectedAt,
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId),
       entityKind = Value(entityKind),
       entityId = Value(entityId),
       mineJson = Value(mineJson),
       serverVersion = Value(serverVersion),
       detectedAt = Value(detectedAt);
  static Insertable<EntityConflict> custom({
    Expression<String>? spaceId,
    Expression<String>? entityKind,
    Expression<String>? entityId,
    Expression<String>? mineJson,
    Expression<int>? serverVersion,
    Expression<String>? serverStatus,
    Expression<int>? detectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (spaceId != null) 'space_id': spaceId,
      if (entityKind != null) 'entity_kind': entityKind,
      if (entityId != null) 'entity_id': entityId,
      if (mineJson != null) 'mine_json': mineJson,
      if (serverVersion != null) 'server_version': serverVersion,
      if (serverStatus != null) 'server_status': serverStatus,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntityConflictsCompanion copyWith({
    Value<String>? spaceId,
    Value<String>? entityKind,
    Value<String>? entityId,
    Value<String>? mineJson,
    Value<int>? serverVersion,
    Value<String?>? serverStatus,
    Value<int>? detectedAt,
    Value<int>? rowid,
  }) {
    return EntityConflictsCompanion(
      spaceId: spaceId ?? this.spaceId,
      entityKind: entityKind ?? this.entityKind,
      entityId: entityId ?? this.entityId,
      mineJson: mineJson ?? this.mineJson,
      serverVersion: serverVersion ?? this.serverVersion,
      serverStatus: serverStatus ?? this.serverStatus,
      detectedAt: detectedAt ?? this.detectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(entityKind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (mineJson.present) {
      map['mine_json'] = Variable<String>(mineJson.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (serverStatus.present) {
      map['server_status'] = Variable<String>(serverStatus.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<int>(detectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntityConflictsCompanion(')
          ..write('spaceId: $spaceId, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('mineJson: $mineJson, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverStatus: $serverStatus, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class BlobsLocal extends Table with TableInfo<BlobsLocal, BlobsLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BlobsLocal(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _uploadedMeta = const VerificationMeta(
    'uploaded',
  );
  late final GeneratedColumn<int> uploaded = GeneratedColumn<int>(
    'uploaded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _uploadedAtMeta = const VerificationMeta(
    'uploadedAt',
  );
  late final GeneratedColumn<int> uploadedAt = GeneratedColumn<int>(
    'uploaded_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    spaceId,
    module,
    sha256,
    path,
    bytes,
    uploaded,
    uploadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blobs_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlobsLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('uploaded')) {
      context.handle(
        _uploadedMeta,
        uploaded.isAcceptableOrUnknown(data['uploaded']!, _uploadedMeta),
      );
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
        _uploadedAtMeta,
        uploadedAt.isAcceptableOrUnknown(data['uploaded_at']!, _uploadedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spaceId, module, sha256};
  @override
  BlobsLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlobsLocalData(
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      uploaded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uploaded'],
      )!,
      uploadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uploaded_at'],
      ),
    );
  }

  @override
  BlobsLocal createAlias(String alias) {
    return BlobsLocal(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(space_id, module, sha256)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class BlobsLocalData extends DataClass implements Insertable<BlobsLocalData> {
  final String spaceId;
  final String module;
  final String sha256;
  final String path;
  final int bytes;
  final int uploaded;
  final int? uploadedAt;
  const BlobsLocalData({
    required this.spaceId,
    required this.module,
    required this.sha256,
    required this.path,
    required this.bytes,
    required this.uploaded,
    this.uploadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['space_id'] = Variable<String>(spaceId);
    map['module'] = Variable<String>(module);
    map['sha256'] = Variable<String>(sha256);
    map['path'] = Variable<String>(path);
    map['bytes'] = Variable<int>(bytes);
    map['uploaded'] = Variable<int>(uploaded);
    if (!nullToAbsent || uploadedAt != null) {
      map['uploaded_at'] = Variable<int>(uploadedAt);
    }
    return map;
  }

  BlobsLocalCompanion toCompanion(bool nullToAbsent) {
    return BlobsLocalCompanion(
      spaceId: Value(spaceId),
      module: Value(module),
      sha256: Value(sha256),
      path: Value(path),
      bytes: Value(bytes),
      uploaded: Value(uploaded),
      uploadedAt: uploadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedAt),
    );
  }

  factory BlobsLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlobsLocalData(
      spaceId: serializer.fromJson<String>(json['space_id']),
      module: serializer.fromJson<String>(json['module']),
      sha256: serializer.fromJson<String>(json['sha256']),
      path: serializer.fromJson<String>(json['path']),
      bytes: serializer.fromJson<int>(json['bytes']),
      uploaded: serializer.fromJson<int>(json['uploaded']),
      uploadedAt: serializer.fromJson<int?>(json['uploaded_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'space_id': serializer.toJson<String>(spaceId),
      'module': serializer.toJson<String>(module),
      'sha256': serializer.toJson<String>(sha256),
      'path': serializer.toJson<String>(path),
      'bytes': serializer.toJson<int>(bytes),
      'uploaded': serializer.toJson<int>(uploaded),
      'uploaded_at': serializer.toJson<int?>(uploadedAt),
    };
  }

  BlobsLocalData copyWith({
    String? spaceId,
    String? module,
    String? sha256,
    String? path,
    int? bytes,
    int? uploaded,
    Value<int?> uploadedAt = const Value.absent(),
  }) => BlobsLocalData(
    spaceId: spaceId ?? this.spaceId,
    module: module ?? this.module,
    sha256: sha256 ?? this.sha256,
    path: path ?? this.path,
    bytes: bytes ?? this.bytes,
    uploaded: uploaded ?? this.uploaded,
    uploadedAt: uploadedAt.present ? uploadedAt.value : this.uploadedAt,
  );
  BlobsLocalData copyWithCompanion(BlobsLocalCompanion data) {
    return BlobsLocalData(
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      module: data.module.present ? data.module.value : this.module,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      path: data.path.present ? data.path.value : this.path,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      uploaded: data.uploaded.present ? data.uploaded.value : this.uploaded,
      uploadedAt: data.uploadedAt.present
          ? data.uploadedAt.value
          : this.uploadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlobsLocalData(')
          ..write('spaceId: $spaceId, ')
          ..write('module: $module, ')
          ..write('sha256: $sha256, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('uploaded: $uploaded, ')
          ..write('uploadedAt: $uploadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(spaceId, module, sha256, path, bytes, uploaded, uploadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlobsLocalData &&
          other.spaceId == this.spaceId &&
          other.module == this.module &&
          other.sha256 == this.sha256 &&
          other.path == this.path &&
          other.bytes == this.bytes &&
          other.uploaded == this.uploaded &&
          other.uploadedAt == this.uploadedAt);
}

class BlobsLocalCompanion extends UpdateCompanion<BlobsLocalData> {
  final Value<String> spaceId;
  final Value<String> module;
  final Value<String> sha256;
  final Value<String> path;
  final Value<int> bytes;
  final Value<int> uploaded;
  final Value<int?> uploadedAt;
  final Value<int> rowid;
  const BlobsLocalCompanion({
    this.spaceId = const Value.absent(),
    this.module = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.path = const Value.absent(),
    this.bytes = const Value.absent(),
    this.uploaded = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlobsLocalCompanion.insert({
    required String spaceId,
    required String module,
    required String sha256,
    required String path,
    required int bytes,
    this.uploaded = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : spaceId = Value(spaceId),
       module = Value(module),
       sha256 = Value(sha256),
       path = Value(path),
       bytes = Value(bytes);
  static Insertable<BlobsLocalData> custom({
    Expression<String>? spaceId,
    Expression<String>? module,
    Expression<String>? sha256,
    Expression<String>? path,
    Expression<int>? bytes,
    Expression<int>? uploaded,
    Expression<int>? uploadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (spaceId != null) 'space_id': spaceId,
      if (module != null) 'module': module,
      if (sha256 != null) 'sha256': sha256,
      if (path != null) 'path': path,
      if (bytes != null) 'bytes': bytes,
      if (uploaded != null) 'uploaded': uploaded,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlobsLocalCompanion copyWith({
    Value<String>? spaceId,
    Value<String>? module,
    Value<String>? sha256,
    Value<String>? path,
    Value<int>? bytes,
    Value<int>? uploaded,
    Value<int?>? uploadedAt,
    Value<int>? rowid,
  }) {
    return BlobsLocalCompanion(
      spaceId: spaceId ?? this.spaceId,
      module: module ?? this.module,
      sha256: sha256 ?? this.sha256,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      uploaded: uploaded ?? this.uploaded,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (uploaded.present) {
      map['uploaded'] = Variable<int>(uploaded.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<int>(uploadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlobsLocalCompanion(')
          ..write('spaceId: $spaceId, ')
          ..write('module: $module, ')
          ..write('sha256: $sha256, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('uploaded: $uploaded, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncRuntime extends Table with TableInfo<SyncRuntime, SyncRuntimeData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncRuntime(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY CHECK (id = 1)',
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _authenticatedMeta = const VerificationMeta(
    'authenticated',
  );
  late final GeneratedColumn<int> authenticated = GeneratedColumn<int>(
    'authenticated',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _changeRevisionMeta = const VerificationMeta(
    'changeRevision',
  );
  late final GeneratedColumn<int> changeRevision = GeneratedColumn<int>(
    'change_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _noticesJsonMeta = const VerificationMeta(
    'noticesJson',
  );
  late final GeneratedColumn<String> noticesJson = GeneratedColumn<String>(
    'notices_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'[]\'',
    defaultValue: const CustomExpression('\'[]\''),
  );
  static const VerificationMeta _writeAllowedMeta = const VerificationMeta(
    'writeAllowed',
  );
  late final GeneratedColumn<int> writeAllowed = GeneratedColumn<int>(
    'write_allowed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _identityJsonMeta = const VerificationMeta(
    'identityJson',
  );
  late final GeneratedColumn<String> identityJson = GeneratedColumn<String>(
    'identity_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sessionKindMeta = const VerificationMeta(
    'sessionKind',
  );
  late final GeneratedColumn<String> sessionKind = GeneratedColumn<String>(
    'session_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'full\'',
    defaultValue: const CustomExpression('\'full\''),
  );
  static const VerificationMeta _spaceIdsJsonMeta = const VerificationMeta(
    'spaceIdsJson',
  );
  late final GeneratedColumn<String> spaceIdsJson = GeneratedColumn<String>(
    'space_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'[]\'',
    defaultValue: const CustomExpression('\'[]\''),
  );
  static const VerificationMeta _roundOwnerMeta = const VerificationMeta(
    'roundOwner',
  );
  late final GeneratedColumn<String> roundOwner = GeneratedColumn<String>(
    'round_owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _roundLeaseUntilMeta = const VerificationMeta(
    'roundLeaseUntil',
  );
  late final GeneratedColumn<int> roundLeaseUntil = GeneratedColumn<int>(
    'round_lease_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _pendingDeletionsJsonMeta =
      const VerificationMeta('pendingDeletionsJson');
  late final GeneratedColumn<String> pendingDeletionsJson =
      GeneratedColumn<String>(
        'pending_deletions_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT \'[]\'',
        defaultValue: const CustomExpression('\'[]\''),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    generation,
    authenticated,
    changeRevision,
    noticesJson,
    writeAllowed,
    identityJson,
    sessionKind,
    spaceIdsJson,
    roundOwner,
    roundLeaseUntil,
    pendingDeletionsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_runtime';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRuntimeData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    if (data.containsKey('authenticated')) {
      context.handle(
        _authenticatedMeta,
        authenticated.isAcceptableOrUnknown(
          data['authenticated']!,
          _authenticatedMeta,
        ),
      );
    }
    if (data.containsKey('change_revision')) {
      context.handle(
        _changeRevisionMeta,
        changeRevision.isAcceptableOrUnknown(
          data['change_revision']!,
          _changeRevisionMeta,
        ),
      );
    }
    if (data.containsKey('notices_json')) {
      context.handle(
        _noticesJsonMeta,
        noticesJson.isAcceptableOrUnknown(
          data['notices_json']!,
          _noticesJsonMeta,
        ),
      );
    }
    if (data.containsKey('write_allowed')) {
      context.handle(
        _writeAllowedMeta,
        writeAllowed.isAcceptableOrUnknown(
          data['write_allowed']!,
          _writeAllowedMeta,
        ),
      );
    }
    if (data.containsKey('identity_json')) {
      context.handle(
        _identityJsonMeta,
        identityJson.isAcceptableOrUnknown(
          data['identity_json']!,
          _identityJsonMeta,
        ),
      );
    }
    if (data.containsKey('session_kind')) {
      context.handle(
        _sessionKindMeta,
        sessionKind.isAcceptableOrUnknown(
          data['session_kind']!,
          _sessionKindMeta,
        ),
      );
    }
    if (data.containsKey('space_ids_json')) {
      context.handle(
        _spaceIdsJsonMeta,
        spaceIdsJson.isAcceptableOrUnknown(
          data['space_ids_json']!,
          _spaceIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('round_owner')) {
      context.handle(
        _roundOwnerMeta,
        roundOwner.isAcceptableOrUnknown(data['round_owner']!, _roundOwnerMeta),
      );
    }
    if (data.containsKey('round_lease_until')) {
      context.handle(
        _roundLeaseUntilMeta,
        roundLeaseUntil.isAcceptableOrUnknown(
          data['round_lease_until']!,
          _roundLeaseUntilMeta,
        ),
      );
    }
    if (data.containsKey('pending_deletions_json')) {
      context.handle(
        _pendingDeletionsJsonMeta,
        pendingDeletionsJson.isAcceptableOrUnknown(
          data['pending_deletions_json']!,
          _pendingDeletionsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRuntimeData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRuntimeData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      authenticated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}authenticated'],
      )!,
      changeRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_revision'],
      )!,
      noticesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notices_json'],
      )!,
      writeAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}write_allowed'],
      )!,
      identityJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_json'],
      ),
      sessionKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_kind'],
      )!,
      spaceIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_ids_json'],
      )!,
      roundOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}round_owner'],
      ),
      roundLeaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_lease_until'],
      ),
      pendingDeletionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_deletions_json'],
      )!,
    );
  }

  @override
  SyncRuntime createAlias(String alias) {
    return SyncRuntime(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SyncRuntimeData extends DataClass implements Insertable<SyncRuntimeData> {
  final int id;
  final int generation;
  final int authenticated;
  final int changeRevision;
  final String noticesJson;
  final int writeAllowed;
  final String? identityJson;
  final String sessionKind;
  final String spaceIdsJson;
  final String? roundOwner;
  final int? roundLeaseUntil;
  final String pendingDeletionsJson;
  const SyncRuntimeData({
    required this.id,
    required this.generation,
    required this.authenticated,
    required this.changeRevision,
    required this.noticesJson,
    required this.writeAllowed,
    this.identityJson,
    required this.sessionKind,
    required this.spaceIdsJson,
    this.roundOwner,
    this.roundLeaseUntil,
    required this.pendingDeletionsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['generation'] = Variable<int>(generation);
    map['authenticated'] = Variable<int>(authenticated);
    map['change_revision'] = Variable<int>(changeRevision);
    map['notices_json'] = Variable<String>(noticesJson);
    map['write_allowed'] = Variable<int>(writeAllowed);
    if (!nullToAbsent || identityJson != null) {
      map['identity_json'] = Variable<String>(identityJson);
    }
    map['session_kind'] = Variable<String>(sessionKind);
    map['space_ids_json'] = Variable<String>(spaceIdsJson);
    if (!nullToAbsent || roundOwner != null) {
      map['round_owner'] = Variable<String>(roundOwner);
    }
    if (!nullToAbsent || roundLeaseUntil != null) {
      map['round_lease_until'] = Variable<int>(roundLeaseUntil);
    }
    map['pending_deletions_json'] = Variable<String>(pendingDeletionsJson);
    return map;
  }

  SyncRuntimeCompanion toCompanion(bool nullToAbsent) {
    return SyncRuntimeCompanion(
      id: Value(id),
      generation: Value(generation),
      authenticated: Value(authenticated),
      changeRevision: Value(changeRevision),
      noticesJson: Value(noticesJson),
      writeAllowed: Value(writeAllowed),
      identityJson: identityJson == null && nullToAbsent
          ? const Value.absent()
          : Value(identityJson),
      sessionKind: Value(sessionKind),
      spaceIdsJson: Value(spaceIdsJson),
      roundOwner: roundOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(roundOwner),
      roundLeaseUntil: roundLeaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(roundLeaseUntil),
      pendingDeletionsJson: Value(pendingDeletionsJson),
    );
  }

  factory SyncRuntimeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRuntimeData(
      id: serializer.fromJson<int>(json['id']),
      generation: serializer.fromJson<int>(json['generation']),
      authenticated: serializer.fromJson<int>(json['authenticated']),
      changeRevision: serializer.fromJson<int>(json['change_revision']),
      noticesJson: serializer.fromJson<String>(json['notices_json']),
      writeAllowed: serializer.fromJson<int>(json['write_allowed']),
      identityJson: serializer.fromJson<String?>(json['identity_json']),
      sessionKind: serializer.fromJson<String>(json['session_kind']),
      spaceIdsJson: serializer.fromJson<String>(json['space_ids_json']),
      roundOwner: serializer.fromJson<String?>(json['round_owner']),
      roundLeaseUntil: serializer.fromJson<int?>(json['round_lease_until']),
      pendingDeletionsJson: serializer.fromJson<String>(
        json['pending_deletions_json'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'generation': serializer.toJson<int>(generation),
      'authenticated': serializer.toJson<int>(authenticated),
      'change_revision': serializer.toJson<int>(changeRevision),
      'notices_json': serializer.toJson<String>(noticesJson),
      'write_allowed': serializer.toJson<int>(writeAllowed),
      'identity_json': serializer.toJson<String?>(identityJson),
      'session_kind': serializer.toJson<String>(sessionKind),
      'space_ids_json': serializer.toJson<String>(spaceIdsJson),
      'round_owner': serializer.toJson<String?>(roundOwner),
      'round_lease_until': serializer.toJson<int?>(roundLeaseUntil),
      'pending_deletions_json': serializer.toJson<String>(pendingDeletionsJson),
    };
  }

  SyncRuntimeData copyWith({
    int? id,
    int? generation,
    int? authenticated,
    int? changeRevision,
    String? noticesJson,
    int? writeAllowed,
    Value<String?> identityJson = const Value.absent(),
    String? sessionKind,
    String? spaceIdsJson,
    Value<String?> roundOwner = const Value.absent(),
    Value<int?> roundLeaseUntil = const Value.absent(),
    String? pendingDeletionsJson,
  }) => SyncRuntimeData(
    id: id ?? this.id,
    generation: generation ?? this.generation,
    authenticated: authenticated ?? this.authenticated,
    changeRevision: changeRevision ?? this.changeRevision,
    noticesJson: noticesJson ?? this.noticesJson,
    writeAllowed: writeAllowed ?? this.writeAllowed,
    identityJson: identityJson.present ? identityJson.value : this.identityJson,
    sessionKind: sessionKind ?? this.sessionKind,
    spaceIdsJson: spaceIdsJson ?? this.spaceIdsJson,
    roundOwner: roundOwner.present ? roundOwner.value : this.roundOwner,
    roundLeaseUntil: roundLeaseUntil.present
        ? roundLeaseUntil.value
        : this.roundLeaseUntil,
    pendingDeletionsJson: pendingDeletionsJson ?? this.pendingDeletionsJson,
  );
  SyncRuntimeData copyWithCompanion(SyncRuntimeCompanion data) {
    return SyncRuntimeData(
      id: data.id.present ? data.id.value : this.id,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      authenticated: data.authenticated.present
          ? data.authenticated.value
          : this.authenticated,
      changeRevision: data.changeRevision.present
          ? data.changeRevision.value
          : this.changeRevision,
      noticesJson: data.noticesJson.present
          ? data.noticesJson.value
          : this.noticesJson,
      writeAllowed: data.writeAllowed.present
          ? data.writeAllowed.value
          : this.writeAllowed,
      identityJson: data.identityJson.present
          ? data.identityJson.value
          : this.identityJson,
      sessionKind: data.sessionKind.present
          ? data.sessionKind.value
          : this.sessionKind,
      spaceIdsJson: data.spaceIdsJson.present
          ? data.spaceIdsJson.value
          : this.spaceIdsJson,
      roundOwner: data.roundOwner.present
          ? data.roundOwner.value
          : this.roundOwner,
      roundLeaseUntil: data.roundLeaseUntil.present
          ? data.roundLeaseUntil.value
          : this.roundLeaseUntil,
      pendingDeletionsJson: data.pendingDeletionsJson.present
          ? data.pendingDeletionsJson.value
          : this.pendingDeletionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRuntimeData(')
          ..write('id: $id, ')
          ..write('generation: $generation, ')
          ..write('authenticated: $authenticated, ')
          ..write('changeRevision: $changeRevision, ')
          ..write('noticesJson: $noticesJson, ')
          ..write('writeAllowed: $writeAllowed, ')
          ..write('identityJson: $identityJson, ')
          ..write('sessionKind: $sessionKind, ')
          ..write('spaceIdsJson: $spaceIdsJson, ')
          ..write('roundOwner: $roundOwner, ')
          ..write('roundLeaseUntil: $roundLeaseUntil, ')
          ..write('pendingDeletionsJson: $pendingDeletionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    generation,
    authenticated,
    changeRevision,
    noticesJson,
    writeAllowed,
    identityJson,
    sessionKind,
    spaceIdsJson,
    roundOwner,
    roundLeaseUntil,
    pendingDeletionsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRuntimeData &&
          other.id == this.id &&
          other.generation == this.generation &&
          other.authenticated == this.authenticated &&
          other.changeRevision == this.changeRevision &&
          other.noticesJson == this.noticesJson &&
          other.writeAllowed == this.writeAllowed &&
          other.identityJson == this.identityJson &&
          other.sessionKind == this.sessionKind &&
          other.spaceIdsJson == this.spaceIdsJson &&
          other.roundOwner == this.roundOwner &&
          other.roundLeaseUntil == this.roundLeaseUntil &&
          other.pendingDeletionsJson == this.pendingDeletionsJson);
}

class SyncRuntimeCompanion extends UpdateCompanion<SyncRuntimeData> {
  final Value<int> id;
  final Value<int> generation;
  final Value<int> authenticated;
  final Value<int> changeRevision;
  final Value<String> noticesJson;
  final Value<int> writeAllowed;
  final Value<String?> identityJson;
  final Value<String> sessionKind;
  final Value<String> spaceIdsJson;
  final Value<String?> roundOwner;
  final Value<int?> roundLeaseUntil;
  final Value<String> pendingDeletionsJson;
  const SyncRuntimeCompanion({
    this.id = const Value.absent(),
    this.generation = const Value.absent(),
    this.authenticated = const Value.absent(),
    this.changeRevision = const Value.absent(),
    this.noticesJson = const Value.absent(),
    this.writeAllowed = const Value.absent(),
    this.identityJson = const Value.absent(),
    this.sessionKind = const Value.absent(),
    this.spaceIdsJson = const Value.absent(),
    this.roundOwner = const Value.absent(),
    this.roundLeaseUntil = const Value.absent(),
    this.pendingDeletionsJson = const Value.absent(),
  });
  SyncRuntimeCompanion.insert({
    this.id = const Value.absent(),
    this.generation = const Value.absent(),
    this.authenticated = const Value.absent(),
    this.changeRevision = const Value.absent(),
    this.noticesJson = const Value.absent(),
    this.writeAllowed = const Value.absent(),
    this.identityJson = const Value.absent(),
    this.sessionKind = const Value.absent(),
    this.spaceIdsJson = const Value.absent(),
    this.roundOwner = const Value.absent(),
    this.roundLeaseUntil = const Value.absent(),
    this.pendingDeletionsJson = const Value.absent(),
  });
  static Insertable<SyncRuntimeData> custom({
    Expression<int>? id,
    Expression<int>? generation,
    Expression<int>? authenticated,
    Expression<int>? changeRevision,
    Expression<String>? noticesJson,
    Expression<int>? writeAllowed,
    Expression<String>? identityJson,
    Expression<String>? sessionKind,
    Expression<String>? spaceIdsJson,
    Expression<String>? roundOwner,
    Expression<int>? roundLeaseUntil,
    Expression<String>? pendingDeletionsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (generation != null) 'generation': generation,
      if (authenticated != null) 'authenticated': authenticated,
      if (changeRevision != null) 'change_revision': changeRevision,
      if (noticesJson != null) 'notices_json': noticesJson,
      if (writeAllowed != null) 'write_allowed': writeAllowed,
      if (identityJson != null) 'identity_json': identityJson,
      if (sessionKind != null) 'session_kind': sessionKind,
      if (spaceIdsJson != null) 'space_ids_json': spaceIdsJson,
      if (roundOwner != null) 'round_owner': roundOwner,
      if (roundLeaseUntil != null) 'round_lease_until': roundLeaseUntil,
      if (pendingDeletionsJson != null)
        'pending_deletions_json': pendingDeletionsJson,
    });
  }

  SyncRuntimeCompanion copyWith({
    Value<int>? id,
    Value<int>? generation,
    Value<int>? authenticated,
    Value<int>? changeRevision,
    Value<String>? noticesJson,
    Value<int>? writeAllowed,
    Value<String?>? identityJson,
    Value<String>? sessionKind,
    Value<String>? spaceIdsJson,
    Value<String?>? roundOwner,
    Value<int?>? roundLeaseUntil,
    Value<String>? pendingDeletionsJson,
  }) {
    return SyncRuntimeCompanion(
      id: id ?? this.id,
      generation: generation ?? this.generation,
      authenticated: authenticated ?? this.authenticated,
      changeRevision: changeRevision ?? this.changeRevision,
      noticesJson: noticesJson ?? this.noticesJson,
      writeAllowed: writeAllowed ?? this.writeAllowed,
      identityJson: identityJson ?? this.identityJson,
      sessionKind: sessionKind ?? this.sessionKind,
      spaceIdsJson: spaceIdsJson ?? this.spaceIdsJson,
      roundOwner: roundOwner ?? this.roundOwner,
      roundLeaseUntil: roundLeaseUntil ?? this.roundLeaseUntil,
      pendingDeletionsJson: pendingDeletionsJson ?? this.pendingDeletionsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (authenticated.present) {
      map['authenticated'] = Variable<int>(authenticated.value);
    }
    if (changeRevision.present) {
      map['change_revision'] = Variable<int>(changeRevision.value);
    }
    if (noticesJson.present) {
      map['notices_json'] = Variable<String>(noticesJson.value);
    }
    if (writeAllowed.present) {
      map['write_allowed'] = Variable<int>(writeAllowed.value);
    }
    if (identityJson.present) {
      map['identity_json'] = Variable<String>(identityJson.value);
    }
    if (sessionKind.present) {
      map['session_kind'] = Variable<String>(sessionKind.value);
    }
    if (spaceIdsJson.present) {
      map['space_ids_json'] = Variable<String>(spaceIdsJson.value);
    }
    if (roundOwner.present) {
      map['round_owner'] = Variable<String>(roundOwner.value);
    }
    if (roundLeaseUntil.present) {
      map['round_lease_until'] = Variable<int>(roundLeaseUntil.value);
    }
    if (pendingDeletionsJson.present) {
      map['pending_deletions_json'] = Variable<String>(
        pendingDeletionsJson.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRuntimeCompanion(')
          ..write('id: $id, ')
          ..write('generation: $generation, ')
          ..write('authenticated: $authenticated, ')
          ..write('changeRevision: $changeRevision, ')
          ..write('noticesJson: $noticesJson, ')
          ..write('writeAllowed: $writeAllowed, ')
          ..write('identityJson: $identityJson, ')
          ..write('sessionKind: $sessionKind, ')
          ..write('spaceIdsJson: $spaceIdsJson, ')
          ..write('roundOwner: $roundOwner, ')
          ..write('roundLeaseUntil: $roundLeaseUntil, ')
          ..write('pendingDeletionsJson: $pendingDeletionsJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$JiabuDatabase extends GeneratedDatabase {
  _$JiabuDatabase(QueryExecutor e) : super(e);
  $JiabuDatabaseManager get managers => $JiabuDatabaseManager(this);
  late final Spaces spaces = Spaces(this);
  late final Index spacesSpace = Index(
    'spaces_space',
    'CREATE INDEX spaces_space ON spaces (space_id)',
  );
  late final SpaceMembers spaceMembers = SpaceMembers(this);
  late final Index spaceMembersSpace = Index(
    'space_members_space',
    'CREATE INDEX space_members_space ON space_members (space_id)',
  );
  late final MemberGrants memberGrants = MemberGrants(this);
  late final Index memberGrantsSpace = Index(
    'member_grants_space',
    'CREATE INDEX member_grants_space ON member_grants (space_id)',
  );
  late final Accounts accounts = Accounts(this);
  late final Index accountsSpace = Index(
    'accounts_space',
    'CREATE INDEX accounts_space ON accounts (space_id)',
  );
  late final AllocationPlans allocationPlans = AllocationPlans(this);
  late final Index allocationPlansSpace = Index(
    'allocation_plans_space',
    'CREATE INDEX allocation_plans_space ON allocation_plans (space_id)',
  );
  late final Tags tags = Tags(this);
  late final Index tagsSpace = Index(
    'tags_space',
    'CREATE INDEX tags_space ON tags (space_id)',
  );
  late final Records records = Records(this);
  late final Index recordsSpace = Index(
    'records_space',
    'CREATE INDEX records_space ON records (space_id)',
  );
  late final Subjects subjects = Subjects(this);
  late final Index subjectsSpace = Index(
    'subjects_space',
    'CREATE INDEX subjects_space ON subjects (space_id)',
  );
  late final Documents documents = Documents(this);
  late final Index documentsSpace = Index(
    'documents_space',
    'CREATE INDEX documents_space ON documents (space_id)',
  );
  late final EntityEvents entityEvents = EntityEvents(this);
  late final Index entityEventsSpace = Index(
    'entity_events_space',
    'CREATE INDEX entity_events_space ON entity_events (space_id)',
  );
  late final Conversations conversations = Conversations(this);
  late final Index conversationsSpace = Index(
    'conversations_space',
    'CREATE INDEX conversations_space ON conversations (space_id)',
  );
  late final ChatEntries chatEntries = ChatEntries(this);
  late final Index chatEntriesSpace = Index(
    'chat_entries_space',
    'CREATE INDEX chat_entries_space ON chat_entries (space_id)',
  );
  late final Index chatEntriesConversation = Index(
    'chat_entries_conversation',
    'CREATE INDEX chat_entries_conversation ON chat_entries (space_id, member_id, conversation_id, created_at, id)',
  );
  late final ChatClientStates chatClientStates = ChatClientStates(this);
  late final Outbox outbox = Outbox(this);
  late final Index outboxFifo = Index(
    'outbox_fifo',
    'CREATE INDEX outbox_fifo ON outbox (space_id, created_at, id)',
  );
  late final SyncCursors syncCursors = SyncCursors(this);
  late final EntityConflicts entityConflicts = EntityConflicts(this);
  late final BlobsLocal blobsLocal = BlobsLocal(this);
  late final SyncRuntime syncRuntime = SyncRuntime(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    spaces,
    spacesSpace,
    spaceMembers,
    spaceMembersSpace,
    memberGrants,
    memberGrantsSpace,
    accounts,
    accountsSpace,
    allocationPlans,
    allocationPlansSpace,
    tags,
    tagsSpace,
    records,
    recordsSpace,
    subjects,
    subjectsSpace,
    documents,
    documentsSpace,
    entityEvents,
    entityEventsSpace,
    conversations,
    conversationsSpace,
    chatEntries,
    chatEntriesSpace,
    chatEntriesConversation,
    chatClientStates,
    outbox,
    outboxFifo,
    syncCursors,
    entityConflicts,
    blobsLocal,
    syncRuntime,
  ];
}

typedef $SpacesCreateCompanionBuilder = SpacesCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> name,
  Value<String?> accentColor,
  Value<String?> currency,
  Value<String?> timezone,
  Value<int?> isDefault,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> role,
  Value<String?> memberId,
  Value<int?> joinEpoch,
  Value<String?> modules,
  Value<int> localGeneration,
  Value<int> rowid,
});
typedef $SpacesUpdateCompanionBuilder = SpacesCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> name,
  Value<String?> accentColor,
  Value<String?> currency,
  Value<String?> timezone,
  Value<int?> isDefault,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> role,
  Value<String?> memberId,
  Value<int?> joinEpoch,
  Value<String?> modules,
  Value<int> localGeneration,
  Value<int> rowid,
});

class $SpacesFilterComposer extends Composer<_$JiabuDatabase, Spaces> {
  $SpacesFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get joinEpoch => $composableBuilder(
    column: $table.joinEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modules => $composableBuilder(
    column: $table.modules,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localGeneration => $composableBuilder(
    column: $table.localGeneration,
    builder: (column) => ColumnFilters(column),
  );
}

class $SpacesOrderingComposer extends Composer<_$JiabuDatabase, Spaces> {
  $SpacesOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get joinEpoch => $composableBuilder(
    column: $table.joinEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modules => $composableBuilder(
    column: $table.modules,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localGeneration => $composableBuilder(
    column: $table.localGeneration,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SpacesAnnotationComposer extends Composer<_$JiabuDatabase, Spaces> {
  $SpacesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<int> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<int> get joinEpoch =>
      $composableBuilder(column: $table.joinEpoch, builder: (column) => column);

  GeneratedColumn<String> get modules =>
      $composableBuilder(column: $table.modules, builder: (column) => column);

  GeneratedColumn<int> get localGeneration => $composableBuilder(
    column: $table.localGeneration,
    builder: (column) => column,
  );
}

class $SpacesTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Spaces,
          Space,
          $SpacesFilterComposer,
          $SpacesOrderingComposer,
          $SpacesAnnotationComposer,
          $SpacesCreateCompanionBuilder,
          $SpacesUpdateCompanionBuilder,
          (Space, BaseReferences<_$JiabuDatabase, Spaces, Space>),
          Space,
          PrefetchHooks Function()
        > {
  $SpacesTableManager(_$JiabuDatabase db, Spaces table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SpacesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SpacesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SpacesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> accentColor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> timezone = const Value.absent(),
                Value<int?> isDefault = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<int?> joinEpoch = const Value.absent(),
                Value<String?> modules = const Value.absent(),
                Value<int> localGeneration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpacesCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                name: name,
                accentColor: accentColor,
                currency: currency,
                timezone: timezone,
                isDefault: isDefault,
                version: version,
                changeSeq: changeSeq,
                role: role,
                memberId: memberId,
                joinEpoch: joinEpoch,
                modules: modules,
                localGeneration: localGeneration,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> accentColor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> timezone = const Value.absent(),
                Value<int?> isDefault = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<int?> joinEpoch = const Value.absent(),
                Value<String?> modules = const Value.absent(),
                Value<int> localGeneration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpacesCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                name: name,
                accentColor: accentColor,
                currency: currency,
                timezone: timezone,
                isDefault: isDefault,
                version: version,
                changeSeq: changeSeq,
                role: role,
                memberId: memberId,
                joinEpoch: joinEpoch,
                modules: modules,
                localGeneration: localGeneration,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Spaces, Space>(table),
                  BaseReferences<_$JiabuDatabase, Spaces, Space>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SpacesProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Spaces,
      Space,
      $SpacesFilterComposer,
      $SpacesOrderingComposer,
      $SpacesAnnotationComposer,
      $SpacesCreateCompanionBuilder,
      $SpacesUpdateCompanionBuilder,
      (Space, BaseReferences<_$JiabuDatabase, Spaces, Space>),
      Space,
      PrefetchHooks Function()
    >;
typedef $SpaceMembersCreateCompanionBuilder = SpaceMembersCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> displayName,
  Value<String?> role,
  Value<String?> status,
  Value<int?> joinEpoch,
  Value<String?> joinedAt,
  Value<String?> leftAt,
  Value<String?> leftReason,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<int> rowid,
});
typedef $SpaceMembersUpdateCompanionBuilder = SpaceMembersCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> displayName,
  Value<String?> role,
  Value<String?> status,
  Value<int?> joinEpoch,
  Value<String?> joinedAt,
  Value<String?> leftAt,
  Value<String?> leftReason,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<int> rowid,
});

class $SpaceMembersFilterComposer
    extends Composer<_$JiabuDatabase, SpaceMembers> {
  $SpaceMembersFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get joinEpoch => $composableBuilder(
    column: $table.joinEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leftAt => $composableBuilder(
    column: $table.leftAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leftReason => $composableBuilder(
    column: $table.leftReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $SpaceMembersOrderingComposer
    extends Composer<_$JiabuDatabase, SpaceMembers> {
  $SpaceMembersOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get joinEpoch => $composableBuilder(
    column: $table.joinEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leftAt => $composableBuilder(
    column: $table.leftAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leftReason => $composableBuilder(
    column: $table.leftReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SpaceMembersAnnotationComposer
    extends Composer<_$JiabuDatabase, SpaceMembers> {
  $SpaceMembersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get joinEpoch =>
      $composableBuilder(column: $table.joinEpoch, builder: (column) => column);

  GeneratedColumn<String> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<String> get leftAt =>
      $composableBuilder(column: $table.leftAt, builder: (column) => column);

  GeneratedColumn<String> get leftReason => $composableBuilder(
    column: $table.leftReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);
}

class $SpaceMembersTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          SpaceMembers,
          SpaceMember,
          $SpaceMembersFilterComposer,
          $SpaceMembersOrderingComposer,
          $SpaceMembersAnnotationComposer,
          $SpaceMembersCreateCompanionBuilder,
          $SpaceMembersUpdateCompanionBuilder,
          (
            SpaceMember,
            BaseReferences<_$JiabuDatabase, SpaceMembers, SpaceMember>,
          ),
          SpaceMember,
          PrefetchHooks Function()
        > {
  $SpaceMembersTableManager(_$JiabuDatabase db, SpaceMembers table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SpaceMembersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SpaceMembersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SpaceMembersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> joinEpoch = const Value.absent(),
                Value<String?> joinedAt = const Value.absent(),
                Value<String?> leftAt = const Value.absent(),
                Value<String?> leftReason = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceMembersCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                displayName: displayName,
                role: role,
                status: status,
                joinEpoch: joinEpoch,
                joinedAt: joinedAt,
                leftAt: leftAt,
                leftReason: leftReason,
                version: version,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> joinEpoch = const Value.absent(),
                Value<String?> joinedAt = const Value.absent(),
                Value<String?> leftAt = const Value.absent(),
                Value<String?> leftReason = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpaceMembersCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                displayName: displayName,
                role: role,
                status: status,
                joinEpoch: joinEpoch,
                joinedAt: joinedAt,
                leftAt: leftAt,
                leftReason: leftReason,
                version: version,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SpaceMembers, SpaceMember>(table),
                  BaseReferences<_$JiabuDatabase, SpaceMembers, SpaceMember>(
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

typedef $SpaceMembersProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      SpaceMembers,
      SpaceMember,
      $SpaceMembersFilterComposer,
      $SpaceMembersOrderingComposer,
      $SpaceMembersAnnotationComposer,
      $SpaceMembersCreateCompanionBuilder,
      $SpaceMembersUpdateCompanionBuilder,
      (SpaceMember, BaseReferences<_$JiabuDatabase, SpaceMembers, SpaceMember>),
      SpaceMember,
      PrefetchHooks Function()
    >;
typedef $MemberGrantsCreateCompanionBuilder = MemberGrantsCompanion Function({
  required String spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> memberId,
  Value<String?> module,
  Value<String?> level,
  Value<int?> changeSeq,
  Value<int> rowid,
});
typedef $MemberGrantsUpdateCompanionBuilder = MemberGrantsCompanion Function({
  Value<String> spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> memberId,
  Value<String?> module,
  Value<String?> level,
  Value<int?> changeSeq,
  Value<int> rowid,
});

class $MemberGrantsFilterComposer
    extends Composer<_$JiabuDatabase, MemberGrants> {
  $MemberGrantsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $MemberGrantsOrderingComposer
    extends Composer<_$JiabuDatabase, MemberGrants> {
  $MemberGrantsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MemberGrantsAnnotationComposer
    extends Composer<_$JiabuDatabase, MemberGrants> {
  $MemberGrantsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);
}

class $MemberGrantsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          MemberGrants,
          MemberGrant,
          $MemberGrantsFilterComposer,
          $MemberGrantsOrderingComposer,
          $MemberGrantsAnnotationComposer,
          $MemberGrantsCreateCompanionBuilder,
          $MemberGrantsUpdateCompanionBuilder,
          (
            MemberGrant,
            BaseReferences<_$JiabuDatabase, MemberGrants, MemberGrant>,
          ),
          MemberGrant,
          PrefetchHooks Function()
        > {
  $MemberGrantsTableManager(_$JiabuDatabase db, MemberGrants table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MemberGrantsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MemberGrantsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MemberGrantsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> level = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemberGrantsCompanion(
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                memberId: memberId,
                module: module,
                level: level,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> level = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemberGrantsCompanion.insert(
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                memberId: memberId,
                module: module,
                level: level,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<MemberGrants, MemberGrant>(table),
                  BaseReferences<_$JiabuDatabase, MemberGrants, MemberGrant>(
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

typedef $MemberGrantsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      MemberGrants,
      MemberGrant,
      $MemberGrantsFilterComposer,
      $MemberGrantsOrderingComposer,
      $MemberGrantsAnnotationComposer,
      $MemberGrantsCreateCompanionBuilder,
      $MemberGrantsUpdateCompanionBuilder,
      (MemberGrant, BaseReferences<_$JiabuDatabase, MemberGrants, MemberGrant>),
      MemberGrant,
      PrefetchHooks Function()
    >;
typedef $AccountsCreateCompanionBuilder = AccountsCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> kind,
  Value<String?> name,
  Value<int?> isReserve,
  Value<int?> openingBalanceMinor,
  Value<String?> openingOn,
  Value<int?> sortKey,
  Value<String?> createdByMemberId,
  Value<String?> archivedAt,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});
typedef $AccountsUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> kind,
  Value<String?> name,
  Value<int?> isReserve,
  Value<int?> openingBalanceMinor,
  Value<String?> openingOn,
  Value<int?> sortKey,
  Value<String?> createdByMemberId,
  Value<String?> archivedAt,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});

class $AccountsFilterComposer extends Composer<_$JiabuDatabase, Accounts> {
  $AccountsFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isReserve => $composableBuilder(
    column: $table.isReserve,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingBalanceMinor => $composableBuilder(
    column: $table.openingBalanceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openingOn => $composableBuilder(
    column: $table.openingOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $AccountsOrderingComposer extends Composer<_$JiabuDatabase, Accounts> {
  $AccountsOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isReserve => $composableBuilder(
    column: $table.isReserve,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingBalanceMinor => $composableBuilder(
    column: $table.openingBalanceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openingOn => $composableBuilder(
    column: $table.openingOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AccountsAnnotationComposer extends Composer<_$JiabuDatabase, Accounts> {
  $AccountsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get isReserve =>
      $composableBuilder(column: $table.isReserve, builder: (column) => column);

  GeneratedColumn<int> get openingBalanceMinor => $composableBuilder(
    column: $table.openingBalanceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get openingOn =>
      $composableBuilder(column: $table.openingOn, builder: (column) => column);

  GeneratedColumn<int> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $AccountsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Accounts,
          Account,
          $AccountsFilterComposer,
          $AccountsOrderingComposer,
          $AccountsAnnotationComposer,
          $AccountsCreateCompanionBuilder,
          $AccountsUpdateCompanionBuilder,
          (Account, BaseReferences<_$JiabuDatabase, Accounts, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $AccountsTableManager(_$JiabuDatabase db, Accounts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AccountsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AccountsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AccountsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int?> isReserve = const Value.absent(),
                Value<int?> openingBalanceMinor = const Value.absent(),
                Value<String?> openingOn = const Value.absent(),
                Value<int?> sortKey = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                kind: kind,
                name: name,
                isReserve: isReserve,
                openingBalanceMinor: openingBalanceMinor,
                openingOn: openingOn,
                sortKey: sortKey,
                createdByMemberId: createdByMemberId,
                archivedAt: archivedAt,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int?> isReserve = const Value.absent(),
                Value<int?> openingBalanceMinor = const Value.absent(),
                Value<String?> openingOn = const Value.absent(),
                Value<int?> sortKey = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                kind: kind,
                name: name,
                isReserve: isReserve,
                openingBalanceMinor: openingBalanceMinor,
                openingOn: openingOn,
                sortKey: sortKey,
                createdByMemberId: createdByMemberId,
                archivedAt: archivedAt,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Accounts, Account>(table),
                  BaseReferences<_$JiabuDatabase, Accounts, Account>(
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

typedef $AccountsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Accounts,
      Account,
      $AccountsFilterComposer,
      $AccountsOrderingComposer,
      $AccountsAnnotationComposer,
      $AccountsCreateCompanionBuilder,
      $AccountsUpdateCompanionBuilder,
      (Account, BaseReferences<_$JiabuDatabase, Accounts, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $AllocationPlansCreateCompanionBuilder =
    AllocationPlansCompanion Function({
      required String spaceId,
      Value<String> syncState,
      Value<int?> baseVersion,
      Value<String> dataJson,
      Value<String?> accountId,
      Value<int?> amountMinor,
      Value<int?> dayOfMonth,
      Value<int?> enabled,
      Value<String?> nextRunOn,
      Value<String?> lastRunMonth,
      Value<int?> version,
      Value<int?> changeSeq,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $AllocationPlansUpdateCompanionBuilder =
    AllocationPlansCompanion Function({
      Value<String> spaceId,
      Value<String> syncState,
      Value<int?> baseVersion,
      Value<String> dataJson,
      Value<String?> accountId,
      Value<int?> amountMinor,
      Value<int?> dayOfMonth,
      Value<int?> enabled,
      Value<String?> nextRunOn,
      Value<String?> lastRunMonth,
      Value<int?> version,
      Value<int?> changeSeq,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $AllocationPlansFilterComposer
    extends Composer<_$JiabuDatabase, AllocationPlans> {
  $AllocationPlansFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextRunOn => $composableBuilder(
    column: $table.nextRunOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRunMonth => $composableBuilder(
    column: $table.lastRunMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $AllocationPlansOrderingComposer
    extends Composer<_$JiabuDatabase, AllocationPlans> {
  $AllocationPlansOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextRunOn => $composableBuilder(
    column: $table.nextRunOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRunMonth => $composableBuilder(
    column: $table.lastRunMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AllocationPlansAnnotationComposer
    extends Composer<_$JiabuDatabase, AllocationPlans> {
  $AllocationPlansAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get nextRunOn =>
      $composableBuilder(column: $table.nextRunOn, builder: (column) => column);

  GeneratedColumn<String> get lastRunMonth => $composableBuilder(
    column: $table.lastRunMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $AllocationPlansTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          AllocationPlans,
          AllocationPlan,
          $AllocationPlansFilterComposer,
          $AllocationPlansOrderingComposer,
          $AllocationPlansAnnotationComposer,
          $AllocationPlansCreateCompanionBuilder,
          $AllocationPlansUpdateCompanionBuilder,
          (
            AllocationPlan,
            BaseReferences<_$JiabuDatabase, AllocationPlans, AllocationPlan>,
          ),
          AllocationPlan,
          PrefetchHooks Function()
        > {
  $AllocationPlansTableManager(_$JiabuDatabase db, AllocationPlans table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AllocationPlansFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AllocationPlansOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AllocationPlansAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> enabled = const Value.absent(),
                Value<String?> nextRunOn = const Value.absent(),
                Value<String?> lastRunMonth = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AllocationPlansCompanion(
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                accountId: accountId,
                amountMinor: amountMinor,
                dayOfMonth: dayOfMonth,
                enabled: enabled,
                nextRunOn: nextRunOn,
                lastRunMonth: lastRunMonth,
                version: version,
                changeSeq: changeSeq,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> enabled = const Value.absent(),
                Value<String?> nextRunOn = const Value.absent(),
                Value<String?> lastRunMonth = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AllocationPlansCompanion.insert(
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                accountId: accountId,
                amountMinor: amountMinor,
                dayOfMonth: dayOfMonth,
                enabled: enabled,
                nextRunOn: nextRunOn,
                lastRunMonth: lastRunMonth,
                version: version,
                changeSeq: changeSeq,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<AllocationPlans, AllocationPlan>(table),
                  BaseReferences<
                    _$JiabuDatabase,
                    AllocationPlans,
                    AllocationPlan
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AllocationPlansProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      AllocationPlans,
      AllocationPlan,
      $AllocationPlansFilterComposer,
      $AllocationPlansOrderingComposer,
      $AllocationPlansAnnotationComposer,
      $AllocationPlansCreateCompanionBuilder,
      $AllocationPlansUpdateCompanionBuilder,
      (
        AllocationPlan,
        BaseReferences<_$JiabuDatabase, AllocationPlans, AllocationPlan>,
      ),
      AllocationPlan,
      PrefetchHooks Function()
    >;
typedef $TagsCreateCompanionBuilder = TagsCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> presetKey,
  Value<String?> name,
  Value<String?> createdByMemberId,
  Value<String?> deletedAt,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<int> rowid,
});
typedef $TagsUpdateCompanionBuilder = TagsCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> presetKey,
  Value<String?> name,
  Value<String?> createdByMemberId,
  Value<String?> deletedAt,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<int> rowid,
});

class $TagsFilterComposer extends Composer<_$JiabuDatabase, Tags> {
  $TagsFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $TagsOrderingComposer extends Composer<_$JiabuDatabase, Tags> {
  $TagsOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $TagsAnnotationComposer extends Composer<_$JiabuDatabase, Tags> {
  $TagsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get presetKey =>
      $composableBuilder(column: $table.presetKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);
}

class $TagsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Tags,
          Tag,
          $TagsFilterComposer,
          $TagsOrderingComposer,
          $TagsAnnotationComposer,
          $TagsCreateCompanionBuilder,
          $TagsUpdateCompanionBuilder,
          (Tag, BaseReferences<_$JiabuDatabase, Tags, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $TagsTableManager(_$JiabuDatabase db, Tags table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TagsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TagsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TagsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> presetKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                presetKey: presetKey,
                name: name,
                createdByMemberId: createdByMemberId,
                deletedAt: deletedAt,
                version: version,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> presetKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                presetKey: presetKey,
                name: name,
                createdByMemberId: createdByMemberId,
                deletedAt: deletedAt,
                version: version,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Tags, Tag>(table),
                  BaseReferences<_$JiabuDatabase, Tags, Tag>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $TagsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Tags,
      Tag,
      $TagsFilterComposer,
      $TagsOrderingComposer,
      $TagsAnnotationComposer,
      $TagsCreateCompanionBuilder,
      $TagsUpdateCompanionBuilder,
      (Tag, BaseReferences<_$JiabuDatabase, Tags, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $RecordsCreateCompanionBuilder = RecordsCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> kind,
  Value<int?> amountMinor,
  Value<String?> occurredOn,
  Value<String?> accountId,
  Value<String?> toAccountId,
  Value<String?> purposeId,
  Value<String?> toPurposeId,
  Value<String?> refundOfId,
  Value<String?> tagIds,
  Value<String?> note,
  Value<String?> attachments,
  Value<String?> status,
  Value<String?> voidReason,
  Value<String?> origin,
  Value<String?> runId,
  Value<String?> createdByMemberId,
  Value<String?> updatedByMemberId,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});
typedef $RecordsUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> kind,
  Value<int?> amountMinor,
  Value<String?> occurredOn,
  Value<String?> accountId,
  Value<String?> toAccountId,
  Value<String?> purposeId,
  Value<String?> toPurposeId,
  Value<String?> refundOfId,
  Value<String?> tagIds,
  Value<String?> note,
  Value<String?> attachments,
  Value<String?> status,
  Value<String?> voidReason,
  Value<String?> origin,
  Value<String?> runId,
  Value<String?> createdByMemberId,
  Value<String?> updatedByMemberId,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});

class $RecordsFilterComposer extends Composer<_$JiabuDatabase, Records> {
  $RecordsFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purposeId => $composableBuilder(
    column: $table.purposeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toPurposeId => $composableBuilder(
    column: $table.toPurposeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refundOfId => $composableBuilder(
    column: $table.refundOfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagIds => $composableBuilder(
    column: $table.tagIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedByMemberId => $composableBuilder(
    column: $table.updatedByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $RecordsOrderingComposer extends Composer<_$JiabuDatabase, Records> {
  $RecordsOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purposeId => $composableBuilder(
    column: $table.purposeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toPurposeId => $composableBuilder(
    column: $table.toPurposeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refundOfId => $composableBuilder(
    column: $table.refundOfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagIds => $composableBuilder(
    column: $table.tagIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedByMemberId => $composableBuilder(
    column: $table.updatedByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $RecordsAnnotationComposer extends Composer<_$JiabuDatabase, Records> {
  $RecordsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purposeId =>
      $composableBuilder(column: $table.purposeId, builder: (column) => column);

  GeneratedColumn<String> get toPurposeId => $composableBuilder(
    column: $table.toPurposeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refundOfId => $composableBuilder(
    column: $table.refundOfId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagIds =>
      $composableBuilder(column: $table.tagIds, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedByMemberId => $composableBuilder(
    column: $table.updatedByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $RecordsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Records,
          Record,
          $RecordsFilterComposer,
          $RecordsOrderingComposer,
          $RecordsAnnotationComposer,
          $RecordsCreateCompanionBuilder,
          $RecordsUpdateCompanionBuilder,
          (Record, BaseReferences<_$JiabuDatabase, Records, Record>),
          Record,
          PrefetchHooks Function()
        > {
  $RecordsTableManager(_$JiabuDatabase db, Records table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $RecordsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $RecordsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RecordsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<String?> occurredOn = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> purposeId = const Value.absent(),
                Value<String?> toPurposeId = const Value.absent(),
                Value<String?> refundOfId = const Value.absent(),
                Value<String?> tagIds = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> attachments = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> updatedByMemberId = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                kind: kind,
                amountMinor: amountMinor,
                occurredOn: occurredOn,
                accountId: accountId,
                toAccountId: toAccountId,
                purposeId: purposeId,
                toPurposeId: toPurposeId,
                refundOfId: refundOfId,
                tagIds: tagIds,
                note: note,
                attachments: attachments,
                status: status,
                voidReason: voidReason,
                origin: origin,
                runId: runId,
                createdByMemberId: createdByMemberId,
                updatedByMemberId: updatedByMemberId,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<String?> occurredOn = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> purposeId = const Value.absent(),
                Value<String?> toPurposeId = const Value.absent(),
                Value<String?> refundOfId = const Value.absent(),
                Value<String?> tagIds = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> attachments = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> updatedByMemberId = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                kind: kind,
                amountMinor: amountMinor,
                occurredOn: occurredOn,
                accountId: accountId,
                toAccountId: toAccountId,
                purposeId: purposeId,
                toPurposeId: toPurposeId,
                refundOfId: refundOfId,
                tagIds: tagIds,
                note: note,
                attachments: attachments,
                status: status,
                voidReason: voidReason,
                origin: origin,
                runId: runId,
                createdByMemberId: createdByMemberId,
                updatedByMemberId: updatedByMemberId,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Records, Record>(table),
                  BaseReferences<_$JiabuDatabase, Records, Record>(
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

typedef $RecordsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Records,
      Record,
      $RecordsFilterComposer,
      $RecordsOrderingComposer,
      $RecordsAnnotationComposer,
      $RecordsCreateCompanionBuilder,
      $RecordsUpdateCompanionBuilder,
      (Record, BaseReferences<_$JiabuDatabase, Records, Record>),
      Record,
      PrefetchHooks Function()
    >;
typedef $SubjectsCreateCompanionBuilder = SubjectsCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> kind,
  Value<String?> name,
  Value<String?> memberId,
  Value<String?> archivedAt,
  Value<String?> deletedAt,
  Value<String?> createdByMemberId,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});
typedef $SubjectsUpdateCompanionBuilder = SubjectsCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> kind,
  Value<String?> name,
  Value<String?> memberId,
  Value<String?> archivedAt,
  Value<String?> deletedAt,
  Value<String?> createdByMemberId,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});

class $SubjectsFilterComposer extends Composer<_$JiabuDatabase, Subjects> {
  $SubjectsFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $SubjectsOrderingComposer extends Composer<_$JiabuDatabase, Subjects> {
  $SubjectsOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SubjectsAnnotationComposer extends Composer<_$JiabuDatabase, Subjects> {
  $SubjectsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $SubjectsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Subjects,
          Subject,
          $SubjectsFilterComposer,
          $SubjectsOrderingComposer,
          $SubjectsAnnotationComposer,
          $SubjectsCreateCompanionBuilder,
          $SubjectsUpdateCompanionBuilder,
          (Subject, BaseReferences<_$JiabuDatabase, Subjects, Subject>),
          Subject,
          PrefetchHooks Function()
        > {
  $SubjectsTableManager(_$JiabuDatabase db, Subjects table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SubjectsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SubjectsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SubjectsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                kind: kind,
                name: name,
                memberId: memberId,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                createdByMemberId: createdByMemberId,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                kind: kind,
                name: name,
                memberId: memberId,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                createdByMemberId: createdByMemberId,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Subjects, Subject>(table),
                  BaseReferences<_$JiabuDatabase, Subjects, Subject>(
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

typedef $SubjectsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Subjects,
      Subject,
      $SubjectsFilterComposer,
      $SubjectsOrderingComposer,
      $SubjectsAnnotationComposer,
      $SubjectsCreateCompanionBuilder,
      $SubjectsUpdateCompanionBuilder,
      (Subject, BaseReferences<_$JiabuDatabase, Subjects, Subject>),
      Subject,
      PrefetchHooks Function()
    >;
typedef $DocumentsCreateCompanionBuilder = DocumentsCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> templateId,
  Value<int?> templateVersion,
  Value<String?> title,
  Value<String?> eventDate,
  Value<String?> subjectIds,
  Value<String?> content,
  Value<String?> status,
  Value<String?> origin,
  Value<String?> runId,
  Value<String?> createdByMemberId,
  Value<String?> updatedByMemberId,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});
typedef $DocumentsUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<int?> baseVersion,
  Value<String> dataJson,
  Value<String?> module,
  Value<String?> visibility,
  Value<String?> templateId,
  Value<int?> templateVersion,
  Value<String?> title,
  Value<String?> eventDate,
  Value<String?> subjectIds,
  Value<String?> content,
  Value<String?> status,
  Value<String?> origin,
  Value<String?> runId,
  Value<String?> createdByMemberId,
  Value<String?> updatedByMemberId,
  Value<int?> version,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<int> rowid,
});

class $DocumentsFilterComposer extends Composer<_$JiabuDatabase, Documents> {
  $DocumentsFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectIds => $composableBuilder(
    column: $table.subjectIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedByMemberId => $composableBuilder(
    column: $table.updatedByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $DocumentsOrderingComposer extends Composer<_$JiabuDatabase, Documents> {
  $DocumentsOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectIds => $composableBuilder(
    column: $table.subjectIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedByMemberId => $composableBuilder(
    column: $table.updatedByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DocumentsAnnotationComposer
    extends Composer<_$JiabuDatabase, Documents> {
  $DocumentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<String> get subjectIds => $composableBuilder(
    column: $table.subjectIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get createdByMemberId => $composableBuilder(
    column: $table.createdByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedByMemberId => $composableBuilder(
    column: $table.updatedByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $DocumentsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Documents,
          Document,
          $DocumentsFilterComposer,
          $DocumentsOrderingComposer,
          $DocumentsAnnotationComposer,
          $DocumentsCreateCompanionBuilder,
          $DocumentsUpdateCompanionBuilder,
          (Document, BaseReferences<_$JiabuDatabase, Documents, Document>),
          Document,
          PrefetchHooks Function()
        > {
  $DocumentsTableManager(_$JiabuDatabase db, Documents table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DocumentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DocumentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DocumentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<int?> templateVersion = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> eventDate = const Value.absent(),
                Value<String?> subjectIds = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> updatedByMemberId = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                templateId: templateId,
                templateVersion: templateVersion,
                title: title,
                eventDate: eventDate,
                subjectIds: subjectIds,
                content: content,
                status: status,
                origin: origin,
                runId: runId,
                createdByMemberId: createdByMemberId,
                updatedByMemberId: updatedByMemberId,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<int?> templateVersion = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> eventDate = const Value.absent(),
                Value<String?> subjectIds = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String?> createdByMemberId = const Value.absent(),
                Value<String?> updatedByMemberId = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                baseVersion: baseVersion,
                dataJson: dataJson,
                module: module,
                visibility: visibility,
                templateId: templateId,
                templateVersion: templateVersion,
                title: title,
                eventDate: eventDate,
                subjectIds: subjectIds,
                content: content,
                status: status,
                origin: origin,
                runId: runId,
                createdByMemberId: createdByMemberId,
                updatedByMemberId: updatedByMemberId,
                version: version,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Documents, Document>(table),
                  BaseReferences<_$JiabuDatabase, Documents, Document>(
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

typedef $DocumentsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Documents,
      Document,
      $DocumentsFilterComposer,
      $DocumentsOrderingComposer,
      $DocumentsAnnotationComposer,
      $DocumentsCreateCompanionBuilder,
      $DocumentsUpdateCompanionBuilder,
      (Document, BaseReferences<_$JiabuDatabase, Documents, Document>),
      Document,
      PrefetchHooks Function()
    >;
typedef $EntityEventsCreateCompanionBuilder = EntityEventsCompanion Function({
  Value<int?> id,
  required String spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> entityKind,
  Value<String?> entityId,
  Value<String?> kind,
  Value<String?> before,
  Value<String?> after,
  Value<String?> actorMemberId,
  Value<String?> viaApiKeyId,
  Value<String?> viaApiKeyName,
  Value<String?> runId,
  Value<String?> requestId,
  Value<String?> at,
  Value<int?> changeSeq,
  Value<int> rowid,
});
typedef $EntityEventsUpdateCompanionBuilder = EntityEventsCompanion Function({
  Value<int?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> entityKind,
  Value<String?> entityId,
  Value<String?> kind,
  Value<String?> before,
  Value<String?> after,
  Value<String?> actorMemberId,
  Value<String?> viaApiKeyId,
  Value<String?> viaApiKeyName,
  Value<String?> runId,
  Value<String?> requestId,
  Value<String?> at,
  Value<int?> changeSeq,
  Value<int> rowid,
});

class $EntityEventsFilterComposer
    extends Composer<_$JiabuDatabase, EntityEvents> {
  $EntityEventsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorMemberId => $composableBuilder(
    column: $table.actorMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaApiKeyId => $composableBuilder(
    column: $table.viaApiKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaApiKeyName => $composableBuilder(
    column: $table.viaApiKeyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $EntityEventsOrderingComposer
    extends Composer<_$JiabuDatabase, EntityEvents> {
  $EntityEventsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorMemberId => $composableBuilder(
    column: $table.actorMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaApiKeyId => $composableBuilder(
    column: $table.viaApiKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaApiKeyName => $composableBuilder(
    column: $table.viaApiKeyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $EntityEventsAnnotationComposer
    extends Composer<_$JiabuDatabase, EntityEvents> {
  $EntityEventsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get before =>
      $composableBuilder(column: $table.before, builder: (column) => column);

  GeneratedColumn<String> get after =>
      $composableBuilder(column: $table.after, builder: (column) => column);

  GeneratedColumn<String> get actorMemberId => $composableBuilder(
    column: $table.actorMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaApiKeyId => $composableBuilder(
    column: $table.viaApiKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaApiKeyName => $composableBuilder(
    column: $table.viaApiKeyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);
}

class $EntityEventsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          EntityEvents,
          EntityEvent,
          $EntityEventsFilterComposer,
          $EntityEventsOrderingComposer,
          $EntityEventsAnnotationComposer,
          $EntityEventsCreateCompanionBuilder,
          $EntityEventsUpdateCompanionBuilder,
          (
            EntityEvent,
            BaseReferences<_$JiabuDatabase, EntityEvents, EntityEvent>,
          ),
          EntityEvent,
          PrefetchHooks Function()
        > {
  $EntityEventsTableManager(_$JiabuDatabase db, EntityEvents table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $EntityEventsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $EntityEventsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $EntityEventsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> entityKind = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> before = const Value.absent(),
                Value<String?> after = const Value.absent(),
                Value<String?> actorMemberId = const Value.absent(),
                Value<String?> viaApiKeyId = const Value.absent(),
                Value<String?> viaApiKeyName = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<String?> at = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntityEventsCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                entityKind: entityKind,
                entityId: entityId,
                kind: kind,
                before: before,
                after: after,
                actorMemberId: actorMemberId,
                viaApiKeyId: viaApiKeyId,
                viaApiKeyName: viaApiKeyName,
                runId: runId,
                requestId: requestId,
                at: at,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> entityKind = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> before = const Value.absent(),
                Value<String?> after = const Value.absent(),
                Value<String?> actorMemberId = const Value.absent(),
                Value<String?> viaApiKeyId = const Value.absent(),
                Value<String?> viaApiKeyName = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<String?> at = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntityEventsCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                entityKind: entityKind,
                entityId: entityId,
                kind: kind,
                before: before,
                after: after,
                actorMemberId: actorMemberId,
                viaApiKeyId: viaApiKeyId,
                viaApiKeyName: viaApiKeyName,
                runId: runId,
                requestId: requestId,
                at: at,
                changeSeq: changeSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<EntityEvents, EntityEvent>(table),
                  BaseReferences<_$JiabuDatabase, EntityEvents, EntityEvent>(
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

typedef $EntityEventsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      EntityEvents,
      EntityEvent,
      $EntityEventsFilterComposer,
      $EntityEventsOrderingComposer,
      $EntityEventsAnnotationComposer,
      $EntityEventsCreateCompanionBuilder,
      $EntityEventsUpdateCompanionBuilder,
      (EntityEvent, BaseReferences<_$JiabuDatabase, EntityEvents, EntityEvent>),
      EntityEvent,
      PrefetchHooks Function()
    >;
typedef $ConversationsCreateCompanionBuilder = ConversationsCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> memberId,
  Value<String?> createdAt,
  Value<int?> changeSeq,
  Value<String?> serverPayloadJson,
  Value<int> rowid,
});
typedef $ConversationsUpdateCompanionBuilder = ConversationsCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> memberId,
  Value<String?> createdAt,
  Value<int?> changeSeq,
  Value<String?> serverPayloadJson,
  Value<int> rowid,
});

class $ConversationsFilterComposer
    extends Composer<_$JiabuDatabase, Conversations> {
  $ConversationsFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverPayloadJson => $composableBuilder(
    column: $table.serverPayloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $ConversationsOrderingComposer
    extends Composer<_$JiabuDatabase, Conversations> {
  $ConversationsOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverPayloadJson => $composableBuilder(
    column: $table.serverPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ConversationsAnnotationComposer
    extends Composer<_$JiabuDatabase, Conversations> {
  $ConversationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get serverPayloadJson => $composableBuilder(
    column: $table.serverPayloadJson,
    builder: (column) => column,
  );
}

class $ConversationsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Conversations,
          Conversation,
          $ConversationsFilterComposer,
          $ConversationsOrderingComposer,
          $ConversationsAnnotationComposer,
          $ConversationsCreateCompanionBuilder,
          $ConversationsUpdateCompanionBuilder,
          (
            Conversation,
            BaseReferences<_$JiabuDatabase, Conversations, Conversation>,
          ),
          Conversation,
          PrefetchHooks Function()
        > {
  $ConversationsTableManager(_$JiabuDatabase db, Conversations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ConversationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ConversationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ConversationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> serverPayloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                memberId: memberId,
                createdAt: createdAt,
                changeSeq: changeSeq,
                serverPayloadJson: serverPayloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> serverPayloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                memberId: memberId,
                createdAt: createdAt,
                changeSeq: changeSeq,
                serverPayloadJson: serverPayloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Conversations, Conversation>(table),
                  BaseReferences<_$JiabuDatabase, Conversations, Conversation>(
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

typedef $ConversationsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Conversations,
      Conversation,
      $ConversationsFilterComposer,
      $ConversationsOrderingComposer,
      $ConversationsAnnotationComposer,
      $ConversationsCreateCompanionBuilder,
      $ConversationsUpdateCompanionBuilder,
      (
        Conversation,
        BaseReferences<_$JiabuDatabase, Conversations, Conversation>,
      ),
      Conversation,
      PrefetchHooks Function()
    >;
typedef $ChatEntriesCreateCompanionBuilder = ChatEntriesCompanion Function({
  Value<String?> id,
  required String spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> memberId,
  Value<String?> conversationId,
  Value<String?> role,
  Value<String?> replyToId,
  Value<String?> agentRunId,
  Value<String?> protocolVersion,
  Value<String?> fallbackText,
  Value<String?> streamStatus,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<String?> messageJson,
  Value<int> rev,
  Value<int> lastSeq,
  Value<int> authoritative,
  Value<String?> serverPayloadJson,
  Value<int> rowid,
});
typedef $ChatEntriesUpdateCompanionBuilder = ChatEntriesCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<String> syncState,
  Value<String> dataJson,
  Value<String?> memberId,
  Value<String?> conversationId,
  Value<String?> role,
  Value<String?> replyToId,
  Value<String?> agentRunId,
  Value<String?> protocolVersion,
  Value<String?> fallbackText,
  Value<String?> streamStatus,
  Value<int?> changeSeq,
  Value<String?> createdAt,
  Value<String?> updatedAt,
  Value<String?> messageJson,
  Value<int> rev,
  Value<int> lastSeq,
  Value<int> authoritative,
  Value<String?> serverPayloadJson,
  Value<int> rowid,
});

class $ChatEntriesFilterComposer
    extends Composer<_$JiabuDatabase, ChatEntries> {
  $ChatEntriesFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentRunId => $composableBuilder(
    column: $table.agentRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fallbackText => $composableBuilder(
    column: $table.fallbackText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamStatus => $composableBuilder(
    column: $table.streamStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageJson => $composableBuilder(
    column: $table.messageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authoritative => $composableBuilder(
    column: $table.authoritative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverPayloadJson => $composableBuilder(
    column: $table.serverPayloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $ChatEntriesOrderingComposer
    extends Composer<_$JiabuDatabase, ChatEntries> {
  $ChatEntriesOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentRunId => $composableBuilder(
    column: $table.agentRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fallbackText => $composableBuilder(
    column: $table.fallbackText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamStatus => $composableBuilder(
    column: $table.streamStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeSeq => $composableBuilder(
    column: $table.changeSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageJson => $composableBuilder(
    column: $table.messageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authoritative => $composableBuilder(
    column: $table.authoritative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverPayloadJson => $composableBuilder(
    column: $table.serverPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ChatEntriesAnnotationComposer
    extends Composer<_$JiabuDatabase, ChatEntries> {
  $ChatEntriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get agentRunId => $composableBuilder(
    column: $table.agentRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fallbackText => $composableBuilder(
    column: $table.fallbackText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamStatus => $composableBuilder(
    column: $table.streamStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get changeSeq =>
      $composableBuilder(column: $table.changeSeq, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get messageJson => $composableBuilder(
    column: $table.messageJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<int> get lastSeq =>
      $composableBuilder(column: $table.lastSeq, builder: (column) => column);

  GeneratedColumn<int> get authoritative => $composableBuilder(
    column: $table.authoritative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverPayloadJson => $composableBuilder(
    column: $table.serverPayloadJson,
    builder: (column) => column,
  );
}

class $ChatEntriesTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          ChatEntries,
          ChatEntry,
          $ChatEntriesFilterComposer,
          $ChatEntriesOrderingComposer,
          $ChatEntriesAnnotationComposer,
          $ChatEntriesCreateCompanionBuilder,
          $ChatEntriesUpdateCompanionBuilder,
          (ChatEntry, BaseReferences<_$JiabuDatabase, ChatEntries, ChatEntry>),
          ChatEntry,
          PrefetchHooks Function()
        > {
  $ChatEntriesTableManager(_$JiabuDatabase db, ChatEntries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ChatEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ChatEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ChatEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> agentRunId = const Value.absent(),
                Value<String?> protocolVersion = const Value.absent(),
                Value<String?> fallbackText = const Value.absent(),
                Value<String?> streamStatus = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> messageJson = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<int> lastSeq = const Value.absent(),
                Value<int> authoritative = const Value.absent(),
                Value<String?> serverPayloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatEntriesCompanion(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                memberId: memberId,
                conversationId: conversationId,
                role: role,
                replyToId: replyToId,
                agentRunId: agentRunId,
                protocolVersion: protocolVersion,
                fallbackText: fallbackText,
                streamStatus: streamStatus,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                messageJson: messageJson,
                rev: rev,
                lastSeq: lastSeq,
                authoritative: authoritative,
                serverPayloadJson: serverPayloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                Value<String> syncState = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> agentRunId = const Value.absent(),
                Value<String?> protocolVersion = const Value.absent(),
                Value<String?> fallbackText = const Value.absent(),
                Value<String?> streamStatus = const Value.absent(),
                Value<int?> changeSeq = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> messageJson = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<int> lastSeq = const Value.absent(),
                Value<int> authoritative = const Value.absent(),
                Value<String?> serverPayloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatEntriesCompanion.insert(
                id: id,
                spaceId: spaceId,
                syncState: syncState,
                dataJson: dataJson,
                memberId: memberId,
                conversationId: conversationId,
                role: role,
                replyToId: replyToId,
                agentRunId: agentRunId,
                protocolVersion: protocolVersion,
                fallbackText: fallbackText,
                streamStatus: streamStatus,
                changeSeq: changeSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                messageJson: messageJson,
                rev: rev,
                lastSeq: lastSeq,
                authoritative: authoritative,
                serverPayloadJson: serverPayloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ChatEntries, ChatEntry>(table),
                  BaseReferences<_$JiabuDatabase, ChatEntries, ChatEntry>(
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

typedef $ChatEntriesProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      ChatEntries,
      ChatEntry,
      $ChatEntriesFilterComposer,
      $ChatEntriesOrderingComposer,
      $ChatEntriesAnnotationComposer,
      $ChatEntriesCreateCompanionBuilder,
      $ChatEntriesUpdateCompanionBuilder,
      (ChatEntry, BaseReferences<_$JiabuDatabase, ChatEntries, ChatEntry>),
      ChatEntry,
      PrefetchHooks Function()
    >;
typedef $ChatClientStatesCreateCompanionBuilder =
    ChatClientStatesCompanion Function({
      required String spaceId,
      required String messageId,
      Value<String> stateJson,
      Value<int> rowid,
    });
typedef $ChatClientStatesUpdateCompanionBuilder =
    ChatClientStatesCompanion Function({
      Value<String> spaceId,
      Value<String> messageId,
      Value<String> stateJson,
      Value<int> rowid,
    });

class $ChatClientStatesFilterComposer
    extends Composer<_$JiabuDatabase, ChatClientStates> {
  $ChatClientStatesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $ChatClientStatesOrderingComposer
    extends Composer<_$JiabuDatabase, ChatClientStates> {
  $ChatClientStatesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ChatClientStatesAnnotationComposer
    extends Composer<_$JiabuDatabase, ChatClientStates> {
  $ChatClientStatesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get stateJson =>
      $composableBuilder(column: $table.stateJson, builder: (column) => column);
}

class $ChatClientStatesTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          ChatClientStates,
          ChatClientState,
          $ChatClientStatesFilterComposer,
          $ChatClientStatesOrderingComposer,
          $ChatClientStatesAnnotationComposer,
          $ChatClientStatesCreateCompanionBuilder,
          $ChatClientStatesUpdateCompanionBuilder,
          (
            ChatClientState,
            BaseReferences<_$JiabuDatabase, ChatClientStates, ChatClientState>,
          ),
          ChatClientState,
          PrefetchHooks Function()
        > {
  $ChatClientStatesTableManager(_$JiabuDatabase db, ChatClientStates table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ChatClientStatesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ChatClientStatesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ChatClientStatesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> spaceId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> stateJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatClientStatesCompanion(
                spaceId: spaceId,
                messageId: messageId,
                stateJson: stateJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String spaceId,
                required String messageId,
                Value<String> stateJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatClientStatesCompanion.insert(
                spaceId: spaceId,
                messageId: messageId,
                stateJson: stateJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ChatClientStates, ChatClientState>(table),
                  BaseReferences<
                    _$JiabuDatabase,
                    ChatClientStates,
                    ChatClientState
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ChatClientStatesProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      ChatClientStates,
      ChatClientState,
      $ChatClientStatesFilterComposer,
      $ChatClientStatesOrderingComposer,
      $ChatClientStatesAnnotationComposer,
      $ChatClientStatesCreateCompanionBuilder,
      $ChatClientStatesUpdateCompanionBuilder,
      (
        ChatClientState,
        BaseReferences<_$JiabuDatabase, ChatClientStates, ChatClientState>,
      ),
      ChatClientState,
      PrefetchHooks Function()
    >;
typedef $OutboxCreateCompanionBuilder = OutboxCompanion Function({
  Value<String?> id,
  required String spaceId,
  required int joinEpoch,
  required String kind,
  required String payloadJson,
  required String entityIds,
  required String dependsOn,
  required String requestId,
  required int createdAt,
  Value<int> attempts,
  Value<String> state,
  Value<String?> lastError,
  Value<int?> leaseUntil,
  Value<int> rowid,
});
typedef $OutboxUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String?> id,
  Value<String> spaceId,
  Value<int> joinEpoch,
  Value<String> kind,
  Value<String> payloadJson,
  Value<String> entityIds,
  Value<String> dependsOn,
  Value<String> requestId,
  Value<int> createdAt,
  Value<int> attempts,
  Value<String> state,
  Value<String?> lastError,
  Value<int?> leaseUntil,
  Value<int> rowid,
});

class $OutboxFilterComposer extends Composer<_$JiabuDatabase, Outbox> {
  $OutboxFilterComposer({
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

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get joinEpoch => $composableBuilder(
    column: $table.joinEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityIds => $composableBuilder(
    column: $table.entityIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $OutboxOrderingComposer extends Composer<_$JiabuDatabase, Outbox> {
  $OutboxOrderingComposer({
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

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get joinEpoch => $composableBuilder(
    column: $table.joinEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityIds => $composableBuilder(
    column: $table.entityIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $OutboxAnnotationComposer extends Composer<_$JiabuDatabase, Outbox> {
  $OutboxAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<int> get joinEpoch =>
      $composableBuilder(column: $table.joinEpoch, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityIds =>
      $composableBuilder(column: $table.entityIds, builder: (column) => column);

  GeneratedColumn<String> get dependsOn =>
      $composableBuilder(column: $table.dependsOn, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );
}

class $OutboxTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          Outbox,
          OutboxData,
          $OutboxFilterComposer,
          $OutboxOrderingComposer,
          $OutboxAnnotationComposer,
          $OutboxCreateCompanionBuilder,
          $OutboxUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$JiabuDatabase, Outbox, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $OutboxTableManager(_$JiabuDatabase db, Outbox table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $OutboxFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $OutboxOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $OutboxAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<int> joinEpoch = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> entityIds = const Value.absent(),
                Value<String> dependsOn = const Value.absent(),
                Value<String> requestId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                spaceId: spaceId,
                joinEpoch: joinEpoch,
                kind: kind,
                payloadJson: payloadJson,
                entityIds: entityIds,
                dependsOn: dependsOn,
                requestId: requestId,
                createdAt: createdAt,
                attempts: attempts,
                state: state,
                lastError: lastError,
                leaseUntil: leaseUntil,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> id = const Value.absent(),
                required String spaceId,
                required int joinEpoch,
                required String kind,
                required String payloadJson,
                required String entityIds,
                required String dependsOn,
                required String requestId,
                required int createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                spaceId: spaceId,
                joinEpoch: joinEpoch,
                kind: kind,
                payloadJson: payloadJson,
                entityIds: entityIds,
                dependsOn: dependsOn,
                requestId: requestId,
                createdAt: createdAt,
                attempts: attempts,
                state: state,
                lastError: lastError,
                leaseUntil: leaseUntil,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Outbox, OutboxData>(table),
                  BaseReferences<_$JiabuDatabase, Outbox, OutboxData>(
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

typedef $OutboxProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      Outbox,
      OutboxData,
      $OutboxFilterComposer,
      $OutboxOrderingComposer,
      $OutboxAnnotationComposer,
      $OutboxCreateCompanionBuilder,
      $OutboxUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$JiabuDatabase, Outbox, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $SyncCursorsCreateCompanionBuilder = SyncCursorsCompanion Function({
  Value<String?> spaceId,
  Value<int> cursor,
  Value<int> rowid,
});
typedef $SyncCursorsUpdateCompanionBuilder = SyncCursorsCompanion Function({
  Value<String?> spaceId,
  Value<int> cursor,
  Value<int> rowid,
});

class $SyncCursorsFilterComposer
    extends Composer<_$JiabuDatabase, SyncCursors> {
  $SyncCursorsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $SyncCursorsOrderingComposer
    extends Composer<_$JiabuDatabase, SyncCursors> {
  $SyncCursorsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SyncCursorsAnnotationComposer
    extends Composer<_$JiabuDatabase, SyncCursors> {
  $SyncCursorsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<int> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $SyncCursorsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          SyncCursors,
          SyncCursor,
          $SyncCursorsFilterComposer,
          $SyncCursorsOrderingComposer,
          $SyncCursorsAnnotationComposer,
          $SyncCursorsCreateCompanionBuilder,
          $SyncCursorsUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$JiabuDatabase, SyncCursors, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $SyncCursorsTableManager(_$JiabuDatabase db, SyncCursors table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SyncCursorsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SyncCursorsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SyncCursorsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> spaceId = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                spaceId: spaceId,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> spaceId = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                spaceId: spaceId,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncCursors, SyncCursor>(table),
                  BaseReferences<_$JiabuDatabase, SyncCursors, SyncCursor>(
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

typedef $SyncCursorsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      SyncCursors,
      SyncCursor,
      $SyncCursorsFilterComposer,
      $SyncCursorsOrderingComposer,
      $SyncCursorsAnnotationComposer,
      $SyncCursorsCreateCompanionBuilder,
      $SyncCursorsUpdateCompanionBuilder,
      (SyncCursor, BaseReferences<_$JiabuDatabase, SyncCursors, SyncCursor>),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $EntityConflictsCreateCompanionBuilder =
    EntityConflictsCompanion Function({
      required String spaceId,
      required String entityKind,
      required String entityId,
      required String mineJson,
      required int serverVersion,
      Value<String?> serverStatus,
      required int detectedAt,
      Value<int> rowid,
    });
typedef $EntityConflictsUpdateCompanionBuilder =
    EntityConflictsCompanion Function({
      Value<String> spaceId,
      Value<String> entityKind,
      Value<String> entityId,
      Value<String> mineJson,
      Value<int> serverVersion,
      Value<String?> serverStatus,
      Value<int> detectedAt,
      Value<int> rowid,
    });

class $EntityConflictsFilterComposer
    extends Composer<_$JiabuDatabase, EntityConflicts> {
  $EntityConflictsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mineJson => $composableBuilder(
    column: $table.mineJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverStatus => $composableBuilder(
    column: $table.serverStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $EntityConflictsOrderingComposer
    extends Composer<_$JiabuDatabase, EntityConflicts> {
  $EntityConflictsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mineJson => $composableBuilder(
    column: $table.mineJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverStatus => $composableBuilder(
    column: $table.serverStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $EntityConflictsAnnotationComposer
    extends Composer<_$JiabuDatabase, EntityConflicts> {
  $EntityConflictsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get mineJson =>
      $composableBuilder(column: $table.mineJson, builder: (column) => column);

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverStatus => $composableBuilder(
    column: $table.serverStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );
}

class $EntityConflictsTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          EntityConflicts,
          EntityConflict,
          $EntityConflictsFilterComposer,
          $EntityConflictsOrderingComposer,
          $EntityConflictsAnnotationComposer,
          $EntityConflictsCreateCompanionBuilder,
          $EntityConflictsUpdateCompanionBuilder,
          (
            EntityConflict,
            BaseReferences<_$JiabuDatabase, EntityConflicts, EntityConflict>,
          ),
          EntityConflict,
          PrefetchHooks Function()
        > {
  $EntityConflictsTableManager(_$JiabuDatabase db, EntityConflicts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $EntityConflictsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $EntityConflictsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $EntityConflictsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> spaceId = const Value.absent(),
                Value<String> entityKind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> mineJson = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<String?> serverStatus = const Value.absent(),
                Value<int> detectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntityConflictsCompanion(
                spaceId: spaceId,
                entityKind: entityKind,
                entityId: entityId,
                mineJson: mineJson,
                serverVersion: serverVersion,
                serverStatus: serverStatus,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String spaceId,
                required String entityKind,
                required String entityId,
                required String mineJson,
                required int serverVersion,
                Value<String?> serverStatus = const Value.absent(),
                required int detectedAt,
                Value<int> rowid = const Value.absent(),
              }) => EntityConflictsCompanion.insert(
                spaceId: spaceId,
                entityKind: entityKind,
                entityId: entityId,
                mineJson: mineJson,
                serverVersion: serverVersion,
                serverStatus: serverStatus,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<EntityConflicts, EntityConflict>(table),
                  BaseReferences<
                    _$JiabuDatabase,
                    EntityConflicts,
                    EntityConflict
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $EntityConflictsProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      EntityConflicts,
      EntityConflict,
      $EntityConflictsFilterComposer,
      $EntityConflictsOrderingComposer,
      $EntityConflictsAnnotationComposer,
      $EntityConflictsCreateCompanionBuilder,
      $EntityConflictsUpdateCompanionBuilder,
      (
        EntityConflict,
        BaseReferences<_$JiabuDatabase, EntityConflicts, EntityConflict>,
      ),
      EntityConflict,
      PrefetchHooks Function()
    >;
typedef $BlobsLocalCreateCompanionBuilder = BlobsLocalCompanion Function({
  required String spaceId,
  required String module,
  required String sha256,
  required String path,
  required int bytes,
  Value<int> uploaded,
  Value<int?> uploadedAt,
  Value<int> rowid,
});
typedef $BlobsLocalUpdateCompanionBuilder = BlobsLocalCompanion Function({
  Value<String> spaceId,
  Value<String> module,
  Value<String> sha256,
  Value<String> path,
  Value<int> bytes,
  Value<int> uploaded,
  Value<int?> uploadedAt,
  Value<int> rowid,
});

class $BlobsLocalFilterComposer extends Composer<_$JiabuDatabase, BlobsLocal> {
  $BlobsLocalFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $BlobsLocalOrderingComposer
    extends Composer<_$JiabuDatabase, BlobsLocal> {
  $BlobsLocalOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $BlobsLocalAnnotationComposer
    extends Composer<_$JiabuDatabase, BlobsLocal> {
  $BlobsLocalAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get uploaded =>
      $composableBuilder(column: $table.uploaded, builder: (column) => column);

  GeneratedColumn<int> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => column,
  );
}

class $BlobsLocalTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          BlobsLocal,
          BlobsLocalData,
          $BlobsLocalFilterComposer,
          $BlobsLocalOrderingComposer,
          $BlobsLocalAnnotationComposer,
          $BlobsLocalCreateCompanionBuilder,
          $BlobsLocalUpdateCompanionBuilder,
          (
            BlobsLocalData,
            BaseReferences<_$JiabuDatabase, BlobsLocal, BlobsLocalData>,
          ),
          BlobsLocalData,
          PrefetchHooks Function()
        > {
  $BlobsLocalTableManager(_$JiabuDatabase db, BlobsLocal table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $BlobsLocalFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $BlobsLocalOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $BlobsLocalAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> spaceId = const Value.absent(),
                Value<String> module = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int> uploaded = const Value.absent(),
                Value<int?> uploadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlobsLocalCompanion(
                spaceId: spaceId,
                module: module,
                sha256: sha256,
                path: path,
                bytes: bytes,
                uploaded: uploaded,
                uploadedAt: uploadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String spaceId,
                required String module,
                required String sha256,
                required String path,
                required int bytes,
                Value<int> uploaded = const Value.absent(),
                Value<int?> uploadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlobsLocalCompanion.insert(
                spaceId: spaceId,
                module: module,
                sha256: sha256,
                path: path,
                bytes: bytes,
                uploaded: uploaded,
                uploadedAt: uploadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<BlobsLocal, BlobsLocalData>(table),
                  BaseReferences<_$JiabuDatabase, BlobsLocal, BlobsLocalData>(
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

typedef $BlobsLocalProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      BlobsLocal,
      BlobsLocalData,
      $BlobsLocalFilterComposer,
      $BlobsLocalOrderingComposer,
      $BlobsLocalAnnotationComposer,
      $BlobsLocalCreateCompanionBuilder,
      $BlobsLocalUpdateCompanionBuilder,
      (
        BlobsLocalData,
        BaseReferences<_$JiabuDatabase, BlobsLocal, BlobsLocalData>,
      ),
      BlobsLocalData,
      PrefetchHooks Function()
    >;
typedef $SyncRuntimeCreateCompanionBuilder = SyncRuntimeCompanion Function({
  Value<int> id,
  Value<int> generation,
  Value<int> authenticated,
  Value<int> changeRevision,
  Value<String> noticesJson,
  Value<int> writeAllowed,
  Value<String?> identityJson,
  Value<String> sessionKind,
  Value<String> spaceIdsJson,
  Value<String?> roundOwner,
  Value<int?> roundLeaseUntil,
  Value<String> pendingDeletionsJson,
});
typedef $SyncRuntimeUpdateCompanionBuilder = SyncRuntimeCompanion Function({
  Value<int> id,
  Value<int> generation,
  Value<int> authenticated,
  Value<int> changeRevision,
  Value<String> noticesJson,
  Value<int> writeAllowed,
  Value<String?> identityJson,
  Value<String> sessionKind,
  Value<String> spaceIdsJson,
  Value<String?> roundOwner,
  Value<int?> roundLeaseUntil,
  Value<String> pendingDeletionsJson,
});

class $SyncRuntimeFilterComposer
    extends Composer<_$JiabuDatabase, SyncRuntime> {
  $SyncRuntimeFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authenticated => $composableBuilder(
    column: $table.authenticated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeRevision => $composableBuilder(
    column: $table.changeRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noticesJson => $composableBuilder(
    column: $table.noticesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get writeAllowed => $composableBuilder(
    column: $table.writeAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identityJson => $composableBuilder(
    column: $table.identityJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionKind => $composableBuilder(
    column: $table.sessionKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceIdsJson => $composableBuilder(
    column: $table.spaceIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roundOwner => $composableBuilder(
    column: $table.roundOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roundLeaseUntil => $composableBuilder(
    column: $table.roundLeaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingDeletionsJson => $composableBuilder(
    column: $table.pendingDeletionsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $SyncRuntimeOrderingComposer
    extends Composer<_$JiabuDatabase, SyncRuntime> {
  $SyncRuntimeOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authenticated => $composableBuilder(
    column: $table.authenticated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeRevision => $composableBuilder(
    column: $table.changeRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noticesJson => $composableBuilder(
    column: $table.noticesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get writeAllowed => $composableBuilder(
    column: $table.writeAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identityJson => $composableBuilder(
    column: $table.identityJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionKind => $composableBuilder(
    column: $table.sessionKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceIdsJson => $composableBuilder(
    column: $table.spaceIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roundOwner => $composableBuilder(
    column: $table.roundOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roundLeaseUntil => $composableBuilder(
    column: $table.roundLeaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingDeletionsJson => $composableBuilder(
    column: $table.pendingDeletionsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SyncRuntimeAnnotationComposer
    extends Composer<_$JiabuDatabase, SyncRuntime> {
  $SyncRuntimeAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get authenticated => $composableBuilder(
    column: $table.authenticated,
    builder: (column) => column,
  );

  GeneratedColumn<int> get changeRevision => $composableBuilder(
    column: $table.changeRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noticesJson => $composableBuilder(
    column: $table.noticesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get writeAllowed => $composableBuilder(
    column: $table.writeAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get identityJson => $composableBuilder(
    column: $table.identityJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionKind => $composableBuilder(
    column: $table.sessionKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get spaceIdsJson => $composableBuilder(
    column: $table.spaceIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roundOwner => $composableBuilder(
    column: $table.roundOwner,
    builder: (column) => column,
  );

  GeneratedColumn<int> get roundLeaseUntil => $composableBuilder(
    column: $table.roundLeaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingDeletionsJson => $composableBuilder(
    column: $table.pendingDeletionsJson,
    builder: (column) => column,
  );
}

class $SyncRuntimeTableManager
    extends
        RootTableManager<
          _$JiabuDatabase,
          SyncRuntime,
          SyncRuntimeData,
          $SyncRuntimeFilterComposer,
          $SyncRuntimeOrderingComposer,
          $SyncRuntimeAnnotationComposer,
          $SyncRuntimeCreateCompanionBuilder,
          $SyncRuntimeUpdateCompanionBuilder,
          (
            SyncRuntimeData,
            BaseReferences<_$JiabuDatabase, SyncRuntime, SyncRuntimeData>,
          ),
          SyncRuntimeData,
          PrefetchHooks Function()
        > {
  $SyncRuntimeTableManager(_$JiabuDatabase db, SyncRuntime table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SyncRuntimeFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SyncRuntimeOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SyncRuntimeAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> authenticated = const Value.absent(),
                Value<int> changeRevision = const Value.absent(),
                Value<String> noticesJson = const Value.absent(),
                Value<int> writeAllowed = const Value.absent(),
                Value<String?> identityJson = const Value.absent(),
                Value<String> sessionKind = const Value.absent(),
                Value<String> spaceIdsJson = const Value.absent(),
                Value<String?> roundOwner = const Value.absent(),
                Value<int?> roundLeaseUntil = const Value.absent(),
                Value<String> pendingDeletionsJson = const Value.absent(),
              }) => SyncRuntimeCompanion(
                id: id,
                generation: generation,
                authenticated: authenticated,
                changeRevision: changeRevision,
                noticesJson: noticesJson,
                writeAllowed: writeAllowed,
                identityJson: identityJson,
                sessionKind: sessionKind,
                spaceIdsJson: spaceIdsJson,
                roundOwner: roundOwner,
                roundLeaseUntil: roundLeaseUntil,
                pendingDeletionsJson: pendingDeletionsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> authenticated = const Value.absent(),
                Value<int> changeRevision = const Value.absent(),
                Value<String> noticesJson = const Value.absent(),
                Value<int> writeAllowed = const Value.absent(),
                Value<String?> identityJson = const Value.absent(),
                Value<String> sessionKind = const Value.absent(),
                Value<String> spaceIdsJson = const Value.absent(),
                Value<String?> roundOwner = const Value.absent(),
                Value<int?> roundLeaseUntil = const Value.absent(),
                Value<String> pendingDeletionsJson = const Value.absent(),
              }) => SyncRuntimeCompanion.insert(
                id: id,
                generation: generation,
                authenticated: authenticated,
                changeRevision: changeRevision,
                noticesJson: noticesJson,
                writeAllowed: writeAllowed,
                identityJson: identityJson,
                sessionKind: sessionKind,
                spaceIdsJson: spaceIdsJson,
                roundOwner: roundOwner,
                roundLeaseUntil: roundLeaseUntil,
                pendingDeletionsJson: pendingDeletionsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncRuntime, SyncRuntimeData>(table),
                  BaseReferences<_$JiabuDatabase, SyncRuntime, SyncRuntimeData>(
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

typedef $SyncRuntimeProcessedTableManager =
    ProcessedTableManager<
      _$JiabuDatabase,
      SyncRuntime,
      SyncRuntimeData,
      $SyncRuntimeFilterComposer,
      $SyncRuntimeOrderingComposer,
      $SyncRuntimeAnnotationComposer,
      $SyncRuntimeCreateCompanionBuilder,
      $SyncRuntimeUpdateCompanionBuilder,
      (
        SyncRuntimeData,
        BaseReferences<_$JiabuDatabase, SyncRuntime, SyncRuntimeData>,
      ),
      SyncRuntimeData,
      PrefetchHooks Function()
    >;

class $JiabuDatabaseManager {
  final _$JiabuDatabase _db;
  $JiabuDatabaseManager(this._db);
  $SpacesTableManager get spaces => $SpacesTableManager(_db, _db.spaces);
  $SpaceMembersTableManager get spaceMembers =>
      $SpaceMembersTableManager(_db, _db.spaceMembers);
  $MemberGrantsTableManager get memberGrants =>
      $MemberGrantsTableManager(_db, _db.memberGrants);
  $AccountsTableManager get accounts =>
      $AccountsTableManager(_db, _db.accounts);
  $AllocationPlansTableManager get allocationPlans =>
      $AllocationPlansTableManager(_db, _db.allocationPlans);
  $TagsTableManager get tags => $TagsTableManager(_db, _db.tags);
  $RecordsTableManager get records => $RecordsTableManager(_db, _db.records);
  $SubjectsTableManager get subjects =>
      $SubjectsTableManager(_db, _db.subjects);
  $DocumentsTableManager get documents =>
      $DocumentsTableManager(_db, _db.documents);
  $EntityEventsTableManager get entityEvents =>
      $EntityEventsTableManager(_db, _db.entityEvents);
  $ConversationsTableManager get conversations =>
      $ConversationsTableManager(_db, _db.conversations);
  $ChatEntriesTableManager get chatEntries =>
      $ChatEntriesTableManager(_db, _db.chatEntries);
  $ChatClientStatesTableManager get chatClientStates =>
      $ChatClientStatesTableManager(_db, _db.chatClientStates);
  $OutboxTableManager get outbox => $OutboxTableManager(_db, _db.outbox);
  $SyncCursorsTableManager get syncCursors =>
      $SyncCursorsTableManager(_db, _db.syncCursors);
  $EntityConflictsTableManager get entityConflicts =>
      $EntityConflictsTableManager(_db, _db.entityConflicts);
  $BlobsLocalTableManager get blobsLocal =>
      $BlobsLocalTableManager(_db, _db.blobsLocal);
  $SyncRuntimeTableManager get syncRuntime =>
      $SyncRuntimeTableManager(_db, _db.syncRuntime);
}

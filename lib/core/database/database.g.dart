// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MilestonesTable extends Milestones
    with TableInfo<$MilestonesTable, Milestone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MilestonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MilestoneStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(MilestoneStatus.active.value),
      ).withConverter<MilestoneStatus>($MilestonesTable.$converterstatus);
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionPointsMeta = const VerificationMeta(
    'completionPoints',
  );
  @override
  late final GeneratedColumn<int> completionPoints = GeneratedColumn<int>(
    'completion_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    description,
    status,
    colorIndex,
    targetDate,
    completionPoints,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'milestones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Milestone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('completion_points')) {
      context.handle(
        _completionPointsMeta,
        completionPoints.isAcceptableOrUnknown(
          data['completion_points']!,
          _completionPointsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Milestone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Milestone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      status: $MilestonesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
      completionPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_points'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $MilestonesTable createAlias(String alias) {
    return $MilestonesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MilestoneStatus, String, String> $converterstatus =
      const EnumNameConverter<MilestoneStatus>(MilestoneStatus.values);
}

class Milestone extends DataClass implements Insertable<Milestone> {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final MilestoneStatus status;
  final int colorIndex;
  final DateTime? targetDate;
  final int completionPoints;
  final DateTime createdAt;
  final DateTime? completedAt;
  const Milestone({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.status,
    required this.colorIndex,
    this.targetDate,
    required this.completionPoints,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['status'] = Variable<String>(
        $MilestonesTable.$converterstatus.toSql(status),
      );
    }
    map['color_index'] = Variable<int>(colorIndex);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['completion_points'] = Variable<int>(completionPoints);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  MilestonesCompanion toCompanion(bool nullToAbsent) {
    return MilestonesCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      colorIndex: Value(colorIndex),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      completionPoints: Value(completionPoints),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Milestone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Milestone(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      status: $MilestonesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      completionPoints: serializer.fromJson<int>(json['completionPoints']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(
        $MilestonesTable.$converterstatus.toJson(status),
      ),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'completionPoints': serializer.toJson<int>(completionPoints),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Milestone copyWith({
    String? id,
    String? userId,
    String? name,
    Value<String?> description = const Value.absent(),
    MilestoneStatus? status,
    int? colorIndex,
    Value<DateTime?> targetDate = const Value.absent(),
    int? completionPoints,
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Milestone(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    status: status ?? this.status,
    colorIndex: colorIndex ?? this.colorIndex,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    completionPoints: completionPoints ?? this.completionPoints,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Milestone copyWithCompanion(MilestonesCompanion data) {
    return Milestone(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      status: data.status.present ? data.status.value : this.status,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      completionPoints: data.completionPoints.present
          ? data.completionPoints.value
          : this.completionPoints,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Milestone(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('targetDate: $targetDate, ')
          ..write('completionPoints: $completionPoints, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    description,
    status,
    colorIndex,
    targetDate,
    completionPoints,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Milestone &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.description == this.description &&
          other.status == this.status &&
          other.colorIndex == this.colorIndex &&
          other.targetDate == this.targetDate &&
          other.completionPoints == this.completionPoints &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class MilestonesCompanion extends UpdateCompanion<Milestone> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<String?> description;
  final Value<MilestoneStatus> status;
  final Value<int> colorIndex;
  final Value<DateTime?> targetDate;
  final Value<int> completionPoints;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const MilestonesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.completionPoints = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MilestonesCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.completionPoints = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Milestone> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? status,
    Expression<int>? colorIndex,
    Expression<DateTime>? targetDate,
    Expression<int>? completionPoints,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (colorIndex != null) 'color_index': colorIndex,
      if (targetDate != null) 'target_date': targetDate,
      if (completionPoints != null) 'completion_points': completionPoints,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MilestonesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<String?>? description,
    Value<MilestoneStatus>? status,
    Value<int>? colorIndex,
    Value<DateTime?>? targetDate,
    Value<int>? completionPoints,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return MilestonesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      colorIndex: colorIndex ?? this.colorIndex,
      targetDate: targetDate ?? this.targetDate,
      completionPoints: completionPoints ?? this.completionPoints,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MilestonesTable.$converterstatus.toSql(status.value),
      );
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (completionPoints.present) {
      map['completion_points'] = Variable<int>(completionPoints.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MilestonesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('targetDate: $targetDate, ')
          ..write('completionPoints: $completionPoints, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _milestoneIdMeta = const VerificationMeta(
    'milestoneId',
  );
  @override
  late final GeneratedColumn<String> milestoneId = GeneratedColumn<String>(
    'milestone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES milestones (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsPerCompletionMeta =
      const VerificationMeta('pointsPerCompletion');
  @override
  late final GeneratedColumn<int> pointsPerCompletion = GeneratedColumn<int>(
    'points_per_completion',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskRecurrence, String>
  recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(TaskRecurrence.none.value),
  ).withConverter<TaskRecurrence>($TasksTable.$converterrecurrence);
  static const VerificationMeta _recurrenceConfigMeta = const VerificationMeta(
    'recurrenceConfig',
  );
  @override
  late final GeneratedColumn<String> recurrenceConfig = GeneratedColumn<String>(
    'recurrence_config',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(TaskStatus.active.value),
      ).withConverter<TaskStatus>($TasksTable.$converterstatus);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    milestoneId,
    name,
    description,
    pointsPerCompletion,
    recurrence,
    recurrenceConfig,
    dueDate,
    status,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('milestone_id')) {
      context.handle(
        _milestoneIdMeta,
        milestoneId.isAcceptableOrUnknown(
          data['milestone_id']!,
          _milestoneIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('points_per_completion')) {
      context.handle(
        _pointsPerCompletionMeta,
        pointsPerCompletion.isAcceptableOrUnknown(
          data['points_per_completion']!,
          _pointsPerCompletionMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_config')) {
      context.handle(
        _recurrenceConfigMeta,
        recurrenceConfig.isAcceptableOrUnknown(
          data['recurrence_config']!,
          _recurrenceConfigMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      milestoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}milestone_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      pointsPerCompletion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_per_completion'],
      )!,
      recurrence: $TasksTable.$converterrecurrence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}recurrence'],
        )!,
      ),
      recurrenceConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_config'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      status: $TasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaskRecurrence, String, String>
  $converterrecurrence = const EnumNameConverter<TaskRecurrence>(
    TaskRecurrence.values,
  );
  static JsonTypeConverter2<TaskStatus, String, String> $converterstatus =
      const EnumNameConverter<TaskStatus>(TaskStatus.values);
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String userId;
  final String? milestoneId;
  final String name;
  final String? description;
  final int pointsPerCompletion;
  final TaskRecurrence recurrence;
  final String? recurrenceConfig;
  final DateTime? dueDate;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  const Task({
    required this.id,
    required this.userId,
    this.milestoneId,
    required this.name,
    this.description,
    required this.pointsPerCompletion,
    required this.recurrence,
    this.recurrenceConfig,
    this.dueDate,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || milestoneId != null) {
      map['milestone_id'] = Variable<String>(milestoneId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['points_per_completion'] = Variable<int>(pointsPerCompletion);
    {
      map['recurrence'] = Variable<String>(
        $TasksTable.$converterrecurrence.toSql(recurrence),
      );
    }
    if (!nullToAbsent || recurrenceConfig != null) {
      map['recurrence_config'] = Variable<String>(recurrenceConfig);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    {
      map['status'] = Variable<String>(
        $TasksTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      userId: Value(userId),
      milestoneId: milestoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(milestoneId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      pointsPerCompletion: Value(pointsPerCompletion),
      recurrence: Value(recurrence),
      recurrenceConfig: recurrenceConfig == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceConfig),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      status: Value(status),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      milestoneId: serializer.fromJson<String?>(json['milestoneId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      pointsPerCompletion: serializer.fromJson<int>(
        json['pointsPerCompletion'],
      ),
      recurrence: $TasksTable.$converterrecurrence.fromJson(
        serializer.fromJson<String>(json['recurrence']),
      ),
      recurrenceConfig: serializer.fromJson<String?>(json['recurrenceConfig']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      status: $TasksTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'milestoneId': serializer.toJson<String?>(milestoneId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'pointsPerCompletion': serializer.toJson<int>(pointsPerCompletion),
      'recurrence': serializer.toJson<String>(
        $TasksTable.$converterrecurrence.toJson(recurrence),
      ),
      'recurrenceConfig': serializer.toJson<String?>(recurrenceConfig),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'status': serializer.toJson<String>(
        $TasksTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    Value<String?> milestoneId = const Value.absent(),
    String? name,
    Value<String?> description = const Value.absent(),
    int? pointsPerCompletion,
    TaskRecurrence? recurrence,
    Value<String?> recurrenceConfig = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    TaskStatus? status,
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Task(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    milestoneId: milestoneId.present ? milestoneId.value : this.milestoneId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    pointsPerCompletion: pointsPerCompletion ?? this.pointsPerCompletion,
    recurrence: recurrence ?? this.recurrence,
    recurrenceConfig: recurrenceConfig.present
        ? recurrenceConfig.value
        : this.recurrenceConfig,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      milestoneId: data.milestoneId.present
          ? data.milestoneId.value
          : this.milestoneId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      pointsPerCompletion: data.pointsPerCompletion.present
          ? data.pointsPerCompletion.value
          : this.pointsPerCompletion,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      recurrenceConfig: data.recurrenceConfig.present
          ? data.recurrenceConfig.value
          : this.recurrenceConfig,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('milestoneId: $milestoneId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('pointsPerCompletion: $pointsPerCompletion, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceConfig: $recurrenceConfig, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    milestoneId,
    name,
    description,
    pointsPerCompletion,
    recurrence,
    recurrenceConfig,
    dueDate,
    status,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.milestoneId == this.milestoneId &&
          other.name == this.name &&
          other.description == this.description &&
          other.pointsPerCompletion == this.pointsPerCompletion &&
          other.recurrence == this.recurrence &&
          other.recurrenceConfig == this.recurrenceConfig &&
          other.dueDate == this.dueDate &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> milestoneId;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> pointsPerCompletion;
  final Value<TaskRecurrence> recurrence;
  final Value<String?> recurrenceConfig;
  final Value<DateTime?> dueDate;
  final Value<TaskStatus> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.milestoneId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.pointsPerCompletion = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.recurrenceConfig = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.milestoneId = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.pointsPerCompletion = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.recurrenceConfig = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? milestoneId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? pointsPerCompletion,
    Expression<String>? recurrence,
    Expression<String>? recurrenceConfig,
    Expression<DateTime>? dueDate,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (milestoneId != null) 'milestone_id': milestoneId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (pointsPerCompletion != null)
        'points_per_completion': pointsPerCompletion,
      if (recurrence != null) 'recurrence': recurrence,
      if (recurrenceConfig != null) 'recurrence_config': recurrenceConfig,
      if (dueDate != null) 'due_date': dueDate,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? milestoneId,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? pointsPerCompletion,
    Value<TaskRecurrence>? recurrence,
    Value<String?>? recurrenceConfig,
    Value<DateTime?>? dueDate,
    Value<TaskStatus>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      milestoneId: milestoneId ?? this.milestoneId,
      name: name ?? this.name,
      description: description ?? this.description,
      pointsPerCompletion: pointsPerCompletion ?? this.pointsPerCompletion,
      recurrence: recurrence ?? this.recurrence,
      recurrenceConfig: recurrenceConfig ?? this.recurrenceConfig,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (milestoneId.present) {
      map['milestone_id'] = Variable<String>(milestoneId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (pointsPerCompletion.present) {
      map['points_per_completion'] = Variable<int>(pointsPerCompletion.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(
        $TasksTable.$converterrecurrence.toSql(recurrence.value),
      );
    }
    if (recurrenceConfig.present) {
      map['recurrence_config'] = Variable<String>(recurrenceConfig.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('milestoneId: $milestoneId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('pointsPerCompletion: $pointsPerCompletion, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceConfig: $recurrenceConfig, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskCompletionsTable extends TaskCompletions
    with TableInfo<$TaskCompletionsTable, TaskCompletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _completedOnMeta = const VerificationMeta(
    'completedOn',
  );
  @override
  late final GeneratedColumn<DateTime> completedOn = GeneratedColumn<DateTime>(
    'completed_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsEarnedMeta = const VerificationMeta(
    'pointsEarned',
  );
  @override
  late final GeneratedColumn<int> pointsEarned = GeneratedColumn<int>(
    'points_earned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isSkipMeta = const VerificationMeta('isSkip');
  @override
  late final GeneratedColumn<bool> isSkip = GeneratedColumn<bool>(
    'is_skip',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_skip" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isNdMeta = const VerificationMeta('isNd');
  @override
  late final GeneratedColumn<bool> isNd = GeneratedColumn<bool>(
    'is_nd',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_nd" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    userId,
    completedOn,
    pointsEarned,
    isSkip,
    isNd,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskCompletion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('completed_on')) {
      context.handle(
        _completedOnMeta,
        completedOn.isAcceptableOrUnknown(
          data['completed_on']!,
          _completedOnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedOnMeta);
    }
    if (data.containsKey('points_earned')) {
      context.handle(
        _pointsEarnedMeta,
        pointsEarned.isAcceptableOrUnknown(
          data['points_earned']!,
          _pointsEarnedMeta,
        ),
      );
    }
    if (data.containsKey('is_skip')) {
      context.handle(
        _isSkipMeta,
        isSkip.isAcceptableOrUnknown(data['is_skip']!, _isSkipMeta),
      );
    }
    if (data.containsKey('is_nd')) {
      context.handle(
        _isNdMeta,
        isNd.isAcceptableOrUnknown(data['is_nd']!, _isNdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskCompletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskCompletion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      completedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_on'],
      )!,
      pointsEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_earned'],
      )!,
      isSkip: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_skip'],
      )!,
      isNd: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_nd'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TaskCompletionsTable createAlias(String alias) {
    return $TaskCompletionsTable(attachedDatabase, alias);
  }
}

class TaskCompletion extends DataClass implements Insertable<TaskCompletion> {
  final String id;
  final String taskId;
  final String userId;
  final DateTime completedOn;
  final int pointsEarned;
  final bool isSkip;
  final bool isNd;
  final String? note;
  final DateTime createdAt;
  const TaskCompletion({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.completedOn,
    required this.pointsEarned,
    required this.isSkip,
    required this.isNd,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['user_id'] = Variable<String>(userId);
    map['completed_on'] = Variable<DateTime>(completedOn);
    map['points_earned'] = Variable<int>(pointsEarned);
    map['is_skip'] = Variable<bool>(isSkip);
    map['is_nd'] = Variable<bool>(isNd);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TaskCompletionsCompanion toCompanion(bool nullToAbsent) {
    return TaskCompletionsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      userId: Value(userId),
      completedOn: Value(completedOn),
      pointsEarned: Value(pointsEarned),
      isSkip: Value(isSkip),
      isNd: Value(isNd),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory TaskCompletion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskCompletion(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      userId: serializer.fromJson<String>(json['userId']),
      completedOn: serializer.fromJson<DateTime>(json['completedOn']),
      pointsEarned: serializer.fromJson<int>(json['pointsEarned']),
      isSkip: serializer.fromJson<bool>(json['isSkip']),
      isNd: serializer.fromJson<bool>(json['isNd']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'userId': serializer.toJson<String>(userId),
      'completedOn': serializer.toJson<DateTime>(completedOn),
      'pointsEarned': serializer.toJson<int>(pointsEarned),
      'isSkip': serializer.toJson<bool>(isSkip),
      'isNd': serializer.toJson<bool>(isNd),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TaskCompletion copyWith({
    String? id,
    String? taskId,
    String? userId,
    DateTime? completedOn,
    int? pointsEarned,
    bool? isSkip,
    bool? isNd,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => TaskCompletion(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    userId: userId ?? this.userId,
    completedOn: completedOn ?? this.completedOn,
    pointsEarned: pointsEarned ?? this.pointsEarned,
    isSkip: isSkip ?? this.isSkip,
    isNd: isNd ?? this.isNd,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  TaskCompletion copyWithCompanion(TaskCompletionsCompanion data) {
    return TaskCompletion(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      userId: data.userId.present ? data.userId.value : this.userId,
      completedOn: data.completedOn.present
          ? data.completedOn.value
          : this.completedOn,
      pointsEarned: data.pointsEarned.present
          ? data.pointsEarned.value
          : this.pointsEarned,
      isSkip: data.isSkip.present ? data.isSkip.value : this.isSkip,
      isNd: data.isNd.present ? data.isNd.value : this.isNd,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskCompletion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('userId: $userId, ')
          ..write('completedOn: $completedOn, ')
          ..write('pointsEarned: $pointsEarned, ')
          ..write('isSkip: $isSkip, ')
          ..write('isNd: $isNd, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    userId,
    completedOn,
    pointsEarned,
    isSkip,
    isNd,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskCompletion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.userId == this.userId &&
          other.completedOn == this.completedOn &&
          other.pointsEarned == this.pointsEarned &&
          other.isSkip == this.isSkip &&
          other.isNd == this.isNd &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class TaskCompletionsCompanion extends UpdateCompanion<TaskCompletion> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> userId;
  final Value<DateTime> completedOn;
  final Value<int> pointsEarned;
  final Value<bool> isSkip;
  final Value<bool> isNd;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TaskCompletionsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.userId = const Value.absent(),
    this.completedOn = const Value.absent(),
    this.pointsEarned = const Value.absent(),
    this.isSkip = const Value.absent(),
    this.isNd = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskCompletionsCompanion.insert({
    required String id,
    required String taskId,
    this.userId = const Value.absent(),
    required DateTime completedOn,
    this.pointsEarned = const Value.absent(),
    this.isSkip = const Value.absent(),
    this.isNd = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       completedOn = Value(completedOn);
  static Insertable<TaskCompletion> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? userId,
    Expression<DateTime>? completedOn,
    Expression<int>? pointsEarned,
    Expression<bool>? isSkip,
    Expression<bool>? isNd,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (userId != null) 'user_id': userId,
      if (completedOn != null) 'completed_on': completedOn,
      if (pointsEarned != null) 'points_earned': pointsEarned,
      if (isSkip != null) 'is_skip': isSkip,
      if (isNd != null) 'is_nd': isNd,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskCompletionsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? userId,
    Value<DateTime>? completedOn,
    Value<int>? pointsEarned,
    Value<bool>? isSkip,
    Value<bool>? isNd,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TaskCompletionsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      completedOn: completedOn ?? this.completedOn,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      isSkip: isSkip ?? this.isSkip,
      isNd: isNd ?? this.isNd,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (completedOn.present) {
      map['completed_on'] = Variable<DateTime>(completedOn.value);
    }
    if (pointsEarned.present) {
      map['points_earned'] = Variable<int>(pointsEarned.value);
    }
    if (isSkip.present) {
      map['is_skip'] = Variable<bool>(isSkip.value);
    }
    if (isNd.present) {
      map['is_nd'] = Variable<bool>(isNd.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskCompletionsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('userId: $userId, ')
          ..write('completedOn: $completedOn, ')
          ..write('pointsEarned: $pointsEarned, ')
          ..write('isSkip: $isSkip, ')
          ..write('isNd: $isNd, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PointsHistoryTableTable extends PointsHistoryTable
    with TableInfo<$PointsHistoryTableTable, PointsHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointsHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskCompletionIdMeta = const VerificationMeta(
    'taskCompletionId',
  );
  @override
  late final GeneratedColumn<String> taskCompletionId = GeneratedColumn<String>(
    'task_completion_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_completions (id)',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id)',
    ),
  );
  static const VerificationMeta _milestoneIdMeta = const VerificationMeta(
    'milestoneId',
  );
  @override
  late final GeneratedColumn<String> milestoneId = GeneratedColumn<String>(
    'milestone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PointsReason, String> reason =
      GeneratedColumn<String>(
        'reason',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PointsReason>($PointsHistoryTableTable.$converterreason);
  static const VerificationMeta _earnedAtMeta = const VerificationMeta(
    'earnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> earnedAt = GeneratedColumn<DateTime>(
    'earned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskCompletionId,
    taskId,
    milestoneId,
    points,
    reason,
    earnedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'points_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PointsHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_completion_id')) {
      context.handle(
        _taskCompletionIdMeta,
        taskCompletionId.isAcceptableOrUnknown(
          data['task_completion_id']!,
          _taskCompletionIdMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('milestone_id')) {
      context.handle(
        _milestoneIdMeta,
        milestoneId.isAcceptableOrUnknown(
          data['milestone_id']!,
          _milestoneIdMeta,
        ),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsMeta);
    }
    if (data.containsKey('earned_at')) {
      context.handle(
        _earnedAtMeta,
        earnedAt.isAcceptableOrUnknown(data['earned_at']!, _earnedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PointsHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PointsHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskCompletionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_completion_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      milestoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}milestone_id'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
      reason: $PointsHistoryTableTable.$converterreason.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reason'],
        )!,
      ),
      earnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}earned_at'],
      )!,
    );
  }

  @override
  $PointsHistoryTableTable createAlias(String alias) {
    return $PointsHistoryTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PointsReason, String, String> $converterreason =
      const EnumNameConverter<PointsReason>(PointsReason.values);
}

class PointsHistory extends DataClass implements Insertable<PointsHistory> {
  final String id;
  final String? taskCompletionId;
  final String? taskId;
  final String? milestoneId;
  final int points;
  final PointsReason reason;
  final DateTime earnedAt;
  const PointsHistory({
    required this.id,
    this.taskCompletionId,
    this.taskId,
    this.milestoneId,
    required this.points,
    required this.reason,
    required this.earnedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || taskCompletionId != null) {
      map['task_completion_id'] = Variable<String>(taskCompletionId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || milestoneId != null) {
      map['milestone_id'] = Variable<String>(milestoneId);
    }
    map['points'] = Variable<int>(points);
    {
      map['reason'] = Variable<String>(
        $PointsHistoryTableTable.$converterreason.toSql(reason),
      );
    }
    map['earned_at'] = Variable<DateTime>(earnedAt);
    return map;
  }

  PointsHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return PointsHistoryTableCompanion(
      id: Value(id),
      taskCompletionId: taskCompletionId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskCompletionId),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      milestoneId: milestoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(milestoneId),
      points: Value(points),
      reason: Value(reason),
      earnedAt: Value(earnedAt),
    );
  }

  factory PointsHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PointsHistory(
      id: serializer.fromJson<String>(json['id']),
      taskCompletionId: serializer.fromJson<String?>(json['taskCompletionId']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      milestoneId: serializer.fromJson<String?>(json['milestoneId']),
      points: serializer.fromJson<int>(json['points']),
      reason: $PointsHistoryTableTable.$converterreason.fromJson(
        serializer.fromJson<String>(json['reason']),
      ),
      earnedAt: serializer.fromJson<DateTime>(json['earnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskCompletionId': serializer.toJson<String?>(taskCompletionId),
      'taskId': serializer.toJson<String?>(taskId),
      'milestoneId': serializer.toJson<String?>(milestoneId),
      'points': serializer.toJson<int>(points),
      'reason': serializer.toJson<String>(
        $PointsHistoryTableTable.$converterreason.toJson(reason),
      ),
      'earnedAt': serializer.toJson<DateTime>(earnedAt),
    };
  }

  PointsHistory copyWith({
    String? id,
    Value<String?> taskCompletionId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> milestoneId = const Value.absent(),
    int? points,
    PointsReason? reason,
    DateTime? earnedAt,
  }) => PointsHistory(
    id: id ?? this.id,
    taskCompletionId: taskCompletionId.present
        ? taskCompletionId.value
        : this.taskCompletionId,
    taskId: taskId.present ? taskId.value : this.taskId,
    milestoneId: milestoneId.present ? milestoneId.value : this.milestoneId,
    points: points ?? this.points,
    reason: reason ?? this.reason,
    earnedAt: earnedAt ?? this.earnedAt,
  );
  PointsHistory copyWithCompanion(PointsHistoryTableCompanion data) {
    return PointsHistory(
      id: data.id.present ? data.id.value : this.id,
      taskCompletionId: data.taskCompletionId.present
          ? data.taskCompletionId.value
          : this.taskCompletionId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      milestoneId: data.milestoneId.present
          ? data.milestoneId.value
          : this.milestoneId,
      points: data.points.present ? data.points.value : this.points,
      reason: data.reason.present ? data.reason.value : this.reason,
      earnedAt: data.earnedAt.present ? data.earnedAt.value : this.earnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PointsHistory(')
          ..write('id: $id, ')
          ..write('taskCompletionId: $taskCompletionId, ')
          ..write('taskId: $taskId, ')
          ..write('milestoneId: $milestoneId, ')
          ..write('points: $points, ')
          ..write('reason: $reason, ')
          ..write('earnedAt: $earnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskCompletionId,
    taskId,
    milestoneId,
    points,
    reason,
    earnedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PointsHistory &&
          other.id == this.id &&
          other.taskCompletionId == this.taskCompletionId &&
          other.taskId == this.taskId &&
          other.milestoneId == this.milestoneId &&
          other.points == this.points &&
          other.reason == this.reason &&
          other.earnedAt == this.earnedAt);
}

class PointsHistoryTableCompanion extends UpdateCompanion<PointsHistory> {
  final Value<String> id;
  final Value<String?> taskCompletionId;
  final Value<String?> taskId;
  final Value<String?> milestoneId;
  final Value<int> points;
  final Value<PointsReason> reason;
  final Value<DateTime> earnedAt;
  final Value<int> rowid;
  const PointsHistoryTableCompanion({
    this.id = const Value.absent(),
    this.taskCompletionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.milestoneId = const Value.absent(),
    this.points = const Value.absent(),
    this.reason = const Value.absent(),
    this.earnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PointsHistoryTableCompanion.insert({
    required String id,
    this.taskCompletionId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.milestoneId = const Value.absent(),
    required int points,
    required PointsReason reason,
    this.earnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       points = Value(points),
       reason = Value(reason);
  static Insertable<PointsHistory> custom({
    Expression<String>? id,
    Expression<String>? taskCompletionId,
    Expression<String>? taskId,
    Expression<String>? milestoneId,
    Expression<int>? points,
    Expression<String>? reason,
    Expression<DateTime>? earnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskCompletionId != null) 'task_completion_id': taskCompletionId,
      if (taskId != null) 'task_id': taskId,
      if (milestoneId != null) 'milestone_id': milestoneId,
      if (points != null) 'points': points,
      if (reason != null) 'reason': reason,
      if (earnedAt != null) 'earned_at': earnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PointsHistoryTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? taskCompletionId,
    Value<String?>? taskId,
    Value<String?>? milestoneId,
    Value<int>? points,
    Value<PointsReason>? reason,
    Value<DateTime>? earnedAt,
    Value<int>? rowid,
  }) {
    return PointsHistoryTableCompanion(
      id: id ?? this.id,
      taskCompletionId: taskCompletionId ?? this.taskCompletionId,
      taskId: taskId ?? this.taskId,
      milestoneId: milestoneId ?? this.milestoneId,
      points: points ?? this.points,
      reason: reason ?? this.reason,
      earnedAt: earnedAt ?? this.earnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskCompletionId.present) {
      map['task_completion_id'] = Variable<String>(taskCompletionId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (milestoneId.present) {
      map['milestone_id'] = Variable<String>(milestoneId.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(
        $PointsHistoryTableTable.$converterreason.toSql(reason.value),
      );
    }
    if (earnedAt.present) {
      map['earned_at'] = Variable<DateTime>(earnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointsHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('taskCompletionId: $taskCompletionId, ')
          ..write('taskId: $taskId, ')
          ..write('milestoneId: $milestoneId, ')
          ..write('points: $points, ')
          ..write('reason: $reason, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RewardsTable extends Rewards with TableInfo<$RewardsTable, Reward> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RewardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsThresholdMeta = const VerificationMeta(
    'pointsThreshold',
  );
  @override
  late final GeneratedColumn<int> pointsThreshold = GeneratedColumn<int>(
    'points_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isClaimedMeta = const VerificationMeta(
    'isClaimed',
  );
  @override
  late final GeneratedColumn<bool> isClaimed = GeneratedColumn<bool>(
    'is_claimed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_claimed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta(
    'claimedAt',
  );
  @override
  late final GeneratedColumn<DateTime> claimedAt = GeneratedColumn<DateTime>(
    'claimed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPublicMeta = const VerificationMeta(
    'isPublic',
  );
  @override
  late final GeneratedColumn<bool> isPublic = GeneratedColumn<bool>(
    'is_public',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_public" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    description,
    pointsThreshold,
    isClaimed,
    claimedAt,
    isPublic,
    publishedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rewards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reward> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('points_threshold')) {
      context.handle(
        _pointsThresholdMeta,
        pointsThreshold.isAcceptableOrUnknown(
          data['points_threshold']!,
          _pointsThresholdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pointsThresholdMeta);
    }
    if (data.containsKey('is_claimed')) {
      context.handle(
        _isClaimedMeta,
        isClaimed.isAcceptableOrUnknown(data['is_claimed']!, _isClaimedMeta),
      );
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    }
    if (data.containsKey('is_public')) {
      context.handle(
        _isPublicMeta,
        isPublic.isAcceptableOrUnknown(data['is_public']!, _isPublicMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reward map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reward(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      pointsThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_threshold'],
      )!,
      isClaimed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_claimed'],
      )!,
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}claimed_at'],
      ),
      isPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_public'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RewardsTable createAlias(String alias) {
    return $RewardsTable(attachedDatabase, alias);
  }
}

class Reward extends DataClass implements Insertable<Reward> {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int pointsThreshold;
  final bool isClaimed;
  final DateTime? claimedAt;
  final bool isPublic;
  final DateTime? publishedAt;
  final DateTime createdAt;
  const Reward({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.pointsThreshold,
    required this.isClaimed,
    this.claimedAt,
    required this.isPublic,
    this.publishedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['points_threshold'] = Variable<int>(pointsThreshold);
    map['is_claimed'] = Variable<bool>(isClaimed);
    if (!nullToAbsent || claimedAt != null) {
      map['claimed_at'] = Variable<DateTime>(claimedAt);
    }
    map['is_public'] = Variable<bool>(isPublic);
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RewardsCompanion toCompanion(bool nullToAbsent) {
    return RewardsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      pointsThreshold: Value(pointsThreshold),
      isClaimed: Value(isClaimed),
      claimedAt: claimedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(claimedAt),
      isPublic: Value(isPublic),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Reward.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reward(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      pointsThreshold: serializer.fromJson<int>(json['pointsThreshold']),
      isClaimed: serializer.fromJson<bool>(json['isClaimed']),
      claimedAt: serializer.fromJson<DateTime?>(json['claimedAt']),
      isPublic: serializer.fromJson<bool>(json['isPublic']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'pointsThreshold': serializer.toJson<int>(pointsThreshold),
      'isClaimed': serializer.toJson<bool>(isClaimed),
      'claimedAt': serializer.toJson<DateTime?>(claimedAt),
      'isPublic': serializer.toJson<bool>(isPublic),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Reward copyWith({
    String? id,
    String? userId,
    String? name,
    Value<String?> description = const Value.absent(),
    int? pointsThreshold,
    bool? isClaimed,
    Value<DateTime?> claimedAt = const Value.absent(),
    bool? isPublic,
    Value<DateTime?> publishedAt = const Value.absent(),
    DateTime? createdAt,
  }) => Reward(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    pointsThreshold: pointsThreshold ?? this.pointsThreshold,
    isClaimed: isClaimed ?? this.isClaimed,
    claimedAt: claimedAt.present ? claimedAt.value : this.claimedAt,
    isPublic: isPublic ?? this.isPublic,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Reward copyWithCompanion(RewardsCompanion data) {
    return Reward(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      pointsThreshold: data.pointsThreshold.present
          ? data.pointsThreshold.value
          : this.pointsThreshold,
      isClaimed: data.isClaimed.present ? data.isClaimed.value : this.isClaimed,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
      isPublic: data.isPublic.present ? data.isPublic.value : this.isPublic,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reward(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('pointsThreshold: $pointsThreshold, ')
          ..write('isClaimed: $isClaimed, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('isPublic: $isPublic, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    description,
    pointsThreshold,
    isClaimed,
    claimedAt,
    isPublic,
    publishedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reward &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.description == this.description &&
          other.pointsThreshold == this.pointsThreshold &&
          other.isClaimed == this.isClaimed &&
          other.claimedAt == this.claimedAt &&
          other.isPublic == this.isPublic &&
          other.publishedAt == this.publishedAt &&
          other.createdAt == this.createdAt);
}

class RewardsCompanion extends UpdateCompanion<Reward> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> pointsThreshold;
  final Value<bool> isClaimed;
  final Value<DateTime?> claimedAt;
  final Value<bool> isPublic;
  final Value<DateTime?> publishedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RewardsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.pointsThreshold = const Value.absent(),
    this.isClaimed = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RewardsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required int pointsThreshold,
    this.isClaimed = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       pointsThreshold = Value(pointsThreshold);
  static Insertable<Reward> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? pointsThreshold,
    Expression<bool>? isClaimed,
    Expression<DateTime>? claimedAt,
    Expression<bool>? isPublic,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (pointsThreshold != null) 'points_threshold': pointsThreshold,
      if (isClaimed != null) 'is_claimed': isClaimed,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (isPublic != null) 'is_public': isPublic,
      if (publishedAt != null) 'published_at': publishedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RewardsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? pointsThreshold,
    Value<bool>? isClaimed,
    Value<DateTime?>? claimedAt,
    Value<bool>? isPublic,
    Value<DateTime?>? publishedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RewardsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      pointsThreshold: pointsThreshold ?? this.pointsThreshold,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedAt: claimedAt ?? this.claimedAt,
      isPublic: isPublic ?? this.isPublic,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (pointsThreshold.present) {
      map['points_threshold'] = Variable<int>(pointsThreshold.value);
    }
    if (isClaimed.present) {
      map['is_claimed'] = Variable<bool>(isClaimed.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<DateTime>(claimedAt.value);
    }
    if (isPublic.present) {
      map['is_public'] = Variable<bool>(isPublic.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RewardsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('pointsThreshold: $pointsThreshold, ')
          ..write('isClaimed: $isClaimed, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('isPublic: $isPublic, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreakTableTable extends StreakTable
    with TableInfo<$StreakTableTable, Streak> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestStreakMeta = const VerificationMeta(
    'longestStreak',
  );
  @override
  late final GeneratedColumn<int> longestStreak = GeneratedColumn<int>(
    'longest_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastLoggedDateMeta = const VerificationMeta(
    'lastLoggedDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastLoggedDate =
      GeneratedColumn<DateTime>(
        'last_logged_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMilestoneCelebratedMeta =
      const VerificationMeta('lastMilestoneCelebrated');
  @override
  late final GeneratedColumn<int> lastMilestoneCelebrated =
      GeneratedColumn<int>(
        'last_milestone_celebrated',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currentStreak,
    longestStreak,
    lastLoggedDate,
    lastMilestoneCelebrated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak';
  @override
  VerificationContext validateIntegrity(
    Insertable<Streak> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
      );
    }
    if (data.containsKey('longest_streak')) {
      context.handle(
        _longestStreakMeta,
        longestStreak.isAcceptableOrUnknown(
          data['longest_streak']!,
          _longestStreakMeta,
        ),
      );
    }
    if (data.containsKey('last_logged_date')) {
      context.handle(
        _lastLoggedDateMeta,
        lastLoggedDate.isAcceptableOrUnknown(
          data['last_logged_date']!,
          _lastLoggedDateMeta,
        ),
      );
    }
    if (data.containsKey('last_milestone_celebrated')) {
      context.handle(
        _lastMilestoneCelebratedMeta,
        lastMilestoneCelebrated.isAcceptableOrUnknown(
          data['last_milestone_celebrated']!,
          _lastMilestoneCelebratedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Streak map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Streak(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_streak'],
      )!,
      longestStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest_streak'],
      )!,
      lastLoggedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_logged_date'],
      ),
      lastMilestoneCelebrated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_milestone_celebrated'],
      )!,
    );
  }

  @override
  $StreakTableTable createAlias(String alias) {
    return $StreakTableTable(attachedDatabase, alias);
  }
}

class Streak extends DataClass implements Insertable<Streak> {
  final int id;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoggedDate;
  final int lastMilestoneCelebrated;
  const Streak({
    required this.id,
    required this.currentStreak,
    required this.longestStreak,
    this.lastLoggedDate,
    required this.lastMilestoneCelebrated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_streak'] = Variable<int>(currentStreak);
    map['longest_streak'] = Variable<int>(longestStreak);
    if (!nullToAbsent || lastLoggedDate != null) {
      map['last_logged_date'] = Variable<DateTime>(lastLoggedDate);
    }
    map['last_milestone_celebrated'] = Variable<int>(lastMilestoneCelebrated);
    return map;
  }

  StreakTableCompanion toCompanion(bool nullToAbsent) {
    return StreakTableCompanion(
      id: Value(id),
      currentStreak: Value(currentStreak),
      longestStreak: Value(longestStreak),
      lastLoggedDate: lastLoggedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLoggedDate),
      lastMilestoneCelebrated: Value(lastMilestoneCelebrated),
    );
  }

  factory Streak.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Streak(
      id: serializer.fromJson<int>(json['id']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      longestStreak: serializer.fromJson<int>(json['longestStreak']),
      lastLoggedDate: serializer.fromJson<DateTime?>(json['lastLoggedDate']),
      lastMilestoneCelebrated: serializer.fromJson<int>(
        json['lastMilestoneCelebrated'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'longestStreak': serializer.toJson<int>(longestStreak),
      'lastLoggedDate': serializer.toJson<DateTime?>(lastLoggedDate),
      'lastMilestoneCelebrated': serializer.toJson<int>(
        lastMilestoneCelebrated,
      ),
    };
  }

  Streak copyWith({
    int? id,
    int? currentStreak,
    int? longestStreak,
    Value<DateTime?> lastLoggedDate = const Value.absent(),
    int? lastMilestoneCelebrated,
  }) => Streak(
    id: id ?? this.id,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastLoggedDate: lastLoggedDate.present
        ? lastLoggedDate.value
        : this.lastLoggedDate,
    lastMilestoneCelebrated:
        lastMilestoneCelebrated ?? this.lastMilestoneCelebrated,
  );
  Streak copyWithCompanion(StreakTableCompanion data) {
    return Streak(
      id: data.id.present ? data.id.value : this.id,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      longestStreak: data.longestStreak.present
          ? data.longestStreak.value
          : this.longestStreak,
      lastLoggedDate: data.lastLoggedDate.present
          ? data.lastLoggedDate.value
          : this.lastLoggedDate,
      lastMilestoneCelebrated: data.lastMilestoneCelebrated.present
          ? data.lastMilestoneCelebrated.value
          : this.lastMilestoneCelebrated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Streak(')
          ..write('id: $id, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('lastLoggedDate: $lastLoggedDate, ')
          ..write('lastMilestoneCelebrated: $lastMilestoneCelebrated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    currentStreak,
    longestStreak,
    lastLoggedDate,
    lastMilestoneCelebrated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Streak &&
          other.id == this.id &&
          other.currentStreak == this.currentStreak &&
          other.longestStreak == this.longestStreak &&
          other.lastLoggedDate == this.lastLoggedDate &&
          other.lastMilestoneCelebrated == this.lastMilestoneCelebrated);
}

class StreakTableCompanion extends UpdateCompanion<Streak> {
  final Value<int> id;
  final Value<int> currentStreak;
  final Value<int> longestStreak;
  final Value<DateTime?> lastLoggedDate;
  final Value<int> lastMilestoneCelebrated;
  const StreakTableCompanion({
    this.id = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.lastLoggedDate = const Value.absent(),
    this.lastMilestoneCelebrated = const Value.absent(),
  });
  StreakTableCompanion.insert({
    this.id = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.lastLoggedDate = const Value.absent(),
    this.lastMilestoneCelebrated = const Value.absent(),
  });
  static Insertable<Streak> custom({
    Expression<int>? id,
    Expression<int>? currentStreak,
    Expression<int>? longestStreak,
    Expression<DateTime>? lastLoggedDate,
    Expression<int>? lastMilestoneCelebrated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (longestStreak != null) 'longest_streak': longestStreak,
      if (lastLoggedDate != null) 'last_logged_date': lastLoggedDate,
      if (lastMilestoneCelebrated != null)
        'last_milestone_celebrated': lastMilestoneCelebrated,
    });
  }

  StreakTableCompanion copyWith({
    Value<int>? id,
    Value<int>? currentStreak,
    Value<int>? longestStreak,
    Value<DateTime?>? lastLoggedDate,
    Value<int>? lastMilestoneCelebrated,
  }) {
    return StreakTableCompanion(
      id: id ?? this.id,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
      lastMilestoneCelebrated:
          lastMilestoneCelebrated ?? this.lastMilestoneCelebrated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (longestStreak.present) {
      map['longest_streak'] = Variable<int>(longestStreak.value);
    }
    if (lastLoggedDate.present) {
      map['last_logged_date'] = Variable<DateTime>(lastLoggedDate.value);
    }
    if (lastMilestoneCelebrated.present) {
      map['last_milestone_celebrated'] = Variable<int>(
        lastMilestoneCelebrated.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakTableCompanion(')
          ..write('id: $id, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('lastLoggedDate: $lastLoggedDate, ')
          ..write('lastMilestoneCelebrated: $lastMilestoneCelebrated')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MilestonesTable milestones = $MilestonesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $TaskCompletionsTable taskCompletions = $TaskCompletionsTable(
    this,
  );
  late final $PointsHistoryTableTable pointsHistoryTable =
      $PointsHistoryTableTable(this);
  late final $RewardsTable rewards = $RewardsTable(this);
  late final $StreakTableTable streakTable = $StreakTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    milestones,
    tasks,
    taskCompletions,
    pointsHistoryTable,
    rewards,
    streakTable,
  ];
}

typedef $$MilestonesTableCreateCompanionBuilder =
    MilestonesCompanion Function({
      required String id,
      Value<String> userId,
      required String name,
      Value<String?> description,
      Value<MilestoneStatus> status,
      Value<int> colorIndex,
      Value<DateTime?> targetDate,
      Value<int> completionPoints,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$MilestonesTableUpdateCompanionBuilder =
    MilestonesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<String?> description,
      Value<MilestoneStatus> status,
      Value<int> colorIndex,
      Value<DateTime?> targetDate,
      Value<int> completionPoints,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$MilestonesTableReferences
    extends BaseReferences<_$AppDatabase, $MilestonesTable, Milestone> {
  $$MilestonesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: $_aliasNameGenerator(db.milestones.id, db.tasks.milestoneId),
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.milestoneId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MilestonesTableFilterComposer
    extends Composer<_$AppDatabase, $MilestonesTable> {
  $$MilestonesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MilestoneStatus, MilestoneStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionPoints => $composableBuilder(
    column: $table.completionPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.milestoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MilestonesTableOrderingComposer
    extends Composer<_$AppDatabase, $MilestonesTable> {
  $$MilestonesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionPoints => $composableBuilder(
    column: $table.completionPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MilestonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MilestonesTable> {
  $$MilestonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MilestoneStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionPoints => $composableBuilder(
    column: $table.completionPoints,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.milestoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MilestonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MilestonesTable,
          Milestone,
          $$MilestonesTableFilterComposer,
          $$MilestonesTableOrderingComposer,
          $$MilestonesTableAnnotationComposer,
          $$MilestonesTableCreateCompanionBuilder,
          $$MilestonesTableUpdateCompanionBuilder,
          (Milestone, $$MilestonesTableReferences),
          Milestone,
          PrefetchHooks Function({bool tasksRefs})
        > {
  $$MilestonesTableTableManager(_$AppDatabase db, $MilestonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MilestonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MilestonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MilestonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<MilestoneStatus> status = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<int> completionPoints = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MilestonesCompanion(
                id: id,
                userId: userId,
                name: name,
                description: description,
                status: status,
                colorIndex: colorIndex,
                targetDate: targetDate,
                completionPoints: completionPoints,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> userId = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<MilestoneStatus> status = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<int> completionPoints = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MilestonesCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                description: description,
                status: status,
                colorIndex: colorIndex,
                targetDate: targetDate,
                completionPoints: completionPoints,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MilestonesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedData<
                      Milestone,
                      $MilestonesTable,
                      Task
                    >(
                      currentTable: table,
                      referencedTable: $$MilestonesTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MilestonesTableReferences(db, table, p0).tasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.milestoneId == item.id,
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

typedef $$MilestonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MilestonesTable,
      Milestone,
      $$MilestonesTableFilterComposer,
      $$MilestonesTableOrderingComposer,
      $$MilestonesTableAnnotationComposer,
      $$MilestonesTableCreateCompanionBuilder,
      $$MilestonesTableUpdateCompanionBuilder,
      (Milestone, $$MilestonesTableReferences),
      Milestone,
      PrefetchHooks Function({bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      Value<String> userId,
      Value<String?> milestoneId,
      required String name,
      Value<String?> description,
      Value<int> pointsPerCompletion,
      Value<TaskRecurrence> recurrence,
      Value<String?> recurrenceConfig,
      Value<DateTime?> dueDate,
      Value<TaskStatus> status,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> milestoneId,
      Value<String> name,
      Value<String?> description,
      Value<int> pointsPerCompletion,
      Value<TaskRecurrence> recurrence,
      Value<String?> recurrenceConfig,
      Value<DateTime?> dueDate,
      Value<TaskStatus> status,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, Task> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MilestonesTable _milestoneIdTable(_$AppDatabase db) =>
      db.milestones.createAlias(
        $_aliasNameGenerator(db.tasks.milestoneId, db.milestones.id),
      );

  $$MilestonesTableProcessedTableManager? get milestoneId {
    final $_column = $_itemColumn<String>('milestone_id');
    if ($_column == null) return null;
    final manager = $$MilestonesTableTableManager(
      $_db,
      $_db.milestones,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_milestoneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TaskCompletionsTable, List<TaskCompletion>>
  _taskCompletionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskCompletions,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.taskCompletions.taskId),
  );

  $$TaskCompletionsTableProcessedTableManager get taskCompletionsRefs {
    final manager = $$TaskCompletionsTableTableManager(
      $_db,
      $_db.taskCompletions,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskCompletionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PointsHistoryTableTable, List<PointsHistory>>
  _pointsHistoryTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pointsHistoryTable,
        aliasName: $_aliasNameGenerator(
          db.tasks.id,
          db.pointsHistoryTable.taskId,
        ),
      );

  $$PointsHistoryTableTableProcessedTableManager get pointsHistoryTableRefs {
    final manager = $$PointsHistoryTableTableTableManager(
      $_db,
      $_db.pointsHistoryTable,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pointsHistoryTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsPerCompletion => $composableBuilder(
    column: $table.pointsPerCompletion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskRecurrence, TaskRecurrence, String>
  get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get recurrenceConfig => $composableBuilder(
    column: $table.recurrenceConfig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskStatus, TaskStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MilestonesTableFilterComposer get milestoneId {
    final $$MilestonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.milestoneId,
      referencedTable: $db.milestones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MilestonesTableFilterComposer(
            $db: $db,
            $table: $db.milestones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> taskCompletionsRefs(
    Expression<bool> Function($$TaskCompletionsTableFilterComposer f) f,
  ) {
    final $$TaskCompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskCompletions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskCompletionsTableFilterComposer(
            $db: $db,
            $table: $db.taskCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pointsHistoryTableRefs(
    Expression<bool> Function($$PointsHistoryTableTableFilterComposer f) f,
  ) {
    final $$PointsHistoryTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointsHistoryTable,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsHistoryTableTableFilterComposer(
            $db: $db,
            $table: $db.pointsHistoryTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsPerCompletion => $composableBuilder(
    column: $table.pointsPerCompletion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceConfig => $composableBuilder(
    column: $table.recurrenceConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MilestonesTableOrderingComposer get milestoneId {
    final $$MilestonesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.milestoneId,
      referencedTable: $db.milestones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MilestonesTableOrderingComposer(
            $db: $db,
            $table: $db.milestones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointsPerCompletion => $composableBuilder(
    column: $table.pointsPerCompletion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TaskRecurrence, String> get recurrence =>
      $composableBuilder(
        column: $table.recurrence,
        builder: (column) => column,
      );

  GeneratedColumn<String> get recurrenceConfig => $composableBuilder(
    column: $table.recurrenceConfig,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$MilestonesTableAnnotationComposer get milestoneId {
    final $$MilestonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.milestoneId,
      referencedTable: $db.milestones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MilestonesTableAnnotationComposer(
            $db: $db,
            $table: $db.milestones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> taskCompletionsRefs<T extends Object>(
    Expression<T> Function($$TaskCompletionsTableAnnotationComposer a) f,
  ) {
    final $$TaskCompletionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskCompletions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskCompletionsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pointsHistoryTableRefs<T extends Object>(
    Expression<T> Function($$PointsHistoryTableTableAnnotationComposer a) f,
  ) {
    final $$PointsHistoryTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pointsHistoryTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PointsHistoryTableTableAnnotationComposer(
                $db: $db,
                $table: $db.pointsHistoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, $$TasksTableReferences),
          Task,
          PrefetchHooks Function({
            bool milestoneId,
            bool taskCompletionsRefs,
            bool pointsHistoryTableRefs,
          })
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> milestoneId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> pointsPerCompletion = const Value.absent(),
                Value<TaskRecurrence> recurrence = const Value.absent(),
                Value<String?> recurrenceConfig = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                userId: userId,
                milestoneId: milestoneId,
                name: name,
                description: description,
                pointsPerCompletion: pointsPerCompletion,
                recurrence: recurrence,
                recurrenceConfig: recurrenceConfig,
                dueDate: dueDate,
                status: status,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> userId = const Value.absent(),
                Value<String?> milestoneId = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<int> pointsPerCompletion = const Value.absent(),
                Value<TaskRecurrence> recurrence = const Value.absent(),
                Value<String?> recurrenceConfig = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                userId: userId,
                milestoneId: milestoneId,
                name: name,
                description: description,
                pointsPerCompletion: pointsPerCompletion,
                recurrence: recurrence,
                recurrenceConfig: recurrenceConfig,
                dueDate: dueDate,
                status: status,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                milestoneId = false,
                taskCompletionsRefs = false,
                pointsHistoryTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskCompletionsRefs) db.taskCompletions,
                    if (pointsHistoryTableRefs) db.pointsHistoryTable,
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
                        if (milestoneId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.milestoneId,
                                    referencedTable: $$TasksTableReferences
                                        ._milestoneIdTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._milestoneIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskCompletionsRefs)
                        await $_getPrefetchedData<
                          Task,
                          $TasksTable,
                          TaskCompletion
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskCompletionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskCompletionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pointsHistoryTableRefs)
                        await $_getPrefetchedData<
                          Task,
                          $TasksTable,
                          PointsHistory
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._pointsHistoryTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).pointsHistoryTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
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

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, $$TasksTableReferences),
      Task,
      PrefetchHooks Function({
        bool milestoneId,
        bool taskCompletionsRefs,
        bool pointsHistoryTableRefs,
      })
    >;
typedef $$TaskCompletionsTableCreateCompanionBuilder =
    TaskCompletionsCompanion Function({
      required String id,
      required String taskId,
      Value<String> userId,
      required DateTime completedOn,
      Value<int> pointsEarned,
      Value<bool> isSkip,
      Value<bool> isNd,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$TaskCompletionsTableUpdateCompanionBuilder =
    TaskCompletionsCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> userId,
      Value<DateTime> completedOn,
      Value<int> pointsEarned,
      Value<bool> isSkip,
      Value<bool> isNd,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TaskCompletionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskCompletionsTable, TaskCompletion> {
  $$TaskCompletionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.taskCompletions.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PointsHistoryTableTable, List<PointsHistory>>
  _pointsHistoryTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pointsHistoryTable,
        aliasName: $_aliasNameGenerator(
          db.taskCompletions.id,
          db.pointsHistoryTable.taskCompletionId,
        ),
      );

  $$PointsHistoryTableTableProcessedTableManager get pointsHistoryTableRefs {
    final manager =
        $$PointsHistoryTableTableTableManager(
          $_db,
          $_db.pointsHistoryTable,
        ).filter(
          (f) => f.taskCompletionId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pointsHistoryTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TaskCompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskCompletionsTable> {
  $$TaskCompletionsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedOn => $composableBuilder(
    column: $table.completedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsEarned => $composableBuilder(
    column: $table.pointsEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSkip => $composableBuilder(
    column: $table.isSkip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNd => $composableBuilder(
    column: $table.isNd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pointsHistoryTableRefs(
    Expression<bool> Function($$PointsHistoryTableTableFilterComposer f) f,
  ) {
    final $$PointsHistoryTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pointsHistoryTable,
      getReferencedColumn: (t) => t.taskCompletionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsHistoryTableTableFilterComposer(
            $db: $db,
            $table: $db.pointsHistoryTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskCompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskCompletionsTable> {
  $$TaskCompletionsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedOn => $composableBuilder(
    column: $table.completedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsEarned => $composableBuilder(
    column: $table.pointsEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSkip => $composableBuilder(
    column: $table.isSkip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNd => $composableBuilder(
    column: $table.isNd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskCompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskCompletionsTable> {
  $$TaskCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedOn => $composableBuilder(
    column: $table.completedOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointsEarned => $composableBuilder(
    column: $table.pointsEarned,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSkip =>
      $composableBuilder(column: $table.isSkip, builder: (column) => column);

  GeneratedColumn<bool> get isNd =>
      $composableBuilder(column: $table.isNd, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pointsHistoryTableRefs<T extends Object>(
    Expression<T> Function($$PointsHistoryTableTableAnnotationComposer a) f,
  ) {
    final $$PointsHistoryTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pointsHistoryTable,
          getReferencedColumn: (t) => t.taskCompletionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PointsHistoryTableTableAnnotationComposer(
                $db: $db,
                $table: $db.pointsHistoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TaskCompletionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskCompletionsTable,
          TaskCompletion,
          $$TaskCompletionsTableFilterComposer,
          $$TaskCompletionsTableOrderingComposer,
          $$TaskCompletionsTableAnnotationComposer,
          $$TaskCompletionsTableCreateCompanionBuilder,
          $$TaskCompletionsTableUpdateCompanionBuilder,
          (TaskCompletion, $$TaskCompletionsTableReferences),
          TaskCompletion,
          PrefetchHooks Function({bool taskId, bool pointsHistoryTableRefs})
        > {
  $$TaskCompletionsTableTableManager(
    _$AppDatabase db,
    $TaskCompletionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskCompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskCompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskCompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<DateTime> completedOn = const Value.absent(),
                Value<int> pointsEarned = const Value.absent(),
                Value<bool> isSkip = const Value.absent(),
                Value<bool> isNd = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskCompletionsCompanion(
                id: id,
                taskId: taskId,
                userId: userId,
                completedOn: completedOn,
                pointsEarned: pointsEarned,
                isSkip: isSkip,
                isNd: isNd,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                Value<String> userId = const Value.absent(),
                required DateTime completedOn,
                Value<int> pointsEarned = const Value.absent(),
                Value<bool> isSkip = const Value.absent(),
                Value<bool> isNd = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskCompletionsCompanion.insert(
                id: id,
                taskId: taskId,
                userId: userId,
                completedOn: completedOn,
                pointsEarned: pointsEarned,
                isSkip: isSkip,
                isNd: isNd,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskCompletionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({taskId = false, pointsHistoryTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pointsHistoryTableRefs) db.pointsHistoryTable,
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
                        if (taskId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.taskId,
                                    referencedTable:
                                        $$TaskCompletionsTableReferences
                                            ._taskIdTable(db),
                                    referencedColumn:
                                        $$TaskCompletionsTableReferences
                                            ._taskIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pointsHistoryTableRefs)
                        await $_getPrefetchedData<
                          TaskCompletion,
                          $TaskCompletionsTable,
                          PointsHistory
                        >(
                          currentTable: table,
                          referencedTable: $$TaskCompletionsTableReferences
                              ._pointsHistoryTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskCompletionsTableReferences(
                                db,
                                table,
                                p0,
                              ).pointsHistoryTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskCompletionId == item.id,
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

typedef $$TaskCompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskCompletionsTable,
      TaskCompletion,
      $$TaskCompletionsTableFilterComposer,
      $$TaskCompletionsTableOrderingComposer,
      $$TaskCompletionsTableAnnotationComposer,
      $$TaskCompletionsTableCreateCompanionBuilder,
      $$TaskCompletionsTableUpdateCompanionBuilder,
      (TaskCompletion, $$TaskCompletionsTableReferences),
      TaskCompletion,
      PrefetchHooks Function({bool taskId, bool pointsHistoryTableRefs})
    >;
typedef $$PointsHistoryTableTableCreateCompanionBuilder =
    PointsHistoryTableCompanion Function({
      required String id,
      Value<String?> taskCompletionId,
      Value<String?> taskId,
      Value<String?> milestoneId,
      required int points,
      required PointsReason reason,
      Value<DateTime> earnedAt,
      Value<int> rowid,
    });
typedef $$PointsHistoryTableTableUpdateCompanionBuilder =
    PointsHistoryTableCompanion Function({
      Value<String> id,
      Value<String?> taskCompletionId,
      Value<String?> taskId,
      Value<String?> milestoneId,
      Value<int> points,
      Value<PointsReason> reason,
      Value<DateTime> earnedAt,
      Value<int> rowid,
    });

final class $$PointsHistoryTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $PointsHistoryTableTable, PointsHistory> {
  $$PointsHistoryTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TaskCompletionsTable _taskCompletionIdTable(_$AppDatabase db) =>
      db.taskCompletions.createAlias(
        $_aliasNameGenerator(
          db.pointsHistoryTable.taskCompletionId,
          db.taskCompletions.id,
        ),
      );

  $$TaskCompletionsTableProcessedTableManager? get taskCompletionId {
    final $_column = $_itemColumn<String>('task_completion_id');
    if ($_column == null) return null;
    final manager = $$TaskCompletionsTableTableManager(
      $_db,
      $_db.taskCompletions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskCompletionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.pointsHistoryTable.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager? get taskId {
    final $_column = $_itemColumn<String>('task_id');
    if ($_column == null) return null;
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PointsHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $PointsHistoryTableTable> {
  $$PointsHistoryTableTableFilterComposer({
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

  ColumnFilters<String> get milestoneId => $composableBuilder(
    column: $table.milestoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PointsReason, PointsReason, String>
  get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TaskCompletionsTableFilterComposer get taskCompletionId {
    final $$TaskCompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskCompletionId,
      referencedTable: $db.taskCompletions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskCompletionsTableFilterComposer(
            $db: $db,
            $table: $db.taskCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PointsHistoryTableTable> {
  $$PointsHistoryTableTableOrderingComposer({
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

  ColumnOrderings<String> get milestoneId => $composableBuilder(
    column: $table.milestoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TaskCompletionsTableOrderingComposer get taskCompletionId {
    final $$TaskCompletionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskCompletionId,
      referencedTable: $db.taskCompletions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskCompletionsTableOrderingComposer(
            $db: $db,
            $table: $db.taskCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PointsHistoryTableTable> {
  $$PointsHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get milestoneId => $composableBuilder(
    column: $table.milestoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PointsReason, String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get earnedAt =>
      $composableBuilder(column: $table.earnedAt, builder: (column) => column);

  $$TaskCompletionsTableAnnotationComposer get taskCompletionId {
    final $$TaskCompletionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskCompletionId,
      referencedTable: $db.taskCompletions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskCompletionsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PointsHistoryTableTable,
          PointsHistory,
          $$PointsHistoryTableTableFilterComposer,
          $$PointsHistoryTableTableOrderingComposer,
          $$PointsHistoryTableTableAnnotationComposer,
          $$PointsHistoryTableTableCreateCompanionBuilder,
          $$PointsHistoryTableTableUpdateCompanionBuilder,
          (PointsHistory, $$PointsHistoryTableTableReferences),
          PointsHistory,
          PrefetchHooks Function({bool taskCompletionId, bool taskId})
        > {
  $$PointsHistoryTableTableTableManager(
    _$AppDatabase db,
    $PointsHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointsHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointsHistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointsHistoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> taskCompletionId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> milestoneId = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<PointsReason> reason = const Value.absent(),
                Value<DateTime> earnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PointsHistoryTableCompanion(
                id: id,
                taskCompletionId: taskCompletionId,
                taskId: taskId,
                milestoneId: milestoneId,
                points: points,
                reason: reason,
                earnedAt: earnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> taskCompletionId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> milestoneId = const Value.absent(),
                required int points,
                required PointsReason reason,
                Value<DateTime> earnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PointsHistoryTableCompanion.insert(
                id: id,
                taskCompletionId: taskCompletionId,
                taskId: taskId,
                milestoneId: milestoneId,
                points: points,
                reason: reason,
                earnedAt: earnedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PointsHistoryTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskCompletionId = false, taskId = false}) {
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
                    if (taskCompletionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskCompletionId,
                                referencedTable:
                                    $$PointsHistoryTableTableReferences
                                        ._taskCompletionIdTable(db),
                                referencedColumn:
                                    $$PointsHistoryTableTableReferences
                                        ._taskCompletionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable:
                                    $$PointsHistoryTableTableReferences
                                        ._taskIdTable(db),
                                referencedColumn:
                                    $$PointsHistoryTableTableReferences
                                        ._taskIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$PointsHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PointsHistoryTableTable,
      PointsHistory,
      $$PointsHistoryTableTableFilterComposer,
      $$PointsHistoryTableTableOrderingComposer,
      $$PointsHistoryTableTableAnnotationComposer,
      $$PointsHistoryTableTableCreateCompanionBuilder,
      $$PointsHistoryTableTableUpdateCompanionBuilder,
      (PointsHistory, $$PointsHistoryTableTableReferences),
      PointsHistory,
      PrefetchHooks Function({bool taskCompletionId, bool taskId})
    >;
typedef $$RewardsTableCreateCompanionBuilder =
    RewardsCompanion Function({
      required String id,
      Value<String> userId,
      required String name,
      Value<String?> description,
      required int pointsThreshold,
      Value<bool> isClaimed,
      Value<DateTime?> claimedAt,
      Value<bool> isPublic,
      Value<DateTime?> publishedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$RewardsTableUpdateCompanionBuilder =
    RewardsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<String?> description,
      Value<int> pointsThreshold,
      Value<bool> isClaimed,
      Value<DateTime?> claimedAt,
      Value<bool> isPublic,
      Value<DateTime?> publishedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$RewardsTableFilterComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsThreshold => $composableBuilder(
    column: $table.pointsThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isClaimed => $composableBuilder(
    column: $table.isClaimed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RewardsTableOrderingComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsThreshold => $composableBuilder(
    column: $table.pointsThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isClaimed => $composableBuilder(
    column: $table.isClaimed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RewardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RewardsTable> {
  $$RewardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointsThreshold => $composableBuilder(
    column: $table.pointsThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isClaimed =>
      $composableBuilder(column: $table.isClaimed, builder: (column) => column);

  GeneratedColumn<DateTime> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPublic =>
      $composableBuilder(column: $table.isPublic, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RewardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RewardsTable,
          Reward,
          $$RewardsTableFilterComposer,
          $$RewardsTableOrderingComposer,
          $$RewardsTableAnnotationComposer,
          $$RewardsTableCreateCompanionBuilder,
          $$RewardsTableUpdateCompanionBuilder,
          (Reward, BaseReferences<_$AppDatabase, $RewardsTable, Reward>),
          Reward,
          PrefetchHooks Function()
        > {
  $$RewardsTableTableManager(_$AppDatabase db, $RewardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RewardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RewardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RewardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> pointsThreshold = const Value.absent(),
                Value<bool> isClaimed = const Value.absent(),
                Value<DateTime?> claimedAt = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RewardsCompanion(
                id: id,
                userId: userId,
                name: name,
                description: description,
                pointsThreshold: pointsThreshold,
                isClaimed: isClaimed,
                claimedAt: claimedAt,
                isPublic: isPublic,
                publishedAt: publishedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> userId = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required int pointsThreshold,
                Value<bool> isClaimed = const Value.absent(),
                Value<DateTime?> claimedAt = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RewardsCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                description: description,
                pointsThreshold: pointsThreshold,
                isClaimed: isClaimed,
                claimedAt: claimedAt,
                isPublic: isPublic,
                publishedAt: publishedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RewardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RewardsTable,
      Reward,
      $$RewardsTableFilterComposer,
      $$RewardsTableOrderingComposer,
      $$RewardsTableAnnotationComposer,
      $$RewardsTableCreateCompanionBuilder,
      $$RewardsTableUpdateCompanionBuilder,
      (Reward, BaseReferences<_$AppDatabase, $RewardsTable, Reward>),
      Reward,
      PrefetchHooks Function()
    >;
typedef $$StreakTableTableCreateCompanionBuilder =
    StreakTableCompanion Function({
      Value<int> id,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<DateTime?> lastLoggedDate,
      Value<int> lastMilestoneCelebrated,
    });
typedef $$StreakTableTableUpdateCompanionBuilder =
    StreakTableCompanion Function({
      Value<int> id,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<DateTime?> lastLoggedDate,
      Value<int> lastMilestoneCelebrated,
    });

class $$StreakTableTableFilterComposer
    extends Composer<_$AppDatabase, $StreakTableTable> {
  $$StreakTableTableFilterComposer({
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

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastLoggedDate => $composableBuilder(
    column: $table.lastLoggedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMilestoneCelebrated => $composableBuilder(
    column: $table.lastMilestoneCelebrated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StreakTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StreakTableTable> {
  $$StreakTableTableOrderingComposer({
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

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastLoggedDate => $composableBuilder(
    column: $table.lastLoggedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMilestoneCelebrated => $composableBuilder(
    column: $table.lastMilestoneCelebrated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StreakTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreakTableTable> {
  $$StreakTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastLoggedDate => $composableBuilder(
    column: $table.lastLoggedDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMilestoneCelebrated => $composableBuilder(
    column: $table.lastMilestoneCelebrated,
    builder: (column) => column,
  );
}

class $$StreakTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StreakTableTable,
          Streak,
          $$StreakTableTableFilterComposer,
          $$StreakTableTableOrderingComposer,
          $$StreakTableTableAnnotationComposer,
          $$StreakTableTableCreateCompanionBuilder,
          $$StreakTableTableUpdateCompanionBuilder,
          (Streak, BaseReferences<_$AppDatabase, $StreakTableTable, Streak>),
          Streak,
          PrefetchHooks Function()
        > {
  $$StreakTableTableTableManager(_$AppDatabase db, $StreakTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<DateTime?> lastLoggedDate = const Value.absent(),
                Value<int> lastMilestoneCelebrated = const Value.absent(),
              }) => StreakTableCompanion(
                id: id,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastLoggedDate: lastLoggedDate,
                lastMilestoneCelebrated: lastMilestoneCelebrated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<DateTime?> lastLoggedDate = const Value.absent(),
                Value<int> lastMilestoneCelebrated = const Value.absent(),
              }) => StreakTableCompanion.insert(
                id: id,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastLoggedDate: lastLoggedDate,
                lastMilestoneCelebrated: lastMilestoneCelebrated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StreakTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StreakTableTable,
      Streak,
      $$StreakTableTableFilterComposer,
      $$StreakTableTableOrderingComposer,
      $$StreakTableTableAnnotationComposer,
      $$StreakTableTableCreateCompanionBuilder,
      $$StreakTableTableUpdateCompanionBuilder,
      (Streak, BaseReferences<_$AppDatabase, $StreakTableTable, Streak>),
      Streak,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MilestonesTableTableManager get milestones =>
      $$MilestonesTableTableManager(_db, _db.milestones);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$TaskCompletionsTableTableManager get taskCompletions =>
      $$TaskCompletionsTableTableManager(_db, _db.taskCompletions);
  $$PointsHistoryTableTableTableManager get pointsHistoryTable =>
      $$PointsHistoryTableTableTableManager(_db, _db.pointsHistoryTable);
  $$RewardsTableTableManager get rewards =>
      $$RewardsTableTableManager(_db, _db.rewards);
  $$StreakTableTableTableManager get streakTable =>
      $$StreakTableTableTableManager(_db, _db.streakTable);
}

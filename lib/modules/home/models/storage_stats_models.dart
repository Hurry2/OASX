// Models for the OAS `纳物库` (storage) statistics API (`/storage_stats`).
//
// The backend stores one snapshot per run under
// `log/storage_stats/{instance}/{date}/{timestamp}.json` and exposes only the
// last snapshot of each date. Values are free-form strings such as `2.11亿`,
// `1.4万` or `36439`, so numeric parsing is best-effort.

/// Instance index entry: one config name plus the dates that have data.
class StorageStatsInstance {
  /// Creates one instance index entry.
  const StorageStatsInstance({required this.name, required this.dates});

  /// Instance directory name (the sanitized config name).
  final String name;

  /// Dates owning at least one snapshot, newest first.
  final List<String> dates;

  /// Parses one entry from the backend payload.
  factory StorageStatsInstance.fromJson(Map<String, dynamic> json) {
    return StorageStatsInstance(
      name: (json['name'] ?? '').toString(),
      dates: _stringList(json['dates']),
    );
  }
}

/// Response of `GET /storage_stats`.
class StorageStatsInstanceList {
  /// Creates an instance list response.
  const StorageStatsInstanceList({required this.instances});

  /// Every instance that owns at least one snapshot.
  final List<StorageStatsInstance> instances;

  /// Parses the instance index payload.
  factory StorageStatsInstanceList.fromJson(Map<String, dynamic> json) {
    final raw = json['instances'];
    if (raw is! List) {
      return const StorageStatsInstanceList(instances: []);
    }
    return StorageStatsInstanceList(
      instances: raw
          .whereType<Map>()
          .map(
            (item) =>
                StorageStatsInstance.fromJson(item.cast<String, dynamic>()),
          )
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// Instance names in backend order.
  List<String> get names {
    return instances.map((item) => item.name).toList(growable: false);
  }
}

/// One snapshot: resource values plus the matching screenshot metadata.
class StorageStatsDay {
  /// Creates one snapshot record.
  const StorageStatsDay({
    required this.instance,
    required this.date,
    required this.timestamp,
    required this.image,
    required this.imageUrl,
    required this.data,
  });

  /// Instance the snapshot belongs to.
  final String instance;

  /// Snapshot date, `YYYY-MM-DD`.
  final String date;

  /// Snapshot timestamp, `YYYY-MM-DD_HH-MM-SS`.
  final String timestamp;

  /// Screenshot file name, or `null` when the backend found no image.
  final String? image;

  /// Relative image endpoint reported by the backend, or `null`.
  final String? imageUrl;

  /// Resource name to raw value, in the order the backend produced them.
  final Map<String, String> data;

  /// Whether a screenshot is available for this snapshot.
  bool get hasImage => (image ?? '').trim().isNotEmpty;

  /// Resource entries in backend order.
  List<MapEntry<String, String>> get entries {
    return data.entries.toList(growable: false);
  }

  /// Parses one snapshot payload.
  factory StorageStatsDay.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = <String, String>{};
    if (rawData is Map) {
      for (final entry in rawData.entries) {
        final key = (entry.key ?? '').toString();
        if (key.isEmpty) {
          continue;
        }
        data[key] = (entry.value ?? '').toString();
      }
    }
    final image = json['image']?.toString();
    final imageUrl = json['image_url']?.toString();
    return StorageStatsDay(
      instance: (json['instance'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
      image: (image ?? '').isEmpty ? null : image,
      imageUrl: (imageUrl ?? '').isEmpty ? null : imageUrl,
      data: data,
    );
  }
}

/// Response of `GET /storage_stats/{instance}`: every date, newest first.
class StorageStatsSeries {
  /// Creates a series response.
  const StorageStatsSeries({required this.instance, required this.days});

  /// Instance the series belongs to.
  final String instance;

  /// Day snapshots, newest first.
  final List<StorageStatsDay> days;

  /// Whether the instance owns no snapshot at all.
  bool get isEmpty => days.isEmpty;

  /// Parses one series payload.
  factory StorageStatsSeries.fromJson(Map<String, dynamic> json) {
    final raw = json['days'];
    if (raw is! List) {
      return StorageStatsSeries(
        instance: (json['instance'] ?? '').toString(),
        days: const [],
      );
    }
    return StorageStatsSeries(
      instance: (json['instance'] ?? '').toString(),
      days: raw
          .whereType<Map>()
          .map((item) => StorageStatsDay.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.date.isNotEmpty)
          .toList(growable: false),
    );
  }
}

/// Retention policy of the `纳物库` cleanup.
///
/// Owned by the client on purpose: the policy is a viewer-side concern, so it is
/// persisted locally and sent to OAS as request parameters instead of being
/// written into the OAS config file.
class StorageStatsCleanupOptions {
  /// Creates a retention policy.
  const StorageStatsCleanupOptions({
    this.imageKeepDays = 90,
    this.dataKeepDays = 0,
    this.weeklyKeepWeekday = 0,
    this.minKeepDays = 7,
    this.dropSameDayRuns = true,
  });

  /// Screenshot retention in days; `0` keeps every screenshot.
  final int imageKeepDays;

  /// Data retention in days (whole date dropped); `0` keeps everything.
  final int dataKeepDays;

  /// Keep only this ISO weekday (`1` = Monday … `7` = Sunday) for old dates;
  /// `0` disables weekly thinning.
  final int weeklyKeepWeekday;

  /// Recent days skipped entirely by the expiry and thinning rules.
  final int minKeepDays;

  /// Whether every date keeps only its last run.
  final bool dropSameDayRuns;

  /// Serialises the policy into the cleanup request body.
  Map<String, dynamic> toJson() {
    return {
      'image_keep_days': imageKeepDays,
      'data_keep_days': dataKeepDays,
      'weekly_keep_weekday': weeklyKeepWeekday,
      'min_keep_days': minKeepDays,
      'drop_same_day_runs': dropSameDayRuns,
    };
  }

  /// Restores a policy previously persisted on the client.
  factory StorageStatsCleanupOptions.fromJson(Map<String, dynamic> json) {
    return StorageStatsCleanupOptions(
      imageKeepDays: _asInt(json['image_keep_days'], 90),
      dataKeepDays: _asInt(json['data_keep_days'], 0),
      weeklyKeepWeekday: _asInt(json['weekly_keep_weekday'], 0),
      minKeepDays: _asInt(json['min_keep_days'], 7),
      dropSameDayRuns: json['drop_same_day_runs'] is bool
          ? json['drop_same_day_runs'] as bool
          : true,
    );
  }

  /// Returns a copy with the given fields replaced.
  StorageStatsCleanupOptions copyWith({
    int? imageKeepDays,
    int? dataKeepDays,
    int? weeklyKeepWeekday,
    int? minKeepDays,
    bool? dropSameDayRuns,
  }) {
    return StorageStatsCleanupOptions(
      imageKeepDays: imageKeepDays ?? this.imageKeepDays,
      dataKeepDays: dataKeepDays ?? this.dataKeepDays,
      weeklyKeepWeekday: weeklyKeepWeekday ?? this.weeklyKeepWeekday,
      minKeepDays: minKeepDays ?? this.minKeepDays,
      dropSameDayRuns: dropSameDayRuns ?? this.dropSameDayRuns,
    );
  }
}

/// Why one file is scheduled for deletion.
enum StorageStatsCleanupReason {
  /// An earlier run of a date the reader can never reach.
  sameDayDuplicate('same_day_duplicate'),

  /// Screenshot older than the screenshot retention window.
  imageExpired('image_expired'),

  /// Data older than the data retention window.
  dataExpired('data_expired'),

  /// Weekly thinning dropped this weekday.
  weeklyThin('weekly_thin'),

  /// Reason the client does not know about.
  unknown('unknown');

  const StorageStatsCleanupReason(this.wire);

  /// Stable identifier used by the backend.
  final String wire;

  /// Resolves a backend reason string.
  static StorageStatsCleanupReason fromWire(String raw) {
    for (final reason in values) {
      if (reason.wire == raw) {
        return reason;
      }
    }
    return StorageStatsCleanupReason.unknown;
  }
}

/// One file scheduled for deletion.
class StorageStatsCleanupDeletion {
  /// Creates one deletion entry.
  const StorageStatsCleanupDeletion({
    required this.path,
    required this.date,
    required this.reason,
    required this.isImage,
    required this.bytes,
  });

  /// Path relative to `log/storage_stats`, using POSIX separators.
  final String path;

  /// Date the file belongs to, `YYYY-MM-DD`.
  final String date;

  /// Why the backend wants it gone.
  final StorageStatsCleanupReason reason;

  /// Whether the file is a screenshot rather than the JSON payload.
  final bool isImage;

  /// File size in bytes.
  final int bytes;

  /// Parses one deletion entry.
  factory StorageStatsCleanupDeletion.fromJson(Map<String, dynamic> json) {
    return StorageStatsCleanupDeletion(
      path: (json['path'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      reason: StorageStatsCleanupReason.fromWire(
        (json['reason'] ?? '').toString(),
      ),
      isImage: (json['kind'] ?? '').toString() == 'image',
      bytes: _asInt(json['bytes'], 0),
    );
  }
}

/// Cleanup plan of one instance.
class StorageStatsCleanupInstance {
  /// Creates one instance plan.
  const StorageStatsCleanupInstance({
    required this.instance,
    required this.keptDates,
    required this.droppedDates,
    required this.deletions,
  });

  /// Instance directory name.
  final String instance;

  /// Dates that survive the cleanup.
  final List<String> keptDates;

  /// Dates dropped as a whole.
  final List<String> droppedDates;

  /// Files scheduled for deletion.
  final List<StorageStatsCleanupDeletion> deletions;

  /// Parses one instance plan.
  factory StorageStatsCleanupInstance.fromJson(Map<String, dynamic> json) {
    final raw = json['deletions'];
    return StorageStatsCleanupInstance(
      instance: (json['instance'] ?? '').toString(),
      keptDates: _stringList(json['kept_dates']),
      droppedDates: _stringList(json['dropped_dates']),
      deletions: raw is! List
          ? const []
          : raw
                .whereType<Map>()
                .map(
                  (item) => StorageStatsCleanupDeletion.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false),
    );
  }
}

/// File/byte totals of a cleanup plan or result.
class StorageStatsCleanupTotals {
  /// Creates a totals record.
  const StorageStatsCleanupTotals({
    required this.files,
    required this.bytes,
    required this.instances,
  });

  /// Number of files.
  final int files;

  /// Total size in bytes.
  final int bytes;

  /// Number of instances involved.
  final int instances;

  /// An empty totals record.
  static const StorageStatsCleanupTotals empty = StorageStatsCleanupTotals(
    files: 0,
    bytes: 0,
    instances: 0,
  );

  /// Parses a totals payload.
  factory StorageStatsCleanupTotals.fromJson(Map<String, dynamic> json) {
    return StorageStatsCleanupTotals(
      files: _asInt(json['files'], 0),
      bytes: _asInt(json['bytes'], 0),
      instances: _asInt(json['instances'], 0),
    );
  }
}

/// Response of `POST /storage_stats/cleanup`.
class StorageStatsCleanupReport {
  /// Creates a cleanup report.
  const StorageStatsCleanupReport({
    required this.dryRun,
    required this.totals,
    required this.instances,
    required this.deleted,
    required this.failedCount,
  });

  /// Whether the backend only planned the cleanup.
  final bool dryRun;

  /// What the plan would remove.
  final StorageStatsCleanupTotals totals;

  /// Per-instance plans.
  final List<StorageStatsCleanupInstance> instances;

  /// What was actually removed; `null` while previewing.
  final StorageStatsCleanupTotals? deleted;

  /// Files the backend failed to delete.
  final int failedCount;

  /// Every scheduled deletion across all instances.
  List<StorageStatsCleanupDeletion> get deletions => [
    for (final item in instances) ...item.deletions,
  ];

  /// Screenshots scheduled for deletion.
  int get imageCount =>
      deletions.where((item) => item.isImage).toList(growable: false).length;

  /// JSON payloads scheduled for deletion.
  int get dataCount =>
      deletions.where((item) => !item.isImage).toList(growable: false).length;

  /// Parses one cleanup report.
  factory StorageStatsCleanupReport.fromJson(Map<String, dynamic> json) {
    final rawInstances = json['instances'];
    final rawDeleted = json['deleted'];
    final rawFailed = json['failed'];
    final rawTotals = json['totals'];
    return StorageStatsCleanupReport(
      dryRun: json['dry_run'] is bool ? json['dry_run'] as bool : true,
      totals: rawTotals is Map
          ? StorageStatsCleanupTotals.fromJson(
              rawTotals.cast<String, dynamic>(),
            )
          : StorageStatsCleanupTotals.empty,
      instances: rawInstances is! List
          ? const []
          : rawInstances
                .whereType<Map>()
                .map(
                  (item) => StorageStatsCleanupInstance.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false),
      deleted: rawDeleted is Map
          ? StorageStatsCleanupTotals.fromJson(
              rawDeleted.cast<String, dynamic>(),
            )
          : null,
      failedCount: rawFailed is List ? rawFailed.length : 0,
    );
  }
}

/// Coerces a JSON value into an int, falling back to [fallback].
int _asInt(dynamic value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

/// Mirrors the OAS-side sanitization of a config name into an instance folder.
///
/// The backend writes snapshots under `re.sub(r'[^\w.-]', '_', config_name)`
/// with Unicode `\w`, so letters and digits of any script (including CJK)
/// survive while whitespace and punctuation become underscores.
String sanitizeStorageStatsInstanceName(String name) {
  return name.replaceAll(_instanceUnsafePattern, '_');
}

/// Characters the backend replaces with `_` when naming the instance folder.
final RegExp _instanceUnsafePattern = RegExp(
  r'[^\p{L}\p{N}_.\-]',
  unicode: true,
);

/// Coerces a JSON list into a list of non-empty strings.
List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map<String>((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

/// Matches values such as `2.11亿`, `1.4万` or `36,439`.
final RegExp _storageValuePattern = RegExp(
  r'^(-?[0-9]+(?:\.[0-9]+)?)\s*(亿|万)?$',
);

/// Parses a raw storage value into a number, or `null` when it is not numeric.
///
/// Handles the Chinese `万`/`亿` suffixes used by the title-bar resources and
/// tolerates thousands separators and stray whitespace.
double? parseStorageStatsValue(String? raw) {
  final text = (raw ?? '').trim().replaceAll(',', '').replaceAll(' ', '');
  if (text.isEmpty) {
    return null;
  }
  final match = _storageValuePattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  final base = double.tryParse(match.group(1) ?? '');
  if (base == null) {
    return null;
  }
  return switch (match.group(2)) {
    '亿' => base * 100000000,
    '万' => base * 10000,
    _ => base,
  };
}

/// Formats a number back into the game's compact notation.
///
/// Values at or above `1e8` use `亿`, at or above `1e4` use `万`; everything
/// else is rendered as a rounded integer.
String formatStorageStatsValue(double value) {
  if (!value.isFinite) {
    return '-';
  }
  final magnitude = value.abs();
  if (magnitude >= 100000000) {
    return '${_trimDecimal(value / 100000000)}亿';
  }
  if (magnitude >= 10000) {
    return '${_trimDecimal(value / 10000)}万';
  }
  return value.round().toString();
}

/// Formats a signed delta, or an empty string when the delta is negligible.
String formatStorageStatsDelta(double delta) {
  if (!delta.isFinite || delta.round() == 0) {
    return '';
  }
  final sign = delta > 0 ? '+' : '-';
  return '$sign${formatStorageStatsValue(delta.abs())}';
}

/// Formats a byte count into a compact readable size.
String formatStorageStatsBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final text = unit == 0 ? value.round().toString() : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// Formats `value` with at most two decimals and no trailing zeros.
String _trimDecimal(double value) {
  final text = value.toStringAsFixed(2);
  if (!text.contains('.')) {
    return text;
  }
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

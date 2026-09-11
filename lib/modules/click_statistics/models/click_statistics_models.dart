class ClickStatisticsConfigList {
  ClickStatisticsConfigList({required this.configs});

  factory ClickStatisticsConfigList.fromJson(Map<String, dynamic> json) {
    final raw = json['configs'];

    return ClickStatisticsConfigList(
      configs: raw is List
          ? raw
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
          : <String>[],
    );
  }

  final List<String> configs;
}

class ClickStatisticsIndex {
  final String config;
  final Map<String, List<String>> dates;

  ClickStatisticsIndex({required this.config, required this.dates});

  factory ClickStatisticsIndex.fromJson(Map<String, dynamic> json) {
    final rawDates = json['dates'] as Map<String, dynamic>? ?? {};

    final dates = <String, List<String>>{};

    for (final entry in rawDates.entries) {
      final value = entry.value;

      if (value is List) {
        dates[entry.key] = value.map((item) => item.toString()).toList();
      } else {
        dates[entry.key] = <String>[];
      }
    }

    return ClickStatisticsIndex(
      config: json['config']?.toString() ?? '',
      dates: dates,
    );
  }
}

class ClickStatisticsTaskList {
  ClickStatisticsTaskList({required this.config, required this.tasks});

  factory ClickStatisticsTaskList.fromJson(Map<String, dynamic> json) {
    final raw = json['tasks'];

    return ClickStatisticsTaskList(
      config: json['config']?.toString() ?? '',
      tasks: raw is List
          ? raw
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
          : <String>[],
    );
  }

  final String config;
  final List<String> tasks;
}

class ClickStatisticsDateList {
  ClickStatisticsDateList({
    required this.config,
    required this.task,
    required this.dates,
  });

  factory ClickStatisticsDateList.fromJson(Map<String, dynamic> json) {
    final raw = json['dates'];

    return ClickStatisticsDateList(
      config: json['config']?.toString() ?? '',
      task: json['task']?.toString() ?? '',
      dates: raw is List
          ? raw
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
          : <String>[],
    );
  }

  final String config;
  final String task;
  final List<String> dates;
}

class ClickStatisticsSession {
  ClickStatisticsSession({
    required this.sessionId,
    required this.task,
    required this.startTimeText,
    required this.endTimeText,
    required this.durationSeconds,
    required this.success,
    required this.status,
    required this.totalClicks,
    required this.totalSwipes,
  });

  factory ClickStatisticsSession.fromJson(Map<String, dynamic> json) {
    return ClickStatisticsSession(
      sessionId: json['session_id']?.toString() ?? '',
      task: json['task']?.toString() ?? '',
      startTimeText: json['start_time']?.toString() ?? '',
      endTimeText: json['end_time']?.toString() ?? '',
      durationSeconds: _readDouble(json['duration']),
      success: json['success'] == true,
      status: json['status']?.toString() ?? '',
      totalClicks: _readInt(json['total_clicks']),
      totalSwipes: _readInt(json['total_swipes']),
    );
  }

  final String sessionId;
  final String task;

  final String startTimeText;
  final String endTimeText;

  final double durationSeconds;

  final bool success;
  final String status;

  final int totalClicks;
  final int totalSwipes;

  DateTime? get startTime => _tryParseDateTime(startTimeText);
  DateTime? get endTime => _tryParseDateTime(endTimeText);
}

class ClickStatisticsSessionList {
  ClickStatisticsSessionList({
    required this.config,
    required this.task,
    required this.date,
    required this.sessions,
  });

  factory ClickStatisticsSessionList.fromJson(Map<String, dynamic> json) {
    final raw = json['sessions'];

    final sessions = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => ClickStatisticsSession.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <ClickStatisticsSession>[];

    return ClickStatisticsSessionList(
      config: json['config']?.toString() ?? '',
      task: json['task']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      sessions: sessions,
    );
  }

  final String config;
  final String task;
  final String date;

  final List<ClickStatisticsSession> sessions;
}

class ClickStatisticsEvent {
  ClickStatisticsEvent({
    required this.type,
    required this.t,
    required this.x,
    required this.y,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.duration,
    required this.elapsed,
    required this.controlName,
    required this.method,
    required this.interval,
    required this.timestamp,
  });

  factory ClickStatisticsEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'click';
    final isSwipe = type == 'swipe';

    return ClickStatisticsEvent(
      type: type,
      t: _readDouble(json['t']),
      x: isSwipe ? null : _readInt(json['x']),
      y: isSwipe ? null : _readInt(json['y']),
      startX: isSwipe ? _readInt(json['start_x']) : null,
      startY: isSwipe ? _readInt(json['start_y']) : null,
      endX: isSwipe ? _readInt(json['end_x']) : null,
      endY: isSwipe ? _readInt(json['end_y']) : null,
      duration: isSwipe && json['duration'] != null
          ? _readDouble(json['duration'])
          : null,
      elapsed: isSwipe && json['elapsed'] != null
          ? _readDouble(json['elapsed'])
          : null,
      controlName: json['control_name']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      interval: json['interval'] == null ? null : _readDouble(json['interval']),
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }

  /// 事件类型。
  ///
  /// 旧 JSON 没有 type 时默认为 click。
  final String type;

  final double t;

  /// Click 坐标。
  ///
  /// Swipe 事件为 null。
  final int? x;
  final int? y;

  /// Swipe 起点。
  ///
  /// Click 事件为 null。
  final int? startX;
  final int? startY;

  /// Swipe 终点。
  ///
  /// Click 事件为 null。
  final int? endX;
  final int? endY;

  /// Swipe 持续时间。
  final double? duration;

  /// Swipe 实际执行耗时。
  final double? elapsed;

  final String controlName;
  final String method;

  final double? interval;
  final String timestamp;

  bool get isSwipe => type == 'swipe';

  bool get isClick => !isSwipe;

  /// 用于热力图等需要一个主坐标的位置。
  ///
  /// Click 使用点击坐标；
  /// Swipe 使用滑动起点。
  int? get displayX => isSwipe ? startX : x;

  int? get displayY => isSwipe ? startY : y;
}

class ClickStatisticsDetail {
  ClickStatisticsDetail({
    required this.version,
    required this.task,
    required this.configName,
    required this.sessionId,
    required this.startTimeText,
    required this.endTimeText,
    required this.durationSeconds,
    required this.success,
    required this.status,
    required this.summary,
    required this.events,
  });

  factory ClickStatisticsDetail.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];

    final events = rawEvents is List
        ? rawEvents
              .whereType<Map>()
              .map(
                (item) => ClickStatisticsEvent.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <ClickStatisticsEvent>[];

    final rawSummary = json['summary'];

    return ClickStatisticsDetail(
      version: _readInt(json['version'], fallback: 1),
      task: json['task']?.toString() ?? '',
      configName: json['config_name']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      startTimeText: json['start_time']?.toString() ?? '',
      endTimeText: json['end_time']?.toString() ?? '',
      durationSeconds: _readDouble(json['duration']),
      success: json['success'] == true,
      status: json['status']?.toString() ?? '',
      summary: rawSummary is Map
          ? Map<String, dynamic>.from(rawSummary)
          : <String, dynamic>{},
      events: events,
    );
  }

  final int version;

  final String task;
  final String configName;
  final String sessionId;

  final String startTimeText;
  final String endTimeText;

  final double durationSeconds;

  final bool success;
  final String status;

  final Map<String, dynamic> summary;

  final List<ClickStatisticsEvent> events;

  DateTime? get startTime => _tryParseDateTime(startTimeText);
  DateTime? get endTime => _tryParseDateTime(endTimeText);

  /// 优先使用后端 summary。
  ///
  /// 没有 summary 时，根据 events 兼容计算。
  int get totalClicks {
    final value = summary['total_clicks'];
    if (value != null) {
      return _readInt(value);
    }

    return events.where((event) => event.isClick).length;
  }

  /// 优先使用后端 summary。
  ///
  /// 没有 summary 时，根据 events 兼容计算。
  int get totalSwipes {
    final value = summary['total_swipes'];
    if (value != null) {
      return _readInt(value);
    }

    return events.where((event) => event.isSwipe).length;
  }
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _tryParseDateTime(String value) {
  final text = value.trim();

  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}

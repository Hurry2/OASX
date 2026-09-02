class ClickStatisticsConfigList {
  ClickStatisticsConfigList({
    required this.configs,
  });

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


class ClickStatisticsTaskList {
  ClickStatisticsTaskList({
    required this.config,
    required this.tasks,
  });

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
    required this.t,
    required this.x,
    required this.y,
    required this.controlName,
    required this.method,
    required this.interval,
    required this.timestamp,
  });

  factory ClickStatisticsEvent.fromJson(Map<String, dynamic> json) {
    return ClickStatisticsEvent(
      t: _readDouble(json['t']),
      x: _readInt(json['x']),
      y: _readInt(json['y']),
      controlName: json['control_name']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      interval: json['interval'] == null
          ? null
          : _readDouble(json['interval']),
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }

  final double t;
  final int x;
  final int y;

  final String controlName;
  final String method;

  final double? interval;
  final String timestamp;
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

  int get totalClicks => events.length;
}


int _readInt(
  dynamic value, {
  int fallback = 0,
}) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      fallback;
}


double _readDouble(
  dynamic value, {
  double fallback = 0,
}) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      fallback;
}


DateTime? _tryParseDateTime(String value) {
  final text = value.trim();

  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}
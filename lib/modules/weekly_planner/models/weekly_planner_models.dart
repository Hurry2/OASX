import 'package:get/get.dart';

/// Data models for the OAS weekly task planner and Mon-Sun summary strip.
class WeeklyPlannerTask {
  WeeklyPlannerTask({
    required this.task,
    required this.title,
    required this.group,
    required this.isWeeklyMenu,
    required this.enable,
    required this.weeklyDays,
    required this.assignedDays,
    required this.nextRun,
    required this.priority,
  });

  final String task;
  final String title;
  final String group;
  final bool isWeeklyMenu;
  final bool enable;
  final String weeklyDays;
  final List<int> assignedDays;
  final String nextRun;
  final int priority;

  /// Returns localized task name, falling back to OASX GetX translations.
  String get displayTitle {
    if (title.isNotEmpty && title != task) {
      return title;
    }
    final translated = task.tr;
    return translated.isNotEmpty ? translated : task;
  }

  /// Returns localized group name for non-weekly categories.
  String get displayGroup {
    const fallback = {
      'Soul Zones': '刷御魂',
      'Daily Task': '日常任务',
      'Liver Emperor Exclusive': '肝帝专属',
      'Guild': '阴阳寮',
      'Weekly Task': '每周任务',
      'Activity Task': '活动任务',
    };
    final translated = group.tr;
    if (translated.isNotEmpty && translated != group) {
      return translated;
    }
    return fallback[group] ?? group;
  }

  factory WeeklyPlannerTask.fromJson(Map<String, dynamic> json) {
    final rawAssigned = json['assigned_days'];
    final assigned = rawAssigned is List
        ? rawAssigned.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e >= 1 && e <= 7).toList()
        : <int>[];
    return WeeklyPlannerTask(
      task: (json['task'] ?? '').toString(),
      title: (json['title'] ?? json['task'] ?? '').toString(),
      group: (json['group'] ?? '').toString(),
      isWeeklyMenu: json['is_weekly_menu'] == true,
      enable: json['enable'] == true,
      weeklyDays: (json['weekly_days'] ?? '').toString(),
      assignedDays: assigned,
      nextRun: (json['next_run'] ?? '').toString(),
      priority: int.tryParse((json['priority'] ?? 5).toString()) ?? 5,
    );
  }
}

class WeeklyPlannerSummary {
  WeeklyPlannerSummary({
    required this.scriptName,
    required this.todayWeekday,
    required this.counts,
    required this.allCounts,
    required this.tasks,
  });

  final String scriptName;
  final int todayWeekday;
  final Map<int, int> counts;
  final Map<int, int> allCounts;
  final List<WeeklyPlannerTask> tasks;

  factory WeeklyPlannerSummary.fromJson(Map<String, dynamic> json) {
    Map<int, int> parseCounts(dynamic raw) {
      final map = <int, int>{for (var d = 1; d <= 7; d++) d: 0};
      if (raw is Map) {
        for (final entry in raw.entries) {
          final day = int.tryParse(entry.key.toString());
          if (day != null && day >= 1 && day <= 7) {
            map[day] = int.tryParse(entry.value.toString()) ?? 0;
          }
        }
      }
      return map;
    }

    final rawTasks = json['tasks'];
    final tasks = rawTasks is List
        ? rawTasks
            .whereType<Map>()
            .map((e) => WeeklyPlannerTask.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <WeeklyPlannerTask>[];

    return WeeklyPlannerSummary(
      scriptName: (json['script_name'] ?? '').toString(),
      todayWeekday: int.tryParse((json['today_weekday'] ?? 1).toString()) ?? 1,
      counts: parseCounts(json['counts']),
      allCounts: parseCounts(json['all_counts']),
      tasks: tasks,
    );
  }
}

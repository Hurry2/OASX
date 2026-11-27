import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/weekly_planner/models/weekly_planner_models.dart';

/// Manages weekly task counts and schedule editing for an OAS config.
class WeeklyPlannerController extends GetxController {
  final summary = Rxn<WeeklyPlannerSummary>();
  final loading = false.obs;
  final error = ''.obs;
  final activeScript = ''.obs;
  final previewDay = 0.obs;
  final filterDay = 0.obs;
  final onlyWeekly = true.obs;
  final searchQuery = ''.obs;

  Future<void> loadForConfig(String scriptName, {bool force = false}) async {
    final trimmed = scriptName.trim();
    if (trimmed.isEmpty) {
      activeScript.value = '';
      summary.value = null;
      return;
    }
    if (!force && activeScript.value == trimmed && summary.value != null) {
      return;
    }
    activeScript.value = trimmed;
    loading.value = true;
    error.value = '';
    try {
      final loaded = await ApiClient().getWeeklyPlannerSummary(trimmed);
      summary.value = loaded;
      if (previewDay.value == 0) {
        previewDay.value = loaded.todayWeekday;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  void selectPreviewDay(int day) {
    previewDay.value = day;
  }

  List<WeeklyPlannerTask> previewTasksForDay(int day) {
    final data = summary.value;
    if (data == null || day < 1 || day > 7) return const [];
    final list = data.tasks
        .where((t) => t.enable && t.assignedDays.contains(day))
        .toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  void toggleFilterDay(int day) {
    filterDay.value = filterDay.value == day ? 0 : day;
  }

  List<WeeklyPlannerTask> get filteredTasks {
    final data = summary.value;
    if (data == null) return const [];
    final kw = searchQuery.value.trim().toLowerCase();
    final day = filterDay.value;
    final weeklyOnly = onlyWeekly.value;
    return data.tasks.where((t) {
      if (weeklyOnly &&
          !t.isWeeklyMenu &&
          t.weeklyDays.isEmpty &&
          t.assignedDays.isEmpty) {
        return false;
      }
      if (day > 0 && !t.assignedDays.contains(day)) return false;
      if (kw.isNotEmpty &&
          !t.displayTitle.toLowerCase().contains(kw) &&
          !t.title.toLowerCase().contains(kw) &&
          !t.task.toLowerCase().contains(kw)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> toggleTaskDay(WeeklyPlannerTask task, int day) async {
    final script = activeScript.value;
    if (script.isEmpty) return;
    final set = task.weeklyDays
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((e) => e >= 1 && e <= 7)
        .toSet();
    if (set.contains(day)) {
      set.remove(day);
    } else {
      set.add(day);
    }
    final sorted = set.toList()..sort();
    await ApiClient().updateWeeklyPlannerTask(
      script,
      task.task,
      weeklyDays: sorted.join(','),
    );
    await loadForConfig(script, force: true);
  }

  Future<void> setTaskEnable(WeeklyPlannerTask task, bool enable) async {
    final script = activeScript.value;
    if (script.isEmpty) return;
    await ApiClient().updateWeeklyPlannerTask(
      script,
      task.task,
      enable: enable,
    );
    await loadForConfig(script, force: true);
  }

  Future<void> setTaskNextRunNow(WeeklyPlannerTask task) async {
    final script = activeScript.value;
    if (script.isEmpty) return;
    await ApiClient().updateWeeklyPlannerTask(
      script,
      task.task,
      nextRun: 'now',
    );
    await loadForConfig(script, force: true);
  }

  Future<void> clearTaskDays(WeeklyPlannerTask task) async {
    final script = activeScript.value;
    if (script.isEmpty) return;
    await ApiClient().updateWeeklyPlannerTask(
      script,
      task.task,
      weeklyDays: '',
    );
    await loadForConfig(script, force: true);
  }
}

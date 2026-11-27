part of 'api_client.dart';

extension ApiClientWeeklyPlannerX on ApiClient {
  /// Fetches the Mon-Sun weekly task counts and detailed schedule for [configName].
  Future<WeeklyPlannerSummary> getWeeklyPlannerSummary(String configName) async {
    final path = '/tool/weekly-planner/api/${Uri.encodeComponent(configName)}';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid weekly planner response');
    }
    return WeeklyPlannerSummary.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Updates [taskName]'s enable flag, weekly_days, or next_run in [configName].
  Future<void> updateWeeklyPlannerTask(
    String configName,
    String taskName, {
    bool? enable,
    String? weeklyDays,
    String? nextRun,
  }) async {
    final path =
        '/tool/weekly-planner/api/${Uri.encodeComponent(configName)}/${Uri.encodeComponent(taskName)}';
    final payload = <String, dynamic>{};
    if (enable != null) payload['enable'] = enable;
    if (weeklyDays != null) payload['weekly_days'] = weeklyDays;
    if (nextRun != null) payload['next_run'] = nextRun;

    final res = await request(() => put(path, data: payload));
    if (!res.isSuccess) {
      throw Exception(res.error ?? 'Failed to update weekly task');
    }
  }
}

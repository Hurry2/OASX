part of 'api_client.dart';

extension ApiClientClickStatisticsX on ApiClient {
  Future<ClickStatisticsConfigList> getClickStatisticsConfigs() async {
    final res = await request(() => get('/click-statistics/configs'));

    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid click statistics configs response');
    }

    return ClickStatisticsConfigList.fromJson(
      Map<String, dynamic>.from(res.data),
    );
  }

  Future<ClickStatisticsIndex> getClickStatisticsIndex(
    String configName,
  ) async {
    final path =
        '/click-statistics/'
        '${Uri.encodeComponent(configName)}'
        '/index';

    final res = await request(() => get(path));

    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid click statistics index response');
    }

    return ClickStatisticsIndex.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<ClickStatisticsTaskList> getClickStatisticsTasks(
    String configName,
  ) async {
    final path =
        '/click-statistics/'
        '${Uri.encodeComponent(configName)}'
        '/tasks';

    final res = await request(() => get(path));

    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid click statistics tasks response');
    }

    return ClickStatisticsTaskList.fromJson(
      Map<String, dynamic>.from(res.data),
    );
  }

  Future<ClickStatisticsDateList> getClickStatisticsDates(
    String configName,
    String taskName,
  ) async {
    final path =
        '/click-statistics/'
        '${Uri.encodeComponent(configName)}'
        '/'
        '${Uri.encodeComponent(taskName)}'
        '/dates';

    final res = await request(() => get(path));

    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid click statistics dates response');
    }

    return ClickStatisticsDateList.fromJson(
      Map<String, dynamic>.from(res.data),
    );
  }

  Future<ClickStatisticsSessionList> getClickStatisticsSessions(
    String configName,
    String taskName,
    String date,
  ) async {
    final path =
        '/click-statistics/'
        '${Uri.encodeComponent(configName)}'
        '/'
        '${Uri.encodeComponent(taskName)}'
        '?date=${Uri.encodeComponent(date)}';

    final res = await request(() => get(path));

    if (!res.isSuccess || res.data is! Map) {
      throw Exception(
        res.error ?? 'Invalid click statistics sessions response',
      );
    }

    return ClickStatisticsSessionList.fromJson(
      Map<String, dynamic>.from(res.data),
    );
  }

  Future<ClickStatisticsDetail> getClickStatisticsDetail(
    String configName,
    String taskName,
    String date,
    String sessionId,
  ) async {
    final path =
        '/click-statistics/'
        '${Uri.encodeComponent(configName)}'
        '/'
        '${Uri.encodeComponent(taskName)}'
        '/'
        '${Uri.encodeComponent(date)}'
        '/'
        '${Uri.encodeComponent(sessionId)}';

    final res = await request(() => get(path));

    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid click statistics detail response');
    }

    return ClickStatisticsDetail.fromJson(Map<String, dynamic>.from(res.data));
  }
}

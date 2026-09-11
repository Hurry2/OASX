import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/click_statistics/models/click_statistics_models.dart';

class ClickStatisticsController extends GetxController {
  final ApiClient api = ApiClient();

  // ---------------------------------------------------------------------------
  // 数据
  // ---------------------------------------------------------------------------

  final configs = <String>[].obs;
  final tasks = <String>[].obs;
  final dates = <String>[].obs;
  final sessions = <ClickStatisticsSession>[].obs;

  // ---------------------------------------------------------------------------
  // 当前选择
  // ---------------------------------------------------------------------------

  final selectedConfig = RxnString();
  final selectedTask = RxnString();
  final selectedDate = RxnString();
  final selectedSession = Rxn<ClickStatisticsSession>();
  final detail = Rxn<ClickStatisticsDetail>();
  final hoveredEvent = Rxn<ClickStatisticsEvent>();

  // ---------------------------------------------------------------------------
  // 加载状态
  // ---------------------------------------------------------------------------

  final isLoadingConfigs = false.obs;
  final isLoadingTasks = false.obs;
  final isLoadingDates = false.obs;
  final isLoadingSessions = false.obs;
  final isLoadingDetail = false.obs;
  final errorMessage = ''.obs;

  // ---------------------------------------------------------------------------
  // 热力图
  // ---------------------------------------------------------------------------

  /// 热力图整体强度。
  ///
  /// 0.8 = 默认强度
  /// 0.2 ~ 1.5 = UI 可调范围
  final heatIntensity = 0.8.obs;

  // ---------------------------------------------------------------------------
  // 时间轴
  // ---------------------------------------------------------------------------

  /// 当前时间轴位置，单位：秒。
  final timelineSeconds = 0.0.obs;

  /// 时间轴是否正在播放。
  final isPlayingTimeline = false.obs;

  /// 时间轴播放速度。
  final timelineSpeed = 2.0.obs;

  Timer? _timelineTimer;

  // ---------------------------------------------------------------------------
  // 实例下任务 / 日期缓存
  // ---------------------------------------------------------------------------

  /// 当前实例的任务 -> 日期。
  final Map<String, Set<String>> _taskDates = {};

  /// 已加载过的实例索引。
  ///
  /// config
  ///   -> task
  ///       -> dates
  final Map<String, Map<String, Set<String>>> _taskDatesCache = {};

  @override
  void onInit() {
    super.onInit();
    loadConfigs();
  }

  // ---------------------------------------------------------------------------
  // 热力图强度
  // ---------------------------------------------------------------------------

  void setHeatIntensity(double value) {
    heatIntensity.value = value.clamp(0.2, 1.5).toDouble();
  }

  // ---------------------------------------------------------------------------
  // 时间轴
  // ---------------------------------------------------------------------------

  void setTimelineSeconds(double value) {
    final duration = detail.value?.durationSeconds ?? 0;

    timelineSeconds.value = value.clamp(0.0, duration).toDouble();
  }

  void setHoveredEvent(ClickStatisticsEvent? event) {
    hoveredEvent.value = event;
  }

  void setTimelineSpeed(double value) {
    timelineSpeed.value = value;
  }

  void resetTimeline() {
    _stopTimelinePlayback();

    timelineSeconds.value = 0.0;
  }

  void showFullTimeline() {
    _stopTimelinePlayback();

    timelineSeconds.value = detail.value?.durationSeconds ?? 0.0;
  }

  void toggleTimelinePlayback() {
    if (isPlayingTimeline.value) {
      _stopTimelinePlayback();
    } else {
      _startTimelinePlayback();
    }
  }

  void _startTimelinePlayback() {
    final duration = detail.value?.durationSeconds ?? 0.0;

    if (duration <= 0) {
      return;
    }

    // 已经播放到末尾时，再次播放从头开始。
    if (timelineSeconds.value >= duration) {
      timelineSeconds.value = 0.0;
    }

    isPlayingTimeline.value = true;

    _timelineTimer?.cancel();

    _timelineTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final next = timelineSeconds.value + 0.05 * timelineSpeed.value;

      if (next >= duration) {
        timelineSeconds.value = duration;
        _stopTimelinePlayback();
        return;
      }

      timelineSeconds.value = next;
    });
  }

  void _stopTimelinePlayback() {
    _timelineTimer?.cancel();
    _timelineTimer = null;

    isPlayingTimeline.value = false;
  }

  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  Future<void> loadConfigs() async {
    isLoadingConfigs.value = true;
    errorMessage.value = '';

    try {
      final result = await api.getClickStatisticsConfigs();

      configs.assignAll(result.configs);

      if (configs.isEmpty) {
        _clearFromConfig();
        return;
      }

      final current = selectedConfig.value;

      if (current != null && configs.contains(current)) {
        selectedConfig.value = current;
      } else {
        selectedConfig.value = configs.first;
      }

      // 新顺序：
      // 实例 -> 日期 -> 任务 -> 运行记录
      await loadDates();
    } catch (e) {
      errorMessage.value = e.toString();

      _clearFromConfig();
    } finally {
      isLoadingConfigs.value = false;
    }
  }

  Future<void> selectConfig(String? value) async {
    if (value == null || value.isEmpty) {
      return;
    }

    if (selectedConfig.value == value && dates.isNotEmpty) {
      return;
    }

    selectedConfig.value = value;

    await loadDates();
  }

  // ---------------------------------------------------------------------------
  // Date
  // ---------------------------------------------------------------------------
  Future<void> loadDates() async {
    final config = selectedConfig.value;

    if (config == null || config.isEmpty) {
      _clearFromConfig();
      return;
    }

    isLoadingDates.value = true;
    errorMessage.value = '';

    dates.clear();
    tasks.clear();
    sessions.clear();

    selectedDate.value = null;
    selectedTask.value = null;
    selectedSession.value = null;

    detail.value = null;

    resetTimeline();

    try {
      Map<String, Set<String>> taskDates;

      final cached = _taskDatesCache[config];

      if (cached != null) {
        // 已经加载过这个实例，直接使用内存缓存。
        taskDates = cached;
      } else {
        final result = await api.getClickStatisticsIndex(config);

        taskDates = {};

        for (final entry in result.dates.entries) {
          final date = entry.key;

          for (final task in entry.value) {
            taskDates.putIfAbsent(task, () => <String>{}).add(date);
          }
        }

        _taskDatesCache[config] = taskDates;
      }

      _taskDates
        ..clear()
        ..addAll(
          taskDates.map((key, value) => MapEntry(key, Set<String>.from(value))),
        );

      final allDates = <String>{};

      for (final taskDates in _taskDates.values) {
        allDates.addAll(taskDates);
      }

      final sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

      dates.assignAll(sortedDates);

      if (dates.isEmpty) {
        return;
      }

      // 默认选择最新日期。
      selectedDate.value = dates.first;

      await loadTasks();
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingDates.value = false;
    }
  }

  Future<void> selectDate(String? value) async {
    if (value == null || value.isEmpty) {
      return;
    }

    if (selectedDate.value == value && tasks.isNotEmpty) {
      return;
    }

    selectedDate.value = value;

    await loadTasks();
  }

  // ---------------------------------------------------------------------------
  // Task
  // ---------------------------------------------------------------------------

  /// 根据当前选中的日期，从当前实例的任务中筛选出实际存在于该日期的任务。
  Future<void> loadTasks() async {
    final config = selectedConfig.value;
    final date = selectedDate.value;

    if (config == null || config.isEmpty || date == null || date.isEmpty) {
      _clearFromDate();
      return;
    }

    isLoadingTasks.value = true;
    errorMessage.value = '';

    tasks.clear();
    sessions.clear();

    selectedTask.value = null;
    selectedSession.value = null;

    detail.value = null;

    resetTimeline();

    try {
      final availableTasks =
          _taskDates.entries
              .where((entry) => entry.value.contains(date))
              .map((entry) => entry.key)
              .toList()
            ..sort();

      tasks.assignAll(availableTasks);

      if (tasks.isEmpty) {
        return;
      }

      // 默认选择第一个任务。
      selectedTask.value = tasks.first;

      await loadSessions();
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingTasks.value = false;
    }
  }

  Future<void> selectTask(String? value) async {
    if (value == null || value.isEmpty) {
      return;
    }

    selectedTask.value = value;

    await loadSessions();
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  Future<void> loadSessions() async {
    final config = selectedConfig.value;
    final task = selectedTask.value;
    final date = selectedDate.value;

    if (config == null ||
        config.isEmpty ||
        task == null ||
        task.isEmpty ||
        date == null ||
        date.isEmpty) {
      _clearFromTask();
      return;
    }

    isLoadingSessions.value = true;
    errorMessage.value = '';

    sessions.clear();
    selectedSession.value = null;
    detail.value = null;

    resetTimeline();

    try {
      final result = await api.getClickStatisticsSessions(config, task, date);

      sessions.assignAll(result.sessions);

      if (sessions.isEmpty) {
        return;
      }

      // 默认选择最新的一次记录。
      await selectSession(sessions.first);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingSessions.value = false;
    }
  }

  Future<void> selectSession(ClickStatisticsSession session) async {
    final config = selectedConfig.value;
    final task = selectedTask.value;
    final date = selectedDate.value;

    if (config == null || task == null || date == null) {
      return;
    }

    _stopTimelinePlayback();

    selectedSession.value = session;

    detail.value = null;

    isLoadingDetail.value = true;
    errorMessage.value = '';

    try {
      final result = await api.getClickStatisticsDetail(
        config,
        task,
        date,
        session.sessionId,
      );

      detail.value = result;

      // 新 Session 默认显示完整点击记录。
      timelineSeconds.value = result.durationSeconds;

      // 恢复默认热力图强度。
      heatIntensity.value = 0.8;

      // 切换 Session 后清除悬浮状态。
      hoveredEvent.value = null;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingDetail.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  @override
  Future<void> refresh() async {
    _taskDatesCache.clear();

    await loadConfigs();
  }

  // ---------------------------------------------------------------------------
  // Clear
  // ---------------------------------------------------------------------------

  void _clearFromConfig() {
    dates.clear();
    tasks.clear();
    sessions.clear();

    selectedDate.value = null;
    selectedTask.value = null;
    selectedSession.value = null;

    detail.value = null;
    hoveredEvent.value = null;

    _taskDates.clear();

    resetTimeline();
  }

  void _clearFromDate() {
    tasks.clear();
    sessions.clear();

    selectedTask.value = null;
    selectedSession.value = null;

    detail.value = null;
    hoveredEvent.value = null;

    resetTimeline();
  }

  void _clearFromTask() {
    sessions.clear();

    selectedSession.value = null;

    detail.value = null;
    hoveredEvent.value = null;

    resetTimeline();
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void onClose() {
    _timelineTimer?.cancel();
    _timelineTimer = null;

    super.onClose();
  }
}

import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';

/// Drives the `纳物库` (storage) tab of the active script workbench.
///
/// The backend exposes one snapshot per date for every config instance. The
/// controller binds to the instance matching the active config, keeps the whole
/// date series in memory so switching dates needs no extra request, and caches
/// one binding per script so returning to the tab (or flipping between configs)
/// renders instantly instead of re-fetching.
class HomeStorageStatsController extends GetxController {
  /// How long a cached binding is served without any request.
  ///
  /// Past this age the cached payload is still rendered immediately, but a
  /// background refresh runs so a newly written snapshot shows up without a
  /// spinner. Kept short because OAS appends a snapshot at most once a day.
  static const Duration _cacheTtl = Duration(minutes: 1);

  /// Dashboard controller used to resolve the active script and tab.
  final HomeDashboardController dashboardController =
      Get.find<HomeDashboardController>();

  /// Whether the instance index request is in flight.
  final instancesLoading = false.obs;

  /// Whether one instance series request is in flight.
  final seriesLoading = false.obs;

  /// Latest user-visible error message.
  final lastErrorMessage = ''.obs;

  /// Whether the backend reported instances but none belongs to the active
  /// config — i.e. the storage task has not been enabled/run for it yet.
  final instanceUnmatched = false.obs;

  /// Whether a cleanup request (preview or apply) is in flight.
  final cleanupRunning = false.obs;

  /// Latest cleanup plan returned by the backend, or `null`.
  final cleanupReport = Rxn<StorageStatsCleanupReport>();

  /// Latest cleanup error message.
  final cleanupErrorMessage = ''.obs;

  /// Instances reported by the backend, in backend order.
  final instanceNames = <String>[].obs;

  /// Snapshots of the bound instance, newest first.
  final days = <StorageStatsDay>[].obs;

  /// Date currently rendered.
  final selectedDate = ''.obs;

  /// Instance currently rendered.
  ///
  /// Never user-selectable: it is auto-resolved from the active config, just
  /// like the log and statistics tabs.
  String _selectedInstance = '';

  /// Loaded payloads keyed by script name.
  ///
  /// Bounded by the number of configs the user keeps, and each entry is only a
  /// few hundred bytes per stored day, so no eviction is needed.
  final Map<String, _StorageStatsBinding> _bindings = {};

  /// Worker that keeps the controller bound to the dashboard context.
  Worker? _dashboardWorker;

  /// Script currently bound by the storage tab.
  String _boundScriptName = '';

  /// Sequence used to invalidate stale requests.
  int _revision = 0;

  @override
  void onInit() {
    _dashboardWorker = everAll(
      [
        dashboardController.activeScriptName,
        dashboardController.activeWorkbenchTab,
        dashboardController.activeWorkbenchSidebarTab,
        dashboardController.workbenchLayoutMode,
      ],
      (_) {
        unawaited(syncStorageStatsBinding());
      },
    );
    unawaited(syncStorageStatsBinding());
    super.onInit();
  }

  @override
  void onClose() {
    _dashboardWorker?.dispose();
    _dashboardWorker = null;
    super.onClose();
  }

  /// Snapshot currently rendered, or `null` when nothing is selected.
  StorageStatsDay? get selectedDay {
    final date = selectedDate.value;
    if (date.isEmpty) {
      return null;
    }
    for (final day in days) {
      if (day.date == date) {
        return day;
      }
    }
    return null;
  }

  /// Snapshot captured right before the selected one, or `null`.
  StorageStatsDay? get previousDay {
    final current = selectedDay;
    if (current == null) {
      return null;
    }
    final index = days.indexOf(current);
    if (index < 0 || index + 1 >= days.length) {
      return null;
    }
    return days[index + 1];
  }

  /// Absolute screenshot URI of the selected snapshot, or `null`.
  String? get selectedImageUrl {
    final day = selectedDay;
    if (day == null || !day.hasImage) {
      return null;
    }
    return ApiClient().buildStorageStatsImageUrl(day.instance, day.date);
  }

  /// Change of one resource against the previous snapshot, or `null`.
  double? deltaFor(String resource) {
    final current = selectedDay;
    final previous = previousDay;
    if (current == null || previous == null) {
      return null;
    }
    final currentValue = parseStorageStatsValue(current.data[resource]);
    final previousValue = parseStorageStatsValue(previous.data[resource]);
    if (currentValue == null || previousValue == null) {
      return null;
    }
    return currentValue - previousValue;
  }

  /// Instance currently rendered, or `''` when nothing is bound.
  ///
  /// Exposed for the cleanup, which is always scoped to one instance so a
  /// dialog opened for one config can never touch another one's files.
  String get boundInstance => _selectedInstance;

  /// Asks the backend what a cleanup would delete, without deleting anything.
  Future<void> previewCleanup(StorageStatsCleanupOptions options) async {
    await _runCleanup(options, dryRun: true);
  }

  /// Runs the cleanup, then reloads the series so the UI drops the removed days.
  Future<bool> applyCleanup(StorageStatsCleanupOptions options) async {
    final done = await _runCleanup(options, dryRun: false);
    if (done) {
      // The files on disk just changed, so the cached copy is no longer valid;
      // without this the deleted dates would reappear when the tab is reopened.
      _bindings.remove(dashboardController.activeScriptName.value.trim());
      await refresh();
    }
    return done;
  }

  /// Drops the cached plan, e.g. when the cleanup dialog closes.
  void clearCleanupReport() {
    cleanupReport.value = null;
    cleanupErrorMessage.value = '';
  }

  /// Runs one cleanup request, guarding the result against a rebind.
  Future<bool> _runCleanup(
    StorageStatsCleanupOptions options, {
    required bool dryRun,
  }) async {
    final instance = _selectedInstance;
    if (instance.isEmpty) {
      return false;
    }
    cleanupRunning.value = true;
    cleanupErrorMessage.value = '';
    try {
      final report = await ApiClient().runStorageStatsCleanup(
        options: options,
        instance: instance,
        dryRun: dryRun,
      );
      if (_selectedInstance != instance) {
        return false;
      }
      cleanupReport.value = report;
      return true;
    } catch (error) {
      if (_selectedInstance != instance) {
        return false;
      }
      cleanupErrorMessage.value = error.toString();
      return false;
    } finally {
      cleanupRunning.value = false;
    }
  }

  /// Rebinds the storage tab to the currently visible script context.
  ///
  /// The instance always follows the active config, so switching configs
  /// re-resolves it from scratch instead of keeping the previous pick. Staying
  /// on the same config keeps whatever is already rendered, which is what makes
  /// leaving and re-entering the tab free.
  Future<void> syncStorageStatsBinding() async {
    if (!dashboardController.isStorageStatsVisibleInCurrentLayout) {
      _detach();
      return;
    }
    final scriptName = dashboardController.activeScriptName.value.trim();
    if (_boundScriptName == scriptName && instanceNames.isNotEmpty) {
      _refreshIfStale(scriptName);
      return;
    }
    await _bootstrap(scriptName, preferredDate: selectedDate.value);
  }

  /// Selects one date from the already loaded series.
  void selectDate(String date) {
    final normalized = date.trim();
    if (normalized.isEmpty ||
        normalized == selectedDate.value ||
        !days.any((day) => day.date == normalized)) {
      return;
    }
    selectedDate.value = normalized;
  }

  /// Reloads the instance index and the bound instance series.
  ///
  /// Always goes to the network, so this is what the toolbar's refresh action
  /// and the post-cleanup reload use.
  @override
  Future<void> refresh() async {
    await _bootstrap(
      dashboardController.activeScriptName.value.trim(),
      preferredInstance: _selectedInstance,
      preferredDate: selectedDate.value,
      force: true,
    );
  }

  /// Binds the tab to [scriptName], rendering a cached payload when one exists.
  ///
  /// A fresh cache hit costs no request at all; a stale hit still renders
  /// immediately and then refreshes in the background, so the user only ever
  /// sees a spinner on the very first load.
  Future<void> _bootstrap(
    String scriptName, {
    String preferredInstance = '',
    String preferredDate = '',
    bool force = false,
  }) async {
    final cached = force ? null : _bindings[scriptName];
    if (cached != null) {
      _boundScriptName = scriptName;
      _applyBinding(cached, preferredDate: preferredDate);
      if (_isFresh(cached)) {
        return;
      }
      await _fetch(
        scriptName,
        preferredInstance: cached.instance,
        preferredDate: selectedDate.value,
        silent: true,
      );
      return;
    }
    if (_boundScriptName != scriptName) {
      // Another config's numbers must never be shown for this one.
      _clearRenderedPayload();
    }
    await _fetch(
      scriptName,
      preferredInstance: preferredInstance,
      preferredDate: preferredDate,
      silent: false,
    );
  }

  /// Loads the instance index, then the series of the resolved instance.
  ///
  /// [silent] leaves the loading flags untouched so a background refresh cannot
  /// replace already rendered data with a spinner.
  Future<void> _fetch(
    String scriptName, {
    required String preferredInstance,
    required String preferredDate,
    required bool silent,
  }) async {
    final revision = ++_revision;
    _boundScriptName = scriptName;
    if (!silent) {
      instancesLoading.value = true;
      seriesLoading.value = false;
      lastErrorMessage.value = '';
      instanceUnmatched.value = false;
    }
    try {
      final index = await ApiClient().getStorageStatsInstances();
      if (!_isActive(revision)) {
        return;
      }
      instancesLoading.value = false;
      instanceNames.assignAll(index.names);
      if (instanceNames.isEmpty) {
        _bindings.remove(scriptName);
        _clearSelection();
        return;
      }
      final target = _resolveInstance(preferredInstance, scriptName);
      if (target.isEmpty) {
        instanceUnmatched.value = true;
        _bindings.remove(scriptName);
        _clearSelection();
        return;
      }
      _selectedInstance = target;
      await _loadSeries(
        target,
        scriptName: scriptName,
        revision: revision,
        preferredDate: preferredDate,
        silent: silent,
      );
    } catch (error) {
      if (!_isActive(revision)) {
        return;
      }
      instancesLoading.value = false;
      seriesLoading.value = false;
      if (silent) {
        // A background refresh must never blank out data the user is reading.
        // The stale entry is kept so the next visit retries.
        return;
      }
      _bindings.remove(scriptName);
      instanceNames.clear();
      instanceUnmatched.value = false;
      _clearSelection();
      lastErrorMessage.value = error.toString();
    }
  }

  /// Loads every date of one instance.
  ///
  /// [revision] is the sequence issued by [_fetch]; the response is dropped when
  /// a newer request or a rebind has superseded it.
  Future<void> _loadSeries(
    String instance, {
    required String scriptName,
    required int revision,
    required String preferredDate,
    required bool silent,
  }) async {
    _boundScriptName = scriptName;
    if (!silent) {
      seriesLoading.value = true;
      lastErrorMessage.value = '';
    }
    try {
      final series = await ApiClient().getStorageStatsSeries(instance);
      if (!_isActive(revision) || _selectedInstance != instance) {
        return;
      }
      seriesLoading.value = false;
      _bindings[scriptName] = _StorageStatsBinding(
        instances: List<String>.from(instanceNames),
        instance: instance,
        series: series,
        fetchedAt: DateTime.now(),
      );
      days.assignAll(series.days);
      if (days.isEmpty) {
        selectedDate.value = '';
        return;
      }
      final hasPreferred =
          preferredDate.isNotEmpty &&
          days.any((day) => day.date == preferredDate);
      selectedDate.value = hasPreferred ? preferredDate : days.first.date;
    } catch (error) {
      if (!_isActive(revision) || _selectedInstance != instance) {
        return;
      }
      seriesLoading.value = false;
      if (silent) {
        return;
      }
      _bindings.remove(scriptName);
      days.clear();
      selectedDate.value = '';
      lastErrorMessage.value = error.toString();
    }
  }

  /// Renders one cached binding without touching the network.
  void _applyBinding(
    _StorageStatsBinding binding, {
    required String preferredDate,
  }) {
    // Invalidate in-flight requests so a slow response cannot overwrite the
    // payload that was just restored from cache.
    _revision++;
    instanceNames.assignAll(binding.instances);
    _selectedInstance = binding.instance;
    instancesLoading.value = false;
    seriesLoading.value = false;
    instanceUnmatched.value = false;
    lastErrorMessage.value = '';
    days.assignAll(binding.series.days);
    if (days.isEmpty) {
      selectedDate.value = '';
      return;
    }
    final hasPreferred =
        preferredDate.isNotEmpty &&
        days.any((day) => day.date == preferredDate);
    selectedDate.value = hasPreferred ? preferredDate : days.first.date;
  }

  /// Re-fetches [scriptName] in the background when its cache outlived the TTL.
  void _refreshIfStale(String scriptName) {
    final cached = _bindings[scriptName];
    if (cached == null || _isFresh(cached) || seriesLoading.value) {
      return;
    }
    unawaited(
      _fetch(
        scriptName,
        preferredInstance: cached.instance,
        preferredDate: selectedDate.value,
        silent: true,
      ),
    );
  }

  /// Whether [binding] is still inside [_cacheTtl].
  bool _isFresh(_StorageStatsBinding binding) =>
      DateTime.now().difference(binding.fetchedAt) < _cacheTtl;

  /// Resolves the instance owned by [scriptName], or `''` when none matches.
  ///
  /// There is deliberately no fallback to another config's instance: showing a
  /// different account's numbers would be silently wrong. An unmatched config
  /// renders the empty state instead, which doubles as a reminder that the
  /// storage task is not enabled for it.
  String _resolveInstance(String preferred, String scriptName) {
    final names = instanceNames;
    if (preferred.isNotEmpty && names.contains(preferred)) {
      return preferred;
    }
    if (scriptName.isEmpty) {
      return '';
    }
    if (names.contains(scriptName)) {
      return scriptName;
    }
    final sanitized = sanitizeStorageStatsInstanceName(scriptName);
    if (names.contains(sanitized)) {
      return sanitized;
    }
    return '';
  }

  /// Releases the tab binding without dropping the rendered payload.
  ///
  /// The series is deliberately kept, along with [_boundScriptName], so
  /// returning to the tab hits the early return in [syncStorageStatsBinding]
  /// and renders instantly instead of showing a spinner again.
  void _detach() {
    _revision++;
    instancesLoading.value = false;
    seriesLoading.value = false;
    lastErrorMessage.value = '';
    instanceUnmatched.value = false;
  }

  /// Drops the rendered payload when binding to a different config.
  void _clearRenderedPayload() {
    _selectedInstance = '';
    instanceNames.clear();
    days.clear();
    selectedDate.value = '';
    instanceUnmatched.value = false;
    lastErrorMessage.value = '';
  }

  /// Clears the bound instance and the rendered payload.
  void _clearSelection() {
    _selectedInstance = '';
    days.clear();
    selectedDate.value = '';
  }

  /// Returns whether one request still belongs to the active binding.
  bool _isActive(int revision) {
    return revision == _revision &&
        dashboardController.isStorageStatsVisibleInCurrentLayout;
  }
}

/// One cached script binding: the instance index, the resolved instance and its
/// full date series, kept so the tab can render without touching the network.
class _StorageStatsBinding {
  _StorageStatsBinding({
    required this.instances,
    required this.instance,
    required this.series,
    required this.fetchedAt,
  });

  /// Instance names reported by the backend when this binding was loaded.
  final List<String> instances;

  /// Instance this binding resolved to.
  final String instance;

  /// Full date series of [instance], newest first.
  final StorageStatsSeries series;

  /// When the payload was fetched, used for the staleness check.
  final DateTime fetchedAt;
}

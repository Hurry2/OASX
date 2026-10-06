import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/storage_stats_controller.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';
import 'package:oasx/service/storage_stats_prefs_service.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Retention presets offered by the cleanup dialog, in days.
///
/// `0` means "keep forever" and always renders as the last entry.
const List<int> _kImageKeepPresets = <int>[30, 60, 90, 180, 365, 0];
const List<int> _kDataKeepPresets = <int>[0, 30, 90, 180, 365];
const List<int> _kMinKeepPresets = <int>[0, 3, 7, 14, 30];

/// Dialog width; wide enough for the label/dropdown rows to stay on one line.
const double _kCleanupDialogWidth = 420.0;

/// Opens the `纳物库` cleanup dialog for the currently bound instance.
///
/// Returns once the dialog closes; the caller does not need the result because
/// the controller reloads the series itself after a successful cleanup.
Future<void> showStorageStatsCleanupDialog(BuildContext context) async {
  final controller = Get.find<HomeStorageStatsController>();
  if (controller.boundInstance.isEmpty) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => const _StorageCleanupDialog(),
  );
  controller.clearCleanupReport();
}

/// Cleanup configuration plus a live preview of what would be deleted.
class _StorageCleanupDialog extends StatefulWidget {
  const _StorageCleanupDialog();

  @override
  State<_StorageCleanupDialog> createState() => _StorageCleanupDialogState();
}

class _StorageCleanupDialogState extends State<_StorageCleanupDialog> {
  late final HomeStorageStatsController _controller;
  late final StorageStatsPrefsService _prefs;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<HomeStorageStatsController>();
    _prefs = Get.find<StorageStatsPrefsService>();
    // Preview on open so the user sees the impact before touching anything.
    // Deferred by one frame: the preview flips observables that this dialog
    // already listens to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.previewCleanup(_prefs.cleanupOptions.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(I18n.storageStatsCleanup.tr),
      content: SizedBox(
        width: _kCleanupDialogWidth,
        child: SingleChildScrollView(
          child: Obx(() {
            final options = _prefs.cleanupOptions.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.storageStatsCleanupScope.trParams({
                    'instance': _controller.boundInstance,
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                _StorageCleanupDropdown(
                  label: I18n.storageStatsCleanupImageKeep.tr,
                  value: options.imageKeepDays,
                  options: _daysOptions(_kImageKeepPresets),
                  onChanged: (value) =>
                      _applyOptions(options.copyWith(imageKeepDays: value)),
                ),
                _StorageCleanupDropdown(
                  label: I18n.storageStatsCleanupDataKeep.tr,
                  value: options.dataKeepDays,
                  options: _daysOptions(_kDataKeepPresets),
                  onChanged: (value) =>
                      _applyOptions(options.copyWith(dataKeepDays: value)),
                ),
                _StorageCleanupDropdown(
                  label: I18n.storageStatsCleanupWeekly.tr,
                  value: options.weeklyKeepWeekday,
                  options: _weekdayOptions(),
                  onChanged: (value) =>
                      _applyOptions(options.copyWith(weeklyKeepWeekday: value)),
                ),
                _StorageCleanupDropdown(
                  label: I18n.storageStatsCleanupMinKeep.tr,
                  value: options.minKeepDays,
                  options: _daysOptions(_kMinKeepPresets),
                  onChanged: (value) =>
                      _applyOptions(options.copyWith(minKeepDays: value)),
                ),
                _buildDropSameDay(theme, options),
                const SizedBox(height: 4),
                Text(
                  I18n.storageStatsCleanupHint.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                _buildSummary(theme),
              ],
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(I18n.storageStatsCleanupCancel.tr),
        ),
        Obx(() {
          final report = _controller.cleanupReport.value;
          final canRun =
              !_controller.cleanupRunning.value &&
              report != null &&
              report.totals.files > 0;
          return FilledButton(
            onPressed: canRun ? _confirm : null,
            child: Text(I18n.storageStatsCleanupConfirm.tr),
          );
        }),
      ],
    );
  }

  /// The "keep only the last run of each day" switch.
  Widget _buildDropSameDay(
    ThemeData theme,
    StorageStatsCleanupOptions options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              I18n.storageStatsCleanupDropSameDay.tr,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Switch(
            value: options.dropSameDayRuns,
            onChanged: (value) =>
                _applyOptions(options.copyWith(dropSameDayRuns: value)),
          ),
        ],
      ),
    );
  }

  /// Preview / progress / result block under the divider.
  Widget _buildSummary(ThemeData theme) {
    final error = _controller.cleanupErrorMessage.value;
    if (error.isNotEmpty) {
      return Text(
        error,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    if (_controller.cleanupRunning.value) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            I18n.storageStatsCleanupPreviewing.tr,
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }
    final report = _controller.cleanupReport.value;
    if (report == null) {
      return const SizedBox.shrink();
    }
    if (report.totals.files == 0) {
      return Text(
        I18n.storageStatsCleanupNothing.tr,
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.storageStatsCleanupSummary.trParams({
            'files': '${report.totals.files}',
            'size': formatStorageStatsBytes(report.totals.bytes),
          }),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          I18n.storageStatsCleanupSummaryDetail.trParams({
            'images': '${report.imageCount}',
            'data': '${report.dataCount}',
          }),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Persists the edited policy and re-runs the preview.
  void _applyOptions(StorageStatsCleanupOptions options) {
    _prefs.updateCleanupOptions(options);
    _controller.previewCleanup(options);
  }

  /// Runs the cleanup and reports the outcome.
  Future<void> _confirm() async {
    final options = _prefs.cleanupOptions.value;
    final applied = await _controller.applyCleanup(options);
    if (!mounted) {
      return;
    }
    final report = _controller.cleanupReport.value;
    final deleted = report?.deleted;
    Navigator.of(context).pop();
    if (!applied || deleted == null) {
      Get.snackbar(I18n.storageStatsCleanup.tr, I18n.error.tr);
      return;
    }
    if (report != null && report.failedCount > 0) {
      Get.snackbar(
        I18n.storageStatsCleanup.tr,
        I18n.storageStatsCleanupFailed.trParams({
          'count': '${report.failedCount}',
        }),
      );
      return;
    }
    Get.snackbar(
      I18n.storageStatsCleanup.tr,
      I18n.storageStatsCleanupDone.trParams({
        'files': '${deleted.files}',
        'size': formatStorageStatsBytes(deleted.bytes),
      }),
    );
  }

  /// Builds "30 天 / 60 天 … / 永久" entries from day presets.
  Map<int, String> _daysOptions(List<int> presets) {
    return {
      for (final days in presets)
        days: days == 0
            ? I18n.storageStatsCleanupForever.tr
            : I18n.storageStatsCleanupDays.trParams({'days': '$days'}),
    };
  }

  /// Builds "不启用 / 周一 … 周日" entries, reusing the calendar captions.
  Map<int, String> _weekdayOptions() {
    final labels = I18n.storageStatsDateWeekdays.tr.split(',');
    return {
      0: I18n.storageStatsCleanupWeeklyOff.tr,
      for (var index = 0; index < labels.length; index++)
        index + 1: labels[index],
    };
  }
}

/// One label/dropdown row inside the cleanup dialog.
class _StorageCleanupDropdown extends StatelessWidget {
  const _StorageCleanupDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    // A stale persisted value that no preset covers would trip the dropdown
    // assertion, so fall back to the first preset.
    final resolved = options.containsKey(value) ? value : entries.first.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: resolved,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(10),
            onChanged: (next) {
              if (next != null) {
                onChanged(next);
              }
            },
            items: [
              for (final entry in entries)
                DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

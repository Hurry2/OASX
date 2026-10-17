import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/storage_stats_controller.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';
import 'package:oasx/modules/home/widgets/statistics_formatters.dart';
import 'package:oasx/modules/home/widgets/storage_stats_cleanup_dialog.dart';
import 'package:oasx/modules/home/widgets/storage_stats_date_picker.dart';
import 'package:oasx/modules/home/widgets/last_screenshot_panel.dart';
import 'package:oasx/modules/home/widgets/storage_stats_style.dart';
import 'package:oasx/modules/home/widgets/storage_stats_trend_panel.dart';
import 'package:oasx/service/storage_stats_prefs_service.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kStoragePanelPadding = 12.0;
const _kStoragePanelSpacing = 12.0;

const _kStorageResourceMinWidth = 104.0;
const _kStorageResourceSpacing = 8.0;

/// `监控` (monitor) tab content for the active script.
///
/// Mirrors the log tab layout: one card holding a control row (the date
/// selector on the left, actions on the right) above the scrolling content.
/// The rendered instance is bound to the active config, so it is not pickable.
///
/// The body has two views, toggled from the control row and remembered across
/// sessions: the `列表` grid (one date, per-resource change vs the previous
/// date) and the `趋势` charts (every stored date, one small line per resource).
/// Below the grid sits the live emulator screenshot for this config.
class StorageStatsPanel extends StatefulWidget {
  /// Creates the storage statistics panel.
  const StorageStatsPanel({super.key, required this.scriptName});

  /// Config name the backend keys every resource snapshot and frame by.
  final String scriptName;

  @override
  State<StorageStatsPanel> createState() => _StorageStatsPanelState();
}

class _StorageStatsPanelState extends State<StorageStatsPanel> {
  /// Controller that owns storage statistics state.
  HomeStorageStatsController get controller =>
      Get.find<HomeStorageStatsController>();

  /// Local preferences, i.e. which view is active.
  StorageStatsPrefsService get prefs => Get.find<StorageStatsPrefsService>();

  @override
  void initState() {
    super.initState();
    // Safety net for the first entry into the tab. The controller is created
    // with the home page and only syncs on dashboard changes, so a tab that is
    // opened before its worker fires would render the previous config's state
    // with no request of its own. Deferred past the frame because the call
    // flips Rx flags, which must not happen while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(controller.syncStorageStatsBinding());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_kStoragePanelPadding),
        child: Obx(() {
          final day = controller.selectedDay;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StorageStatsToolbar(controller: controller, day: day),
              const SizedBox(height: _kStoragePanelSpacing),
              Expanded(
                child: day == null
                    ? _StorageStatsPlaceholder(
                        label: _placeholderLabel(),
                        message: _placeholderMessage(),
                        loading: _isLoading,
                      )
                    : (prefs.trendViewEnabled.value
                          ? StorageStatsTrendPanel(controller: controller)
                          : _StorageStatsContent(
                              controller: controller,
                              day: day,
                            )),
              ),
              const SizedBox(height: _kStoragePanelSpacing),
              LastScreenshotPanel(scriptName: widget.scriptName),
            ],
          );
        }),
      ),
    );
  }

  /// Whether a spinner belongs in the placeholder.
  ///
  /// `!bindingLoaded` counts as loading on purpose: before the first finished
  /// load nothing is known about this config, and the generic empty text would
  /// be a claim the panel cannot back up.
  bool get _isLoading =>
      controller.instancesLoading.value ||
      controller.seriesLoading.value ||
      !controller.bindingLoaded.value;

  /// Returns the placeholder title for the current controller state.
  String _placeholderLabel() {
    if (_isLoading) {
      return I18n.storageStatsLoading.tr;
    }
    if (controller.lastErrorMessage.value.isNotEmpty) {
      return I18n.error.tr;
    }
    if (controller.emptyReason.value != StorageStatsEmptyReason.unknown) {
      return I18n.storageStatsInstanceMissing.tr;
    }
    return I18n.storageStatsEmpty.tr;
  }

  /// Returns the placeholder hint shown under the title, if any.
  String _placeholderMessage() {
    if (_isLoading) {
      return '';
    }
    if (controller.lastErrorMessage.value.isNotEmpty) {
      return controller.lastErrorMessage.value;
    }
    if (controller.emptyReason.value != StorageStatsEmptyReason.unknown) {
      return I18n.storageStatsInstanceMissingHint.tr;
    }
    return '';
  }
}

/// Control row: the date selector on the left, actions on the right.
class _StorageStatsToolbar extends StatelessWidget {
  const _StorageStatsToolbar({required this.controller, required this.day});

  final HomeStorageStatsController controller;
  final StorageStatsDay? day;

  /// Local preferences holding the active view.
  StorageStatsPrefsService get prefs => Get.find<StorageStatsPrefsService>();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _leadingControls(context)),
        const SizedBox(width: 8),
        _trailingControls(context),
      ],
    );
  }

  /// Builds what sits on the left: the date + snapshot-time selector in the list
  /// view, the covered window in the trend view.
  ///
  /// The instance is bound to the active config, so only the date and the
  /// snapshot time are pickable. The trend view charts every stored date at
  /// once, so a date selector there would be a control that does nothing — it
  /// shows the covered range instead.
  Widget _leadingControls(BuildContext context) {
    final theme = Theme.of(context);
    if (prefs.trendViewEnabled.value) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _trendRangeLabel(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final currentDay = day;
    if (currentDay == null) {
      return const SizedBox.shrink();
    }
    // `Align` hands the controls loose constraints, so the pills hug their
    // labels instead of being stretched by the surrounding `Expanded`.
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StorageStatsDateButton(
            selected: currentDay.date,
            dates: controller.distinctDates,
            onSelected: controller.selectDate,
          ),
          _SnapshotTimeDropdown(controller: controller),
        ],
      ),
    );
  }

  /// `MM-DD ~ MM-DD` window covered by the trend view, oldest first.
  String _trendRangeLabel() {
    final dates = controller.days;
    if (dates.isEmpty) {
      return '';
    }
    final newest = formatStatisticsDayLabel(dates.first.date);
    if (dates.length == 1) {
      return newest;
    }
    return '${formatStatisticsDayLabel(dates.last.date)} ~ $newest';
  }

  /// Builds the view toggle, refresh action and the error indicator.
  Widget _trailingControls(BuildContext context) {
    final loading =
        controller.instancesLoading.value || controller.seriesLoading.value;
    final errorMessage = controller.lastErrorMessage.value;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (errorMessage.isNotEmpty)
          Tooltip(
            message: errorMessage,
            child: IconButton(
              onPressed: null,
              icon: Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (day != null) _viewToggle(),
        if (day != null)
          IconButton(
            tooltip: I18n.storageStatsCleanup.tr,
            onPressed: () => showStorageStatsCleanupDialog(context),
            icon: const Icon(Icons.cleaning_services_rounded),
          ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          )
        else
          IconButton(
            tooltip: I18n.storageStatsRefresh.tr,
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    );
  }

  /// Builds the list/trend switch.
  ///
  /// Own `Obx` on purpose: the panel's outer `Obx` only tracks what its own
  /// builder reads, and this button must follow the preference by itself.
  /// The icon shows the view it switches *to*, and the tooltip names it.
  Widget _viewToggle() {
    return Obx(() {
      final trend = prefs.trendViewEnabled.value;
      return IconButton(
        tooltip:
            (trend ? I18n.storageStatsViewList : I18n.storageStatsViewTrend).tr,
        onPressed: () => prefs.updateTrendViewEnabled(!trend),
        icon: Icon(trend ? Icons.view_list_rounded : Icons.show_chart_rounded),
      );
    });
  }
}

/// Snapshot-time selector for the selected date.
///
/// The date button picks the day; this picks which run within that day, since
/// the backend keeps every run (several runs a day included). It reads the day's
/// timestamps straight from the controller, so it needs no request of its own.
class _SnapshotTimeDropdown extends StatelessWidget {
  const _SnapshotTimeDropdown({required this.controller});

  final HomeStorageStatsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      final timestamps = controller.timestampsForSelectedDate;
      final selected = controller.selectedTimestamp.value;
      final resolved = timestamps.contains(selected) ? selected : null;
      return Tooltip(
        message: I18n.storageStatsTime.tr,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: resolved,
              isDense: true,
              borderRadius: BorderRadius.circular(10),
              hint: Text('--', style: theme.textTheme.labelLarge),
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
              onChanged: timestamps.isEmpty
                  ? null
                  : (next) {
                      if (next != null) {
                        controller.selectTimestamp(next);
                      }
                    },
              items: [
                for (final stamp in timestamps)
                  DropdownMenuItem<String>(
                    value: stamp,
                    child: Text(
                      _timeLabel(stamp),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// `HH:MM:SS` from a `YYYY-MM-DD_HH-MM-SS` stamp; the date is already known.
  String _timeLabel(String stamp) {
    final timePart = stamp.contains('_') ? stamp.split('_').last : stamp;
    return timePart.replaceAll('-', ':');
  }
}

/// Scrolling body of the storage tab: just the resource grid.
///
/// The emulator screenshot is pinned to the bottom of the panel in
/// [StorageStatsPanel], outside the scroll area, so it stays put while the
/// grid scrolls and reads the cached frame on the first connect.
class _StorageStatsContent extends StatelessWidget {
  const _StorageStatsContent({required this.controller, required this.day});

  final HomeStorageStatsController controller;
  final StorageStatsDay day;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [_StorageResourceGrid(controller: controller, day: day)],
    );
  }
}

/// Renders a resource value, compacting large counts into the game's `万`/`亿`
/// notation (two decimals) and falling back to the raw text when empty or
/// non-numeric.
String _formatResourceValue(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return '--';
  }
  final parsed = parseStorageStatsValue(text);
  return parsed == null ? text : formatStorageStatsValue(parsed);
}

/// Tooltip text for a compacted value: the exact original number, or `null`
/// when the value is short enough that a tooltip would only repeat the label.
String? _resourceTooltip(String raw, String displayed) {
  if (!displayed.contains('万') && !displayed.contains('亿')) {
    return null;
  }
  final text = raw.trim();
  final parsed = parseStorageStatsValue(text);
  if (parsed == null) {
    return text.isEmpty ? null : text;
  }
  return _withThousandsSeparators(parsed.round());
}

/// Inserts thousands separators into an integer without pulling in intl.
String _withThousandsSeparators(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Resource value grid with a per-resource change indicator.
class _StorageResourceGrid extends StatelessWidget {
  const _StorageResourceGrid({required this.controller, required this.day});

  final HomeStorageStatsController controller;
  final StorageStatsDay day;

  @override
  Widget build(BuildContext context) {
    final entries = day.entries
        .where((entry) => !storageStatsExcludedResources.contains(entry.key))
        .toList(growable: false);
    if (entries.isEmpty) {
      return Center(child: Text(I18n.storageStatsEmpty.tr));
    }
    final hasPrevious = controller.previousDay != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _kStorageResourceMinWidth;
        final fittingColumns =
            ((available + _kStorageResourceSpacing) /
                    (_kStorageResourceMinWidth + _kStorageResourceSpacing))
                .floor();
        final columns = fittingColumns < 1
            ? 1
            : (fittingColumns > 4 ? 4 : fittingColumns);
        final itemWidth =
            (available - _kStorageResourceSpacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _kStorageResourceSpacing,
          runSpacing: _kStorageResourceSpacing,
          children: [
            for (final entry in entries)
              SizedBox(
                width: itemWidth,
                child: _StorageResourceCard(
                  name: entry.key,
                  value: entry.value,
                  delta: hasPrevious ? controller.deltaFor(entry.key) : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One resource tile showing the current value and its change.
class _StorageResourceCard extends StatelessWidget {
  const _StorageResourceCard({
    required this.name,
    required this.value,
    required this.delta,
  });

  final String name;
  final String value;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = StorageResourceStyle.resolve(name, scheme);
    final displayValue = _formatResourceValue(value);
    final valueTooltip = _resourceTooltip(value, displayValue);
    final valueText = Text(
      displayValue,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    final currentDelta = delta;
    final deltaText = currentDelta == null
        ? ''
        : formatStorageStatsDelta(currentDelta);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StorageResourceIcon(style: style),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: valueTooltip == null
                    ? valueText
                    : Tooltip(message: valueTooltip, child: valueText),
              ),
              if (deltaText.isNotEmpty && currentDelta != null) ...[
                const SizedBox(width: 4),
                StorageDeltaLabel(delta: currentDelta, text: deltaText),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Centered placeholder shown while loading or when nothing is available.
class _StorageStatsPlaceholder extends StatelessWidget {
  const _StorageStatsPlaceholder({
    required this.label,
    this.message = '',
    this.loading = false,
  });

  final String label;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

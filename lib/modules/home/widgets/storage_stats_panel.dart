import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/storage_stats_controller.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';
import 'package:oasx/modules/home/widgets/statistics_formatters.dart';
import 'package:oasx/modules/home/widgets/storage_stats_cleanup_dialog.dart';
import 'package:oasx/modules/home/widgets/storage_stats_date_picker.dart';
import 'package:oasx/modules/home/widgets/storage_stats_style.dart';
import 'package:oasx/modules/home/widgets/storage_stats_trend_panel.dart';
import 'package:oasx/service/storage_stats_prefs_service.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kStoragePanelPadding = 12.0;
const _kStoragePanelSpacing = 12.0;

const _kStorageResourceMinWidth = 104.0;
const _kStorageResourceSpacing = 8.0;

/// `纳物库` (storage) tab content for the active script.
///
/// Mirrors the log tab layout: one card holding a control row (the date
/// selector on the left, actions on the right) above the scrolling content.
/// The rendered instance is bound to the active config, so it is not pickable.
///
/// The body has two views, toggled from the control row and remembered across
/// sessions: the `列表` grid (one date, per-resource change vs the previous
/// date) and the `趋势` charts (every stored date, one small line per resource).
class StorageStatsPanel extends StatefulWidget {
  /// Creates the storage statistics panel.
  const StorageStatsPanel({super.key});

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

  /// Builds what sits on the left: the date selector in the list view, the
  /// covered window in the trend view.
  ///
  /// The instance is bound to the active config, so only the date is pickable.
  /// The trend view charts every stored date at once, so a date selector there
  /// would be a control that does nothing — it shows the covered range instead.
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
    // `Align` hands the button loose constraints, so the pill hugs its label
    // instead of being stretched by the surrounding `Expanded`.
    return Align(
      alignment: Alignment.centerLeft,
      child: StorageStatsDateButton(
        selected: currentDay.date,
        dates: [for (final item in controller.days) item.date],
        onSelected: controller.selectDate,
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

  /// Builds the view toggle, the cleanup, refresh actions and the error
  /// indicator.
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

/// Scrolling body of the storage tab.
class _StorageStatsContent extends StatelessWidget {
  const _StorageStatsContent({required this.controller, required this.day});

  final HomeStorageStatsController controller;
  final StorageStatsDay day;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _StorageResourceGrid(controller: controller, day: day),
        const SizedBox(height: _kStoragePanelSpacing),
        _StorageScreenshotCard(controller: controller, day: day),
      ],
    );
  }
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
                child: Text(
                  value.trim().isEmpty ? '--' : value.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
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

/// Archived storage screenshot with a tap-to-zoom preview.
class _StorageScreenshotCard extends StatelessWidget {
  const _StorageScreenshotCard({required this.controller, required this.day});

  final HomeStorageStatsController controller;
  final StorageStatsDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = controller.selectedImageUrl;
    final capturedAt = _parseCapturedAt(day.timestamp);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    I18n.storageStatsScreenshot.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (capturedAt != null)
                  Text(
                    formatStatisticsDateTime(capturedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (imageUrl == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text(I18n.storageStatsNoScreenshot.tr)),
              )
            else
              _StorageScreenshotPreview(url: imageUrl),
          ],
        ),
      ),
    );
  }
}

/// Parses a backend timestamp such as `2026-10-06_14-19-02`.
DateTime? _parseCapturedAt(String timestamp) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[_\s](\d{2})-(\d{2})-(\d{2})$',
  ).firstMatch(timestamp.trim());
  if (match == null) {
    return null;
  }
  return DateTime.tryParse(
    '${match.group(1)} ${match.group(2)}:${match.group(3)}:${match.group(4)}',
  );
}

/// Network preview of one storage screenshot with zoom support.
class _StorageScreenshotPreview extends StatelessWidget {
  const _StorageScreenshotPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        ),
      ),
    );
  }

  /// Opens the screenshot in a zoomable full-screen dialog.
  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 160,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/storage_stats_controller.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';
import 'package:oasx/modules/home/widgets/statistics_formatters.dart';
import 'package:oasx/modules/home/widgets/storage_stats_cleanup_dialog.dart';
import 'package:oasx/modules/home/widgets/storage_stats_date_picker.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kStoragePanelPadding = 12.0;
const _kStoragePanelSpacing = 12.0;

const _kStorageResourceMinWidth = 104.0;
const _kStorageResourceSpacing = 8.0;

/// Increase tone: the game resource grew since the previous snapshot.
const _kStorageDeltaUpTone = Color(0xFFD64545);

/// Decrease tone: the game resource shrank since the previous snapshot.
const _kStorageDeltaDownTone = Color(0xFF2E9E5B);

/// Resource keys retired from the product that OAS may still emit.
///
/// OASX no longer ships artwork for these, so they are filtered out of the grid
/// instead of rendering with a generic fallback glyph. Drop this once OAS stops
/// writing the key (`tasks/DailyTrifles/script_task.py:run_storage_stats`).
const _kStorageResourceExcluded = <String>{'海蛇皮'};

/// `纳物库` (storage) tab content for the active script.
///
/// Mirrors the log tab layout: one card holding a control row (the date
/// selector on the left, actions on the right) above the scrolling content.
/// The rendered instance is bound to the active config, so it is not pickable.
class StorageStatsPanel extends StatelessWidget {
  /// Creates the storage statistics panel.
  const StorageStatsPanel({super.key});

  /// Controller that owns storage statistics state.
  HomeStorageStatsController get controller =>
      Get.find<HomeStorageStatsController>();

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
                    : _StorageStatsContent(controller: controller, day: day),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Whether any request is in flight.
  bool get _isLoading =>
      controller.instancesLoading.value || controller.seriesLoading.value;

  /// Returns the placeholder title for the current controller state.
  String _placeholderLabel() {
    if (_isLoading) {
      return I18n.storageStatsLoading.tr;
    }
    if (controller.lastErrorMessage.value.isNotEmpty) {
      return I18n.error.tr;
    }
    if (controller.instanceUnmatched.value) {
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
    if (controller.instanceUnmatched.value) {
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _leadingControls()),
        const SizedBox(width: 8),
        _trailingControls(context),
      ],
    );
  }

  /// Builds the date selector shown on the left.
  ///
  /// The instance is bound to the active config, so only the date is pickable.
  Widget _leadingControls() {
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

  /// Builds the cleanup, refresh actions and the error indicator.
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
        .where((entry) => !_kStorageResourceExcluded.contains(entry.key))
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
    final style = _StorageResourceStyle.resolve(name, scheme);
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
              _StorageResourceIcon(style: style),
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
                _StorageDeltaLabel(delta: currentDelta, text: deltaText),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Icon and accent tone used by one resource tile.
class _StorageResourceStyle {
  const _StorageResourceStyle({
    required this.asset,
    required this.icon,
    required this.tone,
  });

  /// In-game icon (transparent PNG) bundled with the app.
  final String asset;

  /// Vector glyph used when the bundled icon is unavailable.
  final IconData icon;

  /// Accent color applied to the fallback glyph.
  final Color tone;

  /// Style used for resource names without a dedicated mapping.
  static const _StorageResourceStyle fallback = _StorageResourceStyle(
    asset: '',
    icon: Icons.category_rounded,
    tone: Color(0xFF757575),
  );

  /// Resolves the icon and tone for one resource name.
  ///
  /// Keys mirror the resource names produced by OAS
  /// (`tasks/DailyTrifles/script_task.py:run_storage_stats`); the PNG files
  /// live under `assets/storage_stats/`.
  static _StorageResourceStyle resolve(String name, ColorScheme scheme) {
    switch (name.trim()) {
      case '金币':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/gold.png',
          icon: Icons.monetization_on_rounded,
          tone: Color(0xFFF2A600),
        );
      case '体力':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/sushi.png',
          icon: Icons.bolt_rounded,
          tone: Color(0xFFEF6C00),
        );
      case '勾玉':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/jade.png',
          icon: Icons.diamond_rounded,
          tone: Color(0xFF7E57C2),
        );
      case '蓝票':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/blue_ticket.png',
          icon: Icons.confirmation_number_rounded,
          tone: Color(0xFF1E88E5),
        );
      case '金蛇皮':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/gold_skin.png',
          icon: Icons.auto_awesome_rounded,
          tone: Color(0xFFC08A00),
        );
      case '逢魔皮':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/demon_skin.png',
          icon: Icons.local_fire_department_rounded,
          tone: Color(0xFFE64A19),
        );
      case '现世符咒':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/present_world_ticket.png',
          icon: Icons.article_rounded,
          tone: Color(0xFF00897B),
        );
      case '御札':
        return const _StorageResourceStyle(
          asset: 'assets/storage_stats/return_soul.png',
          icon: Icons.style_rounded,
          tone: Color(0xFF5C6BC0),
        );
      default:
        return _StorageResourceStyle(
          asset: fallback.asset,
          icon: fallback.icon,
          tone: scheme.onSurfaceVariant,
        );
    }
  }
}

/// Bundled in-game icon for one resource, falling back to a vector glyph.
class _StorageResourceIcon extends StatelessWidget {
  const _StorageResourceIcon({required this.style});

  /// Rendered edge length, in logical pixels.
  static const double _size = 18;

  final _StorageResourceStyle style;

  @override
  Widget build(BuildContext context) {
    if (style.asset.isEmpty) {
      return Icon(style.icon, size: _size - 2, color: style.tone);
    }
    // Icons are transparent RGBA cut-outs, so no rounded clip is applied —
    // clipping would shave the artwork's corners.
    return Image.asset(
      style.asset,
      width: _size,
      height: _size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          Icon(style.icon, size: _size - 2, color: style.tone),
    );
  }
}

/// Signed change label rendered next to a resource value.
class _StorageDeltaLabel extends StatelessWidget {
  const _StorageDeltaLabel({required this.delta, required this.text});

  final double delta;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = delta > 0 ? _kStorageDeltaUpTone : _kStorageDeltaDownTone;
    return Tooltip(
      message: I18n.storageStatsComparePrevious.tr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delta > 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 12,
            color: tone,
          ),
          const SizedBox(width: 1),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
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

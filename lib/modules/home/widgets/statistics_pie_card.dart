import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/statistics_controller.dart';
import 'package:oasx/modules/home/models/script_statistics_models.dart';
import 'package:oasx/modules/home/widgets/statistics_formatters.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Metric mode for the bottom-right statistics pie chart.
enum _PieMetricMode {
  duration,
  runs,
  battles,
}

/// Compact task statistics pie chart shown at the bottom of the right sidebar.
///
/// Defaults to total runtime duration per task, with a quick toggle to run count.
class StatisticsPieCard extends StatefulWidget {
  const StatisticsPieCard({
    super.key,
    required this.onOpenFullStats,
  });

  /// Switches the sidebar to the full statistics tab.
  final VoidCallback onOpenFullStats;

  @override
  State<StatisticsPieCard> createState() => _StatisticsPieCardState();
}

class _StatisticsPieCardState extends State<StatisticsPieCard> {
  _PieMetricMode _metricMode = _PieMetricMode.duration;
  int _touchedIndex = -1;

  static const int _maxSlices = 6;

  static const List<Color> _palette = <Color>[
    Color(0xff5B6ABF),
    Color(0xff2F7D74),
    Color(0xffD97736),
    Color(0xff3F7D4F),
    Color(0xff7A5AA8),
    Color(0xff2F6F9F),
    Color(0xff94A3B8),
  ];

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<HomeStatisticsController>()) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<HomeStatisticsController>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Obx(() {
          final stats = controller.statistics.value;
          final isLoading =
              controller.datesLoading.value ||
              controller.statisticsLoading.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, stats),
              const SizedBox(height: 6),
              Expanded(
                child: _buildBody(context, stats: stats, isLoading: isLoading),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ScriptStatisticsDay? stats) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalRuns = stats == null
        ? 0
        : stats.tasks.values.fold<int>(0, (sum, task) => sum + task.runCount);
    final totalBattles = stats == null
        ? 0
        : stats.tasks.values.fold<int>(
            0,
            (sum, task) => sum + task.battleCount,
          );
    final totalText = stats == null
        ? ''
        : switch (_metricMode) {
            _PieMetricMode.duration => formatStatisticsDuration(
              stats.totalRuntimeSeconds,
            ),
            _PieMetricMode.runs => '$totalRuns 次',
            _PieMetricMode.battles => '$totalBattles 场',
          };
    return Row(
      children: [
        Icon(Icons.pie_chart_rounded, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          I18n.homeStatsTab.tr,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (totalText.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              totalText,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
        const Spacer(),
        _MetricSwitch(
          mode: _metricMode,
          onChanged: (mode) => setState(() {
            _metricMode = mode;
            _touchedIndex = -1;
          }),
        ),
        const SizedBox(width: 2),
        TextButton(
          onPressed: widget.onOpenFullStats,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '详情',
            style: textTheme.labelSmall?.copyWith(color: scheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required ScriptStatisticsDay? stats,
    required bool isLoading,
  }) {
    if (stats == null) {
      return Center(
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                I18n.homeStatsChartEmpty.tr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      );
    }
    final slices = _buildSlices(stats);
    if (slices.isEmpty) {
      return Center(
        child: Text(
          I18n.homeStatsChartEmpty.tr,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final total = slices.fold<double>(0, (sum, item) => sum + item.value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final chartWidth = isCompact ? 104.0 : 132.0;
        final centerRadius = isCompact ? 18.0 : 24.0;
        final baseRadius = isCompact ? 30.0 : 36.0;
        final touchedRadius = isCompact ? 34.0 : 42.0;
        return Row(
          children: [
            SizedBox(
              width: chartWidth,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        if (_touchedIndex != -1) {
                          setState(() => _touchedIndex = -1);
                        }
                        return;
                      }
                      final index =
                          response.touchedSection!.touchedSectionIndex;
                      if (index != _touchedIndex) {
                        setState(() => _touchedIndex = index);
                      }
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: centerRadius,
                  sections: List<PieChartSectionData>.generate(slices.length, (
                    i,
                  ) {
                    final slice = slices[i];
                    final isTouched = i == _touchedIndex;
                    final percent =
                        total > 0 ? (slice.value / total * 100) : 0.0;
                    return PieChartSectionData(
                      color: slice.color,
                      value: slice.value,
                      radius: isTouched ? touchedRadius : baseRadius,
                      title: percent >= 10 ? '${percent.round()}%' : '',
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
            ),
            SizedBox(width: isCompact ? 8 : 12),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: slices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final slice = slices[index];
                  final isHighlighted = index == _touchedIndex;
                  final percent =
                      total > 0 ? (slice.value / total * 100) : 0.0;
                  return _LegendRow(
                    slice: slice,
                    percentText:
                        '${percent.toStringAsFixed(percent >= 10 ? 0 : 1)}%',
                    highlighted: isHighlighted,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<_PieSlice> _buildSlices(ScriptStatisticsDay stats) {
    final items = <_PieSlice>[];
    for (final entry in stats.tasks.entries) {
      final value = switch (_metricMode) {
        _PieMetricMode.duration => entry.value.totalDurationSeconds,
        _PieMetricMode.runs => entry.value.runCount.toDouble(),
        _PieMetricMode.battles => entry.value.battleCount.toDouble(),
      };
      if (value <= 0) {
        continue;
      }
      final formattedValue = switch (_metricMode) {
        _PieMetricMode.duration => formatStatisticsDuration(value),
        _PieMetricMode.runs => '${value.toInt()}次',
        _PieMetricMode.battles => '${value.toInt()}场',
      };
      items.add(
        _PieSlice(
          label: entry.key.tr,
          value: value,
          formattedValue: formattedValue,
          color: _palette.first,
        ),
      );
    }
    items.sort((a, b) => b.value.compareTo(a.value));
    if (items.isEmpty) {
      return const [];
    }
    final result = <_PieSlice>[];
    final takeCount = items.length > _maxSlices ? _maxSlices - 1 : items.length;
    for (var i = 0; i < takeCount; i++) {
      final item = items[i];
      result.add(
        _PieSlice(
          label: item.label,
          value: item.value,
          formattedValue: item.formattedValue,
          color: _palette[i % (_palette.length - 1)],
        ),
      );
    }
    if (items.length > _maxSlices) {
      final restValue = items
          .skip(takeCount)
          .fold<double>(0, (sum, item) => sum + item.value);
      final restFormatted = switch (_metricMode) {
        _PieMetricMode.duration => formatStatisticsDuration(restValue),
        _PieMetricMode.runs => '${restValue.toInt()}次',
        _PieMetricMode.battles => '${restValue.toInt()}场',
      };
      result.add(
        _PieSlice(
          label: '其他',
          value: restValue,
          formattedValue: restFormatted,
          color: _palette.last,
        ),
      );
    }
    return result;
  }
}

class _MetricSwitch extends StatelessWidget {
  const _MetricSwitch({required this.mode, required this.onChanged});

  final _PieMetricMode mode;
  final ValueChanged<_PieMetricMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetricPill(
            label: '时间',
            selected: mode == _PieMetricMode.duration,
            onTap: () => onChanged(_PieMetricMode.duration),
          ),
          _MetricPill(
            label: '次数',
            selected: mode == _PieMetricMode.runs,
            onTap: () => onChanged(_PieMetricMode.runs),
          ),
          _MetricPill(
            label: '战斗',
            selected: mode == _PieMetricMode.battles,
            onTap: () => onChanged(_PieMetricMode.battles),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.slice,
    required this.percentText,
    required this.highlighted,
  });

  final _PieSlice slice;
  final String percentText;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.32)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            slice.formattedValue,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            child: Text(
              percentText,
              textAlign: TextAlign.right,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieSlice {
  const _PieSlice({
    required this.label,
    required this.value,
    required this.formattedValue,
    required this.color,
  });

  final String label;
  final double value;
  final String formattedValue;
  final Color color;
}

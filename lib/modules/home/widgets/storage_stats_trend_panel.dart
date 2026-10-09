import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/storage_stats_controller.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';
import 'package:oasx/modules/home/widgets/statistics_formatters.dart';
import 'package:oasx/modules/home/widgets/storage_stats_style.dart';
import 'package:oasx/service/storage_stats_prefs_service.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kTrendSpacing = 12.0;
const _kTrendChartHeight = 148.0;

/// `趋势` view of the `纳物库` tab: one small line chart per selected resource.
///
/// The list view answers "what changed since the previous snapshot"; this view
/// answers "how did it move over everything we kept". Both read the same
/// already-loaded [HomeStorageStatsController.days], so switching views costs no
/// request.
///
/// Charts are drawn one resource at a time instead of overlaying them: the
/// resources span eight orders of magnitude (金币 is ~2亿 while 现世符咒 is a
/// single digit), so a shared axis would flatten everything except the largest
/// series into a straight line.
class StorageStatsTrendPanel extends StatelessWidget {
  /// Creates the storage trend view.
  const StorageStatsTrendPanel({super.key, required this.controller});

  /// Controller owning the loaded date series.
  final HomeStorageStatsController controller;

  /// Local preferences holding which resources are ticked.
  StorageStatsPrefsService get prefs => Get.find<StorageStatsPrefsService>();

  @override
  Widget build(BuildContext context) {
    // Own `Obx`: this widget is created by the panel's builder but reads the
    // series itself, so it must subscribe on its own.
    return Obx(() {
      final resources = controller.resourceNames;
      if (resources.isEmpty) {
        return Center(child: Text(I18n.storageStatsEmpty.tr));
      }
      final selected = _selectedResources(resources);
      final granularity = prefs.trendGranularity.value;
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          _StorageTrendGranularitySelector(
            granularity: granularity,
            onChanged: prefs.updateTrendGranularity,
          ),
          const SizedBox(height: _kTrendSpacing),
          _StorageTrendSelector(
            resources: resources,
            selected: selected,
            onToggle: (name) => _toggle(selected, name),
            onSelectAll: () => prefs.updateTrendResources(resources),
            onClear: () => prefs.updateTrendResources(const <String>[]),
          ),
          const SizedBox(height: _kTrendSpacing),
          if (selected.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text(I18n.storageStatsTrendNoResource.tr)),
            )
          else
            for (final name in selected) ...[
              _StorageTrendCard(
                controller: controller,
                resource: name,
                granularity: granularity,
              ),
              const SizedBox(height: _kTrendSpacing),
            ],
        ],
      );
    });
  }

  /// Ticked resources, in the canonical display order of [resources].
  ///
  /// An unset preference means "never chosen", which renders every resource;
  /// an explicitly empty selection stays empty (that is what 清空 stores), so
  /// the two cases must not be collapsed into one.
  List<String> _selectedResources(List<String> resources) {
    final stored = prefs.trendResources.value;
    if (stored == null) {
      return List<String>.from(resources);
    }
    return [
      for (final name in resources)
        if (stored.contains(name)) name,
    ];
  }

  /// Ticks or unticks one resource.
  void _toggle(List<String> selected, String name) {
    final next = List<String>.from(selected);
    if (next.contains(name)) {
      next.remove(name);
    } else {
      next.add(name);
    }
    prefs.updateTrendResources(next);
  }
}

/// Bucket-width switch: 日 / 周 / 月.
class _StorageTrendGranularitySelector extends StatelessWidget {
  const _StorageTrendGranularitySelector({
    required this.granularity,
    required this.onChanged,
  });

  final StorageStatsTrendGranularity granularity;
  final ValueChanged<StorageStatsTrendGranularity> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // The aggregation rule is not obvious from the labels alone, so the
        // label carries the explanation.
        Tooltip(
          message: I18n.storageStatsTrendGranularityHint.tr,
          child: Text(
            I18n.storageStatsTrendGranularity.tr,
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(width: 8),
        // `Expanded` lets the segmented button divide the leftover width, so a
        // narrow sidebar shrinks the segments instead of overflowing.
        Expanded(
          child: SegmentedButton<StorageStatsTrendGranularity>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                value: StorageStatsTrendGranularity.day,
                label: Text(I18n.storageStatsTrendDay.tr),
              ),
              ButtonSegment(
                value: StorageStatsTrendGranularity.week,
                label: Text(I18n.storageStatsTrendWeek.tr),
              ),
              ButtonSegment(
                value: StorageStatsTrendGranularity.month,
                label: Text(I18n.storageStatsTrendMonth.tr),
              ),
            ],
            selected: {granularity},
            onSelectionChanged: (values) => onChanged(values.first),
          ),
        ),
      ],
    );
  }
}

/// Resource multi-select shown above the charts.
class _StorageTrendSelector extends StatelessWidget {
  const _StorageTrendSelector({
    required this.resources,
    required this.selected,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClear,
  });

  final List<String> resources;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected =
        resources.isNotEmpty && selected.length == resources.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                I18n.storageStatsTrendResources.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: allSelected ? null : onSelectAll,
              child: Text(I18n.storageStatsTrendSelectAll.tr),
            ),
            TextButton(
              onPressed: selected.isEmpty ? null : onClear,
              child: Text(I18n.storageStatsTrendClear.tr),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in resources)
              FilterChip(
                label: Text(name),
                selected: selected.contains(name),
                showCheckmark: false,
                avatar: StorageResourceIcon(
                  style: StorageResourceStyle.resolve(name, theme.colorScheme),
                ),
                onSelected: (_) => onToggle(name),
              ),
          ],
        ),
      ],
    );
  }
}

/// One resource: name, range caption and its trend line.
///
/// The current value and its change are deliberately *not* repeated in the
/// header: the line already carries them (the last point is always labelled),
/// and with a week/month bucket the delta would not mean "today" anyway. The
/// exact per-day numbers live in the list view.
class _StorageTrendCard extends StatelessWidget {
  const _StorageTrendCard({
    required this.controller,
    required this.resource,
    required this.granularity,
  });

  final HomeStorageStatsController controller;
  final String resource;
  final StorageStatsTrendGranularity granularity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = StorageResourceStyle.resolve(resource, scheme);
    final points = controller.trendFor(resource, granularity: granularity);
    final numbers = <double>[
      for (final point in points)
        if (point.value != null) point.value!,
    ];

    final minValue = numbers.isEmpty ? null : numbers.reduce(math.min);
    final maxValue = numbers.isEmpty ? null : numbers.reduce(math.max);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StorageResourceIcon(style: style),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    resource,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              minValue == null || maxValue == null
                  ? I18n.storageStatsEmpty.tr
                  : I18n.storageStatsTrendRange.trParams({
                      'min': formatStorageStatsValue(minValue),
                      'max': formatStorageStatsValue(maxValue),
                    }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (numbers.isEmpty)
              SizedBox(
                height: _kTrendChartHeight,
                child: Center(child: Text(I18n.storageStatsEmpty.tr)),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: _kTrendChartHeight,
                child: CustomPaint(
                  painter: _StorageTrendPainter(
                    points: points,
                    granularity: granularity,
                    lineColor: style.tone,
                    gridColor: scheme.outlineVariant.withValues(alpha: 0.45),
                    fillColor: style.tone.withValues(alpha: 0.20),
                    labelTextStyle:
                        theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ) ??
                        const TextStyle(fontSize: 11),
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Picks "round" guide values covering `[minValue, maxValue]`.
///
/// Aiming at [target] lines rather than at a fixed step is what keeps the labels
/// readable: a raw range like `2.11亿 … 2.15亿` would otherwise produce ticks at
/// meaningless fractions, while stepping by `100万` yields
/// `2.11亿 / 2.12亿 / 2.13亿 / 2.14亿 / 2.15亿`.
///
/// A candidate step is rejected when two of its labels would read the same.
/// That matters for small ranges: the label formatter rounds below `1万` to an
/// integer, so a step of `0.5` over `3 … 5` would print `4 / 4 / 5 / 5 / 5`.
/// Falls back to the bare range when no candidate step fits.
List<double> _trendAxisTicks(double minValue, double maxValue, int target) {
  if (!minValue.isFinite || !maxValue.isFinite || target < 2) {
    return <double>[minValue, maxValue];
  }
  var low = minValue;
  var high = maxValue;
  if (high - low <= 0) {
    // A flat series still needs a scale to sit on, or there is nothing to label.
    // Below `1` the label formatter has no decimals, so the padding has to reach
    // a full unit — otherwise every label would read `0`. The floor stays at
    // zero because a resource can never hold a negative amount.
    final pad = high.abs() < 1 ? 1.0 : high.abs() * 0.1;
    low = math.max(0.0, high - pad);
    high = high + pad;
  }
  // Span of the adjusted range, i.e. the one the guides are actually spread over.
  final scaleSpan = high - low;
  final magnitude = math
      .pow(10, (math.log(scaleSpan / target) / math.ln10).floor())
      .toDouble();
  List<double>? best;
  var bestScore = double.infinity;
  for (final factor in const <double>[1, 2, 2.5, 5, 10]) {
    final step = factor * magnitude;
    if (!step.isFinite || step <= 0) {
      continue;
    }
    final first = (low / step).floor() * step;
    final last = (high / step).ceil() * step;
    final count = ((last - first) / step).round();
    // Too few lines carry no reference value, too many turn into noise.
    if (count < 1 || count > 8) {
      continue;
    }
    final ticks = <double>[for (var i = 0; i <= count; i++) first + i * step];
    final rendered = <String>{};
    for (final tick in ticks) {
      rendered.add(formatStorageStatsValue(tick));
    }
    if (rendered.length != ticks.length) {
      continue;
    }
    final score = (ticks.length - target).abs().toDouble();
    if (score < bestScore) {
      bestScore = score;
      best = ticks;
    }
  }
  return best ?? <double>[low, high];
}

/// Paints one resource trend: value-labelled guides, the filled line and the
/// date axis.
///
/// Hand-rolled rather than pulled from a chart package: the series is tiny (one
/// point per stored bucket), the app already draws its statistics chart the same
/// way, and a painter has no API surface to keep in sync with a dependency.
///
/// The date axis is drawn here rather than as a sibling widget on purpose: the
/// value labels reserve a left gutter whose width is only known once they are
/// measured, and the axis has to start at the same x to stay under its points.
class _StorageTrendPainter extends CustomPainter {
  _StorageTrendPainter({
    required this.points,
    required this.granularity,
    required this.lineColor,
    required this.gridColor,
    required this.fillColor,
    required this.labelTextStyle,
    required this.textDirection,
  });

  /// Points in ascending date order; `null` values become gaps.
  final List<StorageStatsTrendPoint> points;

  /// Bucket width, used to format the date axis.
  final StorageStatsTrendGranularity granularity;

  /// Stroke colour of the line and fill colour of the dots.
  final Color lineColor;

  /// Colour of the horizontal guides.
  final Color gridColor;

  /// Gradient start colour of the area under the line.
  final Color fillColor;

  /// Style (colour included) of the value and date labels.
  final TextStyle labelTextStyle;

  /// Resolved text direction; a painter has no `BuildContext` to ask.
  final TextDirection textDirection;

  /// Guide lines to aim for. Four is what makes the scale readable.
  static const int _targetGuides = 4;

  /// Gap between a value label and the plot area.
  static const double _labelGap = 6;

  /// Above this many points the dots are skipped, or they merge into a blob.
  static const int _maxDots = 40;

  /// Above this many points only the last point is labelled; labelling every
  /// one would overlap them into an unreadable band.
  static const int _maxPointLabels = 5;

  /// Most date labels that fit under a sidebar-width card.
  static const int _maxDateLabels = 4;

  /// Height of the date strip reserved under the plot.
  static const double _axisHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }
    final numbers = <double>[
      for (final point in points)
        if (point.value != null) point.value!,
    ];
    if (numbers.isEmpty) {
      return;
    }

    final ticks = _trendAxisTicks(
      numbers.reduce(math.min),
      numbers.reduce(math.max),
      _targetGuides,
    );
    final minValue = ticks.first;
    final maxValue = ticks.last;
    final span = maxValue - minValue;

    // Measure every guide label first: the gutter is sized to the widest one,
    // so a `36439` series and a `2.15亿` series both fit without clipping.
    final labels = <TextPainter>[
      for (final tick in ticks) _layout(formatStorageStatsValue(tick)),
    ];
    final gutter =
        labels.fold<double>(0, (width, label) => math.max(width, label.width)) +
        _labelGap;

    // Half a line of padding top and bottom, or the end labels get clipped.
    final pad = (labelTextStyle.fontSize ?? 11.0) * 0.9;
    final plotTop = pad;
    final plotBottom = size.height - _axisHeight - pad;
    final plotLeft = gutter;
    final plotRight = size.width;
    if (plotRight <= plotLeft || plotBottom <= plotTop) {
      return;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < ticks.length; i++) {
      final y =
          plotTop + (plotBottom - plotTop) * (1 - (ticks[i] - minValue) / span);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      labels[i].paint(
        canvas,
        Offset(
          plotLeft - _labelGap - labels[i].width,
          y - labels[i].height / 2,
        ),
      );
    }

    double yAt(double value) {
      return plotTop + (plotBottom - plotTop) * (1 - (value - minValue) / span);
    }

    // One slot per bucket, so a gap keeps its horizontal position and the
    // remaining points stay aligned with the date axis below them.
    final plot = <Offset?>[];
    for (var i = 0; i < points.length; i++) {
      final value = points[i].value;
      if (value == null) {
        plot.add(null);
        continue;
      }
      plot.add(Offset(_slotX(i, plotLeft, plotRight), yAt(value)));
    }

    final segments = <List<Offset>>[];
    var segment = <Offset>[];
    for (final offset in plot) {
      if (offset == null) {
        if (segment.isNotEmpty) {
          segments.add(segment);
          segment = <Offset>[];
        }
        continue;
      }
      segment.add(offset);
    }
    if (segment.isNotEmpty) {
      segments.add(segment);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (final current in segments) {
      if (current.length < 2) {
        continue;
      }
      final line = Path()..moveTo(current.first.dx, current.first.dy);
      for (final offset in current.skip(1)) {
        line.lineTo(offset.dx, offset.dy);
      }
      final area = Path.from(line)
        ..lineTo(current.last.dx, plotBottom)
        ..lineTo(current.first.dx, plotBottom)
        ..close();
      fillPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withValues(alpha: 0)],
      ).createShader(Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom));
      canvas.drawPath(area, fillPaint);
      canvas.drawPath(line, linePaint);
    }

    // A single point (or an isolated one between gaps) has no segment to draw,
    // so the dot is what makes it visible.
    final dots = <Offset>[
      for (final offset in plot)
        if (offset != null) offset,
    ];
    if (dots.length <= _maxDots) {
      final dotPaint = Paint()..color = lineColor;
      for (final offset in dots) {
        canvas.drawCircle(offset, 2.4, dotPaint);
      }
    }

    // Sparse series get a value on every point; a dense one keeps a single label
    // on the last point, since the current value is the number that matters and
    // the card header no longer repeats it.
    _paintPointValues(
      canvas,
      size,
      plot,
      plotLeft,
      all: dots.length <= _maxPointLabels,
    );
    _paintDateAxis(canvas, size, plot, plotLeft, plotRight, plotBottom);
  }

  /// Labels the points with their values.
  ///
  /// [all] is set for sparse series (weekly/monthly buckets), where the exact
  /// numbers are what the reader came for. A dense series passes `false` and only
  /// the last point gets a label. A label that would collide with the previous
  /// one is dropped rather than overprinted, and every label is kept clear of the
  /// guide-label gutter on the left.
  void _paintPointValues(
    Canvas canvas,
    Size size,
    List<Offset?> plot,
    double plotLeft, {
    required bool all,
  }) {
    final lastIndex = plot.lastIndexWhere((offset) => offset != null);
    if (lastIndex < 0) {
      return;
    }
    var lastRight = double.negativeInfinity;
    for (var i = all ? 0 : lastIndex; i < plot.length; i++) {
      final offset = plot[i];
      final value = points[i].value;
      if (offset == null || value == null) {
        continue;
      }
      final label = _layout(formatStorageStatsValue(value));
      // The upper bound never drops below [plotLeft], because `clamp` throws when
      // its bounds cross — which is what a label wider than the plot would do.
      final upper = math.max(plotLeft, size.width - label.width);
      // `num.clamp` returns `num`, so the cast back to double is required.
      final x = (offset.dx - label.width / 2).clamp(plotLeft, upper).toDouble();
      if (x < lastRight + 4) {
        continue;
      }
      // Flip below the dot when there is no room above it.
      final above = offset.dy - label.height - 6 >= 0;
      label.paint(
        canvas,
        Offset(x, above ? offset.dy - label.height - 4 : offset.dy + 4),
      );
      lastRight = x + label.width;
    }
  }

  /// Draws the date axis under the plot.
  ///
  /// The first and last labels are edge-aligned so they cannot spill outside the
  /// card; the rest are centred on their slot.
  void _paintDateAxis(
    Canvas canvas,
    Size size,
    List<Offset?> plot,
    double plotLeft,
    double plotRight,
    double plotBottom,
  ) {
    final indices = _dateLabelIndices(plot.length);
    for (var order = 0; order < indices.length; order++) {
      final index = indices[order];
      final label = _layout(_axisLabel(points[index].date));
      final anchor = plot[index]?.dx ?? _slotX(index, plotLeft, plotRight);
      var x = anchor - label.width / 2;
      if (order == 0) {
        x = plotLeft;
      } else if (order == indices.length - 1) {
        x = plotRight - label.width;
      }
      x = x.clamp(0.0, math.max(0.0, size.width - label.width)).toDouble();
      label.paint(canvas, Offset(x, plotBottom + 5));
    }
  }

  /// Horizontal centre of slot [index] inside the plot area.
  double _slotX(int index, double plotLeft, double plotRight) {
    if (points.length <= 1) {
      return (plotLeft + plotRight) / 2;
    }
    return plotLeft + (plotRight - plotLeft) * index / (points.length - 1);
  }

  /// Slots that get a date label: all of them while they fit, then first, last
  /// and an even spread in between.
  List<int> _dateLabelIndices(int count) {
    if (count <= 0) {
      return const <int>[];
    }
    if (count <= _maxDateLabels) {
      return [for (var i = 0; i < count; i++) i];
    }
    final step = (count - 1) / (_maxDateLabels - 1);
    final picked = <int>[];
    for (var i = 0; i < _maxDateLabels; i++) {
      final index = (i * step).round();
      if (!picked.contains(index)) {
        picked.add(index);
      }
    }
    return picked;
  }

  /// Formats one bucket date for the axis; months would read as a single day
  /// under `MM-dd`.
  String _axisLabel(String date) {
    return granularity == StorageStatsTrendGranularity.month
        ? formatStatisticsMonthLabel(date)
        : formatStatisticsDayLabel(date);
  }

  /// Lays out one label with [labelTextStyle].
  TextPainter _layout(String text) {
    return TextPainter(
      text: TextSpan(text: text, style: labelTextStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
  }

  @override
  bool shouldRepaint(_StorageTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.granularity != granularity ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.labelTextStyle != labelTextStyle ||
        oldDelegate.textDirection != textDirection;
  }
}

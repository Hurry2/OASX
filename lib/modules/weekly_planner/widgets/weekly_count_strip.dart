import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/weekly_planner/models/weekly_planner_models.dart';
import 'package:oasx/modules/weekly_planner/weekly_planner_controller.dart';
import 'package:oasx/modules/weekly_planner/weekly_planner_view.dart';

/// Compact Mon-Sun weekly task count strip + horizontal daily task preview.
class WeeklyCountStrip extends StatefulWidget {
  const WeeklyCountStrip({super.key, required this.scriptName});

  final String scriptName;

  @override
  State<WeeklyCountStrip> createState() => _WeeklyCountStripState();
}

class _WeeklyCountStripState extends State<WeeklyCountStrip> {
  static const _dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  WeeklyPlannerController get _controller {
    if (!Get.isRegistered<WeeklyPlannerController>()) {
      Get.put<WeeklyPlannerController>(WeeklyPlannerController(), permanent: true);
    }
    return Get.find<WeeklyPlannerController>();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadForConfig(widget.scriptName));
  }

  @override
  void didUpdateWidget(covariant WeeklyCountStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptName != widget.scriptName) {
      unawaited(_controller.loadForConfig(widget.scriptName));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Obx(() {
          final summary = _controller.summary.value;
          final today = summary?.todayWeekday ?? DateTime.now().weekday;
          final selectedDay =
              _controller.previewDay.value > 0 ? _controller.previewDay.value : today;
          final dayTasks = _controller.previewTasksForDay(selectedDay);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var d = 1; d <= 7; d++) ...[
                            _DayCountChip(
                              label: _dayLabels[d - 1],
                              count: summary?.counts[d] ?? 0,
                              isToday: d == today,
                              isSelected: d == selectedDay,
                              onTap: () => _controller.selectPreviewDay(d),
                            ),
                            if (d < 7) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => _openWeeklyPlannerDialog(context, selectedDay),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('详情'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${_dayLabels[selectedDay - 1]}安排:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: dayTasks.isEmpty
                        ? Text(
                            '当日暂无已启用的周常或指定周几任务',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < dayTasks.length; i++) ...[
                                  _TaskPreviewPill(task: dayTasks[i]),
                                  if (i < dayTasks.length - 1) const SizedBox(width: 6),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _openWeeklyPlannerDialog(BuildContext context, int initialDay) {
    _controller.filterDay.value = 0;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '周常任务排期 · ${widget.scriptName}',
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '刷新',
                      onPressed: () => _controller.loadForConfig(
                        widget.scriptName,
                        force: true,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 12),
                const Expanded(
                  child: WeeklyPlannerView(embedded: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCountChip extends StatelessWidget {
  const _DayCountChip({
    required this.label,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isSelected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final border = isSelected
        ? scheme.primary
        : (isToday ? scheme.secondary : scheme.outlineVariant);
    final badgeBg = count > 0
        ? (isSelected ? scheme.primary : scheme.secondaryContainer)
        : scheme.surfaceContainerHigh;
    final badgeFg = count > 0
        ? (isSelected ? scheme.onPrimary : scheme.onSecondaryContainer)
        : scheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: isSelected ? 1.4 : 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isToday ? '$label·今' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskPreviewPill extends StatelessWidget {
  const _TaskPreviewPill({required this.task});

  final WeeklyPlannerTask task;

  String get _timeLabel {
    if (task.nextRun.length >= 16) {
      return task.nextRun.substring(11, 16);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeStr = _timeLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: task.isWeeklyMenu
            ? scheme.secondaryContainer.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            task.displayTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          if (timeStr.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

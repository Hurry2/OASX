import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/weekly_planner/models/weekly_planner_models.dart';
import 'package:oasx/modules/weekly_planner/weekly_planner_controller.dart';

/// Detail subpage for viewing and arranging weekly task schedules.
class WeeklyPlannerView extends StatefulWidget {
  const WeeklyPlannerView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<WeeklyPlannerView> createState() => _WeeklyPlannerViewState();
}

class _WeeklyPlannerViewState extends State<WeeklyPlannerView> {
  static const _dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const _shortLabels = ['一', '二', '三', '四', '五', '六', '日'];

  WeeklyPlannerController get _controller {
    if (!Get.isRegistered<WeeklyPlannerController>()) {
      Get.put<WeeklyPlannerController>(WeeklyPlannerController(), permanent: true);
    }
    return Get.find<WeeklyPlannerController>();
  }

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final scriptName = args is Map ? (args['scriptName'] ?? '').toString() : '';
    if (scriptName.isNotEmpty) {
      unawaited(_controller.loadForConfig(scriptName, force: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final name = _controller.activeScript.value;
          return Text(name.isEmpty ? '周常任务排期' : '周常任务排期 · $name');
        }),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () =>
                _controller.loadForConfig(_controller.activeScript.value, force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
        final summary = _controller.summary.value;
        if (_controller.loading.value && summary == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.error.value.isNotEmpty && summary == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_controller.error.value, style: TextStyle(color: scheme.error)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _controller.loadForConfig(
                    _controller.activeScript.value,
                    force: true,
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final tasks = _controller.filteredTasks;
        final today = summary?.todayWeekday ?? DateTime.now().weekday;
        final activeFilterDay = _controller.filterDay.value;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Mon-Sun count cards
              Row(
                children: [
                  for (var d = 1; d <= 7; d++) ...[
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _controller.toggleFilterDay(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: activeFilterDay == d
                                ? scheme.primaryContainer
                                : (d == today
                                    ? scheme.secondaryContainer.withValues(alpha: 0.45)
                                    : scheme.surfaceContainerLowest),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: activeFilterDay == d
                                  ? scheme.primary
                                  : (d == today ? scheme.secondary : scheme.outlineVariant),
                              width: activeFilterDay == d ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                d == today ? '${_dayLabels[d - 1]} · 今' : _dayLabels[d - 1],
                                style: TextStyle(
                                  fontWeight: d == today ? FontWeight.w700 : FontWeight.w600,
                                ),
                              ),
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                child: Text(
                                  '${summary?.counts[d] ?? 0}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (d < 7) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Filter toolbar
              Row(
                children: [
                  FilterChip(
                    label: const Text('仅看周常 / 已设周几'),
                    selected: _controller.onlyWeekly.value,
                    onSelected: (v) => _controller.onlyWeekly.value = v,
                  ),
                  const SizedBox(width: 12),
                  if (activeFilterDay > 0) ...[
                    InputChip(
                      label: Text('筛选: ${_dayLabels[activeFilterDay - 1]}'),
                      onDeleted: () => _controller.filterDay.value = 0,
                    ),
                    const SizedBox(width: 12),
                  ],
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '搜索任务名...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _controller.searchQuery.value = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Task table
              Expanded(
                child: Card(
                  child: tasks.isEmpty
                      ? const Center(child: Text('当前筛选条件下没有任务'))
                      : ListView.separated(
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _buildTaskRow(context, tasks[index]),
                        ),
                ),
              ),
            ],
          ),
        );
      });
  }

  Widget _buildTaskRow(BuildContext context, WeeklyPlannerTask task) {
    final scheme = Theme.of(context).colorScheme;
    final selected = task.weeklyDays
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toSet();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        task.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.isWeeklyMenu
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.isWeeklyMenu ? '周常' : task.group,
                        style: TextStyle(
                          fontSize: 10,
                          color: task.isWeeklyMenu
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  task.task,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: task.enable,
            onChanged: (v) => _controller.setTaskEnable(task, v),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  ChoiceChip(
                    label: Text(_shortLabels[d - 1]),
                    selected: selected.contains(d),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _controller.toggleTaskDay(task, d),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(
              task.nextRun,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => _controller.setTaskNextRunNow(task),
            child: const Text('设为立即'),
          ),
          TextButton(
            onPressed: () => _controller.clearTaskDays(task),
            child: const Text('清空周几'),
          ),
        ],
      ),
    );
  }
}

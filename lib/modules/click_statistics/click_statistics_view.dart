import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/click_statistics/click_statistics_controller.dart';
import 'package:oasx/modules/click_statistics/models/click_statistics_models.dart';
import 'package:oasx/modules/common/widgets/appbar.dart';

class ClickStatisticsView extends GetView<ClickStatisticsController> {
  const ClickStatisticsView({super.key});

  final GlobalKey _heatmapKey = const GlobalObjectKey(
    'click-statistics-heatmap',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildPlatformAppBar(
        context,
        routePath: '/click-statistics',
        trailingActions: [
          IconButton(
            tooltip: '刷新',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoadingConfigs.value && controller.configs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.configs.isEmpty) {
          return _buildError(context);
        }

        if (controller.configs.isEmpty) {
          return _buildEmpty(context, '暂无点击统计记录');
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;

            if (desktop) {
              return _buildDesktop(context);
            }

            return _buildMobile(context);
          },
        );
      }),
    );
  }

  // ===========================================================================
  // Desktop
  // ===========================================================================

  Widget _buildDesktop(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 380,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('筛选', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),

                    _buildConfigDropdown(context),
                    const SizedBox(height: 12),

                    _buildDateDropdown(context),
                    const SizedBox(height: 12),

                    _buildTaskDropdown(context),
                    const SizedBox(height: 20),

                    Text(
                      '运行记录',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),

                    Expanded(child: _buildSessionList(context)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(child: _buildDetailPanel(context)),
        ],
      ),
    );
  }

  // ===========================================================================
  // Mobile
  // ===========================================================================

  Widget _buildMobile(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSelectionPanel(context),
          const SizedBox(height: 16),

          SizedBox(height: 700, child: _buildDetailPanel(context)),
        ],
      ),
    );
  }

  Widget _buildSelectionPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('筛选', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            _buildConfigDropdown(context),
            const SizedBox(height: 12),

            _buildDateDropdown(context),
            const SizedBox(height: 12),

            _buildTaskDropdown(context),
            const SizedBox(height: 20),

            Text('运行记录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            Obx(() {
              if (controller.isLoadingSessions.value) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (controller.sessions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('该日期暂无运行记录')),
                );
              }

              return Column(
                children: controller.sessions
                    .map(
                      (session) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildSessionTile(
                          context,
                          session,
                          controller.selectedSession.value?.sessionId ==
                              session.sessionId,
                        ),
                      ),
                    )
                    .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Dropdown
  // ===========================================================================

  Widget _buildConfigDropdown(BuildContext context) {
    return Obx(() {
      final items = controller.configs;
      final selected = controller.selectedConfig.value;

      return DropdownButtonFormField<String>(
        initialValue: items.contains(selected) ? selected : null,
        decoration: const InputDecoration(
          labelText: '实例',
          border: OutlineInputBorder(),
        ),
        items: items
            .map(
              (value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: controller.isLoadingTasks.value
            ? null
            : controller.selectConfig,
      );
    });
  }

  Widget _buildTaskDropdown(BuildContext context) {
    return Obx(() {
      final items = controller.tasks;
      final selected = controller.selectedTask.value;

      return DropdownButtonFormField<String>(
        initialValue: items.contains(selected) ? selected : null,
        decoration: const InputDecoration(
          labelText: '任务',
          border: OutlineInputBorder(),
        ),
        items: items
            .map(
              (value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value.tr, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: controller.isLoadingDates.value
            ? null
            : controller.selectTask,
      );
    });
  }

  Widget _buildDateDropdown(BuildContext context) {
    return Obx(() {
      final items = controller.dates;
      final selected = controller.selectedDate.value;

      return DropdownButtonFormField<String>(
        initialValue: items.contains(selected) ? selected : null,
        decoration: const InputDecoration(
          labelText: '日期',
          border: OutlineInputBorder(),
        ),
        items: items
            .map(
              (value) =>
                  DropdownMenuItem<String>(value: value, child: Text(value)),
            )
            .toList(),
        onChanged: controller.isLoadingSessions.value
            ? null
            : controller.selectDate,
      );
    });
  }

  // ===========================================================================
  // Session list
  // ===========================================================================

  Widget _buildSessionList(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingSessions.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.sessions.isEmpty) {
        return const Center(child: Text('该日期暂无运行记录'));
      }

      return ListView.separated(
        itemCount: controller.sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final session = controller.sessions[index];

          final selected =
              controller.selectedSession.value?.sessionId == session.sessionId;

          return _buildSessionTile(context, session, selected);
        },
      );
    });
  }

  Widget _buildSessionTile(
    BuildContext context,
    ClickStatisticsSession session,
    bool selected,
  ) {
    final time = session.startTime;

    final timeText = time == null
        ? session.startTimeText
        : '${_twoDigits(time.hour)}:'
              '${_twoDigits(time.minute)}:'
              '${_twoDigits(time.second)}';

    return Material(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.selectSession(session),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                session.success
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: session.success ? Colors.green : Colors.red,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeText,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.totalClicks} 次点击 · '
                      '${session.totalSwipes} 次滑动 · '
                      '${_formatDuration(session.durationSeconds)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Detail
  // ===========================================================================

  Widget _buildDetailPanel(BuildContext context) {
    return Card(
      child: Obx(() {
        if (controller.isLoadingDetail.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final detail = controller.detail.value;

        if (detail == null) {
          return _buildEmpty(context, '选择一条运行记录查看详细点击数据');
        }

        return _buildDetail(context, detail);
      }),
    );
  }

  Widget _buildDetail(BuildContext context, ClickStatisticsDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  detail.task.tr,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),

              Icon(
                detail.success
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: detail.success ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(context, '总点击', '${detail.totalClicks}'),
              _buildStatCard(context, '总滑动', '${detail.totalSwipes}'),
              _buildStatCard(
                context,
                '运行时间',
                _formatDuration(detail.durationSeconds),
              ),
              _buildStatCard(context, '实例', detail.configName),
              _buildStatCard(
                context,
                '状态',
                detail.status.isEmpty
                    ? (detail.success ? '成功' : '失败')
                    : detail.status,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildHeatmap(context, detail),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Heatmap
  // ===========================================================================

  Widget _buildHeatmap(BuildContext context, ClickStatisticsDetail detail) {
    if (detail.events.isEmpty) {
      return const Center(child: Text('没有操作记录'));
    }

    return Obx(() {
      final currentTime = controller.timelineSeconds.value;
      final maxTime = detail.durationSeconds;

      final visibleEvents = detail.events
          .where((event) => event.t <= currentTime)
          .toList();

      final visibleClicks = visibleEvents
          .where((event) => event.isClick)
          .length;

      final visibleSwipes = visibleEvents
          .where((event) => event.isSwipe)
          .length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----------------------------------------------------------------
          // 标题
          // ----------------------------------------------------------------
          Row(
            children: [
              Text('点击热力图', style: Theme.of(context).textTheme.titleMedium),

              const SizedBox(width: 12),

              Text(
                '${visibleEvents.length} / ${detail.events.length} 次操作',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const Spacer(),

              Text('连线', style: Theme.of(context).textTheme.bodySmall),

              Switch(
                value: controller.showClickPath.value,
                onChanged: controller.setShowClickPath,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),

              const SizedBox(width: 8),

              Text('1280 × 720', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),

          const SizedBox(height: 12),

          // ----------------------------------------------------------------
          // 热力图
          // ----------------------------------------------------------------
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1280 / 720,
                child: Container(
                  key: _heatmapKey,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.precise,
                    onHover: (event) {
                      final renderObject = _heatmapKey.currentContext
                          ?.findRenderObject();

                      if (renderObject is! RenderBox) {
                        return;
                      }

                      final localPosition = renderObject.globalToLocal(
                        event.position,
                      );

                      _updateHoveredEvent(
                        localPosition,
                        renderObject.size,
                        visibleEvents,
                      );
                    },
                    onExit: (_) {
                      if (controller.hoveredEvent.value != null) {
                        controller.setHoveredEvent(null);
                      }
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ClickHeatmapPainter(
                              events: visibleEvents,
                              showClickPath: controller.showClickPath.value,
                            ),
                          ),
                        ),

                        Obx(() {
                          final hovered = controller.hoveredEvent.value;

                          if (hovered == null) {
                            return const SizedBox.shrink();
                          }

                          return _buildHoverInfo(context, hovered);
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ----------------------------------------------------------------
          // 时间轴
          // ----------------------------------------------------------------
          Row(
            children: [
              IconButton(
                tooltip: controller.isPlayingTimeline.value ? '暂停' : '播放',
                onPressed: controller.toggleTimelinePlayback,
                icon: Icon(
                  controller.isPlayingTimeline.value
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),

              IconButton(
                tooltip: '回到开始',
                onPressed: controller.resetTimeline,
                icon: const Icon(Icons.replay_rounded),
              ),

              Expanded(
                child: Slider(
                  min: 0,
                  max: maxTime > 0 ? maxTime : 1,
                  value: currentTime.clamp(0, maxTime > 0 ? maxTime : 1),
                  onChanged: controller.setTimelineSeconds,
                ),
              ),

              SizedBox(
                width: 100,
                child: Text(
                  '${_formatTimelineTime(currentTime)} / '
                  '${_formatTimelineTime(maxTime)}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              const SizedBox(width: 8),

              Obx(() {
                return DropdownButton<double>(
                  value: controller.timelineSpeed.value,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('1×')),
                    DropdownMenuItem(value: 2.0, child: Text('2×')),
                    DropdownMenuItem(value: 4.0, child: Text('4×')),
                    DropdownMenuItem(value: 8.0, child: Text('8×')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.setTimelineSpeed(value);
                    }
                  },
                );
              }),
            ],
          ),

          const SizedBox(height: 4),

          // ----------------------------------------------------------------
          // 底部统计
          // ----------------------------------------------------------------
          Row(
            children: [
              Text(
                '已显示 ${visibleEvents.length} 次操作 '
                '($visibleClicks 次点击 · $visibleSwipes 次滑动)',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const Spacer(),

              TextButton(
                onPressed: controller.showFullTimeline,
                child: const Text('显示全部'),
              ),

              TextButton(
                onPressed: controller.resetTimeline,
                child: const Text('归零'),
              ),
            ],
          ),
        ],
      );
    });
  }

  // ===========================================================================
  // Hover event
  // ===========================================================================

  void _updateHoveredEvent(
    Offset localPosition,
    Size size,
    List<ClickStatisticsEvent> events,
  ) {
    const sourceWidth = 1280.0;
    const sourceHeight = 720.0;

    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final drawWidth = sourceWidth * scale;
    final drawHeight = sourceHeight * scale;

    final offsetX = (size.width - drawWidth) / 2;
    final offsetY = (size.height - drawHeight) / 2;

    final sourceX = (localPosition.dx - offsetX) / scale;
    final sourceY = (localPosition.dy - offsetY) / scale;

    if (sourceX < 0 ||
        sourceX >= sourceWidth ||
        sourceY < 0 ||
        sourceY >= sourceHeight) {
      controller.setHoveredEvent(null);
      return;
    }

    const hitRadius = 12.0;
    const hitRadiusSquared = hitRadius * hitRadius;

    ClickStatisticsEvent? nearest;

    double nearestDistanceSquared = double.infinity;

    for (final event in events) {
      if (event.isSwipe) {
        final startX = event.startX?.toDouble();
        final startY = event.startY?.toDouble();
        final endX = event.endX?.toDouble();
        final endY = event.endY?.toDouble();

        if (startX == null || startY == null || endX == null || endY == null) {
          continue;
        }

        final distanceSquared = _distanceToLineSegmentSquared(
          sourceX,
          sourceY,
          startX,
          startY,
          endX,
          endY,
        );

        if (distanceSquared <= hitRadiusSquared &&
            distanceSquared < nearestDistanceSquared) {
          nearestDistanceSquared = distanceSquared;
          nearest = event;
        }
      } else {
        final x = event.x?.toDouble();
        final y = event.y?.toDouble();

        if (x == null || y == null) {
          continue;
        }

        final dx = x - sourceX;
        final dy = y - sourceY;

        final distanceSquared = dx * dx + dy * dy;

        if (distanceSquared <= hitRadiusSquared &&
            distanceSquared < nearestDistanceSquared) {
          nearestDistanceSquared = distanceSquared;
          nearest = event;
        }
      }
    }

    if (!identical(controller.hoveredEvent.value, nearest)) {
      controller.setHoveredEvent(nearest);
    }
  }

  double _distanceToLineSegmentSquared(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      final diffX = px - x1;
      final diffY = py - y1;

      return diffX * diffX + diffY * diffY;
    }

    final t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);

    final clampedT = t.clamp(0.0, 1.0);

    final nearestX = x1 + clampedT * dx;
    final nearestY = y1 + clampedT * dy;

    final diffX = px - nearestX;
    final diffY = py - nearestY;

    return diffX * diffX + diffY * diffY;
  }

  // ===========================================================================
  // Hover info
  // ===========================================================================

  Widget _buildHoverInfo(BuildContext context, ClickStatisticsEvent event) {
    const width = 250.0;

    final renderObject = _heatmapKey.currentContext?.findRenderObject();

    double left = 14;
    double top = 14;

    final displayX = event.displayX;
    final displayY = event.displayY;

    if (renderObject is RenderBox && displayX != null && displayY != null) {
      final size = renderObject.size;

      const sourceWidth = 1280.0;
      const sourceHeight = 720.0;

      final scaleX = size.width / sourceWidth;
      final scaleY = size.height / sourceHeight;
      final scale = scaleX < scaleY ? scaleX : scaleY;

      final drawWidth = sourceWidth * scale;
      final drawHeight = sourceHeight * scale;

      final offsetX = (size.width - drawWidth) / 2;
      final offsetY = (size.height - drawHeight) / 2;

      final position = Offset(
        offsetX + displayX * scale,
        offsetY + displayY * scale,
      );

      left = position.dx + 14;
      top = position.dy + 14;

      final estimatedHeight = event.isSwipe ? 250.0 : 195.0;

      if (left + width > size.width) {
        left = position.dx - width - 14;
      }

      if (top + estimatedHeight > size.height) {
        top = position.dy - estimatedHeight - 14;
      }

      left = left.clamp(4.0, size.width - width - 4);

      top = top.clamp(4.0, size.height - estimatedHeight - 4);
    }

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Material(
          elevation: 6,
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.isSwipe) ...[
                  _buildHoverRow('起点', '${event.startX}, ${event.startY}'),

                  _buildHoverRow('终点', '${event.endX}, ${event.endY}'),

                  _buildHoverRow('距离', _formatSwipeDistance(event)),

                  _buildHoverRow(
                    '持续',
                    event.duration == null
                        ? '-'
                        : '${event.duration!.toStringAsFixed(3)}s',
                  ),

                  _buildHoverRow(
                    '耗时',
                    event.elapsed == null
                        ? '-'
                        : '${event.elapsed!.toStringAsFixed(3)}s',
                  ),
                ] else ...[
                  _buildHoverRow('坐标', '${event.x}, ${event.y}'),
                ],

                _buildHoverRow('时间', '${event.t.toStringAsFixed(3)}s'),

                _buildHoverRow(
                  '间隔',
                  event.interval == null
                      ? '-'
                      : '${event.interval!.toStringAsFixed(3)}s',
                ),

                _buildHoverRow('控件', event.controlName),

                _buildHoverRow('方式', event.method),

                _buildHoverRow('时间戳', event.timestamp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSwipeDistance(ClickStatisticsEvent event) {
    final startX = event.startX;
    final startY = event.startY;
    final endX = event.endX;
    final endY = event.endY;

    if (startX == null || startY == null || endX == null || endY == null) {
      return '-';
    }

    final dx = endX - startX;
    final dy = endY - startY;

    final distance = math.sqrt(dx * dx + dy * dy);

    return '${distance.toStringAsFixed(1)}px';
  }

  Widget _buildHoverRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(title, style: const TextStyle(color: Colors.black54)),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF222222)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Stat card
  // ===========================================================================

  Widget _buildStatCard(BuildContext context, String title, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  // ===========================================================================
  // Empty / Error
  // ===========================================================================

  Widget _buildEmpty(BuildContext context, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),

            Text(controller.errorMessage.value, textAlign: TextAlign.center),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Formatting
  // ===========================================================================

  String _formatDuration(double seconds) {
    final total = seconds.round();

    final minutes = total ~/ 60;
    final remainSeconds = total % 60;

    if (minutes > 0) {
      return '$minutes分'
          '${_twoDigits(remainSeconds)}秒';
    }

    return '$remainSeconds秒';
  }

  String _formatTimelineTime(double seconds) {
    final totalSeconds = seconds.floor();

    final minutes = totalSeconds ~/ 60;
    final remainSeconds = totalSeconds % 60;

    return '$minutes:'
        '${remainSeconds.toString().padLeft(2, '0')}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

// ============================================================================
// Click Heatmap Painter
// ============================================================================

class ClickHeatmapPainter extends CustomPainter {
  ClickHeatmapPainter({required this.events, required this.showClickPath});

  final List<ClickStatisticsEvent> events;

  /// 是否按时间顺序把点击点连成一条线。
  final bool showClickPath;

  static const double sourceWidth = 1280;
  static const double sourceHeight = 720;

  static const double gridSize = 40;
  static const double pointRadius = 2.5;

  /// 温度图的统计格边长。
  static const double heatCellSize = 32;

  /// 单个热区的扩散半径。
  ///
  /// 取两格：相邻格子的光斑大幅重叠，边界就被抹平了，不会出现马赛克。
  static const double heatBlobRadius = heatCellSize * 2;

  /// 热区不透明度区间：最冷 / 最热。
  static const double heatMinOpacity = 0.30;
  static const double heatMaxOpacity = 0.85;

  /// 冷热刻度的下限（一个格子里至少这么多下才算「最热」）。
  ///
  /// 密度是相对的（`本格点击 / 本场最高`），但整场只有两三次点击时
  /// 不该全屏刷成红黄，所以给一个下限兜着。
  static const int heatMinScale = 5;

  /// 温度图调色板：蓝（最冷）→ 青 → 绿 → 黄 → 红（最热）。
  static const List<Color> heatPalette = <Color>[
    Color(0xFF2C7BE5),
    Color(0xFF00B4D8),
    Color(0xFF2ECC71),
    Color(0xFFF1C40F),
    Color(0xFFE74C3C),
  ];

  /// 连线颜色。
  ///
  /// 热力图本身是灰阶的，用橙色才拉得开；但整体压淡，免得盖住底下的点。
  static const Color pathColor = Color(0xFFE8590C);

  /// 连线和箭头的不透明度。
  ///
  /// 想让线更淡/更明显就改这两个值。
  static const double pathLineOpacity = 0.45;
  static const double pathArrowOpacity = 0.65;
  static const double pathStrokeWidth = 1.6;
  static const double pathArrowLength = 7;
  static const double pathArrowWidth = 3.5;
  static const double pathStartRadius = 4.5;

  /// 短于这个长度的线段不画方向箭头。
  ///
  /// 否则连点两下同一个按钮时，箭头会叠在一起糊成一团。
  static const double pathMinArrowSegment = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final scale = scaleX < scaleY ? scaleX : scaleY;

    final drawWidth = sourceWidth * scale;
    final drawHeight = sourceHeight * scale;

    final offsetX = (size.width - drawWidth) / 2;
    final offsetY = (size.height - drawHeight) / 2;

    canvas.save();

    canvas.translate(offsetX, offsetY);

    canvas.scale(scale);

    // ------------------------------------------------------------------------
    // Background
    // ------------------------------------------------------------------------

    final backgroundPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFF7F7F7);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
      backgroundPaint,
    );

    // ------------------------------------------------------------------------
    // Grid
    // ------------------------------------------------------------------------

    _drawGrid(canvas, sourceWidth, sourceHeight);

    // ------------------------------------------------------------------------
    // Heat
    // ------------------------------------------------------------------------

    _drawHeat(canvas);

    // ------------------------------------------------------------------------
    // Swipe paths
    // ------------------------------------------------------------------------

    final swipePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF444444)
      ..isAntiAlias = true;

    final swipeEndpointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF303030)
      ..isAntiAlias = true;

    for (final event in events) {
      if (!event.isSwipe) {
        continue;
      }

      final startX = event.startX?.clamp(0, 1279);
      final startY = event.startY?.clamp(0, 719);
      final endX = event.endX?.clamp(0, 1279);
      final endY = event.endY?.clamp(0, 719);

      if (startX == null || startY == null || endX == null || endY == null) {
        continue;
      }

      final start = Offset(startX.toDouble(), startY.toDouble());

      final end = Offset(endX.toDouble(), endY.toDouble());

      canvas.drawLine(start, end, swipePaint);

      const radius = 4.0;

      canvas.drawCircle(start, radius, swipeEndpointPaint);

      canvas.drawCircle(end, radius, swipeEndpointPaint);

      _drawSwipeArrow(canvas, start, end, swipePaint);
    }

    // ------------------------------------------------------------------------
    // Click path
    // ------------------------------------------------------------------------

    if (showClickPath) {
      _drawClickPath(canvas);
    }

    // ------------------------------------------------------------------------
    // Actual click points
    // ------------------------------------------------------------------------

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1E1E1E)
      ..isAntiAlias = true;

    for (final event in events) {
      if (!event.isClick) {
        continue;
      }

      final x = event.x!.clamp(0, 1279).toDouble();
      final y = event.y!.clamp(0, 719).toDouble();

      canvas.drawCircle(Offset(x, y), pointRadius, pointPaint);
    }

    // ------------------------------------------------------------------------
    // Border
    // ------------------------------------------------------------------------

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF888888);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
      borderPaint,
    );

    // ------------------------------------------------------------------------
    // Coordinate labels
    // ------------------------------------------------------------------------

    _drawCoordinateLabels(canvas);

    canvas.restore();
  }

  /// 在 [end] 处画一个指向线段方向的箭头。
  ///
  /// [arrowLength] / [arrowWidth] 默认是滑动箭头的大小，连线用的是更小的一档。
  void _drawSwipeArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double arrowLength = 10.0,
    double arrowWidth = 5.0,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    final length = math.sqrt(dx * dx + dy * dy);

    if (length < 1) {
      return;
    }

    final unitX = dx / length;
    final unitY = dy / length;

    final tip = end;

    final base = Offset(
      end.dx - unitX * arrowLength,
      end.dy - unitY * arrowLength,
    );

    final perpendicular = Offset(-unitY, unitX);

    final left = Offset(
      base.dx + perpendicular.dx * arrowWidth,
      base.dy + perpendicular.dy * arrowWidth,
    );

    final right = Offset(
      base.dx - perpendicular.dx * arrowWidth,
      base.dy - perpendicular.dy * arrowWidth,
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    final arrowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = paint.color;

    canvas.drawPath(path, arrowPaint);
  }

  /// 按时间顺序把所有点击点连成一条线。
  ///
  /// 后端是按实际执行顺序 append 事件的，所以列表顺序就是点击顺序，不用再排序。
  /// 播放时传进来的 [events] 只包含已经发生的事件，线条会跟着进度逐段长出来。
  ///
  /// 只连 click：滑动本身已经有自己的箭头，混进来反而看不出点击顺序。
  void _drawClickPath(Canvas canvas) {
    final points = <Offset>[];

    for (final event in events) {
      if (!event.isClick) {
        continue;
      }

      final x = event.x?.clamp(0, 1279);
      final y = event.y?.clamp(0, 719);

      if (x == null || y == null) {
        continue;
      }

      points.add(Offset(x.toDouble(), y.toDouble()));
    }

    if (points.length < 2) {
      return;
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pathStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = pathColor.withValues(alpha: pathLineOpacity)
      ..isAntiAlias = true;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    // 箭头单独一档透明度：线压淡了，方向得还能看清。
    final arrowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = pathColor.withValues(alpha: pathArrowOpacity)
      ..isAntiAlias = true;

    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];

      if ((to - from).distance < pathMinArrowSegment) {
        continue;
      }

      _drawSwipeArrow(
        canvas,
        from,
        to,
        arrowPaint,
        arrowLength: pathArrowLength,
        arrowWidth: pathArrowWidth,
      );
    }

    // 起点画个空心圈，和终点区分开。
    final startPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pathStrokeWidth
      ..color = pathColor.withValues(alpha: pathArrowOpacity)
      ..isAntiAlias = true;

    canvas.drawCircle(points.first, pathStartRadius, startPaint);
  }

  /// 把点击密度画成一片温度图。
  ///
  /// 做法是「按格统计密度 → 每格画一个径向渐变光斑」，不是画方块：
  /// 光斑半径是格子的两倍，相邻格子互相叠加，边界就化开了。
  /// 按密度从小到大画，热的压在上面，重叠处自然就是「热色赢」。
  void _drawHeat(Canvas canvas) {
    final density = <String, int>{};

    for (final event in events) {
      if (!event.isClick) {
        continue;
      }

      final x = event.x?.clamp(0, 1279);
      final y = event.y?.clamp(0, 719);

      if (x == null || y == null) {
        continue;
      }

      final gx = (x / heatCellSize).floor();
      final gy = (y / heatCellSize).floor();

      final key = '$gx:$gy';

      density[key] = (density[key] ?? 0) + 1;
    }

    if (density.isEmpty) {
      return;
    }

    final maxCount = density.values.reduce((a, b) => a > b ? a : b);

    final scaleMax = math.max(maxCount, heatMinScale);

    final cells = density.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (final entry in cells) {
      final parts = entry.key.split(':');

      final center = Offset(
        int.parse(parts[0]) * heatCellSize + heatCellSize / 2,
        int.parse(parts[1]) * heatCellSize + heatCellSize / 2,
      );

      final ratio = entry.value / scaleMax;

      final alpha = heatMinOpacity + (heatMaxOpacity - heatMinOpacity) * ratio;

      final color = _paletteColor(ratio).withValues(alpha: alpha);

      canvas.drawCircle(
        center,
        heatBlobRadius,
        Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[
                  color,
                  color.withValues(alpha: alpha * 0.5),
                  color.withValues(alpha: 0),
                ],
                stops: const <double>[0, 0.45, 1],
              ).createShader(
                Rect.fromCircle(center: center, radius: heatBlobRadius),
              )
          ..isAntiAlias = true,
      );
    }
  }

  /// 在 [heatPalette] 上按 [ratio]（0 ~ 1）插值取色。
  static Color _paletteColor(double ratio) {
    // `clamp` 返回 num，不转 double 的话 `Color.lerp` 的 t 过不了类型检查。
    final scaled = ratio.clamp(0.0, 1.0).toDouble() * (heatPalette.length - 1);

    // `clamp` 同样返回 num，直接用会变成「num 当列表下标」；math.min 保 int。
    final lower = math.min(scaled.floor(), heatPalette.length - 2);

    return Color.lerp(
      heatPalette[lower],
      heatPalette[lower + 1],
      scaled - lower,
    )!;
  }

  void _drawGrid(Canvas canvas, double width, double height) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFDCDCDC);

    for (double x = 0; x <= width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }

    for (double y = 0; y <= height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    const majorGrid = gridSize * 5;

    final majorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFBBBBBB);

    for (double x = 0; x <= width; x += majorGrid) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), majorPaint);
    }

    for (double y = 0; y <= height; y += majorGrid) {
      canvas.drawLine(Offset(0, y), Offset(width, y), majorPaint);
    }
  }

  void _drawCoordinateLabels(Canvas canvas) {
    const textStyle = TextStyle(fontSize: 11, color: Color(0xFF777777));

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int x = 0; x <= 1200; x += 200) {
      textPainter.text = TextSpan(text: '$x', style: textStyle);

      textPainter.layout();

      textPainter.paint(canvas, Offset(x + 3, 3));
    }

    for (int y = 0; y <= 600; y += 200) {
      textPainter.text = TextSpan(text: '$y', style: textStyle);

      textPainter.layout();

      textPainter.paint(canvas, Offset(3, y + 3));
    }
  }

  @override
  bool shouldRepaint(covariant ClickHeatmapPainter oldDelegate) {
    return oldDelegate.events != events ||
        oldDelegate.showClickPath != showClickPath;
  }
}

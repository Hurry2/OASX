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
      return const Center(child: Text('没有点击记录'));
    }

    return Obx(() {
      final currentTime = controller.timelineSeconds.value;

      final maxTime = detail.durationSeconds;

      final intensity = controller.heatIntensity.value;

      final visibleEvents = detail.events
          .where((event) => event.t <= currentTime)
          .toList();

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
                '${visibleEvents.length} / '
                '${detail.events.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const Spacer(),

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
                              intensity: intensity,
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
          // 强度
          // ----------------------------------------------------------------
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text('强度', style: Theme.of(context).textTheme.bodySmall),
              ),

              Expanded(
                child: Slider(
                  min: 0.2,
                  max: 1.5,
                  value: intensity.clamp(0.2, 1.5),
                  onChanged: controller.setHeatIntensity,
                ),
              ),

              SizedBox(
                width: 50,
                child: Text(
                  '${(intensity * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),

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
                  '${_formatTimelineTime(currentTime)} / ${_formatTimelineTime(maxTime)}',
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
                '已显示 ${visibleEvents.length} 次点击',
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

    // 当前热力图始终保持 1280:720 比例。
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

    // 鼠标需要靠近真实点击点才触发。
    const hitRadius = 12.0;
    const hitRadiusSquared = hitRadius * hitRadius;

    ClickStatisticsEvent? nearest;

    double nearestDistanceSquared = hitRadiusSquared;

    for (final event in events) {
      final dx = event.x - sourceX;

      final dy = event.y - sourceY;

      final distanceSquared = dx * dx + dy * dy;

      if (distanceSquared <= nearestDistanceSquared) {
        nearestDistanceSquared = distanceSquared;

        nearest = event;
      }
    }

    if (!identical(controller.hoveredEvent.value, nearest)) {
      controller.setHoveredEvent(nearest);
    }
  }

  // ===========================================================================
  // Hover info
  // ===========================================================================

  Widget _buildHoverInfo(BuildContext context, ClickStatisticsEvent event) {
    const width = 250.0;

    final renderObject = _heatmapKey.currentContext?.findRenderObject();

    double left = 14;
    double top = 14;

    if (renderObject is RenderBox) {
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
        offsetX + event.x * scale,
        offsetY + event.y * scale,
      );

      left = position.dx + 14;
      top = position.dy + 14;

      const estimatedHeight = 195.0;

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
                const SizedBox(height: 8),

                _buildHoverRow('坐标', '${event.x}, ${event.y}'),

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
  ClickHeatmapPainter({required this.events, required this.intensity});

  final List<ClickStatisticsEvent> events;
  final double intensity;

  static const double sourceWidth = 1280;
  static const double sourceHeight = 720;

  static const double gridSize = 40;
  static const double pointRadius = 2.5;

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
    // Density
    // ------------------------------------------------------------------------

    final density = <String, int>{};

    for (final event in events) {
      final x = event.x.clamp(0, 1279);

      final y = event.y.clamp(0, 719);

      final gx = (x / gridSize).floor();

      final gy = (y / gridSize).floor();

      final key = '$gx:$gy';

      density[key] = (density[key] ?? 0) + 1;
    }

    if (density.isNotEmpty) {
      final maxDensity = density.values.reduce((a, b) => a > b ? a : b);

      for (final entry in density.entries) {
        final parts = entry.key.split(':');

        final gx = int.parse(parts[0]);

        final gy = int.parse(parts[1]);

        final count = entry.value;

        final ratio = count / maxDensity;

        final alpha = (0.06 + ratio * 0.50 * intensity).clamp(0.03, 0.65);

        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF505050).withValues(alpha: alpha);

        final rect = Rect.fromLTWH(
          gx * gridSize,
          gy * gridSize,
          gridSize,
          gridSize,
        );

        canvas.drawRect(rect, paint);
      }
    }

    // ------------------------------------------------------------------------
    // Actual click points
    // ------------------------------------------------------------------------

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1E1E1E)
      ..isAntiAlias = true;

    for (final event in events) {
      final x = event.x.clamp(0, 1279).toDouble();

      final y = event.y.clamp(0, 719).toDouble();

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
    return oldDelegate.events != events || oldDelegate.intensity != intensity;
  }
}

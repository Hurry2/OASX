part of 'task_status_row.dart';

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({
    required this.controller,
    required this.sourceScriptName,
    required this.task,
    required this.onSetNextRun,
    required this.dragEnabled,
  });

  final HomeDashboardController controller;
  final String sourceScriptName;
  final TaskStatusViewData task;
  final Future<void> Function(String taskName, String nextRun) onSetNextRun;
  final bool dragEnabled;

  @override
  Widget build(BuildContext context) {
    final payload = controller.buildTaskDragPayload(
      sourceConfig: sourceScriptName,
      taskName: task.name,
    );
    final title = Text(
      task.name.tr,
      maxLines: 1,
      overflow: TextOverflow.visible,
      softWrap: false,
      style: Theme.of(context).textTheme.labelLarge,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dragEnabled
            ? Draggable<ConfigDragPayload>(
                data: payload,
                feedback: DragCopyFeedback(label: payload.displayLabel),
                onDragStarted: () => controller.startConfigDrag(payload),
                onDragCompleted: controller.clearConfigDrag,
                onDraggableCanceled: (_, __) => controller.clearConfigDrag(),
                onDragEnd: (_) => controller.clearConfigDrag(),
                child: title,
              )
            : title,
        if (task.timeText.isNotEmpty) ...[
          const SizedBox(height: 3),
          _TimeChip(timeText: task.timeText, task: task, onSetNextRun: onSetNextRun),
        ],
      ],
    );
  }
}

/// Compact time badge shown below the task name for pending/waiting tasks.
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.timeText,
    required this.task,
    required this.onSetNextRun,
  });

  final String timeText;
  final TaskStatusViewData task;
  final Future<void> Function(String taskName, String nextRun) onSetNextRun;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPending = task.type == TaskStatusType.pending;
    final chipColor = isPending
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHigh;
    final textColor = isPending
        ? scheme.onTertiaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.flash_on_rounded : Icons.schedule_rounded,
            size: 10,
            color: textColor,
          ),
          const SizedBox(width: 3),
          DateTimePicker(
            value: timeText,
            notHoverStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontSize: 10,
            ),
            hoverStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontSize: 10,
            ),
            onChange: (value) => unawaited(onSetNextRun(task.name, value)),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing dot for running tasks.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTypeIcon extends StatelessWidget {
  const _TaskTypeIcon({required this.type});

  final TaskStatusType type;

  @override
  Widget build(BuildContext context) {
    if (type == TaskStatusType.running) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Center(child: _PulsingDot(color: Colors.green.shade500)),
      );
    }
    final icon = switch (type) {
      TaskStatusType.pending =>
        const Icon(Icons.layers_rounded, color: Colors.orange),
      TaskStatusType.waiting =>
        Icon(Icons.schedule_rounded, color: Colors.blueGrey.shade400),
      TaskStatusType.running => const SizedBox.shrink(), // unreachable
    };
    return SizedBox(width: 28, height: 28, child: Center(child: icon));
  }
}

class _TaskActionBar extends StatelessWidget {
  const _TaskActionBar({
    required this.onQuickRun,
    required this.onQuickWait,
    required this.onEditTask,
  });

  final VoidCallback? onQuickRun;
  final VoidCallback? onQuickWait;
  final VoidCallback? onEditTask;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TaskActionIcon(
          icon: Icons.flash_on_rounded,
          tooltip: I18n.homeQuickRun.tr,
          onPressed: onQuickRun,
        ),
        _TaskActionIcon(
          icon: Icons.schedule_rounded,
          tooltip: I18n.homeQuickWait.tr,
          onPressed: onQuickWait,
        ),
        _TaskActionIcon(
          icon: Icons.tune_rounded,
          tooltip: I18n.homeOpenTaskParams.tr,
          onPressed: onEditTask,
        ),
      ],
    );
  }
}

class _TaskActionIcon extends StatelessWidget {
  const _TaskActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

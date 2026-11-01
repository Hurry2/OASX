part of 'log_center_panel.dart';

/// Info log list: task cards, and the lines of the opened task.
class LogCenterInfoView extends StatelessWidget {
  /// Creates the info log view.
  const LogCenterInfoView({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.horizontalScrollController,
    required this.onScrollNotification,
  });

  /// Log browser controller.
  final ScriptLogBrowserController controller;

  /// Scroll controller owned by panel state.
  final ScrollController scrollController;

  /// Horizontal scroll controller used when wrapping is disabled.
  final ScrollController horizontalScrollController;

  /// Scroll notification handler.
  final bool Function(ScrollNotification notification) onScrollNotification;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.infoLoading.value && controller.lines.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.infoError.value.isNotEmpty && controller.lines.isEmpty) {
        return _buildMessage(context, controller.infoError.value);
      }
      if (controller.lines.isEmpty) {
        return _buildMessage(context, I18n.homeNoLog.tr);
      }
      final openedTask = controller.isLogTaskOpened;
      return Column(
        children: [
          if (controller.olderLoading.value)
            const LinearProgressIndicator(minHeight: 2),
          if (openedTask) _buildTaskHeader(context),
          Expanded(child: _buildList(context, controller.wrapLines.value)),
        ],
      );
    });
  }

  Widget _buildList(BuildContext context, bool wrapLines) {
    return Scrollbar(
      controller: scrollController,
      interactive: true,
      thumbVisibility: true,
      notificationPredicate: (notification) {
        return notification.metrics.axis == Axis.vertical;
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ClipRect(child: _buildScrollableArea(context, wrapLines)),
      ),
    );
  }

  Widget _buildScrollableArea(BuildContext context, bool wrapLines) {
    // 任务卡片列表永远按行宽换行, 只有打开某个任务的日志才需要横向滚动。
    if (wrapLines || !controller.isLogTaskOpened) {
      return _buildVerticalList(context, wrapLines: true);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _resolveContentWidth(context, constraints.maxWidth);
        return Scrollbar(
          controller: horizontalScrollController,
          interactive: true,
          thumbVisibility: width > constraints.maxWidth,
          notificationPredicate: (notification) {
            return notification.metrics.axis == Axis.horizontal;
          },
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: _buildVerticalList(context, wrapLines: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalList(BuildContext context, {required bool wrapLines}) {
    final rows = controller.logRows;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _openCopyDialog(context),
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: ListView.builder(
          key: ValueKey<String>('log-info-${controller.scriptName}'),
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final section = row.section;
            if (section != null) {
              return _buildTaskCard(context, section);
            }
            return LogCenterLogText(
              line: row.line?.text ?? '',
              maxLines: wrapLines ? null : 1,
              overflow: wrapLines ? TextOverflow.clip : TextOverflow.visible,
              softWrap: wrapLines,
            );
          },
        ),
      ),
    );
  }

  /// Builds one tappable task card that opens the task log.
  Widget _buildTaskCard(BuildContext context, ScriptLogSection section) {
    final range = _sectionTimeRange(section);
    final count = '${section.lineCount} ${I18n.homeLogSectionLines.tr}';
    final failure = controller.logTaskFailureMessage(section);
    final subtitle = <String>[
      if (range != null) range,
      count,
      if (failure.isNotEmpty) I18n.homeLogTaskFailed.tr,
    ].join(' · ');
    return Card(
      key: ValueKey<String>('log-task-card-${section.key}'),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        title: Text(
          _sectionLabel(section),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failure.isNotEmpty) _buildFailureMark(context, failure),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => controller.openLogTask(section.key),
      ),
    );
  }

  /// Builds the "failed and restarted" mark, using the failure line as tooltip.
  Widget _buildFailureMark(BuildContext context, String message) {
    return Tooltip(
      message: message,
      child: Icon(
        Icons.error_outline_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Builds the header with the back action while a task log is open.
  Widget _buildTaskHeader(BuildContext context) {
    final label = controller.openedLogTaskLabel.value.trim().isEmpty
        ? I18n.homeLogSectionUnknown.tr
        : controller.openedLogTaskLabel.value;
    final failure = controller.openedLogTaskFailureMessage;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey<String>('log-task-back'),
            tooltip: I18n.back.tr,
            onPressed: controller.backToLogTaskList,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              '$label · ${controller.openedLogTaskLines.length} '
              '${I18n.homeLogSectionLines.tr}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (failure.isNotEmpty) ...[
            const SizedBox(width: 4),
            _buildFailureMark(context, failure),
          ],
        ],
      ),
    );
  }

  /// Resolves one display label for a task section.
  String _sectionLabel(ScriptLogSection section) {
    return section.label.trim().isEmpty
        ? I18n.homeLogSectionUnknown.tr
        : section.label;
  }

  /// Builds the `first ~ last` timestamp range of one task section.
  String? _sectionTimeRange(ScriptLogSection section) {
    final lines = controller.lines;
    if (section.firstIndex >= lines.length ||
        section.lastIndex >= lines.length) {
      return null;
    }
    final first = _leadingTimestamp(lines[section.firstIndex].text);
    final last = _leadingTimestamp(lines[section.lastIndex].text);
    if (first == null && last == null) {
      return null;
    }
    if (first == null) {
      return last;
    }
    if (last == null || last == first) {
      return first;
    }
    return '$first ~ $last';
  }

  double _resolveContentWidth(BuildContext context, double viewportWidth) {
    final fontSize = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
    final longest = controller.maxLineWidthScore;
    final estimatedWidth = longest * fontSize * 0.64 + 48;
    return estimatedWidth < viewportWidth ? viewportWidth : estimatedWidth;
  }

  Widget _buildMessage(BuildContext context, String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  /// Opens the dedicated copy dialog with the current info log body.
  void _openCopyDialog(BuildContext context) {
    showLogCenterCopyDialog(
      context,
      text: controller.infoLogText,
      onCopy: controller.copyText,
    );
  }
}

/// Extracts the leading `timestamp |` prefix of one log line.
String? _leadingTimestamp(String text) {
  final separator = text.indexOf(' | ');
  if (separator <= 0) {
    return null;
  }
  final candidate = text.substring(0, separator).trim();
  return candidate.contains(':') ? candidate : null;
}
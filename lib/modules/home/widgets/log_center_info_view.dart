part of 'log_center_panel.dart';

/// Cache of raw label → localized label, keyed by locale + label.
final Map<String, String> _logLabelCache = <String, String>{};

/// Looks [label] up in one translation [table], ignoring case; '' when missing.
///
/// Split out from [_localizedLogLabel] so the matching rule is unit testable without
/// touching the GetX translation registry.
String localizedLogLabelFrom(String label, Map<String, String> table) {
  final trimmed = label.trim();

  if (trimmed.isEmpty) {
    return '';
  }

  final direct = table[trimmed];

  if (direct != null) {
    return direct;
  }

  final wanted = trimmed.toLowerCase();

  for (final entry in table.entries) {
    if (entry.key.toLowerCase() == wanted) {
      return entry.value;
    }
  }

  return '';
}

/// Localizes one task label that came from the log window.
///
/// Newer OAS builds already annotate lines with the localized name (`大富翁`), but
/// older ones send the raw banner title in upper case (`DEMONENCOUNTER`). Look those
/// up in the loaded dictionary case-insensitively so both ends render as Chinese.
String _localizedLogLabel(String label) {
  final trimmed = label.trim();

  if (trimmed.isEmpty) {
    return '';
  }

  final direct = trimmed.tr;

  if (direct != trimmed) {
    return direct;
  }

  final locale = Get.locale ?? Get.fallbackLocale ?? const Locale('zh', 'CN');
  final cacheKey = '${locale.toString()}|${trimmed.toLowerCase()}';
  final cached = _logLabelCache[cacheKey];

  if (cached != null) {
    return cached;
  }

  final table =
      Get.translations[locale.toString()] ??
      Get.translations['zh_CN'] ??
      const <String, String>{};
  final translated = localizedLogLabelFrom(trimmed, table);

  _logLabelCache[cacheKey] = translated.isEmpty ? trimmed : translated;

  return _logLabelCache[cacheKey]!;
}

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
    // 不换行时每行必然是同一高度 → 给 itemExtent, 滚动位置计算变成纯算术, 明显更跟手。
    // 换行模式行高不定, 不能固定（否则折行的行会被裁掉）。
    final rowExtent = wrapLines ? null : _singleLineRowExtent(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _openCopyDialog(context),
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: ListView.builder(
          key: ValueKey<String>('log-info-${controller.scriptName}'),
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemExtent: rowExtent,
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
    // 进程启动横幅不是任务，用独立图标标出来（保留卡片是为了能看出这里重启过）。
    final isStart = isLogStartBanner(section);
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
        title: Row(
          children: [
            if (isStart) ...[
              Icon(
                Icons.restart_alt_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                _sectionLabel(section),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
        onTap: () {
          // 记住卡片列表位置，返回时恢复（否则会跳到顶部并触发取旧日志）。
          controller.captureCardListOffset(
            scrollController.hasClients ? scrollController.offset : 0,
          );
          controller.openLogTask(section.key);
        },
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
    final openedLabel = _localizedLogLabel(controller.openedLogTaskLabel.value);
    final label = openedLabel.isEmpty
        ? I18n.homeLogSectionUnknown.tr
        : openedLabel;
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

  /// 不换行时一行日志的精确行高（文本行高 + 上下 1px 内边距 + 1px 余量）。
  double _singleLineRowExtent(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final fontSize = style?.fontSize ?? 14;
    final heightFactor = style?.height ?? 1.4;
    return fontSize * heightFactor + 3;
  }

  /// Resolves one display label for a task section.
  String _sectionLabel(ScriptLogSection section) {
    final label = _localizedLogLabel(section.label);
    return label.isEmpty ? I18n.homeLogSectionUnknown.tr : label;
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
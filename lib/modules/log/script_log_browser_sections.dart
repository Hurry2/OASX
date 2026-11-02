part of 'script_log_browser_controller.dart';

/// One task section inside the info log view.
class ScriptLogSection {
  /// Creates one task section.
  const ScriptLogSection({
    required this.key,
    required this.label,
    required this.firstIndex,
    required this.lineCount,
  });

  /// Stable key built from the section's first line.
  ///
  /// Banner sections stay stable across history prepends; the window head (lines
  /// before the first banner) does not, which is why the opened task is snapshotted.
  final String key;

  /// Display label (Chinese task name); empty when the task is unknown.
  final String label;

  /// Index of the first line inside the controller line list.
  final int firstIndex;

  /// Number of lines owned by this section.
  final int lineCount;

  /// Index of the last line owned by this section.
  int get lastIndex => firstIndex + lineCount - 1;
}

/// Splits ordered log lines into task sections.
///
/// A section starts at the first line and at every line flagged `taskStart`, so
/// two consecutive runs of the same task stay separate sections. The label comes
/// from the line's task, which the backend fills in for every line. Sections keep
/// the log order, so the newest task is the last one.
List<ScriptLogSection> buildScriptLogSections(List<ScriptLogLine> lines) {
  final sections = <ScriptLogSection>[];
  if (lines.isEmpty) {
    return sections;
  }
  var startIndex = 0;
  var label = lines.first.task ?? '';
  for (var index = 1; index < lines.length; index++) {
    if (!lines[index].taskStart) {
      continue;
    }
    sections.add(
      ScriptLogSection(
        key: lines[startIndex].key,
        label: label,
        firstIndex: startIndex,
        lineCount: index - startIndex,
      ),
    );
    startIndex = index;
    label = lines[index].task ?? '';
  }
  sections.add(
    ScriptLogSection(
      key: lines[startIndex].key,
      label: label,
      firstIndex: startIndex,
      lineCount: lines.length - startIndex,
    ),
  );
  return sections;
}

/// 任务视图（按日志行渲染）下：距顶部还剩这么多行时预取更旧的日志。
const int kLogPrefetchRemainingLines = 50;

/// 卡片视图下"一行"是整段任务（比日志行高得多），只有第一张卡露出来才预取。
const int kLogPrefetchRemainingCards = 1;

/// One rendered row in the info log list: a task card or a log line.
class ScriptLogRow {
  /// Creates a task card row.
  const ScriptLogRow.card(this.section) : line = null;

  /// Creates a log line row.
  const ScriptLogRow.line(this.line) : section = null;

  /// Task section payload; null for line rows.
  final ScriptLogSection? section;

  /// Log line payload; null for card rows.
  final ScriptLogLine? line;
}

/// Banner title of the process-start marker (`logger.hr('Start', level=0)`).
///
/// It is not a task, it only marks that the process (re)started. Cards keep it so
/// restarts stay visible in the list, but it is drawn with its own icon.
const String logStartBannerTitle = 'START';

/// Log markers emitted when a task failed and a restart was scheduled.
///
/// `Saving error: ` comes from `script.py` right before `task_call("Restart")` on
/// every error path that stores an error report; `recover it via Restart` comes
/// from the runtime controller when the game was not running.
const List<String> _logRestartTriggers = <String>[
  'Saving error: ',
  'recover it via Restart',
];

/// Whether one log line means the task failed and a restart followed.
bool _isLogRestartTriggerLine(String text) {
  for (final marker in _logRestartTriggers) {
    if (text.contains(marker)) {
      return true;
    }
  }
  return false;
}

/// Message part of one formatted log line (`time | file:line | LEVEL | message`).
String _logLineMessage(String text) {
  final separator = text.lastIndexOf(' | ');
  final message = separator >= 0 ? text.substring(separator + 3) : text;
  return message.trim();
}

/// Whether one section is the process-start banner rather than a task.
bool isLogStartBanner(ScriptLogSection section) {
  return section.label.trim().toUpperCase() == logStartBannerTitle;
}

extension ScriptLogBrowserSectionsX on ScriptLogBrowserController {
  /// Whether the info view is currently reading one task's log.
  bool get isLogTaskOpened => selectedLogTaskKey.value.isNotEmpty;

  /// 距顶部还剩多少行时才去预取更旧的日志（按当前是卡片层还是任务层区分）。
  ///
  /// 卡片层的 row 是整段任务，用任务层的行数阈值会在任意滚动位置都命中，
  /// 于是"从任务视图退回卡片列表（位置被夹到底部）"也会立刻加载更旧的日志。
  int get prefetchTriggerRows =>
      isLogTaskOpened ? kLogPrefetchRemainingLines : kLogPrefetchRemainingCards;

  /// Whether following the tail may reload the latest window.
  ///
  /// Reloading replaces the whole window, which would drop the very lines the
  /// user opened, so it stays disabled while a task log is open.
  bool get shouldReloadLatestOnFollow => !isLogTaskOpened;

  /// Finds one section by its key, or null when it no longer exists.
  ScriptLogSection? logSectionByKey(String key) {
    if (key.isEmpty) {
      return null;
    }
    for (final section in buildScriptLogSections(lines)) {
      if (section.key == key) {
        return section;
      }
    }
    return null;
  }

  /// Opens one task section and snapshots its lines.
  void openLogTask(String key) {
    final section = logSectionByKey(key);
    if (section == null) {
      return;
    }
    selectedLogTaskKey.value = key;
    openedLogTaskLabel.value = section.label;
    _openedSectionFirstIndex = section.firstIndex;
    _openedSectionLineCount = section.lineCount;
    openedLogTaskLines.assignAll(_linesOfSection(section));
    // 进任务默认停在最新的一行（最下面），而不是从最旧的那行开始。
    scrollToBottom?.call();
  }

  /// Returns to the task card list.
  void backToLogTaskList() {
    selectedLogTaskKey.value = '';
    openedLogTaskLabel.value = '';
    openedLogTaskLines.clear();
    // 读任务期间不裁剪, 回到列表后把积压的历史释放掉（保留两天的量）。
    trimToLiveWindow();
  }

  /// Keeps the opened task snapshot in sync.
  ///
  /// The section key is derived from the section's first line, and the window
  /// head (the long-running task that has no banner inside the window) changes
  /// that line as soon as older history is prepended. Once the key stops
  /// resolving the previous snapshot is kept, so scrolling never throws the user
  /// back to the card list.
  void refreshOpenedLogTask() {
    if (!isLogTaskOpened) {
      openedLogTaskLabel.value = '';
      openedLogTaskLines.clear();
      return;
    }
    final section = logSectionByKey(selectedLogTaskKey.value);
    if (section == null) {
      return;
    }
    // 分段没变就不重建快照: 大任务每次日志追加都整份复制会明显卡顿。
    if (section.firstIndex == _openedSectionFirstIndex &&
        section.lineCount == _openedSectionLineCount) {
      return;
    }
    _openedSectionFirstIndex = section.firstIndex;
    _openedSectionLineCount = section.lineCount;
    openedLogTaskLabel.value = section.label;
    openedLogTaskLines.assignAll(_linesOfSection(section));
  }

  /// Lines shown for one section: clamped to the current list.
  ///
  /// 不再按行数截断（用户要求：行数不限制）；渲染侧是虚拟化的，长任务也不会卡。
  List<ScriptLogLine> _linesOfSection(ScriptLogSection section) {
    final start = section.firstIndex.clamp(0, lines.length);
    final end = (section.lastIndex + 1).clamp(start, lines.length);
    return lines.sublist(start, end);
  }

  /// 窗口里最新 [kLogRetainedDays] 天的日志文件名（窗口按老→新排列，从尾部往前数）。
  Set<String> get retainedLogDays {
    final days = <String>{};
    for (var index = lines.length - 1; index >= 0; index--) {
      if (days.length == kLogRetainedDays) {
        break;
      }
      days.add(lines[index].fileName);
    }
    return days;
  }

  /// 窗口是否已经覆盖了要保留的天数（覆盖之后不必再往回取更旧的日志）。
  bool get logWindowCoversRetention =>
      retainedLogDays.length >= kLogRetainedDays;

  /// 该分段是否属于要保留的那几天。
  bool isRetainedDaySection(ScriptLogSection section) {
    if (lines.isEmpty || section.firstIndex >= lines.length) {
      return true;
    }
    return retainedLogDays.contains(lines[section.firstIndex].fileName);
  }

  /// Card sections shown in the list.
  ///
  /// 只展示需要保留的两天（旧版 OAS 的窗口可能回填到更早，那些日子不再显示）。
  /// 窗口首段是残缺段（首行不是横幅）时隐藏，但它得确实还在列表里才需要跳过。
  /// 结果按 `lines` 缓存，`lines` 变化时作废（见 onInit 的 ever）—— 行数多时这是卡顿主因。
  List<ScriptLogSection> get visibleLogSections {
    final cached = _visibleSectionCache;
    if (cached != null) {
      return cached;
    }
    var sections = buildScriptLogSections(lines);
    if (lines.isNotEmpty) {
      final kept = sections.where(isRetainedDaySection).toList();
      if (kept.isNotEmpty) {
        sections = kept;
      }
    }
    final headIsPartial =
        lines.isNotEmpty &&
        !lines.first.taskStart &&
        sections.isNotEmpty &&
        sections.first.firstIndex == 0;
    final result = headIsPartial && sections.length > 1
        ? sections.sublist(1)
        : sections;
    _visibleSectionCache = result;
    return result;
  }

  /// The restart-trigger log line of one task section, or '' when it did not fail.
  String logTaskFailureMessage(ScriptLogSection section) {
    if (lines.isEmpty) {
      return '';
    }
    final start = section.firstIndex.clamp(0, lines.length);
    final end = section.lastIndex.clamp(0, lines.length - 1);
    for (var index = start; index <= end; index++) {
      final text = lines[index].text;
      if (_isLogRestartTriggerLine(text)) {
        return _logLineMessage(text);
      }
    }
    return '';
  }

  /// The restart-trigger log line of the opened task, or '' when it did not fail.
  String get openedLogTaskFailureMessage {
    for (final line in openedLogTaskLines) {
      if (_isLogRestartTriggerLine(line.text)) {
        return _logLineMessage(line.text);
      }
    }
    return '';
  }

  /// Rows rendered by the current level.
  ///
  /// The card level shows one row per visible task; the task level shows the
  /// opened task's snapshot. Keeping this 1:1 with what is drawn lets the
  /// viewport math stay meaningful at both levels.
  List<ScriptLogRow> get logRows {
    if (!isLogTaskOpened) {
      return [
        for (final item in visibleLogSections) ScriptLogRow.card(item),
      ];
    }
    return [for (final line in openedLogTaskLines) ScriptLogRow.line(line)];
  }
}
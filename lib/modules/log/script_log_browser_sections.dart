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

/// Banner title of the process-start marker, which is not a task.
const String _logStartBannerTitle = 'START';

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

/// Whether one section deserves a card.
///
/// `START` comes from `logger.hr('Start', level=0)` at process start; it only marks
/// a restart, so it is noise in a task list.
bool _isTaskSection(ScriptLogSection section) {
  return section.label.trim().toUpperCase() != _logStartBannerTitle;
}

extension ScriptLogBrowserSectionsX on ScriptLogBrowserController {
  /// Whether the info view is currently reading one task's log.
  bool get isLogTaskOpened => selectedLogTaskKey.value.isNotEmpty;

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
    openedLogTaskLines.assignAll(_linesOfSection(section));
    // 读某个任务时按手动浏览保留更长的窗口, 免得刚打开就被裁掉。
    retainedLogLineLimit = kManualScrollLogWindowLineLimit;
  }

  /// Returns to the task card list.
  void backToLogTaskList() {
    selectedLogTaskKey.value = '';
    openedLogTaskLabel.value = '';
    openedLogTaskLines.clear();
    syncWindowLimitForMode();
    // 读任务期间不裁剪, 回到列表后把积压的历史释放掉。
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
    openedLogTaskLabel.value = section.label;
    openedLogTaskLines.assignAll(_linesOfSection(section));
  }

  /// Lines shown for one section: clamped to the current list, then capped to the
  /// newest [kLogTaskMaxLines] so one huge task cannot blow up the view.
  List<ScriptLogLine> _linesOfSection(ScriptLogSection section) {
    final start = section.firstIndex.clamp(0, lines.length);
    final end = (section.lastIndex + 1).clamp(start, lines.length);
    if (end - start <= kLogTaskMaxLines) {
      return lines.sublist(start, end);
    }
    return lines.sublist(end - kLogTaskMaxLines, end);
  }

  /// Card sections shown in the list.
  ///
  /// * the process-start banner (`START`) is not a task and never gets a card;
  /// * the window head is a partial task (its first line is not a banner, so only
  ///   its tail is inside the window) and is hidden whenever other tasks remain.
  List<ScriptLogSection> get visibleLogSections {
    final all = buildScriptLogSections(lines);
    final tasks = all.where(_isTaskSection).toList();
    // 整窗只剩"非任务"内容时仍然显示, 免得界面全空。
    final sections = tasks.isEmpty ? all : tasks;
    if (sections.length > 1 && !lines.first.taskStart) {
      return sections.sublist(1);
    }
    return sections;
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
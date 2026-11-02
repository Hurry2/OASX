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

/// Banner title of the process-start marker (`logger.hr('Start', level=0)`).
///
/// It is not a task, it only marks that the process (re)started. Cards keep it so
/// restarts stay visible in the list, but it is drawn with its own icon.
const String logStartBannerTitle = 'START';

/// Log marker emitted when a task actually went through the error pipeline.
///
/// `Saving error: ` comes from `script.py` right before it stores an error report,
/// i.e. a real exception.
///
/// 注意**不**包含 `recover it via Restart`：那句只是"游戏没在跑"，用户自己空闲时
/// 关闭游戏、随后重启也会出现 —— 用户明确要求"正常关闭游戏重启不要标成报错重启"。
const List<String> _logErrorTriggers = <String>['Saving error: '];

/// Whether one log line means the task itself errored.
bool _isLogErrorTriggerLine(String text) {
  for (final marker in _logErrorTriggers) {
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

  /// Whether following the tail may reload the latest window.
  ///
  /// Reloading replaces the whole window, which would drop the very lines the
  /// user opened, so it stays disabled while a task log is open.
  bool get shouldReloadLatestOnFollow => !isLogTaskOpened;

  /// Finds one section by its key, or null when it no longer exists.
  ///
  /// 走缓存的索引（O(1)）：每次日志追加都会刷新已打开任务的快照，
  /// 不能在这里重扫整份 lines（行数多时就是卡顿来源）。
  ScriptLogSection? logSectionByKey(String key) {
    if (key.isEmpty) {
      return null;
    }
    return _sectionIndex[key];
  }

  /// Every task section in the window, cached by the line-list signature.
  List<ScriptLogSection> get allLogSections {
    final signature = _sectionCacheSignature;
    final cached = _allSectionCache;
    if (cached != null && signature == _allSectionCacheSignature) {
      return cached;
    }
    final computed = buildScriptLogSections(lines);
    _allSectionCache = computed;
    _allSectionCacheSignature = signature;
    // 索引由它派生，重建时一并作废。
    _sectionIndexCache = null;
    return computed;
  }

  /// Key → section index over [allLogSections] (O(1) lookups).
  Map<String, ScriptLogSection> get _sectionIndex {
    final all = allLogSections;
    final cached = _sectionIndexCache;
    if (cached != null) {
      return cached;
    }
    final index = <String, ScriptLogSection>{};
    for (final section in all) {
      index[section.key] = section;
    }
    _sectionIndexCache = index;
    return index;
  }

  /// 记住卡片列表当前的滚动位置，返回时恢复。
  ///
  /// 不记的话，从任务视图退回时位置会被夹到顶部 → 看着像"滚到最顶" → 立刻触发取旧日志，
  /// 前面的重启卡片就"冒出来"了。
  void captureCardListOffset(double offset) {
    _cardListOffset = offset.isFinite && offset > 0 ? offset : 0;
  }

  /// Opens one task section and snapshots its newest lines.
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

  /// Returns to the task card list and restores its previous position.
  void backToLogTaskList() {
    selectedLogTaskKey.value = '';
    openedLogTaskLabel.value = '';
    openedLogTaskLines.clear();
    // 读任务期间不裁剪, 回到列表后把积压的历史释放掉（保留两天的量）。
    trimToLiveWindow();
    final restoreOffset = _cardListOffset;
    _cardListOffset = 0;
    if (restoreOffset > 0) {
      // 锚点还停在任务视图里，会解析出错误位置 → 清掉，按精确偏移恢复。
      savedAnchorKey = '';
      savedAnchorDelta = 0;
      restoreScrollOffset?.call(restoreOffset);
    }
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

  /// Lines shown for one section: the newest [kLogTaskMaxLines] lines of it.
  ///
  /// 卡片可以覆盖很多任务，但单个任务点进去只看最近 [kLogTaskMaxLines] 行
  /// （用户要求：要更完整的日志直接去看 txt 文件）—— 这也让任务视图保持轻量。
  List<ScriptLogLine> _linesOfSection(ScriptLogSection section) {
    final start = section.firstIndex.clamp(0, lines.length);
    final end = (section.lastIndex + 1).clamp(start, lines.length);
    if (end - start <= kLogTaskMaxLines) {
      return lines.sublist(start, end);
    }
    return lines.sublist(end - kLogTaskMaxLines, end);
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
  /// 结果按行列表签名缓存 —— 行数多时重算是卡顿主因。
  List<ScriptLogSection> get visibleLogSections {
    final signature = _sectionCacheSignature;
    final cached = _visibleSectionCache;
    if (cached != null && signature == _visibleSectionCacheSignature) {
      return cached;
    }
    var sections = allLogSections;
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
    _visibleSectionCacheSignature = signature;
    return result;
  }

  /// The error log line of one task section, or '' when it did not error.
  String logTaskFailureMessage(ScriptLogSection section) {
    if (lines.isEmpty) {
      return '';
    }
    final start = section.firstIndex.clamp(0, lines.length);
    final end = section.lastIndex.clamp(0, lines.length - 1);
    for (var index = start; index <= end; index++) {
      final text = lines[index].text;
      if (_isLogErrorTriggerLine(text)) {
        return _logLineMessage(text);
      }
    }
    return '';
  }

  /// The error log line of the opened task, or '' when it did not error.
  String get openedLogTaskFailureMessage {
    for (final line in openedLogTaskLines) {
      if (_isLogErrorTriggerLine(line.text)) {
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
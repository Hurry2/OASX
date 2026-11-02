part of 'script_log_browser_controller.dart';

/// Cursor schema used by the log browser API.
const int _logCursorVersion = 1;

extension ScriptLogBrowserWindowX on ScriptLogBrowserController {
  /// Clears currently displayed info lines.
  void clearInfoLogs() {
    lines.clear();
    _lineKeys.clear();
    _maxLineWidthScore = 0;
    _widthScoreSignature = '';
    savedScrollOffset = 0;
    savedAnchorKey = '';
    savedAnchorDelta = 0;
  }

  /// Drops history older than the newest [kLogRetainedDays] days.
  ///
  /// 保留策略按"天"而不是"行数"（用户要求：保留两天、不限行数）。
  /// 打开某个任务时不裁剪：分段的身份是它的首行，裁掉首行会让打开的任务失联，
  /// 界面就会退回卡片列表。
  void trimToLiveWindow() {
    if (isLogTaskOpened || lines.isEmpty) {
      return;
    }
    final keepFrom = _retainedWindowStart();
    if (keepFrom <= 0) {
      return;
    }
    final removedLines = lines.take(keepFrom).toList();
    lines.removeRange(0, keepFrom);
    _removeLineKeys(removedLines);
    if (lines.isNotEmpty) {
      // 保留段的最旧一行成为新的回翻游标。
      olderCursor = _buildOlderCursor(lines.first);
      reachedStart = false;
    }
  }

  /// Index of the first line that is still kept.
  ///
  /// 两个条件取更严的那个：① 最近 [kLogRetainedDays] 天；② 文本不超过
  /// [kLogMaxRetainedBytes]（内存软上限）。`lines` 按老→新排列，所以从尾部往前数一趟即可。
  int _retainedWindowStart() {
    final days = <String>{};
    var bytes = 0;
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      if (!days.contains(line.fileName)) {
        if (days.length == kLogRetainedDays) {
          return index + 1;
        }
        days.add(line.fileName);
      }
      bytes += line.byteLength > 0 ? line.byteLength : line.text.length;
      if (bytes > kLogMaxRetainedBytes) {
        return index + 1;
      }
    }
    return 0;
  }

  /// Removes dedupe keys for discarded lines.
  void _removeLineKeys(Iterable<ScriptLogLine> removedLines) {
    for (final line in removedLines) {
      _lineKeys.remove(line.key);
    }
  }

  /// Applies a fresh latest window.
  void applyFreshWindow(ScriptLogWindow window) {
    lines.assignAll(window.lines);
    _lineKeys
      ..clear()
      ..addAll(window.lines.map((line) => line.key));
    // 宽度分数是惰性的（见 maxLineWidthScore），这里不必重算。
    olderCursor = window.olderCursor;
    liveCursor = window.liveCursor;
    reachedStart = window.reachedStart || !window.hasOlder;
  }

  /// Prepends older lines and asks UI to preserve viewport.
  void prependOlderWindow(ScriptLogWindow window) {
    if (window.lines.isEmpty) {
      olderCursor = window.olderCursor;
      reachedStart = window.reachedStart || !window.hasOlder;
      return;
    }
    final olderLines = window.lines
        .where((line) => !_lineKeys.contains(line.key))
        .toList();
    if (olderLines.isNotEmpty) {
      lines.insertAll(0, olderLines);
      _lineKeys.addAll(olderLines.map((line) => line.key));
      preserveViewportAfterPrepend?.call(olderLines.length);
    }
    olderCursor = window.olderCursor;
    reachedStart = window.reachedStart || !window.hasOlder;
  }

  /// Recomputes the widest line score after bulk changes.
  void _recomputeMaxLineWidthScore(String signature) {
    var score = 0;
    for (final line in lines) {
      final current = _scoreScriptLogLineWidth(line.text);
      if (current > score) {
        score = current;
      }
    }
    _maxLineWidthScore = score;
    _widthScoreSignature = signature;
  }

  /// Builds an API-compatible older cursor for a retained first line.
  String _buildOlderCursor(ScriptLogLine line) {
    final cursorPayload = {
      'v': _logCursorVersion,
      'script_name': scriptName,
      'direction': 'older',
      'file_name': line.fileName,
      'offset': line.offset,
      'line_no': line.lineNo,
    };
    final json = jsonEncode(cursorPayload);
    return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  }
}

part of 'script_log_browser_controller.dart';

/// Number of error log lines shown immediately after parsing completes.
const int _errorLogInitialBatchSize = 200;

/// Number of error log lines appended in each follow-up batch.
const int _errorLogAppendBatchSize = 400;

/// Width threshold after which one log line skips rich highlighting.
const int kErrorLogPlainTextThreshold = 4096;

/// Parsed error log payload prepared outside the widget tree.
class ScriptErrorLogRenderPayload {
  /// Creates one parsed error log payload.
  const ScriptErrorLogRenderPayload({
    required this.lines,
    required this.maxWidthScore,
  });

  /// Prepared log lines.
  final List<String> lines;

  /// Widest line width score.
  final int maxWidthScore;
}

/// Heading that owns the log fence inside a generated error report.
const String _errorReportLogHeading = '## 日志';

/// Extracts the log body from a generated error report.
///
/// Legacy plain-text logs are returned unchanged, so the error view keeps
/// rendering exactly what it rendered before the report format existed.
String extractErrorReportLog(String content) {
  if (!content.contains(_errorReportLogHeading)) {
    return content;
  }
  final lines = const LineSplitter().convert(content);
  var headingIndex = -1;
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].trimRight() == _errorReportLogHeading) {
      headingIndex = index;
      break;
    }
  }
  if (headingIndex < 0) {
    return content;
  }
  var fenceIndex = -1;
  for (var index = headingIndex + 1; index < lines.length; index++) {
    if (lines[index].trimRight().startsWith('```')) {
      fenceIndex = index;
      break;
    }
  }
  if (fenceIndex < 0) {
    return content;
  }
  final body = <String>[];
  for (var index = fenceIndex + 1; index < lines.length; index++) {
    if (lines[index].trimRight() == '```') {
      break;
    }
    body.add(lines[index]);
  }
  return body.join('\n');
}

/// Parses raw error log text into virtual-rendering payload.
ScriptErrorLogRenderPayload parseScriptErrorLogPayload(String content) {
  final normalized = _trimErrorLogTrailingBreaks(extractErrorReportLog(content));
  if (normalized.isEmpty) {
    return const ScriptErrorLogRenderPayload(lines: <String>[], maxWidthScore: 0);
  }
  final lines = const LineSplitter().convert(normalized);
  var maxWidthScore = 0;
  for (final line in lines) {
    final score = _scoreScriptLogLineWidth(line);
    if (score > maxWidthScore) {
      maxWidthScore = score;
    }
  }
  return ScriptErrorLogRenderPayload(
    lines: lines,
    maxWidthScore: maxWidthScore,
  );
}

/// Removes trailing CR/LF characters from one error log payload.
String _trimErrorLogTrailingBreaks(String value) {
  var end = value.length;
  while (end > 0) {
    final codeUnit = value.codeUnitAt(end - 1);
    if (codeUnit != 10 && codeUnit != 13) {
      break;
    }
    end--;
  }
  return end == value.length ? value : value.substring(0, end);
}

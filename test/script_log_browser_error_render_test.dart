import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';

void main() {
  test('parseScriptErrorLogPayload splits lines and trims trailing breaks', () {
    const content = 'INFO line\r\nERROR line\r\n\r\n';
    final payload = parseScriptErrorLogPayload(content);

    expect(payload.lines, <String>['INFO line', 'ERROR line']);
    expect(payload.maxWidthScore > 0, isTrue);
  });

  test('plain text threshold keeps large single line detectable', () {
    final content = 'A' * (kErrorLogPlainTextThreshold + 5);
    final payload = parseScriptErrorLogPayload(content);

    expect(payload.lines, <String>[content]);
    expect(payload.maxWidthScore, content.length);
  });

  const reportContent = '# OASX 错误报告\n'
      '\n'
      '- 配置：16416-5556\n'
      '- 任务：SixRealms\n'
      '- 时间：2026-11-01T13:17:28.746+08:00\n'
      '- 错误类型：GameTooManyClickError: Too many click\n'
      '\n'
      '## 任务详细设置\n'
      '\n'
      '> 以下为导出时保存的任务设置（已脱敏），不是报错时的历史快照。\n'
      '\n'
      '### 任务调度\n'
      '\n'
      '| 设置项 | 当前值 |\n'
      '| :--- | :--- |\n'
      '| Enable | 关闭 |\n'
      '\n'
      '## 截图\n'
      '\n'
      '图片内嵌于本文件；请使用支持 data URI 的 Markdown 阅读器。\n'
      '\n'
      '![错误截图 1](data:image/png;base64,AAAA)\n'
      '\n'
      '## 日志\n'
      '\n'
      '```text\n'
      '════════════════ SIXREALMS ════════════════\n'
      '2026-11-01 13:17:28.743 | logger.py:0505 | ERROR | GameTooManyClickError\n'
      '```\n';

  test('extractErrorReportLog keeps only the log fence body', () {
    final log = extractErrorReportLog(reportContent);

    expect(log, contains('════════════════ SIXREALMS'));
    expect(log, contains('GameTooManyClickError'));
    expect(log, isNot(contains('# OASX 错误报告')));
    expect(log, isNot(contains('| 设置项 | 当前值 |')));
    expect(log, isNot(contains('data:image')));
    expect(log, isNot(contains('## 截图')));
    expect(log, isNot(contains('```')));
  });

  test('extractErrorReportLog keeps legacy plain text unchanged', () {
    const legacy = 'INFO line\nERROR line\n';

    expect(extractErrorReportLog(legacy), legacy);
  });

  test('extractErrorReportLog falls back when the fence is missing', () {
    const withoutFence = '# OASX 错误报告\n\n## 日志\n\nno fence here\n';

    expect(extractErrorReportLog(withoutFence), withoutFence);
  });

  test('extractErrorReportLog returns empty for an empty log fence', () {
    const empty = '# OASX 错误报告\n\n## 日志\n\n```text\n```\n';

    expect(extractErrorReportLog(empty), '');
  });

  test('parseScriptErrorLogPayload renders only the report log body', () {
    final payload = parseScriptErrorLogPayload(reportContent);

    expect(payload.lines.length, 2);
    expect(payload.lines.first, contains('SIXREALMS'));
    expect(payload.lines.last, contains('GameTooManyClickError'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';

ScriptLogLine _line(
  int lineNo,
  String text, {
  String? task,
  bool start = false,
}) {
  return ScriptLogLine(
    fileName: '2026-11-01_demo.txt',
    lineNo: lineNo,
    offset: lineNo * 10,
    byteLength: text.length,
    text: text,
    lineTruncated: false,
    task: task,
    taskStart: start,
  );
}

ScriptLogBrowserController _controllerWithTasks() {
  final controller = ScriptLogBrowserController(scriptName: 'demo');
  controller.lines
    ..clear()
    ..addAll(<ScriptLogLine>[
      _line(1, '════', task: '大富翁', start: true),
      _line(2, '──── RICHMAN ────', task: '大富翁'),
      _line(3, '════', task: '大富翁'),
      _line(4, 'work', task: '大富翁'),
      _line(5, '════', task: '六道之门', start: true),
      _line(6, 'work', task: '六道之门'),
    ]);
  return controller;
}

void main() {
  test('buildScriptLogSections splits on task banners', () {
    final sections = buildScriptLogSections(_controllerWithTasks().lines);

    expect(sections.length, 2);
    expect(sections.first.label, '大富翁');
    expect(sections.first.firstIndex, 0);
    expect(sections.first.lineCount, 4);
    expect(sections.first.lastIndex, 3);
    expect(sections.last.label, '六道之门');
    expect(sections.last.firstIndex, 4);
    expect(sections.last.lineCount, 2);
  });

  test('buildScriptLogSections keeps repeated runs of one task apart', () {
    final sections = buildScriptLogSections(<ScriptLogLine>[
      _line(1, 'first run', task: '大富翁', start: true),
      _line(2, 'end of first', task: '大富翁'),
      _line(3, 'second run', task: '大富翁', start: true),
    ]);

    expect(sections.length, 2);
    expect(sections.first.label, sections.last.label);
    expect(sections.first.key, isNot(sections.last.key));
  });

  test('buildScriptLogSections labels a head without a banner as unknown', () {
    final sections = buildScriptLogSections(<ScriptLogLine>[
      _line(1, 'older line', task: '六道之门'),
      _line(2, '════', task: '大富翁', start: true),
    ]);

    expect(sections.length, 2);
    expect(sections.first.label, '六道之门');
    expect(sections.first.lineCount, 1);
    expect(sections.last.label, '大富翁');
  });

  test('buildScriptLogSections returns nothing for empty lines', () {
    expect(buildScriptLogSections(<ScriptLogLine>[]), isEmpty);
  });

  test('logRows shows one card per task while no task is opened', () {
    final controller = _controllerWithTasks();
    final rows = controller.logRows;

    expect(controller.isLogTaskOpened, isFalse);
    expect(rows.length, 2);
    expect(rows.every((row) => row.section != null), isTrue);
    expect(rows.every((row) => row.line == null), isTrue);
    expect(rows.last.section?.label, '六道之门');
  });

  test('openLogTask renders only the opened task lines', () {
    final controller = _controllerWithTasks();
    final sections = buildScriptLogSections(controller.lines);
    controller.openLogTask(sections.first.key);

    expect(controller.openedLogTaskLabel.value, '大富翁');
    final rows = controller.logRows;
    expect(rows.length, 4);
    expect(rows.every((row) => row.line != null), isTrue);
    expect(rows.first.line?.text, '════');
    expect(rows.last.line?.text, 'work');
    expect(
      rows.any((row) => row.line?.task == '六道之门'),
      isFalse,
      reason: '只渲染打开的那个任务',
    );
  });

  test('backToLogTaskList returns to the card list', () {
    final controller = _controllerWithTasks();
    final sections = buildScriptLogSections(controller.lines);
    controller.openLogTask(sections.last.key);
    expect(controller.isLogTaskOpened, isTrue);

    controller.backToLogTaskList();
    expect(controller.isLogTaskOpened, isFalse);
    expect(controller.logRows.length, 2);
  });

  test('an unknown task key falls back to the card list', () {
    final controller = _controllerWithTasks();
    controller.openLogTask('missing:key');

    expect(controller.isLogTaskOpened, isFalse);
    expect(controller.logRows.every((row) => row.section != null), isTrue);
  });

  test('prepending history past a window-head section keeps the task view', () {
    // 窗口头部段: 首行不是任务横幅, key 取自 lines[0] —— 前插旧日志会换掉它。
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        _line(10, 'head-1', task: '六道之门'),
        _line(11, 'head-2', task: '六道之门'),
      ]);
    final head = buildScriptLogSections(controller.lines).single;
    expect(controller.lines.first.taskStart, isFalse);

    controller.openLogTask(head.key);
    expect(controller.isLogTaskOpened, isTrue);
    expect(controller.openedLogTaskLines.length, 2);

    controller.lines.insertAll(0, <ScriptLogLine>[
      _line(1, 'older-1', task: '大富翁', start: true),
      _line(2, 'older-2', task: '大富翁'),
    ]);
    // 前插后旧 key 已经不存在了(这正是"往下滑就退界面"的成因)。
    expect(controller.logSectionByKey(head.key), isNull);
    controller.refreshOpenedLogTask();

    expect(controller.isLogTaskOpened, isTrue, reason: '不能自动退回卡片列表');
    expect(controller.openedLogTaskLabel.value, '六道之门');
    expect(controller.logRows.length, 2);
    expect(controller.logRows.first.line?.text, 'head-1');
  });

  test('refreshOpenedLogTask follows the section while it still resolves', () {
    final controller = _controllerWithTasks();
    final sections = buildScriptLogSections(controller.lines);
    controller.openLogTask(sections.last.key);
    expect(controller.openedLogTaskLines.length, 2);

    controller.lines.add(_line(7, 'work-more', task: '六道之门'));
    controller.refreshOpenedLogTask();

    expect(controller.openedLogTaskLines.length, 3);
    expect(controller.logRows.last.line?.text, 'work-more');
  });

  test('visibleLogSections hides the partial window head when tasks remain', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        _line(1, 'head-part', task: '六道之门'),
        _line(2, '════', task: '大富翁', start: true),
        _line(3, 'work', task: '大富翁'),
      ]);
    expect(buildScriptLogSections(controller.lines).length, 2);

    final visible = controller.visibleLogSections;

    expect(visible.length, 1, reason: '最老的残缺任务不显示');
    expect(visible.single.label, '大富翁');
    expect(controller.logRows.length, 1);
    expect(controller.logRows.single.section?.label, '大富翁');
  });

  test('visibleLogSections keeps the head when it is all there is', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        _line(1, 'head-1', task: '六道之门'),
        _line(2, 'head-2', task: '六道之门'),
      ]);

    expect(controller.visibleLogSections.length, 1);
    expect(controller.logRows.length, 1);
    expect(controller.logRows.single.section?.label, '六道之门');
  });

  test('visibleLogSections keeps every section when none is partial', () {
    final controller = _controllerWithTasks();

    expect(controller.visibleLogSections.length, 2);
    expect(controller.logRows.length, 2);
  });

  test('visibleLogSections drops the process-start banner', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        _line(1, '════', task: 'START', start: true),
        _line(2, 'start body', task: 'START'),
        _line(3, '════', task: '大富翁', start: true),
        _line(4, 'work', task: '大富翁'),
      ]);

    final visible = controller.visibleLogSections;

    expect(visible.length, 1, reason: 'START 不是任务, 不该占卡片');
    expect(visible.single.label, '大富翁');
    expect(controller.logRows.length, 1);
  });

  test('visibleLogSections falls back when every section is a start banner', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        _line(1, '════', task: 'START', start: true),
        _line(2, 'body', task: 'START'),
      ]);

    expect(controller.visibleLogSections.length, 1, reason: '不能把界面弄成全空');
    expect(controller.logRows.length, 1);
  });

  test('logTaskFailureMessage spots a task that failed and restarted', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        _line(1, '════', task: '大富翁', start: true),
        _line(2, '2026-11-01 18:00:00.000 | common.py:0048 | INFO | Current coin: 0',
            task: '大富翁'),
        _line(
          3,
          '2026-11-01 18:00:01.000 | script.py:0133 | WARNING | '
          'Saving error: ./log/error/模拟器1_1',
          task: '大富翁',
        ),
        _line(4, '════', task: '重启', start: true),
        _line(
          5,
          '2026-11-01 18:00:02.000 | runtime_controller.py:0341 | WARNING | '
          'Game is not running before task `六道之门`, recover it via Restart',
          task: '重启',
        ),
      ]);
    final sections = buildScriptLogSections(controller.lines);
    expect(sections.length, 2);

    expect(
      controller.logTaskFailureMessage(sections.first),
      contains('Saving error'),
    );
    expect(
      controller.logTaskFailureMessage(sections.last),
      contains('recover it via Restart'),
    );
  });

  test('a normal task section carries no failure mark', () {
    final controller = _controllerWithTasks();

    for (final section in controller.visibleLogSections) {
      expect(controller.logTaskFailureMessage(section), isEmpty);
    }
  });

  test('openedLogTaskFailureMessage follows the opened snapshot', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        _line(1, '════', task: '大富翁', start: true),
        _line(
          2,
          '2026-11-01 18:00:01.000 | script.py:0133 | WARNING | '
          'Saving error: ./log/error/x_1',
          task: '大富翁',
        ),
      ]);
    final section = buildScriptLogSections(controller.lines).single;

    expect(controller.openedLogTaskFailureMessage, isEmpty);
    controller.openLogTask(section.key);
    expect(controller.openedLogTaskFailureMessage, contains('Saving error'));
    controller.backToLogTaskList();
    expect(controller.openedLogTaskFailureMessage, isEmpty);
  });

  test('following the tail must not reload the window while a task is open', () {
    final controller = _controllerWithTasks();
    expect(controller.shouldReloadLatestOnFollow, isTrue);

    final sections = buildScriptLogSections(controller.lines);
    controller.openLogTask(sections.first.key);
    expect(controller.shouldReloadLatestOnFollow, isFalse);

    controller.backToLogTaskList();
    expect(controller.shouldReloadLatestOnFollow, isTrue);
  });

  test('openLogTask keeps a longer window and back restores the mode limit', () {
    final controller = _controllerWithTasks();
    final sections = buildScriptLogSections(controller.lines);

    controller.openLogTask(sections.first.key);
    expect(controller.retainedLogLineLimit, kManualScrollLogWindowLineLimit);

    controller.backToLogTaskList();
    expect(controller.retainedLogLineLimit, kAutoScrollLogWindowLineLimit);
  });

  test('trimToLiveWindow leaves the opened task untouched', () {
    final controller = _controllerWithTasks();
    final sections = buildScriptLogSections(controller.lines);
    controller.openLogTask(sections.first.key);
    controller.retainedLogLineLimit = 4;

    controller.trimToLiveWindow();

    expect(controller.lines.length, 6, reason: '读任务期间完全不裁剪');
    expect(
      controller.openedLogTaskLines.length,
      4,
      reason: '裁剪不能把被打开任务的首行弄丢, 否则会退出子界面',
    );
    expect(controller.logRows.length, 4);
  });

  test('trimToLiveWindow resumes after returning to the card list', () {
    final controller = _controllerWithTasks();
    final sections = buildScriptLogSections(controller.lines);
    controller.openLogTask(sections.first.key);
    controller.retainedLogLineLimit = 4;
    controller.trimToLiveWindow();
    expect(controller.lines.length, 6);

    controller.backToLogTaskList();
    controller.retainedLogLineLimit = 4;
    controller.trimToLiveWindow();

    expect(controller.lines.length, 4);
    expect(controller.lines.last.task, '六道之门');
  });

  test('trimToLiveWindow keeps freshly prepended history when asked', () {
    final controller = _controllerWithTasks();
    controller.retainedLogLineLimit = 6;
    controller.lines.insertAll(0, <ScriptLogLine>[
      for (var index = 0; index < 4; index++)
        _line(index + 100, 'older-$index', task: '大富翁', start: index == 0),
    ]);

    controller.trimToLiveWindow(keepOlder: true);

    expect(controller.lines.length, 6);
    expect(controller.lines.first.text, 'older-0', reason: '刚拉回来的旧内容不能丢');
    expect(controller.lines[3].text, 'older-3');
    expect(controller.lines.last.task, '大富翁', reason: '被裁掉的是较新的那一侧');
  });

  test('prefetchOlder is skipped while a task is open', () async {
    final controller = _controllerWithTasks();
    final sections = buildScriptLogSections(controller.lines);
    controller.openLogTask(sections.first.key);
    controller.olderCursor = 'some-cursor';

    await controller.prefetchOlder();

    expect(controller.olderLoading.value, isFalse, reason: '不该发起请求');
    expect(controller.lines.length, 6, reason: '窗口不该被拉长(否则回列表会多出卡片)');
  });

  test('a task longer than the cap keeps only its newest lines', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.lines
      ..clear()
      ..addAll(<ScriptLogLine>[
        for (var index = 0; index < kLogTaskMaxLines + 200; index++)
          _line(index + 1, 'line-$index', task: '六道之门', start: index == 0),
      ]);
    final section = buildScriptLogSections(controller.lines).single;

    controller.openLogTask(section.key);

    expect(controller.openedLogTaskLines.length, kLogTaskMaxLines);
    expect(controller.openedLogTaskLines.first.text, 'line-200');
    expect(controller.openedLogTaskLines.last.text, 'line-1199');
  });
}
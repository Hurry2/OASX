import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

/// Application logger.
///
/// 故意给一个**可用的默认实现**而不是 `late`：启动早期（任何服务初始化之前）也可能有人写日志，
/// `late` 会直接抛 LateInitializationError 让整个 App 起不来 —— 曾经因为在 `ApiClient`
/// 的构造函数里写日志而踩过（Logger 是 late，而 SettingsController 会在 initLogger() 之前
/// 构造 ApiClient）。真正落盘的文件日志仍由 [initLogger] 换上。
Logger logger = _getWebLogger();

Future<void> initLogger() async {
  if (kIsWeb) {
    logger = _getWebLogger();
    logger.i('---------------------------------------------------------------');
    logger.i('Logger initialized');
    logger.i('log path: web console');
    return;
  }

  final logDir = await _resolveLogDirectory();
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }
  final dateTime = DateTime.now().toIso8601String().substring(0, 10);
  logger = _getLogger(logDir.path, dateTime);
  logger.i('---------------------------------------------------------------');
  logger.i('Logger initialized');
  logger.i('log path: ${logDir.path}/$dateTime.txt');
  logger.i('App path: ${Platform.resolvedExecutable}');
  logger.i('Current Directory: ${Directory.current.path}');

  unawaited(_cleanupOldLogs(logDir.path));
}

Future<Directory> _resolveLogDirectory() async {
  if (kIsWeb) {
    throw UnsupportedError('Web does not support file-based logging.');
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final installDir = File(Platform.resolvedExecutable).parent.path;
    return Directory('$installDir${Platform.pathSeparator}logs');
  }
  final appDocDir = await getApplicationCacheDirectory();
  return Directory('${appDocDir.path}${Platform.pathSeparator}logs');
}

class CustomConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      stdout.write('$line\n');
    }
  }
}

Logger _getWebLogger() {
  return Logger(
    filter: ProductionFilter(),
    printer: SimplePrinter(printTime: true),
    output: ConsoleOutput(),
  );
}

Logger _getLogger(String logPath, String dateTime) {
  //
  LogFilter filter = ProductionFilter();
  //
  LogPrinter printer = SimplePrinter(printTime: true);
  //
  MultiOutput multiOutput = MultiOutput([
    FileOutput(
      file: File('$logPath/$dateTime.txt'),
      encoding: utf8,
    ),
    CustomConsoleOutput(),
  ]);

  return Logger(
    filter: filter,
    printer: printer,
    output: multiOutput,
  );
}

Future<void> _cleanupOldLogs(String logDirPath) async {
  try {
    final logDir = Directory(logDirPath);
    if (!logDir.existsSync()) return;

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final files = logDir.listSync();
    int deletedCount = 0;
    for (var file in files) {
      if (file is File && file.path.endsWith('.txt')) {
        // 从文件名提取日期（假设文件名格式为 "yyyy-MM-dd.txt"）
        final fileName = file.uri.pathSegments.last;
        if (fileName.length >= 14 && fileName.endsWith('.txt')) {
          try {
            final dateStr = fileName.substring(0, 10);
            final fileDate = DateTime.parse(dateStr);
            if (fileDate.isBefore(sevenDaysAgo)) {
              await file.delete();
              deletedCount++;
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    if (deletedCount > 0) {
      logger.i('Cleaned up $deletedCount old log files');
    }
  } catch (e) {
    logger.e('Error cleaning up old logs: $e');
  }
}

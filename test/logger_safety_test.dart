import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/utils/logger.dart';

void main() {
  test('logger is usable before initLogger runs', () {
    // 启动早期（initLogger 之前）写日志不能抛异常。
    //
    // 曾经踩过：logger 是 `late` 变量，而 `ApiClient` 的构造函数会在
    // `SettingsController` 初始化时（早于 `initLogger()`）被执行 → 构造里那行日志
    // 直接抛 LateInitializationError，整个 App 起不来（而且因为日志还没就绪，
    // 磁盘上连一行记录都没有）。
    expect(() => logger.i('[test] early info'), returnsNormally);
    expect(() => logger.w('[test] early warning'), returnsNormally);
    expect(() => logger.e('[test] early error'), returnsNormally);
  });
}
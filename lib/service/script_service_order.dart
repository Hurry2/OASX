part of 'script_service.dart';

/// 配置列表的自定义排序（左侧栏拖动排序）。
extension ScriptServiceOrderX on ScriptService {
  /// 用拖动后的顺序覆盖当前顺序，并持久化。
  ///
  /// [order] 必须是完整的配置名列表；缺失的名字按原顺序补在末尾，避免一次
  /// 排序把没参与拖动的配置挤掉。
  void applyScriptOrder(Iterable<String> order) {
    final next = <String>[];
    for (final name in order) {
      final normalized = name.trim();
      if (normalized.isEmpty || next.contains(normalized)) {
        continue;
      }
      if (!scriptOrderList.contains(normalized)) {
        continue;
      }
      next.add(normalized);
    }
    for (final name in scriptOrderList) {
      if (!next.contains(name)) {
        next.add(name);
      }
    }
    scriptOrderList.value = next;
    _customScriptOrder
      ..clear()
      ..addAll(next);
    _persistCustomScriptOrder();
  }

  /// 写入本地存储；失败不抛出，排序只是体验优化，不该影响主流程。
  void _persistCustomScriptOrder() {
    try {
      _storage.write(
        StorageKey.scriptOrder.name,
        jsonEncode(_customScriptOrder),
      );
    } catch (e) {
      printError(info: 'persist script order error: $e');
    }
  }

  /// 读取本地存储；同时兼容 `List` 和 JSON `String` 两种历史写法。
  void _loadCustomScriptOrderFromStorage() {
    _customScriptOrder.clear();
    final raw = _storage.read(StorageKey.scriptOrder.name);
    if (raw is List) {
      _customScriptOrder.addAll(
        raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
      );
      return;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _customScriptOrder.addAll(
            decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
          );
        }
      } catch (e) {
        printError(info: 'load script order error: $e');
      }
    }
  }
}

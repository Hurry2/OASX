part of 'script_service.dart';

/// 配置列表的自定义排序（左侧栏拖动排序）。
extension ScriptServiceOrderX on ScriptService {
  /// 用拖动后的顺序覆盖当前顺序，并持久化。
  ///
  /// [order] 必须是完整的配置名列表；缺失的名字按原顺序补在末尾，避免一次
  /// 排序把没参与拖动的配置挤掉。
  void applyScriptOrder(Iterable<String> order) {
    _selectCustomScriptOrderForCurrentBackend();
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
  ///
  /// 存的是「后端地址 → 顺序」的整张表，写入前先把内存里当前这份同步进表，
  /// 这样换后端不会互相覆盖。
  void _persistCustomScriptOrder() {
    try {
      final backend = _customScriptOrderBackend;
      if (backend.isNotEmpty) {
        _customScriptOrders[backend] = List<String>.of(_customScriptOrder);
      }
      _storage.write(
        StorageKey.scriptOrder.name,
        jsonEncode(_customScriptOrders),
      );
    } catch (e) {
      printError(info: 'persist script order error: $e');
    }
  }

  /// 读取本地存储，并按当前后端挑出该用的那份。
  void _loadCustomScriptOrderFromStorage() {
    _customScriptOrders
      ..clear()
      ..addAll(
        parseScriptOrderStorage(
          _storage.read(StorageKey.scriptOrder.name),
          currentBackend: _currentBackendKey,
        ),
      );
    _selectCustomScriptOrderForCurrentBackend();
  }

  /// 把 [_customScriptOrder] 换成"当前后端"的那份。
  ///
  /// 后端地址没变就直接返回（绝大多数调用都属于这种），避免把内存里刚排好的顺序
  /// 用表里的旧副本覆盖掉。
  void _selectCustomScriptOrderForCurrentBackend() {
    final backend = _currentBackendKey;
    if (_customScriptOrderBackend == backend) {
      return;
    }
    _customScriptOrderBackend = backend;
    _customScriptOrder
      ..clear()
      ..addAll(scriptOrderForBackend(_customScriptOrders, backend));
  }
}

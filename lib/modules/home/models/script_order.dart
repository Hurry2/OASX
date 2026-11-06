// Pure helpers behind the user-defined config order in the left sidebar.
//
// Kept free of any Flutter import on purpose: this machine cannot run `flutter
// analyze` nor spawn any Dart tool that starts a subprocess, but `dart run
// <file>.dart` works as long as the file does not transitively import Flutter.
// Keeping the ordering math here means it can actually be executed and verified.
//
// 顺序**按后端地址分别保存**：同一台设备会切换局域网里的多台 OAS，各自的配置名
// 往往不同。若共用一份，切到另一台时会因为"和当前配置名零重叠"被判为陈旧并覆盖
// 落盘，切回来自定义顺序就没了。

import 'dart:convert';

/// Applies the user-defined order [customOrder] on top of the server order.
///
/// Names recorded in [customOrder] keep that relative order and come first;
/// every other name follows in its original position. Names that no longer
/// exist on the server are ignored, so a deleted config never leaves a hole.
List<String> applyCustomScriptOrder(
  Iterable<String> names,
  Iterable<String> customOrder,
) {
  final source = <String>[];
  for (final name in names) {
    if (name.isNotEmpty && !source.contains(name)) {
      source.add(name);
    }
  }
  final result = <String>[];
  for (final name in customOrder) {
    if (name.isEmpty || !source.contains(name) || result.contains(name)) {
      continue;
    }
    result.add(name);
  }
  for (final name in source) {
    if (!result.contains(name)) {
      result.add(name);
    }
  }
  return result;
}

/// Reads the persisted per-backend order.
///
/// 兼容三种历史写法：
/// * 后端地址 → 列表的 Map（当前格式）；
/// * 上述 Map 的 JSON 字符串；
/// * 旧版：列表或列表的 JSON 字符串 —— 整份迁移到 [currentBackend]。
Map<String, List<String>> parseScriptOrderStorage(
  dynamic raw, {
  required String currentBackend,
}) {
  List<String> normalize(Iterable<dynamic> values) => <String>[
    for (final value in values)
      if (value.toString().trim().isNotEmpty) value.toString().trim(),
  ];

  dynamic decoded = raw;
  if (raw is String) {
    try {
      decoded = raw.trim().isEmpty ? null : jsonDecode(raw);
    } catch (_) {
      decoded = null;
    }
  }

  final result = <String, List<String>>{};
  if (decoded is Map) {
    for (final entry in decoded.entries) {
      final backend = entry.key.toString().trim();
      final value = entry.value;
      if (backend.isEmpty || value is! List) {
        continue;
      }
      final order = normalize(value);
      if (order.isNotEmpty) {
        result[backend] = order;
      }
    }
    return result;
  }

  final backend = currentBackend.trim();
  if (decoded is List && backend.isNotEmpty) {
    final order = normalize(decoded);
    if (order.isNotEmpty) {
      result[backend] = order;
    }
  }
  return result;
}

/// Order stored for one backend; empty when it never dragged anything there.
List<String> scriptOrderForBackend(
  Map<String, List<String>> orders,
  String backend,
) {
  final key = backend.trim();
  if (key.isEmpty) {
    return const <String>[];
  }
  return orders[key] ?? const <String>[];
}

/// Whether [customOrder] shares no name with [names].
///
/// A total mismatch means the stored order belongs to a different backend
/// (another install, another config directory) — keeping it would make the
/// sidebar silently fall back to the server order on every reload, which looks
/// exactly like "my drag order was reset after restarting OAS".
bool isScriptOrderStale(
  Iterable<String> names,
  Iterable<String> customOrder,
) {
  final source = <String>{};
  for (final name in names) {
    if (name.isNotEmpty) {
      source.add(name);
    }
  }
  if (source.isEmpty) {
    return false;
  }
  var hasCustom = false;
  for (final name in customOrder) {
    if (name.isEmpty) {
      continue;
    }
    hasCustom = true;
    if (source.contains(name)) {
      return false;
    }
  }
  // Never stored an order yet (first run): not stale, let the caller build the
  // default order instead of writing one here.
  return hasCustom;
}

/// Maps a reorder performed on the *visible* list back onto the full order.
///
/// [fullOrder] is every config in display order; [visibleOrder] is the subset
/// currently rendered (a sub-sequence of [fullOrder], narrowed by the search
/// box and the state filter). The result is [fullOrder] with the dragged name
/// moved so that inside [visibleOrder] it lands at [newIndex] — names hidden by
/// the filter keep their relative positions.
///
/// [oldIndex] / [newIndex] follow [ReorderCallback] semantics, i.e. [newIndex]
/// is the insertion slot *before* the dragged item is removed.
List<String> reorderVisibleNames({
  required List<String> fullOrder,
  required List<String> visibleOrder,
  required int oldIndex,
  required int newIndex,
}) {
  final unchanged = List<String>.of(fullOrder);
  if (oldIndex < 0 || oldIndex >= visibleOrder.length) {
    return unchanged;
  }
  if (newIndex < 0 || newIndex > visibleOrder.length) {
    return unchanged;
  }
  final moved = visibleOrder[oldIndex];
  if (!unchanged.remove(moved)) {
    return List<String>.of(fullOrder);
  }
  final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
  final remaining = List<String>.of(visibleOrder)..removeAt(oldIndex);
  if (target >= remaining.length) {
    // Moved to the end: anchor on the last visible item still present.
    if (remaining.isEmpty) {
      return unchanged..add(moved);
    }
    final index = unchanged.indexOf(remaining.last);
    return index < 0
        ? (unchanged..add(moved))
        : (unchanged..insert(index + 1, moved));
  }
  final index = unchanged.indexOf(remaining[target]);
  return index < 0
      ? (unchanged..add(moved))
      : (unchanged..insert(index, moved));
}

// Pure helpers behind the user-defined config order in the left sidebar.
//
// Kept free of any import on purpose: this machine cannot run `flutter analyze`
// nor spawn any Dart tool that starts a subprocess, but `dart run <file>.dart`
// works as long as the file does not transitively import Flutter. Keeping the
// ordering math here means it can actually be executed and verified.

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

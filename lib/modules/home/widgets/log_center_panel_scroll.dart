part of 'log_center_panel.dart';

/// Toggles line wrapping while keeping current bottom/manual behavior stable.
void _handleLogCenterLineWrapToggle(_LogCenterPanelState state) {
  final controller = state._controller;
  if (controller == null) {
    return;
  }
  if (controller.activeTab.value == ScriptLogBrowserTab.error) {
    controller.toggleLineWrap();
    return;
  }
  final shouldFollow =
      controller.autoScroll.value || _isLogCenterAtBottom(state);
  _suppressLogCenterScrollHandling(state, frames: shouldFollow ? 4 : 2);
  controller.toggleLineWrap();
  if (!shouldFollow) {
    return;
  }
  controller.autoScroll.value = true;
  controller.trimToLiveWindow();
  _scrollLogCenterToBottom(state, jumpOnly: true);
}

/// Activates a controller once the panel viewport is attached.
void _activateLogCenterControllerAfterFrame(
  _LogCenterPanelState state,
  ScriptLogBrowserController controller,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted || state._controller != controller) {
      return;
    }
    if (controller.viewportOwner != state._viewportOwner) {
      return;
    }
    if (controller.activeTab.value == ScriptLogBrowserTab.error) {
      controller.activate();
      return;
    }
    if (controller.shouldRefreshLatestOnInfoResume) {
      controller.activate();
      return;
    }
    if (controller.autoScroll.value) {
      controller.trimToLiveWindow();
      _scrollLogCenterToBottom(state, jumpOnly: true);
    } else {
      controller.restoreManualPosition();
    }
    controller.activate();
  });
}

/// Releases the viewport callbacks owned by this panel.
void _releaseLogCenterController(
  _LogCenterPanelState state, {
  required bool suspend,
}) {
  final controller = state._controller;
  if (controller == null || controller.viewportOwner != state._viewportOwner) {
    return;
  }
  if (controller.activeTab.value == ScriptLogBrowserTab.info) {
    controller.handleInfoViewHidden();
  }
  controller.scrollToBottom = null;
  controller.restoreScrollOffset = null;
  controller.preserveViewportAfterPrepend = null;
  controller.resetErrorDetailViewport = null;
  controller.viewportOwner = null;
  if (suspend) {
    controller.suspend();
  }
}

/// Resets the error detail viewport to the initial position.
void _resetErrorDetailViewport(_LogCenterPanelState state) {
  final vertical = state._errorDetailScrollController;
  final horizontal = state._errorDetailHorizontalScrollController;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (vertical != null && vertical.hasClients) {
      vertical.jumpTo(0);
    }
    if (horizontal != null && horizontal.hasClients) {
      horizontal.jumpTo(0);
    }
  });
}

/// Handles one scroll notification from the info log list.
void _handleLogCenterScrollPosition(_LogCenterPanelState state) {
  final controller = state._controller;
  final scrollController = state._scrollController;
  if (controller == null ||
      scrollController == null ||
      !scrollController.hasClients) {
    return;
  }
  final position = scrollController.position;
  final offset = scrollController.offset;
  final isAtBottom =
      offset >=
      position.maxScrollExtent - _LogCenterPanelState._bottomThreshold;
  controller.handleViewportPosition(isAtBottom: isAtBottom);
  _saveLogCenterViewport(state);
  final rowsBeforeViewport =
      _firstVisibleLogRowIndex(controller, scrollController, offset);
  // 卡片层的"一行"是整段任务（比日志行高得多），沿用按行数的阈值会在任意位置都命中。
  // 更关键的是：内容没占满视口时根本没有"向上滚"这个动作 —— 从任务视图退回卡片列表时
  // 位置会被夹到 0（看起来像滚到最顶），曾经因此每次返回都取 1000 行更旧的日志，日期一路往前翻。
  final canScrollUp = position.maxScrollExtent > 0;
  if (canScrollUp && rowsBeforeViewport <= controller.prefetchTriggerRows) {
    controller.prefetchOlder();
  }
}

/// Persists the current info log viewport for script revisit recovery.
void _saveLogCenterViewport(_LogCenterPanelState state) {
  final controller = state._controller;
  final scrollController = state._scrollController;
  if (controller == null ||
      scrollController == null ||
      !scrollController.hasClients) {
    return;
  }
  final offset = scrollController.offset;
  // 用 logRowCount/按索引取锚点, 避免每帧 materialize 整份 logRows —— 行数多时那就是卡顿来源。
  final rowCount = controller.logRowCount;
  final extent = _rowExtentFor(controller, scrollController);
  final rowIndex = _firstVisibleLogRowIndex(
    controller,
    scrollController,
    offset,
  ).clamp(0, rowCount);
  final anchorKey = rowIndex < rowCount
      ? controller.logRowAnchorKeyAt(rowIndex)
      : '';
  controller.saveViewport(
    offset: offset,
    anchorKey: anchorKey,
    anchorDelta: offset - rowIndex * extent,
  );
}

/// Resolves the anchor log line key of one rendered row.
String _rowAnchorKey(
  ScriptLogBrowserController controller,
  ScriptLogRow row,
) {
  final line = row.line;
  if (line != null) {
    return line.key;
  }
  final section = row.section;
  if (section == null || section.firstIndex >= controller.lines.length) {
    return '';
  }
  return controller.lines[section.firstIndex].key;
}

/// Best-effort extent of one rendered row, measured from the live geometry.
///
/// Collapsed task sections contribute a header instead of many lines, so a
/// fixed per-line extent would misplace the viewport.
double _rowExtentFor(
  ScriptLogBrowserController? controller,
  ScrollController scrollController,
) {
  if (controller == null || !scrollController.hasClients) {
    return _LogCenterPanelState._estimatedLineExtent;
  }
  final rowCount = controller.logRowCount;
  if (rowCount <= 0) {
    return _LogCenterPanelState._estimatedLineExtent;
  }
  final position = scrollController.position;
  final contentExtent = position.maxScrollExtent + position.viewportDimension;
  if (contentExtent <= 0) {
    return _LogCenterPanelState._estimatedLineExtent;
  }
  final extent = contentExtent / rowCount;
  return extent > 1 ? extent : _LogCenterPanelState._estimatedLineExtent;
}

/// Scrolls the info log list to the current bottom after layout settles.
void _scrollLogCenterToBottom(
  _LogCenterPanelState state, {
  bool jumpOnly = false,
}) {
  final token = ++state._bottomScrollToken;
  _suppressLogCenterScrollHandling(state, frames: 3);
  _scheduleLogCenterBottomJump(state, token, jumpOnly: jumpOnly);
}

/// Jumps to bottom once layout is ready.
void _scheduleLogCenterBottomJump(
  _LogCenterPanelState state,
  int token, {
  required bool jumpOnly,
}) {
  final scrollController = state._scrollController;
  if (!state.mounted || scrollController == null) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted ||
        token != state._bottomScrollToken ||
        !scrollController.hasClients) {
      return;
    }
    final target = scrollController.position.maxScrollExtent;
    if (jumpOnly || (scrollController.offset - target).abs() > 400) {
      scrollController.jumpTo(target);
    } else {
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  });
}

/// Ignores scroll updates produced by programmatic jumps for a few frames.
void _suppressLogCenterScrollHandling(
  _LogCenterPanelState state, {
  required int frames,
}) {
  final token = ++state._scrollSuppressionToken;
  state._suppressScrollHandling = true;
  _scheduleLogCenterScrollHandlingRelease(state, token, frames);
}

/// Releases programmatic scroll suppression after layout has settled.
void _scheduleLogCenterScrollHandlingRelease(
  _LogCenterPanelState state,
  int token,
  int frames,
) {
  if (frames <= 0) {
    if (state.mounted && token == state._scrollSuppressionToken) {
      state._suppressScrollHandling = false;
    }
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted || token != state._scrollSuppressionToken) {
      return;
    }
    _scheduleLogCenterScrollHandlingRelease(state, token, frames - 1);
  });
}

/// Returns whether the vertical info viewport is already near bottom.
bool _isLogCenterAtBottom(_LogCenterPanelState state) {
  final scrollController = state._scrollController;
  if (scrollController == null || !scrollController.hasClients) {
    return false;
  }
  final position = scrollController.position;
  return scrollController.offset >=
      position.maxScrollExtent - _LogCenterPanelState._bottomThreshold;
}

/// Restores a previously saved info log scroll offset.
void _restoreLogCenterScrollOffset(_LogCenterPanelState state, double offset) {
  final scrollController = state._scrollController;
  final controller = state._controller;
  if (!state.mounted || scrollController == null) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted || !scrollController.hasClients) {
      return;
    }
    final target = _resolveLogCenterOffset(
      controller,
      scrollController,
      fallbackOffset: offset,
    );
    scrollController.jumpTo(target);
  });
}

/// Preserves the visible info log window after older lines are prepended.
void _preserveLogCenterViewportAfterPrepend(
  _LogCenterPanelState state,
  int insertedCount,
) {
  final scrollController = state._scrollController;
  final controller = state._controller;
  if (!state.mounted || scrollController == null || insertedCount <= 0) {
    return;
  }
  final previousOffset = scrollController.hasClients
      ? scrollController.offset
      : 0.0;
  final delta = insertedCount * _LogCenterPanelState._estimatedLineExtent;
  // 程序化跳转产生的滚动通知不能再次触发预取, 否则"旧内容折叠时视口推不动"
  // 会让加载旧日志变成死循环。
  _suppressLogCenterScrollHandling(state, frames: 3);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted || !scrollController.hasClients) {
      return;
    }
    final target = _resolveLogCenterOffset(
      controller,
      scrollController,
      fallbackOffset: previousOffset + delta,
    ).clamp(0.0, scrollController.position.maxScrollExtent);
    scrollController.jumpTo(target);
  });
}

/// Estimates the first visible rendered row index from the scroll offset.
int _firstVisibleLogRowIndex(
  ScriptLogBrowserController? controller,
  ScrollController scrollController,
  double offset,
) {
  return (offset / _rowExtentFor(controller, scrollController)).floor();
}

/// Resolves one best-effort scroll target from the saved anchor state.
double _resolveLogCenterOffset(
  ScriptLogBrowserController? controller,
  ScrollController scrollController, {
  required double fallbackOffset,
}) {
  final maxExtent = scrollController.position.maxScrollExtent;
  if (controller == null || controller.savedAnchorKey.isEmpty) {
    return fallbackOffset.clamp(0.0, maxExtent);
  }
  final rows = controller.logRows;
  var rowIndex = rows.indexWhere(
    (row) => row.line?.key == controller.savedAnchorKey,
  );
  if (rowIndex < 0) {
    rowIndex = rows.indexWhere(
      (row) => _rowAnchorKey(controller, row) == controller.savedAnchorKey,
    );
  }
  if (rowIndex < 0) {
    return fallbackOffset.clamp(0.0, maxExtent);
  }
  final target = rowIndex * _rowExtentFor(controller, scrollController) +
      controller.savedAnchorDelta;
  return target.clamp(0.0, maxExtent);
}

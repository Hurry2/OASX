part of 'script_log_browser_controller.dart';

extension ScriptLogBrowserInfoX on ScriptLogBrowserController {
  /// Loads latest log window and starts live stream.
  Future<void> refreshLatest() async {
    final requestId = ++revision;
    _infoLoadRequestId = requestId;
    infoLoading.value = true;
    infoError.value = '';
    await stopStream();
    try {
      final window = await ApiClient().getScriptLogWindow(
        scriptName,
        limitLines: kLogWindowLoadLines,
        limitBytes: kLogWindowLoadBytes,
      );
      if (!isInfoLoadActive(requestId)) {
        return;
      }
      applyFreshWindow(window);
      _shouldRefreshLatestOnInfoResume = false;
      syncWindowLimitForMode();
      infoLoading.value = false;
      unawaited(startStream(requestId));
      syncBottomAfterFrame();
    } catch (error) {
      if (!isInfoLoadActive(requestId)) {
        return;
      }
      infoLoading.value = false;
      infoError.value = error.toString();
      streamStatus.value = ScriptLogStreamStatus.error;
    } finally {
      // 同上: 必须无条件清掉本轮的 loading 标志。
      if (_infoLoadRequestId == requestId) {
        _infoLoadRequestId = 0;
        infoLoading.value = false;
      }
    }
  }

  /// Loads older lines before the current first line.
  Future<void> prefetchOlder() async {
    // 打开任务时不预取: 任务视图最多只显示最后 kLogTaskMaxLines 行, 预取来的
    // 旧日志进不了这个视图, 却会让窗口不断变长 —— 回到卡片列表就会多出一堆卡片。
    if (isLogTaskOpened) {
      return;
    }
    final cursor = olderCursor;
    if (cursor == null || cursor.isEmpty || reachedStart) {
      return;
    }
    if (olderLoading.value || infoLoading.value) {
      return;
    }
    final requestId = revision;
    _olderLoadRequestId = requestId;
    olderLoading.value = true;
    try {
      final window = await ApiClient().getScriptLogWindow(
        scriptName,
        cursor: cursor,
        limitLines: kLogWindowLoadLines,
        limitBytes: kLogWindowLoadBytes,
      );
      if (isOlderLoadActive(requestId)) {
        prependOlderWindow(window);
        syncWindowLimitForMode();
        // 刚拉回来的旧内容不能被立刻裁掉(否则这次请求等于白做, 还会再触发预取)。
        trimToLiveWindow(keepOlder: true);
      }
    } catch (error) {
      if (isOlderLoadActive(requestId)) {
        infoError.value = error.toString();
      }
    } finally {
      // 无条件清掉"本轮"的 loading: revision 在请求飞行中被刷新时
      // isOlderLoadActive 会永久为假, 旧写法会把进度条一直留在界面上。
      if (_olderLoadRequestId == requestId) {
        _olderLoadRequestId = 0;
        olderLoading.value = false;
      }
    }
  }

  /// Copies info lines to clipboard.
  void copyInfoLogs() {
    copyText(infoLogText);
  }

  /// Starts the live stream without replacing the current visible window.
  Future<void> resumeLiveStream() async {
    final requestId = ++revision;
    await stopStream();
    unawaited(startStream(requestId));
  }

  /// Restores the saved manual position.
  void restoreManualPosition() {
    if (savedScrollOffset <= 0) {
      return;
    }
    restoreScrollOffset?.call(savedScrollOffset);
  }

  /// Schedules a bottom follow after the current frame.
  void syncBottomAfterFrame() {
    if (_bottomSyncQueued) {
      return;
    }
    _bottomSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomSyncQueued = false;
      scrollToBottom?.call();
    });
  }
}

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
    // 打开任务时不预取: 预取来的旧行只会在回到卡片列表后让窗口变长。
    if (isLogTaskOpened) {
      return;
    }
    // 窗口已经覆盖到要保留的天数（两天）就不再往回取。
    if (logWindowCoversRetention) {
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
        // 保留策略按天: 超出两天的部分在这里被裁掉（包括刚拉回来但超出的页）。
        trimToLiveWindow();
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

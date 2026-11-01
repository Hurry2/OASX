part of 'script_log_browser_controller.dart';

extension ScriptLogBrowserActionsX on ScriptLogBrowserController {
  /// Initializes or restores the info log session.
  void activate() {
    if (activeTab.value == ScriptLogBrowserTab.error) {
      unawaited(stopStream());
      startErrorListAutoRefresh();
      unawaited(loadErrorList(reset: true));
      errorDetailVisible.value = false;
      return;
    }
    stopErrorListAutoRefresh();
    if (lines.isEmpty) {
      unawaited(refreshLatest());
      return;
    }
    if (_shouldRefreshLatestOnInfoResume) {
      if (isLogTaskOpened) {
        // 打开着某个任务时同样不能重载窗口, 否则会把它顶掉。
        _shouldRefreshLatestOnInfoResume = false;
      } else {
        // 重载会把窗口换成最新的一份。先把上一轮残留清掉, 否则会先用旧窗口渲染一屏
        // (上次浏览滑到很旧的位置时里面有十几个任务边界 → 看起来"先加载满、再变回两个")。
        clearInfoLogs();
        unawaited(refreshLatest());
        return;
      }
    }
    if (autoScroll.value) {
      trimToLiveWindow();
      syncBottomAfterFrame();
    } else {
      restoreManualPosition();
    }
    if (streamClient == null) {
      unawaited(resumeLiveStream());
    }
  }

  /// Selects the visible tab.
  void selectTab(ScriptLogBrowserTab tab) {
    if (tab != ScriptLogBrowserTab.error) {
      cancelSelectedErrorRenderWork();
    }
    if (activeTab.value == ScriptLogBrowserTab.info &&
        tab != ScriptLogBrowserTab.info) {
      handleInfoViewHidden();
    }
    activeTab.value = tab;
    activate();
  }

  /// Enables bottom following and immediately jumps to bottom.
  void enableAutoScroll() {
    if (!autoScroll.value) {
      autoScroll.value = true;
    }
    // 正在看某个任务的日志时不能重载最新窗口: 那会把正在读的行换掉,
    // 于是打开的任务消失、界面退回卡片列表（"往下滚动就退出子界面"的根因）。
    if (!shouldReloadLatestOnFollow) {
      return;
    }
    unawaited(refreshLatest());
  }

  /// Toggles auto-scroll state.
  void toggleAutoScroll() {
    if (autoScroll.value) {
      autoScroll.value = false;
      return;
    }
    enableAutoScroll();
  }

  /// Toggles long line wrapping.
  void toggleLineWrap() {
    wrapLines.value = !wrapLines.value;
  }

  /// Records manual scroll state.
  void saveViewport({
    required double offset,
    String anchorKey = '',
    double anchorDelta = 0,
  }) {
    savedScrollOffset = offset;
    savedAnchorKey = anchorKey;
    savedAnchorDelta = anchorDelta;
  }

  /// Sets auto-scroll according to viewport bottom state.
  void handleViewportPosition({required bool isAtBottom}) {
    if (isAtBottom && !autoScroll.value) {
      enableAutoScroll();
      return;
    }
    if (!isAtBottom && autoScroll.value) {
      autoScroll.value = false;
      retainedLogLineLimit = kManualScrollLogWindowLineLimit;
    }
  }

  /// Records whether returning to info view should refresh the latest window.
  void handleInfoViewHidden() {
    _shouldRefreshLatestOnInfoResume = autoScroll.value;
  }

  /// Copies text and shows the shared success snackbar.
  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      I18n.tip.tr,
      I18n.copySuccess.tr,
      duration: const Duration(seconds: 1),
    );
  }

  /// Clears the current visible page.
  void clearCurrentView() {
    if (activeTab.value == ScriptLogBrowserTab.error) {
      clearSelectedError();
      return;
    }
    clearInfoLogs();
  }

  /// Clears the selected error detail only.
  void clearSelectedError() {
    cancelSelectedErrorRenderWork();
    selectedErrorId.value = '';
    selectedErrorTitle.value = '';
    selectedErrorDetail.value = null;
    errorDetailVisible.value = false;
    errorMessage.value = '';
  }

  /// Disconnects live transport while keeping visible session state.
  Future<void> suspend() async {
    revision++;
    stopErrorListAutoRefresh();
    completePendingLoads();
    cancelSelectedErrorRenderWork();
    await stopStream();
  }

  /// Returns the current info-log payload with preserved line breaks.
  String get infoLogText => lines.map((line) => line.text).join('\n');

  /// Returns the current error-detail log payload with preserved line breaks.
  String get selectedErrorLogText => selectedErrorLogLines.join('\n');

  /// Copies the current visible log payload.
  void copyCurrentView() {
    if (activeTab.value == ScriptLogBrowserTab.error) {
      copySelectedErrorLog();
      return;
    }
    copyInfoLogs();
  }

  /// Clears active loading flags when pending requests are invalidated.
  void completePendingLoads() {
    _infoLoadRequestId = 0;
    _olderLoadRequestId = 0;
    _errorListRequestId = 0;
    _errorDetailRequestId = 0;
    infoLoading.value = false;
    olderLoading.value = false;
    errorListLoading.value = false;
    errorDetailLoading.value = false;
  }

  /// Returns whether one async request is still current.
  bool isRequestActive(int requestId) {
    return requestId == revision && !isClosed;
  }

  /// Returns whether one info latest-window request is current.
  bool isInfoLoadActive(int requestId) {
    return isRequestActive(requestId) && _infoLoadRequestId == requestId;
  }

  /// Returns whether one older-window request is current.
  bool isOlderLoadActive(int requestId) {
    return isRequestActive(requestId) && _olderLoadRequestId == requestId;
  }

  /// Returns whether one error-list request is current.
  bool isErrorListLoadActive(int requestId) {
    return isRequestActive(requestId) && _errorListRequestId == requestId;
  }

  /// Returns whether one error-detail request is current.
  bool isErrorDetailLoadActive(int requestId) {
    return isRequestActive(requestId) && _errorDetailRequestId == requestId;
  }
}

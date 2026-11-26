import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/modules/home/models/last_screenshot_meta.dart';
import 'package:oasx/service/websocket_service.dart';
import 'package:oasx/translation/i18n_content.dart';

/// 最近一帧及其元数据，按"频道"（后端地址 + 配置名）缓存。
///
/// 面板会因为布局变化被销毁重建（例如收起/恢复右侧栏、切换布局模式），而这些状态原本
/// 是 State 私有的 → 重建后先是"空"，要等后端推下一帧才有画面（脚本已停时可能永远等不到）。
/// 缓存放在模块级，重建时直接恢复上一帧。
final Map<String, Uint8List> _lastFrameByChannel = <String, Uint8List>{};
final Map<String, LastScreenshotMeta> _lastMetaByChannel =
    <String, LastScreenshotMeta>{};
final Map<String, double> _lastAspectByChannel = <String, double>{};

/// 频道缓存上限：每个配置一帧（1280×720 的图约几百 KB），只留最近用过的几个。
const int _frameCacheLimit = 4;

/// 正在关闭中的频道 → 关闭 Future。
///
/// 重建后的新实例在 `connect` 之前必须先等它落地：`WebSocketService.connect` 在连接仍
/// 报 connected 时会**复用**同一条客户端，若旧实例的 close 晚一步到达，就会把新实例刚挂上
/// 的监听一并清掉，画面从此永久为空。收起/恢复右侧栏正是"销毁 → 紧接着重建"这条路径。
final Map<String, Future<void>> _pendingCloseByChannel = <String, Future<void>>{};

/// 记录一帧到频道缓存，并按上限淘汰最旧的条目。
void _rememberLiveFrame(String channel, Uint8List frame) {
  _lastFrameByChannel.remove(channel);
  _lastFrameByChannel[channel] = frame;
  while (_lastFrameByChannel.length > _frameCacheLimit) {
    final oldest = _lastFrameByChannel.keys.first;
    _lastFrameByChannel.remove(oldest);
    _lastMetaByChannel.remove(oldest);
    _lastAspectByChannel.remove(oldest);
  }
}

/// 该频道确认没有画面（后端推了 empty）。
void _forgetLiveFrame(String channel) {
  _lastFrameByChannel.remove(channel);
}

/// 记录该频道最近一帧的元数据 / 宽高比。
void _rememberLiveMeta(String channel, LastScreenshotMeta meta) {
  _lastMetaByChannel[channel] = meta;
}

void _rememberLiveAspect(String channel, double aspectRatio) {
  _lastAspectByChannel[channel] = aspectRatio;
}

/// Shows what the script is currently looking at for one config.
///
/// Frames arrive over a WebSocket from OAS's image service, which already holds
/// the frame the script registered on its last screenshot. Reading it does not
/// trigger a screenshot, so this works while the script is running — unlike the
/// annotator tool, which opens its own device and fights the script over the
/// emulator.
///
/// Because the image service keeps each config's newest frame regardless of the
/// cache TTL, the last picture also stays on screen after the script stops, so
/// nothing has to be written to disk.
class LastScreenshotPanel extends StatefulWidget {
  const LastScreenshotPanel({
    super.key,
    required this.scriptName,
    this.compact = false,
  });

  /// Config name the backend keys the frame by.
  final String scriptName;

  /// Compact mode used when embedded alongside the bottom-middle pie chart.
  final bool compact;

  @override
  State<LastScreenshotPanel> createState() => _LastScreenshotPanelState();
}

class _LastScreenshotPanelState extends State<LastScreenshotPanel> {
  /// Aspect ratio used before the real frame size is known.
  ///
  /// OAS enforces 1280x720, so this is usually correct anyway.
  static const double _fallbackAspectRatio = 16 / 9;

  /// Caps the auto-sized preview so it cannot squeeze the task list away.
  static const double _maxPreviewHeight = 480;

  /// How often the relative age label is recomputed.
  ///
  /// Only the label is refreshed, never the image or the metadata: the picture
  /// on screen must keep matching the age next to it.
  static const Duration _ageTickInterval = Duration(seconds: 30);

  final GetStorage _storage = GetStorage();

  bool _collapsed = false;

  /// Real aspect ratio of the latest frame, learned from the decoded image.
  double? _aspectRatio;

  /// Frame whose aspect ratio was already requested, to avoid re-resolving.
  Uint8List? _resolvedFrame;

  /// Newest frame pushed by the backend; null until the first one arrives.
  Uint8List? _liveFrame;

  /// Metadata announced right before [_liveFrame] in the same push.
  LastScreenshotMeta? _pendingLiveMeta;

  /// When the shown frame was captured; null until the first answer arrives.
  LastScreenshotMeta? _meta;

  /// WebSocket name in use, so the right one gets closed when switching config.
  String? _liveChannel;

  /// Keeps the relative age honest while the panel stays open.
  Timer? _ageTicker;

  /// Channel name for the live stream.
  ///
  /// Carries the backend address so that pointing the app at another OAS host
  /// opens a fresh stream. `WebSocketService.connect` matches on the name alone
  /// and ignores the url, so a name without the host would keep reusing the
  /// stream that is still connected to the previous host.
  String _liveChannelName(String scriptName) =>
      'screenshot_live_${ApiClient().baseAddress}_$scriptName';

  /// Effective collapse state; compact mode is always expanded.
  bool get _isCollapsed => !widget.compact && _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = _readCollapsed();
    // 布局变化导致的重建：先把上一帧捡回来，避免"空画面"闪一下（甚至一直空着）。
    _restoreCachedFrame();
    if (!_isCollapsed) {
      _connectLive();
    }
    _ageTicker = Timer.periodic(_ageTickInterval, (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Seeds the panel from the channel cache kept across rebuilds.
  void _restoreCachedFrame() {
    final channel = _liveChannelName(widget.scriptName);
    _liveFrame = _lastFrameByChannel[channel];
    _meta = _lastMetaByChannel[channel];
    _aspectRatio = _lastAspectByChannel[channel];
  }

  @override
  void dispose() {
    _ageTicker?.cancel();
    _ageTicker = null;
    unawaited(_disconnectLive());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LastScreenshotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another config's frame must not stay on screen after switching. The stream
    // itself is re-pointed by [_ensureLiveChannel] on the next build, which also
    // catches a changed backend address.
    if (oldWidget.scriptName != widget.scriptName) {
      _clearFrame();
    }
  }

  /// Drops the frame on screen, e.g. before the stream is rebuilt.
  void _clearFrame() {
    _liveFrame = null;
    _meta = null;
    _pendingLiveMeta = null;
    _aspectRatio = null;
    _resolvedFrame = null;
  }

  /// Keeps the live stream pointed at the current config and backend host.
  ///
  /// The preview used to be an `Image.network` whose URL was rebuilt on every
  /// build, so it followed a backend address change for free. A WebSocket keeps
  /// whatever host it dialed, so the channel has to be rebuilt whenever its name
  /// (config + address) changes. Checking from `build` rather than only from
  /// `didUpdateWidget` matters: editing the address in settings leaves this
  /// panel alive without rebuilding its parent, and it would otherwise stay on
  /// the previous host until the app restarted.
  void _ensureLiveChannel() {
    if (_isCollapsed) {
      return;
    }
    final expected = _liveChannelName(widget.scriptName);
    if (_liveChannel == expected) {
      return;
    }
    // Deferred: reconnecting mutates state, which build must not do.
    // 先 await 旧流的关闭，再连接：否则晚到的 close 会把新挂上的监听清掉。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isCollapsed || _liveChannel == expected) {
        return;
      }
      setState(_clearFrame);
      await _disconnectLive();
      if (!mounted || _isCollapsed) {
        return;
      }
      await _connectLive();
    });
  }

  /// Opens the live stream that keeps the preview in sync with the script.
  Future<void> _connectLive() async {
    final channel = _liveChannelName(widget.scriptName);
    // 旧实例可能刚发起过 close；先等它落地，否则它的 close 会清掉我们马上要挂的监听。
    final pendingClose = _pendingCloseByChannel[channel];
    if (pendingClose != null) {
      try {
        await pendingClose;
      } catch (_) {
        // 关闭失败不影响本次重连。
      }
    }
    if (!mounted) {
      return;
    }
    _liveChannel = channel;
    final service = Get.find<WebSocketService>();
    // Listeners are keyed by name, so stale ones have to go before reconnecting.
    service.removeAllListeners(channel);
    try {
      await service.connect(
        name: channel,
        url: ApiClient().buildLiveScreenshotWsUrl(widget.scriptName),
        listener: _onLiveMessage,
      );
    } catch (e) {
      // The preview just stays empty; the client retries on its own.
      printError(info: 'screenshot live connect failed: $e');
      return;
    }
    if (!mounted || _liveChannel != channel) {
      // The panel went away or switched config while connecting, so drop it.
      unawaited(service.close(channel));
    }
  }

  /// Closes the live stream, if one is open.
  ///
  /// Callers that intend to reconnect must await it. `WebSocketService.connect`
  /// returns the existing client while it still reports `connected`, so a close
  /// that lands afterwards would clear the listeners attached in the meantime
  /// and leave the preview permanently empty.
  Future<void> _disconnectLive() async {
    final channel = _liveChannel;
    _liveChannel = null;
    if (channel == null) {
      return;
    }
    // 登记这次关闭：重建出来的新实例会先等它完成，避免竞态清掉新监听。
    final pending = _closeChannel(channel);
    _pendingCloseByChannel[channel] = pending;
    try {
      await pending;
    } finally {
      if (identical(_pendingCloseByChannel[channel], pending)) {
        _pendingCloseByChannel.remove(channel);
      }
    }
  }

  /// Closes one channel, mapping failures to a non-throwing future.
  Future<void> _closeChannel(String channel) async {
    try {
      await Get.find<WebSocketService>().close(channel);
    } catch (e) {
      // Cleanup must never throw, e.g. when the app is shutting down.
      printError(info: 'screenshot live close failed: $e');
    }
  }

  /// Handles one push: a metadata message (text) or a frame (binary).
  void _onLiveMessage(dynamic message) {
    if (!mounted) {
      return;
    }
    if (message is List<int>) {
      final meta = _pendingLiveMeta;
      final frame = Uint8List.fromList(message);
      final channel = _liveChannelName(widget.scriptName);
      _rememberLiveFrame(channel, frame);
      if (meta != null) {
        _rememberLiveMeta(channel, meta);
      }
      setState(() {
        _liveFrame = frame;
        if (meta != null) {
          _meta = meta;
        }
      });
      _syncAspectRatio(frame);
      return;
    }
    if (message is! String) {
      return;
    }
    final decoded = jsonDecode(message);
    if (decoded is! Map) {
      return;
    }
    if (decoded['event'] == 'empty') {
      // This config never produced a frame, i.e. the script never started.
      final channel = _liveChannelName(widget.scriptName);
      _forgetLiveFrame(channel);
      _rememberLiveMeta(channel, const LastScreenshotMeta.empty());
      setState(() {
        _liveFrame = null;
        _meta = const LastScreenshotMeta.empty();
      });
      return;
    }
    _pendingLiveMeta = LastScreenshotMeta.fromLiveFrame(
      decoded.cast<String, dynamic>(),
    );
  }

  /// Drops what is on screen and opens a fresh stream.
  ///
  /// Closing is awaited before reconnecting: the channel name does not change
  /// here, so a still-open client would be reused and the late `close` would
  /// then wipe the listeners just attached, leaving the preview stuck empty.
  Future<void> _refresh() async {
    setState(_clearFrame);
    await _disconnectLive();
    if (!_isCollapsed) {
      await _connectLive();
    }
  }

  /// Builds the "captured at" line, or null when there is nothing to say.
  String? _capturedLabel() {
    final meta = _meta;
    if (meta == null) {
      return null;
    }
    final capturedAt = meta.capturedAt;
    if (!meta.exists || capturedAt == null) {
      // Also used when collapsed, where the preview cannot explain itself.
      return I18n.lastScreenshotEmpty.tr;
    }
    final age = screenshotAgeOf(capturedAt);
    final ageLabel = switch (age.unit) {
      ScreenshotAgeUnit.justNow => I18n.lastScreenshotAgeJustNow.tr,
      ScreenshotAgeUnit.minutes => I18n.lastScreenshotAgeMinutes.trParams({
        'n': '${age.value}',
      }),
      ScreenshotAgeUnit.hours => I18n.lastScreenshotAgeHours.trParams({
        'n': '${age.value}',
      }),
      ScreenshotAgeUnit.days => I18n.lastScreenshotAgeDays.trParams({
        'n': '${age.value}',
      }),
    };
    return '${formatScreenshotCapturedAt(capturedAt)} · $ageLabel';
  }

  /// Builds the full "captured at" line for non-compact mode.
  String? _fullCapturedLabel() {
    final meta = _meta;
    if (meta == null) {
      return null;
    }
    final capturedAt = meta.capturedAt;
    if (!meta.exists || capturedAt == null) {
      return I18n.lastScreenshotEmpty.tr;
    }
    final age = screenshotAgeOf(capturedAt);
    final ageLabel = switch (age.unit) {
      ScreenshotAgeUnit.justNow => I18n.lastScreenshotAgeJustNow.tr,
      ScreenshotAgeUnit.minutes => I18n.lastScreenshotAgeMinutes.trParams({
        'n': '${age.value}',
      }),
      ScreenshotAgeUnit.hours => I18n.lastScreenshotAgeHours.trParams({
        'n': '${age.value}',
      }),
      ScreenshotAgeUnit.days => I18n.lastScreenshotAgeDays.trParams({
        'n': '${age.value}',
      }),
    };
    return I18n.lastScreenshotCapturedAt.trParams({
      'time': formatScreenshotCapturedAt(capturedAt),
      'age': ageLabel,
    });
  }

  /// Reads the remembered collapse state of the preview.
  bool _readCollapsed() {
    return _storage.read<bool>(StorageKey.lastScreenshotCollapsed.name) ??
        false;
  }

  /// Toggles the preview and remembers the choice across sessions.
  ///
  /// Re-expanding awaits the close for the same reason as [_refresh]: the
  /// channel name is unchanged, so a half-closed client would be reused and
  /// then lose its listeners.
  Future<void> _toggleCollapsed() async {
    final next = !_collapsed;
    setState(() => _collapsed = next);
    _storage.write(StorageKey.lastScreenshotCollapsed.name, next);
    if (next) {
      // Nothing is on screen while collapsed, so stop paying for the stream.
      await _disconnectLive();
    } else {
      await _connectLive();
    }
  }

  /// Learns the frame aspect ratio so the preview can size itself to it.
  void _syncAspectRatio(Uint8List frame) {
    if (identical(_resolvedFrame, frame)) {
      return;
    }
    _resolvedFrame = frame;
    final stream = MemoryImage(frame).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      final width = info.image.width;
      final height = info.image.height;
      if (width <= 0 || height <= 0) {
        return;
      }
      final ratio = width / height;
      // 也写进频道缓存：重建后直接就有正确的宽高比，画面不会先被拉伸一下。
      _rememberLiveAspect(_liveChannelName(widget.scriptName), ratio);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _aspectRatio == ratio) {
          return;
        }
        setState(() => _aspectRatio = ratio);
      });
    }, onError: (_, __) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    _ensureLiveChannel();
    final theme = Theme.of(context);
    final label = widget.compact ? _capturedLabel() : _fullCapturedLabel();
    final scheme = theme.colorScheme;
    if (widget.compact) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    I18n.lastScreenshotTitle.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer.withValues(
                            alpha: 0.65,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    tooltip: I18n.lastScreenshotRefresh.tr,
                    onPressed: _refresh,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(child: _preview(context)),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 10 : 12),
        child: Column(
          mainAxisSize: widget.compact ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    I18n.lastScreenshotTitle.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                _action(
                  icon: Icons.refresh_rounded,
                  tooltip: I18n.lastScreenshotRefresh.tr,
                  onPressed: _refresh,
                ),
                if (!widget.compact)
                  _action(
                    icon: _collapsed
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    tooltip:
                        (_collapsed
                                ? I18n.lastScreenshotExpand
                                : I18n.lastScreenshotCollapse)
                            .tr,
                    onPressed: _toggleCollapsed,
                  ),
              ],
            ),
            if (label != null) ...[
              const SizedBox(height: 2),
              Padding(
                // Lines up with the title text, past the 18px icon and its gap.
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (widget.compact) ...[
              const SizedBox(height: 6),
              Expanded(child: _preview(context)),
            ] else if (!_collapsed) ...[
              const SizedBox(height: 8),
              _preview(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }

  Widget _preview(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final frame = _liveFrame;
    final previewContent = frame == null
        ? Center(
            child: Text(
              I18n.lastScreenshotEmpty.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        : Image.memory(
            frame,
            fit: BoxFit.contain,
            // Keeps the old frame visible while the next one decodes,
            // so a 4fps stream does not flicker.
            gaplessPlayback: true,
          );
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: frame == null ? null : () => _openFullscreen(context, frame),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: widget.compact ? double.infinity : null,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          child: widget.compact
              ? previewContent
              : ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: _maxPreviewHeight,
                  ),
                  child: AspectRatio(
                    aspectRatio: _aspectRatio ?? _fallbackAspectRatio,
                    child: previewContent,
                  ),
                ),
        ),
      ),
    );
  }

  /// Opens the frame in a zoomable full-screen dialog.
  void _openFullscreen(BuildContext context, Uint8List frame) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                maxScale: 5,
                child: Image.memory(frame, fit: BoxFit.contain),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(
                    dialogContext,
                  ).closeButtonTooltip,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

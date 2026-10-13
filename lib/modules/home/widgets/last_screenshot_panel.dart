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
  const LastScreenshotPanel({super.key, required this.scriptName});

  /// Config name the backend keys the frame by.
  final String scriptName;

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

  @override
  void initState() {
    super.initState();
    _collapsed = _readCollapsed();
    if (!_collapsed) {
      _connectLive();
    }
    _ageTicker = Timer.periodic(_ageTickInterval, (_) {
      if (mounted) {
        setState(() {});
      }
    });
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
    if (_collapsed) {
      return;
    }
    final expected = _liveChannelName(widget.scriptName);
    if (_liveChannel == expected) {
      return;
    }
    // Deferred: reconnecting mutates state, which build must not do.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _collapsed || _liveChannel == expected) {
        return;
      }
      unawaited(_disconnectLive());
      setState(_clearFrame);
      _connectLive();
    });
  }

  /// Opens the live stream that keeps the preview in sync with the script.
  Future<void> _connectLive() async {
    final channel = _liveChannelName(widget.scriptName);
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
    if (!_collapsed) {
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
    final label = _capturedLabel();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            if (!_collapsed) ...[const SizedBox(height: 8), _preview(context)],
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: frame == null ? null : () => _openFullscreen(context, frame),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxPreviewHeight),
            child: AspectRatio(
              aspectRatio: _aspectRatio ?? _fallbackAspectRatio,
              child: frame == null
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
                    ),
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Shows the newest screenshot OAS captured for one config.
///
/// The backend overwrites a single file per config, so refreshing only needs a
/// fresh cache buster rather than a new backend call.
class LastScreenshotPanel extends StatefulWidget {
  const LastScreenshotPanel({super.key, required this.scriptName});

  /// Config name the backend keys the screenshot file by.
  final String scriptName;

  @override
  State<LastScreenshotPanel> createState() => _LastScreenshotPanelState();
}

class _LastScreenshotPanelState extends State<LastScreenshotPanel> {
  /// Aspect ratio used before the real frame size is known.
  static const double _fallbackAspectRatio = 16 / 9;

  /// Caps the auto-sized preview so it cannot squeeze the task list away.
  static const double _maxPreviewHeight = 480;

  final GetStorage _storage = GetStorage();

  late int _cacheBuster = _stamp();
  bool _collapsed = false;

  /// Real aspect ratio of the latest frame, learned from the decoded image.
  double? _aspectRatio;

  /// URL whose aspect ratio was already requested, to avoid re-resolving.
  String? _resolvedUrl;

  static int _stamp() => DateTime.now().millisecondsSinceEpoch;

  String get _url => ApiClient().buildLastScreenshotUrl(
    widget.scriptName,
    cacheBuster: _cacheBuster,
  );

  @override
  void initState() {
    super.initState();
    _collapsed = _readCollapsed();
    _syncAspectRatio(_url);
  }

  @override
  void didUpdateWidget(covariant LastScreenshotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another config's frame must not stay on screen after switching.
    if (oldWidget.scriptName != widget.scriptName) {
      _cacheBuster = _stamp();
      _aspectRatio = null;
      _resolvedUrl = null;
      _syncAspectRatio(_url);
    }
  }

  void _refresh() {
    setState(() {
      _cacheBuster = _stamp();
      _resolvedUrl = null;
    });
    _syncAspectRatio(_url);
  }

  /// Reads the remembered collapse state of the preview.
  bool _readCollapsed() {
    return _storage.read<bool>(StorageKey.lastScreenshotCollapsed.name) ??
        false;
  }

  /// Toggles the preview and remembers the choice across sessions.
  void _toggleCollapsed() {
    final next = !_collapsed;
    setState(() => _collapsed = next);
    _storage.write(StorageKey.lastScreenshotCollapsed.name, next);
  }

  /// Learns the frame aspect ratio so the preview can size itself to it.
  void _syncAspectRatio(String url) {
    if (_resolvedUrl == url) {
      return;
    }
    _resolvedUrl = url;
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
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
    final theme = Theme.of(context);
    final url = _url;
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
            if (!_collapsed) ...[
              const SizedBox(height: 8),
              _preview(context, url),
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

  Widget _preview(BuildContext context, String url) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openFullscreen(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxPreviewHeight),
            child: AspectRatio(
              aspectRatio: _aspectRatio ?? _fallbackAspectRatio,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    I18n.lastScreenshotEmpty.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the frame in a zoomable full-screen dialog.
  void _openFullscreen(BuildContext context, String url) {
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
                child: Image.network(url, fit: BoxFit.contain),
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

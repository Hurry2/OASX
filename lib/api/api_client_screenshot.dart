part of 'api_client.dart';

/// Client calls for the OAS `screenshot` API.
extension ApiClientScreenshotX on ApiClient {
  /// Resolves the WebSocket endpoint that streams one config's live frames.
  ///
  /// The backend reads the frame the script registered into its image service,
  /// so this never triggers a screenshot and can run alongside the script. Each
  /// new frame arrives as a json metadata message followed by a binary JPEG.
  ///
  /// Built from scratch rather than via [Uri.replace] so no stray `?` is left
  /// behind by an empty query, and so any query on the base address is dropped.
  String buildLiveScreenshotWsUrl(String instance) {
    final base = Uri.parse(baseAddress);
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      userInfo: base.userInfo.isEmpty ? null : base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'screenshot',
        'live',
        'ws',
        instance.trim(),
      ],
    ).toString();
  }
}

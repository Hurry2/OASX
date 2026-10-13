part of 'api_client.dart';

/// Client calls for the OAS `screenshot` API (`GET /screenshot/last`).
///
/// The backend overwrites a single file per config, so the same URL always
/// resolves to the newest frame. Callers pass a cache buster to force a
/// refetch instead of being served from the HTTP cache.
extension ApiClientScreenshotX on ApiClient {
  /// Resolves the absolute URL of one config's latest screenshot.
  ///
  /// [cacheBuster] is appended as the `t` query parameter.
  String buildLastScreenshotUrl(String instance, {int? cacheBuster}) {
    final base = Uri.parse(baseAddress);
    return base
        .replace(
          pathSegments: [
            ...base.pathSegments.where((segment) => segment.isNotEmpty),
            'screenshot',
            'last',
          ],
          queryParameters: {
            'instance': instance.trim(),
            if (cacheBuster != null) 't': '$cacheBuster',
          },
        )
        .toString();
  }
}

import 'package:intl/intl.dart';

/// Metadata of one config's latest frame.
///
/// Comes from the live-frame push: the backend announces every frame with
/// `{"event": "frame", "created_at": <epoch seconds>}` right before the JPEG
/// bytes, so the panel can tell how fresh the picture on screen is.
class LastScreenshotMeta {
  const LastScreenshotMeta({required this.exists, this.capturedAt});

  /// Metadata for a config that has never produced a frame.
  const LastScreenshotMeta.empty() : exists = false, capturedAt = null;

  /// Whether OAS already has a frame for this config.
  final bool exists;

  /// When the frame was captured, in local time.
  final DateTime? capturedAt;

  /// Builds metadata from a live-frame push.
  ///
  /// `created_at` is epoch seconds; Dart converts to local time here so the
  /// label never depends on the server's time zone.
  factory LastScreenshotMeta.fromLiveFrame(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    return LastScreenshotMeta(
      exists: true,
      capturedAt: createdAt is num
          ? DateTime.fromMillisecondsSinceEpoch((createdAt * 1000).round())
          : null,
    );
  }
}

/// Coarse age unit of a screenshot, chosen so the label stays short.
enum ScreenshotAgeUnit {
  /// Written less than a minute ago.
  justNow,

  /// Written within the last hour.
  minutes,

  /// Written within the last day.
  hours,

  /// Written one or more days ago.
  days,
}

/// Age of a screenshot grouped into the unit its label should use.
class ScreenshotAge {
  const ScreenshotAge(this.unit, this.value);

  final ScreenshotAgeUnit unit;

  /// Amount of [unit]; always 0 for [ScreenshotAgeUnit.justNow].
  final int value;
}

/// Formats a capture time, dropping the date parts that add no information.
///
/// Same day shows only the clock, same year adds the date, older adds the year,
/// so the label stays as short as it can while remaining unambiguous.
String formatScreenshotCapturedAt(DateTime capturedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final sameDay =
      capturedAt.year == reference.year &&
      capturedAt.month == reference.month &&
      capturedAt.day == reference.day;
  if (sameDay) {
    return DateFormat('HH:mm:ss').format(capturedAt);
  }
  if (capturedAt.year == reference.year) {
    return DateFormat('MM-dd HH:mm').format(capturedAt);
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(capturedAt);
}

/// Groups [capturedAt] into a coarse unit for display.
ScreenshotAge screenshotAgeOf(DateTime capturedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(capturedAt);
  if (elapsed.isNegative || elapsed.inMinutes < 1) {
    // A negative age means clock drift between the two machines; treating it as
    // "just now" is friendlier than rendering a negative duration.
    return const ScreenshotAge(ScreenshotAgeUnit.justNow, 0);
  }
  if (elapsed.inHours < 1) {
    return ScreenshotAge(ScreenshotAgeUnit.minutes, elapsed.inMinutes);
  }
  if (elapsed.inDays < 1) {
    return ScreenshotAge(ScreenshotAgeUnit.hours, elapsed.inHours);
  }
  return ScreenshotAge(ScreenshotAgeUnit.days, elapsed.inDays);
}

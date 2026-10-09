import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Increase tone: the game resource grew since the previous snapshot.
///
/// Follows the in-game (and Chinese market) convention — red is up, green is
/// down — which is the opposite of the western one. Shared by the list grid and
/// the trend view so a change never changes colour between the two.
const Color storageStatsDeltaUpTone = Color(0xFFD64545);

/// Decrease tone: the game resource shrank since the previous snapshot.
const Color storageStatsDeltaDownTone = Color(0xFF2E9E5B);

/// Icon and accent tone used by one resource.
///
/// Shared presentation of a resource name: the list grid uses it for the tile
/// artwork, the trend view for the legend chip and the line colour.
class StorageResourceStyle {
  /// Creates one resource style.
  const StorageResourceStyle({
    required this.asset,
    required this.icon,
    required this.tone,
  });

  /// In-game icon (transparent PNG) bundled with the app.
  final String asset;

  /// Vector glyph used when the bundled icon is unavailable.
  final IconData icon;

  /// Accent colour: the fallback glyph tint and the trend line colour.
  final Color tone;

  /// Style used for resource names without a dedicated mapping.
  static const StorageResourceStyle fallback = StorageResourceStyle(
    asset: '',
    icon: Icons.category_rounded,
    tone: Color(0xFF757575),
  );

  /// Resolves the icon and tone for one resource name.
  ///
  /// Keys mirror the resource names produced by OAS
  /// (`tasks/DailyTrifles/script_task.py:run_storage_stats`); the PNG files
  /// live under `assets/storage_stats/`.
  static StorageResourceStyle resolve(String name, ColorScheme scheme) {
    switch (name.trim()) {
      case '金币':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/gold.png',
          icon: Icons.monetization_on_rounded,
          tone: Color(0xFFF2A600),
        );
      case '体力':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/sushi.png',
          icon: Icons.bolt_rounded,
          tone: Color(0xFFEF6C00),
        );
      case '勾玉':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/jade.png',
          icon: Icons.diamond_rounded,
          tone: Color(0xFF7E57C2),
        );
      case '蓝票':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/blue_ticket.png',
          icon: Icons.confirmation_number_rounded,
          tone: Color(0xFF1E88E5),
        );
      case '金蛇皮':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/gold_skin.png',
          icon: Icons.auto_awesome_rounded,
          tone: Color(0xFFC08A00),
        );
      case '逢魔皮':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/demon_skin.png',
          icon: Icons.local_fire_department_rounded,
          tone: Color(0xFFE64A19),
        );
      case '现世符咒':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/present_world_ticket.png',
          icon: Icons.article_rounded,
          tone: Color(0xFF00897B),
        );
      case '御札':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/return_soul.png',
          icon: Icons.style_rounded,
          tone: Color(0xFF5C6BC0),
        );
      default:
        return StorageResourceStyle(
          asset: fallback.asset,
          icon: fallback.icon,
          tone: scheme.onSurfaceVariant,
        );
    }
  }
}

/// Bundled in-game icon for one resource, falling back to a vector glyph.
class StorageResourceIcon extends StatelessWidget {
  /// Creates one resource icon.
  const StorageResourceIcon({super.key, required this.style});

  /// Rendered edge length, in logical pixels.
  static const double _size = 18;

  /// Style carrying the asset path, fallback glyph and tint.
  final StorageResourceStyle style;

  @override
  Widget build(BuildContext context) {
    if (style.asset.isEmpty) {
      return Icon(style.icon, size: _size - 2, color: style.tone);
    }
    // Icons are transparent RGBA cut-outs, so no rounded clip is applied —
    // clipping would shave the artwork's corners.
    return Image.asset(
      style.asset,
      width: _size,
      height: _size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          Icon(style.icon, size: _size - 2, color: style.tone),
    );
  }
}

/// Signed change label rendered next to a resource value.
class StorageDeltaLabel extends StatelessWidget {
  /// Creates one delta label.
  const StorageDeltaLabel({super.key, required this.delta, required this.text});

  /// Signed change; its sign picks the tone and the arrow direction.
  final double delta;

  /// Pre-formatted change text.
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = delta > 0
        ? storageStatsDeltaUpTone
        : storageStatsDeltaDownTone;
    return Tooltip(
      message: I18n.storageStatsComparePrevious.tr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delta > 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 12,
            color: tone,
          ),
          const SizedBox(width: 1),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

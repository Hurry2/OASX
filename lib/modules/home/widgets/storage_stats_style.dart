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
  /// (`tasks/DailyTrifles/mem_read.js` SPEC), i.e. the in-game currency names
  /// read straight from game memory. The PNG files are named after each
  /// currency id and live under `assets/storage_stats/`.
  static StorageResourceStyle resolve(String name, ColorScheme scheme) {
    switch (name.trim()) {
      case '勾玉':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900002.png',
          icon: Icons.diamond_rounded,
          tone: Color(0xFF7E57C2),
        );
      case '体力':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900003.png',
          icon: Icons.bolt_rounded,
          tone: Color(0xFFEF6C00),
        );
      case '神秘的符咒':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/490001.png',
          icon: Icons.auto_awesome_rounded,
          tone: Color(0xFF1E88E5),
        );
      case '魂玉':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900000.png',
          icon: Icons.monetization_on_rounded,
          tone: Color(0xFFF2A600),
        );
      case '金币':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900001.png',
          icon: Icons.paid_rounded,
          tone: Color(0xFFE6B800),
        );
      case '大蛇的逆鳞':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900217.png',
          icon: Icons.spa_rounded,
          tone: Color(0xFF00897B),
        );
      case '逢魔之魂':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900218.png',
          icon: Icons.local_fire_department_rounded,
          tone: Color(0xFFE64A19),
        );
      case '被遗忘的绘本':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/1001416.png',
          icon: Icons.menu_book_rounded,
          tone: Color(0xFF8D6E63),
        );
      case '八岐大蛇鳞片':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900216.png',
          icon: Icons.shield_rounded,
          tone: Color(0xFF2E9E5B),
        );
      case '勋章':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900016.png',
          icon: Icons.military_tech_rounded,
          tone: Color(0xFFFFB300),
        );
      case '功勋':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900090.png',
          icon: Icons.star_rounded,
          tone: Color(0xFF546E7A),
        );
      case '荣誉':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900012.png',
          icon: Icons.emoji_events_rounded,
          tone: Color(0xFFC9A227),
        );
      case '御札':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900178.png',
          icon: Icons.style_rounded,
          tone: Color(0xFF5C6BC0),
        );
      case '御行达摩':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/411.png',
          icon: Icons.brightness_1_rounded,
          tone: Color(0xFFD64545),
        );
      case '御行达摩(碎片)':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/434111.png',
          icon: Icons.donut_small_rounded,
          tone: Color(0xFFEF5350),
        );
      case '御灵境之钥':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900215.png',
          icon: Icons.key_rounded,
          tone: Color(0xFF26C6DA),
        );
      case '痴念之卷':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900041.png',
          icon: Icons.auto_stories_rounded,
          tone: Color(0xFF7E57C2),
        );
      case '结界挑战券':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900024.png',
          icon: Icons.confirmation_number_rounded,
          tone: Color(0xFF26A69A),
        );
      case '破碎的符咒':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/490002.png',
          icon: Icons.blur_circular_rounded,
          tone: Color(0xFF78909C),
        );
      case '式神挑战券':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900120.png',
          icon: Icons.confirmation_number_outlined,
          tone: Color(0xFF5E35B1),
        );
      case '百鬼夜行门票':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900007.png',
          icon: Icons.confirmation_number_rounded,
          tone: Color(0xFF8E24AA),
        );
      case '现世符咒':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/490004.png',
          icon: Icons.article_rounded,
          tone: Color(0xFF00897B),
        );
      case '皮肤券':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900023.png',
          icon: Icons.face_rounded,
          tone: Color(0xFFEC407A),
        );
      case 'SP皮肤券':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/906058.png',
          icon: Icons.face_rounded,
          tone: Color(0xFFD81B60),
        );
      case '樱饼':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900273.png',
          icon: Icons.fastfood_rounded,
          tone: Color(0xFFF48FB1),
        );
      case '绘卷碎片·小':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/903549.png',
          icon: Icons.auto_stories_rounded,
          tone: Color(0xFF5C6BC0),
        );
      case '绘卷碎片·中':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/903550.png',
          icon: Icons.auto_stories_rounded,
          tone: Color(0xFF3949AB),
        );
      case '绘卷碎片·大':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/903551.png',
          icon: Icons.auto_stories_rounded,
          tone: Color(0xFF5E35B1),
        );
      case '寄售券':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900338.png',
          icon: Icons.confirmation_number_rounded,
          tone: Color(0xFF7E57C2),
        );
      case '契忆':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900622.png',
          icon: Icons.auto_stories_rounded,
          tone: Color(0xFF26A69A),
        );
      case '百物式盘':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/777800.png',
          icon: Icons.auto_awesome_rounded,
          tone: Color(0xFF8E24AA),
        );
      case '金御札':
        return const StorageResourceStyle(
          asset: 'assets/storage_stats/900188.png',
          icon: Icons.style_rounded,
          tone: Color(0xFFC08A00),
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

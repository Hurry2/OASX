import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chinese_font_library/chinese_font_library.dart';

const List<String> _webChineseFontFallback = <String>[
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'Noto Sans SC',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
  'sans-serif',
];

/// 一套"看着舒服"的配色种子：低饱和、明暗模式下都不刺眼。
///
/// 只挑一个种子色，其余由 M3 的 `colorSchemeSeed` 自动配平（含深浅两套）。
enum AppAccentTheme {
  indigo('靛蓝 Indigo', Color(0xff5B6ABF)),
  teal('青碧 Teal', Color(0xff2F7D74)),
  forest('森绿 Forest', Color(0xff3F7D4F)),
  ocean('海蓝 Ocean', Color(0xff2F6F9F)),
  violet('紫罗兰 Violet', Color(0xff7A5AA8)),
  clay('暖陶 Clay', Color(0xffB06A4A));

  const AppAccentTheme(this.label, this.seed);

  /// 显示名（中英并列，避免再铺一套 i18n）。
  final String label;

  /// M3 种子色。
  final Color seed;
}

/// 界面背景预设：每种都给出明/暗两版，避免反色模式下糊成一片。
enum AppBackgroundTheme {
  auto('跟随主题 Auto', null, null),
  snow('纯白 Snow', Color(0xffFFFFFF), Color(0xff1B1B1F)),
  warm('暖白 Warm', Color(0xffFAF7F2), Color(0xff23211E)),
  paper('米纸 Paper', Color(0xffF5F3EC), Color(0xff26241F)),
  mist('雾青 Mist', Color(0xffF1F5F4), Color(0xff1E2423)),
  night('夜墨 Ink', Color(0xffF2F3F7), Color(0xff121316));

  const AppBackgroundTheme(this.label, this.light, this.dark);

  /// 显示名（中英并列）。
  final String label;

  /// 浅色模式背景；null 表示用 M3 默认。
  final Color? light;

  /// 深色模式背景；null 表示用 M3 默认。
  final Color? dark;
}

/// M3 默认背景（`auto` 预设回退到这里）。
const Color _defaultLightBackground = Color.fromRGBO(255, 251, 255, 1);
const Color _defaultDarkBackground = Color.fromRGBO(49, 48, 51, 1);

/// 选壁纸后自动采用的表面不透明度（用户觉得挡得太多时可以再往下调）。
const double kDefaultWallpaperSurfaceAlpha = 0.86;

/// Builds one app theme from the chosen accent seed, background preset and
/// surface opacity.
///
/// [surfaceAlpha] < 1 时：表面改成半透明、Scaffold/画布/导航栏透明，
/// 好让底下的自定义壁纸（或桌面）透出来。可读性靠壁纸层那层遮罩保证。
ThemeData buildAppTheme({
  required Brightness brightness,
  AppAccentTheme accent = AppAccentTheme.indigo,
  AppBackgroundTheme background = AppBackgroundTheme.auto,
  double surfaceAlpha = 1.0,
}) {
  final isLight = brightness == Brightness.light;
  final fallback = isLight ? _defaultLightBackground : _defaultDarkBackground;
  final backgroundColor =
      (isLight ? background.light : background.dark) ?? fallback;
  final base = ThemeData(
    colorSchemeSeed: accent.seed,
    useMaterial3: true,
    brightness: brightness,
    textTheme: _buildTextTheme(brightness),
  );
  if (surfaceAlpha < 1.0) {
    final scheme = base.colorScheme;
    return base.copyWith(
      colorScheme: scheme.copyWith(
        surface: _withSurfaceAlpha(scheme.surface, surfaceAlpha),
        surfaceContainerLowest: _withSurfaceAlpha(
          scheme.surfaceContainerLowest,
          surfaceAlpha,
        ),
        surfaceContainerLow: _withSurfaceAlpha(
          scheme.surfaceContainerLow,
          surfaceAlpha,
        ),
        surfaceContainer: _withSurfaceAlpha(
          scheme.surfaceContainer,
          surfaceAlpha,
        ),
        surfaceContainerHigh: _withSurfaceAlpha(
          scheme.surfaceContainerHigh,
          surfaceAlpha,
        ),
        surfaceContainerHighest: _withSurfaceAlpha(
          scheme.surfaceContainerHighest,
          surfaceAlpha,
        ),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.transparent,
      ),
    );
  }
  return base.copyWith(
    scaffoldBackgroundColor: backgroundColor,
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: backgroundColor,
    ),
  );
}

/// Applies [surfaceAlpha] while keeping the color's own opacity cap.
Color _withSurfaceAlpha(Color color, double surfaceAlpha) =>
    color.withValues(alpha: color.a * surfaceAlpha);

/// 实际使用的主题见 `ThemeService.lightThemeData` / `darkThemeData`
/// （它们把选中的配色与背景组合起来）。

TextTheme _buildTextTheme(Brightness brightness) {
  const baseTheme = TextTheme(
    bodyLarge: TextStyle(),
    bodyMedium: TextStyle(),
    bodySmall: TextStyle(),
    labelLarge: TextStyle(),
    labelMedium: TextStyle(),
    labelSmall: TextStyle(),
    titleLarge: TextStyle(),
    titleMedium: TextStyle(),
    titleSmall: TextStyle(),
  );
  if (kIsWeb) {
    return _applyFontFallback(baseTheme, _webChineseFontFallback);
  }
  return baseTheme.apply(fontFamily: 'LatoLato').useSystemChineseFont(
        brightness,
      );
}

TextTheme _applyFontFallback(TextTheme textTheme, List<String> fallback) {
  return textTheme.copyWith(
    bodyLarge: _applyTextStyleFallback(textTheme.bodyLarge, fallback),
    bodyMedium: _applyTextStyleFallback(textTheme.bodyMedium, fallback),
    bodySmall: _applyTextStyleFallback(textTheme.bodySmall, fallback),
    labelLarge: _applyTextStyleFallback(textTheme.labelLarge, fallback),
    labelMedium: _applyTextStyleFallback(textTheme.labelMedium, fallback),
    labelSmall: _applyTextStyleFallback(textTheme.labelSmall, fallback),
    titleLarge: _applyTextStyleFallback(textTheme.titleLarge, fallback),
    titleMedium: _applyTextStyleFallback(textTheme.titleMedium, fallback),
    titleSmall: _applyTextStyleFallback(textTheme.titleSmall, fallback),
  );
}

TextStyle? _applyTextStyleFallback(TextStyle? style, List<String> fallback) {
  return style?.copyWith(fontFamilyFallback: fallback);
}

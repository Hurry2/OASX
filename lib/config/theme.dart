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

/// 精选高辨识度现代配色种子（参照 Linear / Cyber Mint / Matcha / Nord / Rosé / Sunset）。
///
/// 搭配 M3 `DynamicSchemeVariant.vibrant`，让每个配色的主色与容器色都有明显区分。
enum AppAccentTheme {
  indigo('靛蓝 Indigo', Color(0xff4F46E5)),
  teal('青碧 Mint', Color(0xff0D9488)),
  forest('森绿 Matcha', Color(0xff16A34A)),
  ocean('海蓝 Nord', Color(0xff0284C7)),
  violet('紫罗兰 Rosé', Color(0xff9333EA)),
  clay('珊瑚橘 Coral', Color(0xffEA580C));

  const AppAccentTheme(this.label, this.seed);

  /// 显示名（中英并列，避免再铺一套 i18n）。
  final String label;

  /// M3 种子色。
  final Color seed;
}

/// 界面背景预设：每种都给出明/暗两版，且与纯白拉开明显氛围差距。
enum AppBackgroundTheme {
  auto('跟随主题 Auto', null, null),
  snow('极简 Snow', Color(0xffFFFFFF), Color(0xff0F1117)),
  warm('奶油 Warm', Color(0xffFDF6EC), Color(0xff1E1815)),
  paper('羊皮纸 Paper', Color(0xffF4EBD9), Color(0xff211D18)),
  mist('雾青 Mist', Color(0xffE6F4F1), Color(0xff101E20)),
  night('暮色 Ink', Color(0xffECEEF8), Color(0xff0D101B));

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
  final scheme = ColorScheme.fromSeed(
    seedColor: accent.seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    textTheme: _buildTextTheme(brightness),
  );
  if (surfaceAlpha < 1.0) {
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

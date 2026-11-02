import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/config/theme.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/service/system_tray_service.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/platform_utils.dart';
import 'package:path_provider/path_provider.dart';

/// 允许作为壁纸的图片扩展名。
///
/// 与 Flutter 内置解码器（PNG/JPEG/GIF/WebP/BMP）保持一致 —— **不含 HEIC**：
/// 引擎解不了 HEIC，硬塞进来只会得到一张打不开的图。
const List<String> _wallpaperExtensions = <String>[
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.bmp',
  '.gif',
];

/// 默认壁纸遮罩浓度（越大壁纸越淡、文字越好读）。
const double _defaultWallpaperDim = 0.55;

/// Owns the app's theme choices: dark/light, accent seed, background and wallpaper.
class ThemeService extends GetxService {
  final _storage = GetStorage();
  final _dark = false.obs;
  final _accent = AppAccentTheme.indigo.obs;
  final _background = AppBackgroundTheme.auto.obs;
  final _wallpaperPath = ''.obs;
  final _wallpaperDim = _defaultWallpaperDim.obs;
  final _surfaceAlpha = 1.0.obs;

  bool get isDarkMode => _dark.value;
  AppAccentTheme get accent => _accent.value;
  AppBackgroundTheme get background => _background.value;

  /// 壁纸文件的绝对路径（'' = 未设置）。
  String get wallpaperPath => _wallpaperPath.value;

  /// 壁纸遮罩浓度（0 = 原图，越大越淡）。
  double get wallpaperDim => _wallpaperDim.value;

  /// 是否设置了自定义壁纸。
  bool get hasWallpaper => _wallpaperPath.value.isNotEmpty;

  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// 自定义壁纸只在桌面端可用（Web 没有文件系统）。
  bool get canUseWallpaper => !PlatformUtils.isWeb;

  /// Current light theme built from the selected accent + background.
  ThemeData get lightThemeData => buildAppTheme(
    brightness: Brightness.light,
    accent: _accent.value,
    background: _background.value,
    surfaceAlpha: _surfaceAlpha.value,
  );

  /// Current dark theme built from the selected accent + background.
  ThemeData get darkThemeData => buildAppTheme(
    brightness: Brightness.dark,
    accent: _accent.value,
    background: _background.value,
    surfaceAlpha: _surfaceAlpha.value,
  );

  /// 界面表面不透明度（1 = 完全不透明；越低壁纸/桌面透出越多）。
  double get surfaceAlpha => _surfaceAlpha.value;

  @override
  void onInit() {
    _dark.value = _storage.read(StorageKey.dark.name) ?? false;
    _accent.value = AppAccentTheme.values.firstWhere(
      (item) => item.name == (_storage.read(StorageKey.accentTheme.name) ?? ''),
      orElse: () => AppAccentTheme.indigo,
    );
    _background.value = AppBackgroundTheme.values.firstWhere(
      (item) =>
          item.name == (_storage.read(StorageKey.backgroundTheme.name) ?? ''),
      orElse: () => AppBackgroundTheme.auto,
    );
    _wallpaperPath.value = _storage.read(StorageKey.wallpaperPath.name) ?? '';
    _wallpaperDim.value =
        (_storage.read(StorageKey.wallpaperDim.name) as num?)?.toDouble() ??
        _defaultWallpaperDim;
    _surfaceAlpha.value =
        (_storage.read(StorageKey.surfaceAlpha.name) as num?)?.toDouble() ??
        1.0;
    dropMissingWallpaper();
    switchTheme(_dark.value);
    super.onInit();
  }

  void switchTheme([bool? dark]) {
    _dark.value = dark ?? !_dark.value;
    _storage.write(StorageKey.dark.name, _dark.value);
    Get.changeThemeMode(themeMode);
    if (Get.isRegistered<SystemTrayService>()) {
      Get.find<SystemTrayService>().syncTrayTheme(_dark.value);
    }
  }

  /// Selects one accent palette (persisted; UI rebuilds through the Obx in main).
  void selectAccent(AppAccentTheme value) {
    if (_accent.value == value) {
      return;
    }
    _accent.value = value;
    _storage.write(StorageKey.accentTheme.name, value.name);
  }

  /// Selects one background preset (persisted).
  void selectBackground(AppBackgroundTheme value) {
    if (_background.value == value) {
      return;
    }
    _background.value = value;
    _storage.write(StorageKey.backgroundTheme.name, value.name);
  }

  /// 选择一张图片作为壁纸。
  ///
  /// 会把图片**复制**到应用目录（原图被删/移动也不影响），文件名带时间戳，
  /// 避免 `Image.file` 按路径缓存导致换图不生效。
  Future<void> pickWallpaper() async {
    if (!canUseWallpaper) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final pickedPath = result?.files.single.path;
    if (pickedPath == null || pickedPath.isEmpty) {
      return;
    }
    final directory = await getApplicationSupportDirectory();
    final target = Directory(
      '${directory.path}${Platform.pathSeparator}oasx_wallpaper',
    );
    await target.create(recursive: true);
    final extension = _resolveExtension(pickedPath);
    if (extension.isEmpty) {
      // Flutter 内置解码器只认 PNG/JPEG/WebP/GIF/BMP（HEIC 之类解不了），
      // 所以宁可直接拒绝，也不要静默改名成 .png 留一张打不开的图。
      Get.snackbar(I18n.tip.tr, I18n.wallpaperUnsupported.tr);
      return;
    }
    await _removeExistingWallpapers(target);
    final destination = File(
      '${target.path}${Platform.pathSeparator}'
      'wallpaper_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await File(pickedPath).copy(destination.path);
    _applyWallpaperPath(destination.path);
    if (_surfaceAlpha.value >= 1.0) {
      // 第一次选壁纸时给个默认透明度，否则界面表面会把壁纸全挡住。
      setSurfaceAlpha(kDefaultWallpaperSurfaceAlpha);
    }
  }

  /// 清掉自定义壁纸（回到纯色背景）。
  void clearWallpaper() {
    final path = _wallpaperPath.value;
    _applyWallpaperPath('');
    if (path.isEmpty) {
      return;
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // 删不掉也无所谓，反正记录已经清空。
    }
  }

  /// 调整壁纸遮罩浓度。
  void setWallpaperDim(double value) {
    final clamped = value.clamp(0.0, 0.95).toDouble();
    if (_wallpaperDim.value == clamped) {
      return;
    }
    _wallpaperDim.value = clamped;
    _storage.write(StorageKey.wallpaperDim.name, clamped);
  }

  /// 调整界面表面不透明度（越低壁纸/桌面透出越多）。
  void setSurfaceAlpha(double value) {
    final clamped = value.clamp(0.3, 1.0).toDouble();
    if (_surfaceAlpha.value == clamped) {
      return;
    }
    _surfaceAlpha.value = clamped;
    _storage.write(StorageKey.surfaceAlpha.name, clamped);
  }

  /// 图片被删/移动时自动清掉记录，避免启动后一直显示不出来。
  void dropMissingWallpaper() {
    final path = _wallpaperPath.value;
    if (path.isEmpty || File(path).existsSync()) {
      return;
    }
    _applyWallpaperPath('');
  }

  void _applyWallpaperPath(String path) {
    _wallpaperPath.value = path;
    if (path.isEmpty) {
      _storage.remove(StorageKey.wallpaperPath.name);
      return;
    }
    _storage.write(StorageKey.wallpaperPath.name, path);
  }

  Future<void> _removeExistingWallpapers(Directory directory) async {
    try {
      for (final entity in directory.listSync()) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith('wallpaper_')) {
          entity.deleteSync();
        }
      }
    } catch (_) {
      // 清理失败不影响本次选择。
    }
  }

  /// 返回可用的扩展名；不支持的格式返回 ''（调用方负责提示）。
  String _resolveExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) {
      return '';
    }
    final extension = path.substring(dot).toLowerCase();
    return _wallpaperExtensions.contains(extension) ? extension : '';
  }
}
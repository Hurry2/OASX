import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/service/theme_service.dart';

/// 自定义壁纸层：把用户选的图片铺在应用内容底下，中间加一层按主题取向的遮罩。
///
/// 没设壁纸时直接返回 [child]（零开销）。
class AppWallpaper extends StatelessWidget {
  const AppWallpaper({super.key, required this.child});

  /// 应用内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    return Obx(() {
      final path = themeService.wallpaperPath;
      if (path.isEmpty) {
        return child;
      }
      final file = File(path);
      if (!file.existsSync()) {
        return child;
      }
      // 遮罩用主题自身的表面色：浅色主题偏白、深色主题偏黑，
      // 壁纸自然地向当前主题靠拢，文字可读性由浓度控制。
      final scrim = Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: themeService.wallpaperDim);
      return Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              file,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned.fill(child: ColoredBox(color: scrim)),
          child,
        ],
      );
    });
  }
}
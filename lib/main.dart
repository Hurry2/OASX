import 'dart:io';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/modules/common/widgets/app_wallpaper.dart';
import 'package:oasx/modules/settings/controllers/settings_controller.dart';
import 'package:oasx/service/app_exit_service.dart';
import 'package:oasx/service/autostart_service.dart';
import 'package:oasx/service/app_update_service.dart';
import 'package:oasx/service/locale_service.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/service/storage_stats_prefs_service.dart';
import 'package:oasx/service/system_tray_service.dart';
import 'package:oasx/service/theme_service.dart';
import 'package:oasx/service/websocket_service.dart';
import 'package:oasx/service/window_service.dart';
import 'package:oasx/translation/i18n.dart';
import 'package:oasx/utils/logger.dart';
import 'package:oasx/utils/platform_utils.dart';
import 'package:oasx/routes.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// 屏蔽系统代理对 OAS 后端连接的干扰。
///
/// OAS 后端跑在本机（默认 127.0.0.1:22267），本地回环绝不能走代理。
/// 但第三方代理软件（游戏加速、抓包工具等）会把系统代理指向自己的端口，
/// 关闭后端口失效，连接就变成"远程计算机拒绝网络连接"，App 侧表现为
/// 一直连不上、只能重启。这里给所有 dart:io HttpClient 设成直连；
/// 需要代理的功能（例如应用更新）会在创建后自行覆盖 findProxy。
class _DirectConnectionOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'DIRECT';
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _DirectConnectionOverrides();
  await initService();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode && PlatformUtils.isWindows,
      builder: (context) => const OASXApp(),
    ),
  );
}

class OASXApp extends StatelessWidget {
  const OASXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeService = Get.find<LocaleService>();
    final themeService = Get.find<ThemeService>();

    return ResponsiveApp(
      builder: (context) {
        // 配色/背景/明暗任意一项变化 → 重建两套主题。
        return Obx(
          () => GetMaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => AppWallpaper(
              child: DevicePreview.appBuilder(context, child),
            ),
            scrollBehavior: GlobalBehavior(),
            translations: Messages(),
            locale: localeService.currentLocale,
            fallbackLocale: localeService.fallbackLocale,
            title: 'OASX',
            initialRoute: Routes.initial,
            getPages: Routes.routes,
            theme: themeService.lightThemeData,
            darkTheme: themeService.darkThemeData,
            themeMode: themeService.themeMode,
          ),
        );
      },
    );
  }
}

class GlobalBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

Future<void> initService() async {
  await GetStorage.init();

  Get.put(SettingsController(), permanent: true);
  Get.put(AppExitService(), permanent: true);
  if (PlatformUtils.isDesktop) {
    Get.put(SystemTrayService(), permanent: true);
  }
  Get.lazyPut<WebSocketService>(() => WebSocketService(), fenix: true);
  final windowService = Get.put(WindowService());

  await Future.wait([
    initLogger(),
    Get.putAsync(() async => LocaleService()),
    Get.putAsync(() async => ThemeService()),
    Get.putAsync(() async => AutoStartService(), permanent: true),
    Get.putAsync(() async => AppUpdateService(), permanent: true),
    windowService.ready,
    Get.putAsync(() async => ScriptService(), permanent: true),
    Get.putAsync(() async => StorageStatsPrefsService(), permanent: true),
  ]);
}

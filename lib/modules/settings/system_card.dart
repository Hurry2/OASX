import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:styled_widget/styled_widget.dart';

import 'package:oasx/config/global.dart';
import 'package:oasx/config/theme.dart';
import 'package:oasx/modules/settings/controllers/settings_controller.dart';
import 'package:oasx/modules/settings/widgets/setting_card.dart';
import 'package:oasx/modules/settings/widgets/setting_item.dart';
import 'package:oasx/service/autostart_service.dart';
import 'package:oasx/service/app_exit_service.dart';
import 'package:oasx/service/app_update_service.dart';
import 'package:oasx/service/locale_service.dart';
import 'package:oasx/service/theme_service.dart';
import 'package:oasx/service/window_service.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/check_version.dart';
import 'package:oasx/utils/platform_utils.dart';

class SystemSettingsCard extends StatelessWidget {
  const SystemSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingCard(
      title: I18n.systemSetting.tr,
      items: [
        SettingItem(
          left: Text(I18n.changeTheme.tr),
          right: const ThemeSwitcher(),
        ),
        SettingItem(
          left: Text(I18n.accentColor.tr),
          right: const AccentColorPicker(),
        ),
        SettingItem(
          left: Text(I18n.appBackground.tr),
          right: const BackgroundPicker(),
        ),
        if (!PlatformUtils.isWeb)
          SettingItem(
            left: Text(I18n.appWallpaper.tr),
            right: const WallpaperPicker(),
          ),
        if (!PlatformUtils.isWeb)
          SettingItem(
            left: Row(
              children: [
                Text(I18n.surfaceAlpha.tr),
                Tooltip(
                  message: I18n.surfaceAlphaHelp.tr,
                  child: const Icon(Icons.help_outline, size: 16),
                ).paddingOnly(left: 5),
              ],
            ),
            right: const SurfaceAlphaSlider(),
          ),
        if (PlatformUtils.isDesktop)
          SettingItem(
            left: Row(
              children: [
                Text(I18n.windowOpacity.tr),
                Tooltip(
                  message: I18n.windowOpacityHelp.tr,
                  child: const Icon(Icons.help_outline, size: 16),
                ).paddingOnly(left: 5),
              ],
            ),
            right: const WindowOpacitySlider(),
          ),
        SettingItem(
          left: Text(I18n.changeLanguage.tr),
          right: const LanguageToggle(),
        ),
        if (PlatformUtils.isDesktop)
          SettingItem(
            left: Text(I18n.rememberWindowPositionSize.tr),
            right: const WindowStateSwitch(),
          ),
        if (PlatformUtils.isDesktop)
          SettingItem(
            left: Row(
              children: [
                Text(I18n.minimizeToSystemTray.tr),
                Tooltip(
                  message: I18n.minimizeToSystemTrayHelp.tr,
                  child: const Icon(Icons.help_outline, size: 16),
                ).paddingOnly(left: 5),
              ],
            ),
            right: const SystemTraySwitch(),
          ),
        SettingItem(
          left: Row(
            children: [
              Text(I18n.shutdownOasOnExit.tr),
              Tooltip(
                message: I18n.shutdownOasOnExitHelp.tr,
                child: const Icon(Icons.help_outline, size: 16),
              ).paddingOnly(left: 5),
            ],
          ),
          right: const ShutdownOasOnExitSwitch(),
        ),
        if (PlatformUtils.isDesktop)
          SettingItem(
            left: Row(
              children: [
                Text(I18n.launchAtStartup.tr),
                Tooltip(
                  message: I18n.launchAtStartupHelp.tr,
                  child: const Icon(Icons.help_outline, size: 16),
                ).paddingOnly(left: 5),
              ],
            ),
            right: const LaunchAtStartupSwitch(),
          ),
        if (!PlatformUtils.isWeb)
          SettingItem(
            left: Row(
              children: [
                Text(I18n.updateProxyUrl.tr),
                Tooltip(
                  message: I18n.updateProxyUrlHelp.tr,
                  child: const Icon(Icons.help_outline, size: 16),
                ).paddingOnly(left: 5),
              ],
            ),
            right: const UpdateProxyUrlField(),
          ),
        SettingItem(
          left: Text('${I18n.currentVersion.tr}: ${GlobalVar.version}'),
          right: PlatformUtils.isWeb
              ? const SizedBox.shrink()
              : const CheckUpdateButton(),
        ),
      ],
    );
  }
}

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final localeService = Get.find<LocaleService>();
    return Obx(() {
      final isSelected = switch (localeService.language.value) {
        'zh-CN' => [true, false],
        'en-US' => [false, true],
        _ => [true, false],
      };
      return ToggleButtons(
        isSelected: isSelected,
        onPressed: (index) {
          localeService.switchLanguage(index == 0 ? 'zh-CN' : 'en-US');
        },
        borderRadius: BorderRadius.circular(10),
        children: [
          Text(I18n.zhCn.tr).paddingSymmetric(horizontal: 10),
          Text(I18n.enUs.tr).paddingSymmetric(horizontal: 10),
        ],
      ).constrained(maxHeight: 40);
    });
  }
}

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    return Obx(() {
      return IconButton(
        onPressed: themeService.switchTheme,
        icon: const Icon(Icons.light_mode),
        selectedIcon: const Icon(Icons.dark_mode),
        isSelected: themeService.isDarkMode,
      );
    });
  }
}

/// 主题配色（M3 种子色）选择器。
class AccentColorPicker extends StatelessWidget {
  const AccentColorPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    return Obx(
      () => Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        children: [
          for (final item in AppAccentTheme.values)
            _ThemeSwatch(
              color: item.seed,
              label: item.label,
              selected: themeService.accent == item,
              onTap: () => themeService.selectAccent(item),
            ),
        ],
      ),
    );
  }
}

/// 界面背景选择器：每项画成"明亮两半"，一眼能看出深浅两种模式的样子。
class BackgroundPicker extends StatelessWidget {
  const BackgroundPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    final scheme = Theme.of(context).colorScheme;
    return Obx(
      () => Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        children: [
          for (final item in AppBackgroundTheme.values)
            _ThemeSwatch(
              // 「跟随主题」用当前主题的表面色示意。
              color: item.light ?? scheme.surface,
              secondColor: item.dark ?? scheme.surfaceContainerHighest,
              label: item.label,
              selected: themeService.background == item,
              onTap: () => themeService.selectBackground(item),
              autoIcon: item == AppBackgroundTheme.auto,
            ),
        ],
      ),
    );
  }
}

/// 界面表面不透明度（越低壁纸/桌面透出越多）。
class SurfaceAlphaSlider extends StatelessWidget {
  const SurfaceAlphaSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    return Obx(
      () => SizedBox(
        width: 180,
        child: Slider(
          value: themeService.surfaceAlpha,
          min: 0.3,
          max: 1,
          onChanged: themeService.setSurfaceAlpha,
        ),
      ),
    );
  }
}

/// 窗口整体不透明度（越低桌面透出越多）。
class WindowOpacitySlider extends StatelessWidget {
  const WindowOpacitySlider({super.key});

  @override
  Widget build(BuildContext context) {
    final windowService = Get.find<WindowService>();
    return Obx(
      () => SizedBox(
        width: 180,
        child: Slider(
          value: windowService.windowOpacity.value,
          min: 0.4,
          max: 1,
          onChanged: windowService.setWindowOpacity,
        ),
      ),
    );
  }
}

/// 自定义壁纸：选择 / 更换图片、清除，以及遮罩浓度。
class WallpaperPicker extends StatelessWidget {
  const WallpaperPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final path = themeService.wallpaperPath;
      final hasWallpaper = path.isNotEmpty;
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (hasWallpaper) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(path),
                width: 36,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    SizedBox(width: 36, height: 24, child: ColoredBox(color: scheme.surfaceContainerHighest)),
              ),
            ),
            Tooltip(
              message: I18n.wallpaperDim.tr,
              child: SizedBox(
                width: 110,
                child: Slider(
                  value: themeService.wallpaperDim,
                  onChanged: themeService.setWallpaperDim,
                ),
              ),
            ),
          ],
          TextButton.icon(
            onPressed: themeService.pickWallpaper,
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(
              (hasWallpaper ? I18n.changeImage : I18n.selectImage).tr,
            ),
          ),
          if (hasWallpaper)
            IconButton(
              tooltip: I18n.clearImage.tr,
              onPressed: themeService.clearWallpaper,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      );
    });
  }
}

/// 一个可点的圆形色块（选中时描主色边）。
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.secondColor,
    this.autoIcon = false,
  });

  final Color color;
  final Color? secondColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool autoIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 26.0;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipOval(
              child: secondColor == null
                  ? Container(
                      color: color,
                      child: autoIcon
                          ? Icon(
                              Icons.auto_awesome,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            )
                          : null,
                    )
                  : Row(
                      children: [
                        Expanded(child: Container(color: color)),
                        Expanded(child: Container(color: secondColor)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class WindowStateSwitch extends StatelessWidget {
  const WindowStateSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final windowService = Get.find<WindowService>();
    return Obx(
      () => Switch(
        value: windowService.enableWindowState.value,
        onChanged: windowService.updateWindowStateEnable,
      ),
    );
  }
}

class SystemTraySwitch extends StatelessWidget {
  const SystemTraySwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final windowService = Get.find<WindowService>();
    return Obx(
      () => Switch(
        value: windowService.enableSystemTray.value,
        onChanged: windowService.updateSystemTrayEnable,
      ),
    );
  }
}

class ShutdownOasOnExitSwitch extends StatelessWidget {
  const ShutdownOasOnExitSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final appExitService = Get.find<AppExitService>();
    return Obx(
      () => Switch(
        value: appExitService.shutdownOasOnExit.value,
        onChanged: appExitService.updateShutdownOasOnExit,
      ),
    );
  }
}

class LaunchAtStartupSwitch extends StatelessWidget {
  const LaunchAtStartupSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final autoStartService = Get.find<AutoStartService>();
    return Obx(
      () => Switch(
        value: autoStartService.enableLaunchAtStartup.value,
        onChanged: autoStartService.isApplying.value
            ? null
            : autoStartService.updateLaunchAtStartupEnable,
      ),
    );
  }
}

class UpdateProxyUrlField extends StatefulWidget {
  const UpdateProxyUrlField({super.key});

  @override
  State<UpdateProxyUrlField> createState() => _UpdateProxyUrlFieldState();
}

class _UpdateProxyUrlFieldState extends State<UpdateProxyUrlField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _settingsController = Get.find<SettingsController>();
    _controller = TextEditingController(
      text: _settingsController.updateProxyUrl.value,
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _syncTextController();
      return SizedBox(
        width: 220,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.url,
          scrollPadding: EdgeInsets.only(
            left: 12,
            top: 12,
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'http://127.0.0.1:7897'),
          onTapOutside: PlatformUtils.isWeb
              ? null
              : (_) => _focusNode.unfocus(),
          onEditingComplete: PlatformUtils.isWeb ? null : _focusNode.unfocus,
          onChanged: _settingsController.updateUpdateProxyUrl,
        ),
      );
    });
  }

  void _syncTextController() {
    if (_focusNode.hasFocus) {
      return;
    }
    final current = _settingsController.updateProxyUrl.value;
    if (_controller.text == current) {
      return;
    }
    _controller.value = TextEditingValue(
      text: current,
      selection: TextSelection.collapsed(offset: current.length),
    );
  }
}

class CheckUpdateButton extends StatelessWidget {
  const CheckUpdateButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appUpdateService = Get.find<AppUpdateService>();
    return Obx(() {
      return ElevatedButton(
        onPressed: appUpdateService.isCheckingForUpdates.value
            ? null
            : () async => await checkUpdate(showTip: true, forceCheck: true),
        child: appUpdateService.isCheckingForUpdates.value
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(I18n.executeUpdate.tr),
      );
    });
  }
}

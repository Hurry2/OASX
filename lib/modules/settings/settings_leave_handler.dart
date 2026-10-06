import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/settings/controllers/settings_controller.dart';

Future<void> handleSettingsLeaveEffect() async {
  if (!Get.isRegistered<SettingsController>()) {
    return;
  }
  final settingsController = Get.find<SettingsController>();
  // 补记一条地址历史：用户可能没让输入框失焦就直接切走了。重复值会被去重，
  // 没改过地址时也不会产生任何变化。
  settingsController.rememberAddress(settingsController.address.value);
  if (!settingsController.consumeLoginConfigChanged()) {
    return;
  }
  if (!Get.isRegistered<HomeDashboardController>()) {
    return;
  }
  await Get.find<HomeDashboardController>().refreshAfterSettingsChanged();
}

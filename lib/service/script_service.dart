import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/common/controllers/progress_snackbar_controller.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/models/script_order.dart';
import 'package:oasx/modules/home/models/taskitem_model.dart';
import 'package:oasx/service/websocket_service.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/extension_utils.dart';
import 'package:oasx/utils/platform_utils.dart';
import 'package:oasx/utils/time_utils.dart';
import 'package:oasx/modules/log/script_log_controller.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';

part 'script_service_ws.dart';
part 'script_service_auto.dart';
part 'script_service_config.dart';
part 'script_service_order.dart';

class ScriptService extends GetxService {
  // ignore: unused_field
  final _storage = GetStorage();
  final wsService = Get.find<WebSocketService>();
  final scriptModelMap = <String, ScriptModel>{}.obs;
  final scriptOrderList = <String>[].obs;
  final autoScriptList = <String>[].obs;

  /// 用户拖动排序后的配置顺序，持久化在本地 —— **按后端地址分别保存**。
  ///
  /// 后端 `/config_list` 只按文件名返回，顺序不受 OASX 控制，所以每次同步
  /// 服务端列表后都要用它重新排一遍，否则自定义顺序会被刷新冲掉。
  ///
  /// 同一台设备会切换局域网里的多台 OAS，各自的配置名往往不同；共用一份排序时，
  /// 切到另一台会因"和当前配置名零重叠"被判为陈旧并覆盖落盘，切回来就没了。
  /// 现在地址 → 顺序各存一份，[_customScriptOrder] 始终是"当前后端那一份"。
  final _customScriptOrders = <String, List<String>>{};

  /// [_customScriptOrder] 当前对应哪个后端（空 = 还没对上）。
  String _customScriptOrderBackend = '';

  /// 当前后端地址，用来区分不同 OAS 的排序。
  String get _currentBackendKey => ApiClient().baseAddress.trim();

  final _customScriptOrder = <String>[];

  bool get _shouldSkipBackendReload {
    return PlatformUtils.isWeb && !ApiClient().hasConfiguredBackendAddress;
  }

  @override
  Future<void> onInit() async {
    _loadAutoScriptListFromStorage();
    _loadCustomScriptOrderFromStorage();
    await reloadFromServer();
    super.onInit();
  }

  @override
  Future<void> onClose() async {
    await Future.wait([
      ...scriptModelMap.keys.map(
        (e) => Future.wait([
          stopScript(e),
          wsService.close(e),
          Get.delete<ScriptLogController>(tag: e, force: true),
          Get.delete<ScriptLogBrowserController>(tag: e, force: true),
        ]),
      ),
    ]);
    scriptModelMap.clear();
    super.onClose();
  }

  void addScriptModel(dynamic sm) {
    if (sm is String) {
      sm = ScriptModel(sm);
    }
    if (scriptModelMap.containsKey(sm.name)) return;
    scriptModelMap[sm.name] = sm;
    if (!scriptOrderList.contains(sm.name)) {
      scriptOrderList.add(sm.name);
    }
  }

  void updateScriptModel(ScriptModel sm) {
    if (!scriptModelMap.containsKey(sm.name)) return;
    scriptModelMap[sm.name] = sm;
  }

  void addOrUpdateScriptModel(ScriptModel sm) {
    if (scriptModelMap.containsKey(sm.name)) {
      updateScriptModel(sm);
    } else {
      addScriptModel(sm);
    }
  }

  void deleteScriptModel(String name) {
    if (!scriptModelMap.containsKey(name)) return;
    scriptModelMap.remove(name);
    wsService.close(name);
    autoScriptList.removeWhere((e) => e == name);
    scriptOrderList.removeWhere((e) => e == name);
    if (_customScriptOrder.remove(name)) {
      _persistCustomScriptOrder();
    }
  }

  void syncScriptOrder(Iterable<String> scripts) {
    // 换了后端（局域网里切 OAS）就把内存里的排序换成那台机器自己的那份，
    // 否则下面"陈旧判定"会拿另一台的顺序去覆盖它。
    _selectCustomScriptOrderForCurrentBackend();
    final source = <String>[
      for (final name in scripts)
        if (name.trim().isNotEmpty) name.trim(),
    ];
    // 自定义顺序与当前后端配置名完全对不上，说明本地存的是另一套环境的顺序
    // （换安装目录 / 换配置目录 / 换后端）。继续沿用会每次都退化成服务端原序，
    // 表现就是"重启后拖动顺序被重置"，所以这里改用当前列表接管并落盘。
    final staleOrder = isScriptOrderStale(source, _customScriptOrder);
    final normalized = applyCustomScriptOrder(
      source,
      staleOrder ? const <String>[] : _customScriptOrder,
    );
    scriptOrderList.value = normalized;
    if (staleOrder && normalized.isNotEmpty) {
      _customScriptOrder
        ..clear()
        ..addAll(normalized);
      _persistCustomScriptOrder();
    }
    for (final name in normalized) {
      if (!scriptModelMap.containsKey(name)) {
        addScriptModel(name);
      }
    }
    final validSet = normalized.toSet();
    final removed = scriptModelMap.keys
        .where((e) => !validSet.contains(e))
        .toList();
    for (final name in removed) {
      deleteScriptModel(name);
    }
  }

  ScriptModel? findScriptModel(String name) {
    return scriptModelMap[name];
  }

  bool isRunning(String scriptName) {
    return scriptModelMap.containsKey(scriptName) &&
        scriptModelMap[scriptName]!.state.value == ScriptState.running;
  }

  Future<bool> tryCloseScriptWithReason(String scriptName) async {
    try {
      final scriptModel = findScriptModel(scriptName);
      if (scriptModel != null &&
          scriptModel.state.value == ScriptState.running) {
        Get.snackbar(
          I18n.tip.tr,
          I18n.configUpdateTip.tr,
          duration: const Duration(milliseconds: 2000),
        );
        return false;
      }
      await wsService.close(scriptName);
      return true;
    } catch (e) {
      if (e.toString().contains('not found')) {
        return true;
      }
      return false;
    }
  }

  Future<void> refreshScriptsFromServer() async {
    if (_shouldSkipBackendReload) {
      await resetDashboardState();
      return;
    }
    final latest = await ApiClient().getScriptList();
    syncScriptOrder(latest);
  }

  Future<void> reloadFromServer() async {
    if (_shouldSkipBackendReload) {
      await resetDashboardState();
      return;
    }
    final scriptList = await ApiClient().getScriptList();
    syncScriptOrder(scriptList);
    if (scriptList.isEmpty) {
      return;
    }
    await Future.wait(scriptList.map((name) => connectScript(name)));
  }

  Future<void> resetDashboardState() async {
    await wsService.closeAll();
    final names = scriptModelMap.keys.toList();
    for (final name in names) {
      if (Get.isRegistered<ScriptLogController>(tag: name)) {
        try {
          Get.delete<ScriptLogController>(tag: name, force: true);
        } catch (_) {}
      }
      if (Get.isRegistered<ScriptLogBrowserController>(tag: name)) {
        try {
          Get.delete<ScriptLogBrowserController>(tag: name, force: true);
        } catch (_) {}
      }
    }
    scriptModelMap.clear();
    scriptOrderList.clear();
  }
}

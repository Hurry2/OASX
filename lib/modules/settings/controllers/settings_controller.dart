import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/config/global.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/modules/server/models/deploy_webui_config.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/check_version.dart';
import 'package:oasx/utils/platform_utils.dart';

class SettingsController extends GetxController {
  final storage = GetStorage();

  /// 登录地址历史保留条数，最近使用的排在最前。
  static const int maxAddressHistory = 8;

  late String temporaryDirectory;
  final autoLoginAfterDeploy = false.obs;
  final autoDeploy = false.obs;
  bool _loginConfigChanged = false;

  final address = ''.obs;
  final addressHistory = <String>[].obs;
  final updateProxyUrl = ''.obs;
  final username = ''.obs;
  final password = ''.obs;

  @override
  void onInit() {
    autoLoginAfterDeploy.value =
        storage.read(StorageKey.autoLoginAfterDeploy.name) ?? false;
    autoDeploy.value =
        (storage.read(StorageKey.autoDeploy.name) ?? false) &&
        PlatformUtils.isDesktop;
    address.value = storage.read(StorageKey.address.name) ?? '';
    _loadAddressHistory();
    updateProxyUrl.value = storage.read(StorageKey.updateProxyUrl.name) ?? '';
    username.value = storage.read(StorageKey.username.name) ?? '';
    password.value = storage.read(StorageKey.password.name) ?? '';

    initTemporaryDirectory();
    getCurrentVersion().then((value) {
      GlobalVar.version = value;
    });
    syncApiAddress();
    super.onInit();
  }

  void initTemporaryDirectory() {
    final cachedDirectory = storage.read(StorageKey.temporaryDirectory.name);
    if (cachedDirectory is String && cachedDirectory.isNotEmpty) {
      temporaryDirectory = cachedDirectory;
      return;
    }

    temporaryDirectory = kIsWeb ? 'web_cache' : Directory.systemTemp.path;
    storage.write(StorageKey.temporaryDirectory.name, temporaryDirectory);
  }

  void updateAutoLoginAfterDeploy(bool nv) {
    autoLoginAfterDeploy.value = nv;
    storage.write(StorageKey.autoLoginAfterDeploy.name, nv);
  }

  void updateAutoDeploy(bool nv) {
    autoDeploy.value = nv;
    storage.write(StorageKey.autoDeploy.name, nv);
  }

  void updateAddress(String value) {
    final next = value.trim();
    if (address.value == next) {
      return;
    }
    address.value = next;
    storage.write(StorageKey.address.name, address.value);
    syncApiAddress();
    _loginConfigChanged = true;
  }

  /// 记录一条登录地址历史。
  ///
  /// 只在"提交"时机调用（输入框失焦、离开设置页）；[updateAddress] 每敲一个
  /// 字符都会触发，绝不能拿它喂历史，否则会存进一堆 `192`、`192.1` 之类的
  /// 半成品。存的是输入框里的原样文本（不含 `http://`），与 [address] 一致，
  /// 回填时不会出现重复协议头。
  void rememberAddress(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) {
      return;
    }
    final updated = List<String>.from(addressHistory)
      ..remove(candidate)
      ..insert(0, candidate);
    if (updated.length > maxAddressHistory) {
      updated.removeRange(maxAddressHistory, updated.length);
    }
    _applyAddressHistory(updated);
  }

  void clearAddressHistory() {
    if (addressHistory.isEmpty) {
      return;
    }
    _applyAddressHistory(const <String>[]);
  }

  void _applyAddressHistory(List<String> value) {
    if (listEquals(addressHistory, value)) {
      return;
    }
    addressHistory.assignAll(value);
    storage.write(StorageKey.addressHistory.name, jsonEncode(value));
  }

  /// 兼容两种落盘形态：GetStorage 直接反序列化出的 `List`，以及旧版本可能写入
  /// 的 JSON 字符串（沿用 [StorageKey.autoScriptList] 的写法）。
  void _loadAddressHistory() {
    final raw = storage.read(StorageKey.addressHistory.name);
    Iterable<Object?>? source;
    if (raw is List) {
      source = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          source = decoded;
        }
      } catch (_) {
        return;
      }
    }
    if (source == null) {
      return;
    }

    final restored = <String>[];
    for (final Object? item in source) {
      final text = item?.toString().trim() ?? '';
      if (text.isEmpty || restored.contains(text)) {
        continue;
      }
      restored.add(text);
      if (restored.length >= maxAddressHistory) {
        break;
      }
    }
    addressHistory.assignAll(restored);
  }

  void updateUpdateProxyUrl(String value) {
    final next = value.trim();
    if (updateProxyUrl.value == next) {
      return;
    }
    updateProxyUrl.value = next;
    storage.write(StorageKey.updateProxyUrl.name, next);
  }

  void updateUsername(String value) {
    final next = value.trim();
    if (username.value == next) {
      return;
    }
    username.value = next;
    storage.write(StorageKey.username.name, username.value);
    _loginConfigChanged = true;
  }

  void updatePassword(String value) {
    if (password.value == value) {
      return;
    }
    password.value = value;
    storage.write(StorageKey.password.name, password.value);
    _loginConfigChanged = true;
  }

  bool consumeLoginConfigChanged() {
    final changed = _loginConfigChanged;
    _loginConfigChanged = false;
    return changed;
  }

  /// Re-resolves which backend the API client dials.
  ///
  /// The OAS listener port is user-configurable, so the deploy file is re-read
  /// first; an address typed into settings always takes precedence. Safe to call
  /// repeatedly, e.g. after the OAS root path changes.
  void syncApiAddress() {
    _refreshFallbackAddress();
    if (address.value.isEmpty) {
      if (PlatformUtils.isWeb) {
        ApiClient().clearAddress();
        return;
      }
      ApiClient().resetAddress();
      return;
    }
    ApiClient().setAddress(address.value);
  }

  /// Adopts the listener from `<OAS root>/config/deploy.yaml`.
  ///
  /// Skipped while no OAS root path is known, which leaves the OAS default in
  /// place; [DeployWebuiConfig.read] never throws, so a missing or malformed
  /// deploy file also falls back to that default.
  void _refreshFallbackAddress() {
    final rootPath = storage.read(StorageKey.rootPathServer.name);
    if (rootPath is! String || rootPath.trim().isEmpty) {
      return;
    }
    ApiClient.applyDeployWebuiConfig(DeployWebuiConfig.read(rootPath));
  }

  Future<bool> killServer({
    bool showTip = true,
    bool resetDashboardToDisconnected = true,
  }) async {
    final success = await ApiClient().killServer();
    if (success) {
      if (resetDashboardToDisconnected) {
        unawaited(_resetDashboardAfterKillServer());
      }
    } else if (showTip) {
      Get.snackbar(I18n.killServerFailure.tr, I18n.killServerFailureMsg.tr);
    }
    return success;
  }

  Future<void> _resetDashboardAfterKillServer() async {
    if (Get.isRegistered<HomeDashboardController>()) {
      Get.find<HomeDashboardController>().markConnectionFailedFromKillServer();
    }
    if (Get.isRegistered<ScriptService>()) {
      try {
        await Get.find<ScriptService>().resetDashboardState().timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {}
    }
  }
}

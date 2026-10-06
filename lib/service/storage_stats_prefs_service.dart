import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';

/// Local preferences of the `纳物库` tab.
///
/// Kept on the client on purpose: how much history to keep is a viewer-side
/// concern, so the policy travels to OAS as cleanup request parameters instead
/// of being written into the OAS config file.
class StorageStatsPrefsService extends GetxService {
  final _storage = GetStorage();

  /// Retention policy used by the cleanup dialog.
  final cleanupOptions = const StorageStatsCleanupOptions().obs;

  @override
  void onInit() {
    cleanupOptions.value = _readCleanupOptions();
    super.onInit();
  }

  /// Replaces the retention policy and persists it.
  void updateCleanupOptions(StorageStatsCleanupOptions options) {
    cleanupOptions.value = options;
    _storage.write(StorageKey.storageStatsCleanup.name, options.toJson());
  }

  StorageStatsCleanupOptions _readCleanupOptions() {
    final raw = _storage.read(StorageKey.storageStatsCleanup.name);
    if (raw is Map) {
      return StorageStatsCleanupOptions.fromJson(raw.cast<String, dynamic>());
    }
    return const StorageStatsCleanupOptions();
  }
}

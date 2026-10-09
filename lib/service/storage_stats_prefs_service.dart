import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/modules/home/models/storage_stats_models.dart';

/// Local preferences of the `纳物库` tab.
///
/// Kept on the client on purpose: how much history to keep is a viewer-side
/// concern, so the policy travels to OAS as cleanup request parameters instead
/// of being written into the OAS config file. The view preferences below are
/// purely presentational and never reach OAS at all.
class StorageStatsPrefsService extends GetxService {
  final _storage = GetStorage();

  /// Retention policy used by the cleanup dialog.
  final cleanupOptions = const StorageStatsCleanupOptions().obs;

  /// Whether the tab renders the `趋势` charts instead of the `列表` grid.
  final trendViewEnabled = false.obs;

  /// Resources ticked in the trend view.
  ///
  /// `null` means "never chosen", which the view renders as every resource; an
  /// explicitly empty list means the user unticked everything, so the two must
  /// stay distinguishable.
  final trendResources = Rxn<List<String>>();

  /// Bucket width of the trend charts: daily, weekly or monthly.
  final trendGranularity = StorageStatsTrendGranularity.day.obs;

  @override
  void onInit() {
    cleanupOptions.value = _readCleanupOptions();
    trendViewEnabled.value = _readTrendViewEnabled();
    trendResources.value = _readTrendResources();
    trendGranularity.value = _readTrendGranularity();
    super.onInit();
  }

  /// Replaces the retention policy and persists it.
  void updateCleanupOptions(StorageStatsCleanupOptions options) {
    cleanupOptions.value = options;
    _storage.write(StorageKey.storageStatsCleanup.name, options.toJson());
  }

  /// Switches the tab between the list grid and the trend charts.
  void updateTrendViewEnabled(bool value) {
    if (trendViewEnabled.value == value) {
      return;
    }
    trendViewEnabled.value = value;
    _storage.write(StorageKey.storageStatsTrendView.name, value);
  }

  /// Replaces the ticked trend resources and persists them.
  ///
  /// Passing `null` restores the "never chosen" state, i.e. show everything.
  void updateTrendResources(List<String>? value) {
    if (listEquals(trendResources.value, value)) {
      return;
    }
    trendResources.value = value == null ? null : List<String>.from(value);
    final key = StorageKey.storageStatsTrendResources.name;
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage.write(key, jsonEncode(value));
    }
  }

  /// Switches the trend charts between daily, weekly and monthly buckets.
  void updateTrendGranularity(StorageStatsTrendGranularity value) {
    if (trendGranularity.value == value) {
      return;
    }
    trendGranularity.value = value;
    _storage.write(StorageKey.storageStatsTrendGranularity.name, value.name);
  }

  StorageStatsCleanupOptions _readCleanupOptions() {
    final raw = _storage.read(StorageKey.storageStatsCleanup.name);
    if (raw is Map) {
      return StorageStatsCleanupOptions.fromJson(raw.cast<String, dynamic>());
    }
    return const StorageStatsCleanupOptions();
  }

  bool _readTrendViewEnabled() {
    final raw = _storage.read(StorageKey.storageStatsTrendView.name);
    return raw is bool ? raw : false;
  }

  /// Reads the stored bucket width, falling back to daily.
  ///
  /// Matched by enum name so reordering [StorageStatsTrendGranularity] can never
  /// silently remap an existing preference.
  StorageStatsTrendGranularity _readTrendGranularity() {
    final raw = _storage.read(StorageKey.storageStatsTrendGranularity.name);
    if (raw is String) {
      for (final value in StorageStatsTrendGranularity.values) {
        if (value.name == raw) {
          return value;
        }
      }
    }
    return StorageStatsTrendGranularity.day;
  }

  /// Reads the ticked resources, tolerating both the JSON string written by
  /// [updateTrendResources] and a plain list left by an older build.
  List<String>? _readTrendResources() {
    final raw = _storage.read(StorageKey.storageStatsTrendResources.name);
    if (raw == null) {
      return null;
    }
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
        return null;
      }
    }
    if (source == null) {
      return null;
    }
    return [
      for (final item in source)
        if ((item?.toString().trim() ?? '').isNotEmpty) item.toString().trim(),
    ];
  }
}

part of 'api_client.dart';

/// Client calls for the OAS `纳物库` (storage) statistics API.
///
/// Endpoints live under `/storage_stats`: they expose the last snapshot of each
/// date for every config instance, plus the matching screenshot image. The
/// single mutating endpoint is the cleanup, which is always confirmed with a
/// dry run first.
extension ApiClientStorageStatsX on ApiClient {
  /// Loads the instance index (`GET /storage_stats`).
  Future<StorageStatsInstanceList> getStorageStatsInstances() async {
    final res = await request(
      () => get('/storage_stats', options: _storageStatsNoCacheOptions(this)),
    );
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid storage stats response');
    }
    return StorageStatsInstanceList.fromJson(_storageStatsJsonMap(res.data));
  }

  /// Loads every date of one instance (`GET /storage_stats/{instance}`).
  Future<StorageStatsSeries> getStorageStatsSeries(String instance) async {
    final normalized = instance.trim();
    if (normalized.isEmpty) {
      throw Exception('Empty storage stats instance');
    }
    final res = await request(
      () => get(
        '/storage_stats/${Uri.encodeComponent(normalized)}',
        options: _storageStatsNoCacheOptions(this),
      ),
    );
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid storage stats series response');
    }
    return StorageStatsSeries.fromJson(_storageStatsJsonMap(res.data));
  }

  /// Resolves the absolute screenshot URI for one instance/date pair.
  String buildStorageStatsImageUrl(String instance, String date) {
    final base = _storageStatsBaseUri(this);
    return base
        .replace(
          pathSegments: [
            ...base.pathSegments.where((segment) => segment.isNotEmpty),
            'storage_stats',
            instance.trim(),
            date.trim(),
            'image',
          ],
        )
        .toString();
  }

  /// Previews or runs the cleanup (`POST /storage_stats/cleanup`).
  ///
  /// [dryRun] `true` only plans the deletion so the UI can show what would go;
  /// confirming sends the same options with `dryRun: false`. The backend always
  /// recomputes the plan from these options, so no file path ever travels from
  /// the client to the disk.
  Future<StorageStatsCleanupReport> runStorageStatsCleanup({
    required StorageStatsCleanupOptions options,
    required String instance,
    required bool dryRun,
  }) async {
    final res = await request(
      () => post(
        '/storage_stats/cleanup',
        data: {
          ...options.toJson(),
          'instance': instance.trim(),
          'dry_run': dryRun,
        },
      ),
    );
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid storage stats cleanup response');
    }
    return StorageStatsCleanupReport.fromJson(_storageStatsJsonMap(res.data));
  }
}

/// Resolves the configured backend base URI for storage stats requests.
///
/// Falls back to the OAS default when no explicit address is configured, so the
/// returned URI is always absolute.
Uri _storageStatsBaseUri(ApiClient client) => Uri.parse(client.baseAddress);

/// Builds no-cache request options so freshly written snapshots are visible.
Options _storageStatsNoCacheOptions(ApiClient client) {
  final cacheOptions = client._cacheOptions.copyWith(
    policy: CachePolicy.noCache,
  );
  return Options(
    extra: cacheOptions.toExtra(),
    headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  );
}

/// Casts a decoded payload into a string-keyed map.
Map<String, dynamic> _storageStatsJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

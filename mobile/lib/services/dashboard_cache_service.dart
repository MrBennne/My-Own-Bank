import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_service.dart';

class DashboardCacheService {
  DashboardCacheService._();
  static final DashboardCacheService instance = DashboardCacheService._();

  static const _dataPrefix = 'dashboard_cache_';
  static const _tsPrefix = 'dashboard_cache_ts_';
  static const _staleDuration = Duration(minutes: 5);

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String _key(String filterKey) => '$_dataPrefix$filterKey';
  String _tsKey(String filterKey) => '$_tsPrefix$filterKey';

  /// Returns cached data if fresh (< 5 min old), or null if stale/missing.
  DashboardData? load(String filterKey) {
    final tsMs = _prefs.getInt(_tsKey(filterKey));
    if (tsMs == null) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(tsMs);
    if (DateTime.now().difference(cachedAt) > _staleDuration) return null;

    final json = _prefs.getString(_key(filterKey));
    if (json == null) return null;

    try {
      return DashboardData.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Saves dashboard data with current timestamp.
  Future<void> save(String filterKey, DashboardData data) async {
    await Future.wait([
      _prefs.setString(_key(filterKey), jsonEncode(data.toJson())),
      _prefs.setInt(_tsKey(filterKey), DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  /// Clears all cached dashboard data.
  Future<void> invalidateAll() async {
    final keys = _prefs.getKeys().where(
      (k) => k.startsWith(_dataPrefix) || k.startsWith(_tsPrefix),
    );
    await Future.wait(keys.map((k) => _prefs.remove(k)));
  }
}

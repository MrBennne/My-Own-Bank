import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_service.dart';

class DashboardCacheService {
  DashboardCacheService._();
  static final DashboardCacheService instance = DashboardCacheService._();

  static const _dataPrefix = 'dash_data_';
  static const _tsPrefix = 'dash_ts_';
  static const _staleDuration = Duration(minutes: 5);

  SharedPreferences? _prefs;
  bool get _ready => _prefs != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String _key(String filterKey) => '$_dataPrefix$filterKey';
  String _tsKey(String filterKey) => '$_tsPrefix$filterKey';

  /// Sanitise a PocketBase filter string into a safe SharedPreferences key.
  static String sanitiseKey(String raw) =>
      raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  /// Returns cached data if fresh (< 5 min old), or null if stale/missing.
  DashboardData? load(String filterKey) {
    if (!_ready) return null;
    final prefs = _prefs!;

    final tsMs = prefs.getInt(_tsKey(filterKey));
    if (tsMs == null) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(tsMs);
    if (DateTime.now().difference(cachedAt) > _staleDuration) return null;

    final json = prefs.getString(_key(filterKey));
    if (json == null) return null;

    try {
      return DashboardData.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Saves dashboard data with current timestamp.
  /// Data is written first, then timestamp, so a timestamp only exists
  /// once data is confirmed persisted.
  Future<void> save(String filterKey, DashboardData data) async {
    if (!_ready) return;
    final prefs = _prefs!;
    await prefs.setString(_key(filterKey), jsonEncode(data.toJson()));
    await prefs.setInt(
        _tsKey(filterKey), DateTime.now().millisecondsSinceEpoch);
  }

  /// Clears all cached dashboard data.
  Future<void> invalidateAll() async {
    if (!_ready) return;
    final prefs = _prefs!;
    final keys = prefs.getKeys().where(
          (k) => k.startsWith(_dataPrefix) || k.startsWith(_tsPrefix),
        );
    await Future.wait(keys.map((k) => prefs.remove(k)));
  }
}

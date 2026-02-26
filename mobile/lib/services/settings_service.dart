import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists accounts and app preferences.
/// Call [init] once in main() before runApp.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _prefs;

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // -------------------------------------------------------------------------
  // Accounts
  // -------------------------------------------------------------------------

  static const _accountsKey = 'known_accounts';

  List<String> get accounts {
    final saved = _prefs.getStringList(_accountsKey);
    if (saved != null && saved.isNotEmpty) return List.unmodifiable(saved);
    return const ['Lønkonto'];
  }

  Future<void> addAccount(String name) async {
    final current = List<String>.from(accounts);
    if (!current.contains(name)) {
      current.add(name);
      await _prefs.setStringList(_accountsKey, current);
      notifyListeners();
    }
  }

  Future<void> removeAccount(String name) async {
    final current = List<String>.from(accounts)..remove(name);
    await _prefs.setStringList(_accountsKey, current);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Import behaviour
  // -------------------------------------------------------------------------

  static const _alwaysUncategorizedKey = 'always_uncategorized';

  bool get alwaysUncategorized =>
      _prefs.getBool(_alwaysUncategorizedKey) ?? false;

  Future<void> setAlwaysUncategorized(bool value) async {
    await _prefs.setBool(_alwaysUncategorizedKey, value);
    notifyListeners();
  }
}

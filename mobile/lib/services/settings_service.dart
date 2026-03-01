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

  // -------------------------------------------------------------------------
  // Transaction filters & sort
  // -------------------------------------------------------------------------

  static const _txSearchQueryKey = 'tx_search_query';
  static const _txSelectedCategoryKey = 'tx_selected_category';
  static const _txSelectedTypeKey = 'tx_selected_type';
  static const _txSortFieldKey = 'tx_sort_field';
  static const _txSortAscKey = 'tx_sort_asc';

  String get txSearchQuery => _prefs.getString(_txSearchQueryKey) ?? '';
  String get txSelectedCategory =>
      _prefs.getString(_txSelectedCategoryKey) ?? '';
  String get txSelectedType => _prefs.getString(_txSelectedTypeKey) ?? 'All';
  String get txSortField => _prefs.getString(_txSortFieldKey) ?? 'date';
  bool get txSortAsc => _prefs.getBool(_txSortAscKey) ?? false;

  Future<void> saveTransactionFilters({
    required String searchQuery,
    required String selectedCategory,
    required String selectedType,
    required String sortField,
    required bool sortAsc,
  }) async {
    await Future.wait([
      _prefs.setString(_txSearchQueryKey, searchQuery),
      _prefs.setString(_txSelectedCategoryKey, selectedCategory),
      _prefs.setString(_txSelectedTypeKey, selectedType),
      _prefs.setString(_txSortFieldKey, sortField),
      _prefs.setBool(_txSortAscKey, sortAsc),
    ]);
    notifyListeners();
  }
}

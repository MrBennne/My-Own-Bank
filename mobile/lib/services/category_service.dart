import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import 'auth_service.dart';

const String _kBaseUrl = 'http://locserv.tail18bcbb.ts.net:8091';

/// Canonical group display order.
const List<String> kGroupOrder = [
  'Faste Udgifter',
  'Variable N\u00f8dvendigheder',
  'Livsstil',
  'Opsparing & Investering',
  'G\u00e6ld',
  'Indkomst',
  'Overf\u00f8rsel',
];

class CategoryService extends ChangeNotifier {
  CategoryService._();
  static final CategoryService instance = CategoryService._();

  final AuthService _auth = AuthService();

  List<Category> _categories = [];
  bool _loaded = false;

  List<Category> get categories => List.unmodifiable(_categories);
  bool get loaded => _loaded;

  List<Category> get topLevel =>
      _categories.where((c) => !c.isSubcategory).toList();

  List<Category> childrenOf(String parentId) =>
      _categories.where((c) => c.parentId == parentId).toList();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    final all = <Category>[];
    int page = 1, totalPages = 1;
    do {
      final uri =
          Uri.parse('$_kBaseUrl/api/collections/categories/records').replace(
        queryParameters: {
          'perPage': '500',
          'page': '$page',
          'expand': 'parent',
          'sort': 'sort_order,name',
        },
      );
      final resp = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) break;
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      for (final item in data['items'] as List) {
        all.add(Category.fromJson(item as Map<String, dynamic>));
      }
      totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      page++;
    } while (page <= totalPages);
    _categories = all;
    _loaded = true;
    notifyListeners();
  }

  // ── Category CRUD ─────────────────────────────────────────────────────────

  Future<Category> createCategory(
    String name,
    String type, {
    String? group,
    String? parentId,
    String? color,
    List<String>? keywords,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_kBaseUrl/api/collections/categories/records'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'name': name,
            'type': type,
            'group': group ?? '',
            'parent': parentId ?? '',
            'color': color ?? '',
            'sort_order': _categories.length,
            'keywords': keywords ?? [],
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Failed to create category (${resp.statusCode})');
    }
    await refresh();
    return Category.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    String? type,
    String? group,
    String? color,
    String? parentId,
    int? sortOrder,
    List<String>? keywords,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (type != null) body['type'] = type;
    if (group != null) body['group'] = group;
    if (color != null) body['color'] = color;
    if (parentId != null) body['parent'] = parentId;
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (keywords != null) body['keywords'] = keywords;

    final resp = await http
        .patch(
          Uri.parse('$_kBaseUrl/api/collections/categories/records/$id'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Failed to update category (${resp.statusCode})');
    }
    await refresh();
  }

  Future<void> deleteCategory(String id) async {
    // Delete subcategories first
    final children = childrenOf(id);
    for (final child in children) {
      await deleteCategory(child.id);
    }
    final resp = await http
        .delete(
          Uri.parse('$_kBaseUrl/api/collections/categories/records/$id'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Failed to delete category (${resp.statusCode})');
    }
    await refresh();
  }

  // ── Categorization engine ─────────────────────────────────────────────────

  /// Returns (category, subcategory, type) for a transaction name.
  /// Matches keywords longest-first (globally across all categories) to avoid false positives.
  /// For example, "Lønoverførsel" matches the keyword "Lønoverførsel" (9 chars) before "overførsel" (10 chars).
  ({String category, String subcategory, String type}) categorize(
      String txName, String txType) {
    final lower = txName.toLowerCase();

    // Build parent lookup and collect all keywords with their categories
    final catMap = {for (final c in _categories) c.id: c};
    final allMatches = <(String keyword, Category category, String effectiveType)>[];

    for (final cat in _categories) {
      final effectiveType = cat.isSubcategory
          ? catMap[cat.parentId]?.type ?? cat.type
          : cat.type;
      for (final kw in cat.keywords) {
        allMatches.add((kw, cat, effectiveType));
      }
    }

    // Sort by keyword length descending (longest matches first)
    allMatches.sort((a, b) => b.$1.length.compareTo(a.$1.length));

    // Check in longest-first order
    for (final (kw, cat, effectiveType) in allMatches) {
      if (!lower.contains(kw.toLowerCase())) continue;

      // Transfer matches always win
      if (effectiveType == 'transfer') {
        if (cat.isSubcategory) {
          return (
            category: cat.parentName ?? cat.name,
            subcategory: cat.name,
            type: 'Transfer'
          );
        }
        return (category: cat.name, subcategory: '', type: 'Transfer');
      }

      // Type-specific match
      final matchType = txType == 'Income' ? 'income' : 'expense';
      if (effectiveType == matchType) {
        if (cat.isSubcategory) {
          return (
            category: cat.parentName ?? cat.name,
            subcategory: cat.name,
            type: txType
          );
        }
        return (category: cat.name, subcategory: '', type: txType);
      }
    }

    return (category: 'Uncategorized', subcategory: '', type: txType);
  }

  // ── Grouped categories ────────────────────────────────────────────────────

  /// Returns categories grouped by the [group] field, in canonical order.
  /// Optionally filter by [filterType] (income/expense/transfer).
  List<CategoryGroup> groupedCategories({String? filterType}) {
    final filtered = _categories.where((c) {
      if (filterType != null) return c.type == filterType;
      return true;
    }).toList();

    // Group by group name
    final map = <String, List<Category>>{};
    for (final c in filtered) {
      final g = c.group.isNotEmpty ? c.group : 'Andet';
      map.putIfAbsent(g, () => []).add(c);
    }

    // Sort groups by canonical order, unknown groups at end
    final groups = map.entries.toList()
      ..sort((a, b) {
        final ai = kGroupOrder.indexOf(a.key);
        final bi = kGroupOrder.indexOf(b.key);
        final aIdx = ai == -1 ? 999 : ai;
        final bIdx = bi == -1 ? 999 : bi;
        return aIdx.compareTo(bIdx);
      });

    return groups
        .map((e) => CategoryGroup(groupName: e.key, categories: e.value))
        .toList();
  }

  /// All category names for dropdown filters.
  List<String> get allCategoryNames {
    final names = <String>{};
    for (final cat in _categories) {
      names.add(cat.name);
    }
    names.add('Uncategorized');
    return names.toList()..sort();
  }

  // ── Color resolution ──────────────────────────────────────────────────────

  static const _palette = [
    Color(0xFF0d6efd),
    Color(0xFF20c997),
    Color(0xFFffc107),
    Color(0xFFdc3545),
    Color(0xFF6f42c1),
    Color(0xFFfd7e14),
    Color(0xFF0dcaf0),
    Color(0xFF198754),
    Color(0xFFd63384),
    Color(0xFF4ecdc4),
    Color(0xFFff6b6b),
    Color(0xFF45b7d1),
    Color(0xFF96ceb4),
    Color(0xFFe17055),
    Color(0xFFa29bfe),
    Color(0xFF00b894),
  ];

  Color colorFor(String categoryName) {
    if (categoryName == 'Uncategorized') return const Color(0xFF6c757d);
    final cat = _categories
        .cast<Category?>()
        .firstWhere((c) => c!.name == categoryName, orElse: () => null);
    if (cat?.parsedColor != null) return cat!.parsedColor!;
    final hash = categoryName.codeUnits.fold(0, (h, c) => h * 31 + c);
    return _palette[hash.abs() % _palette.length];
  }

  String? typeOf(String categoryName) {
    final cat = _categories
        .cast<Category?>()
        .firstWhere((c) => c!.name == categoryName, orElse: () => null);
    return cat?.type;
  }

  bool isTransferCategory(String categoryName) =>
      typeOf(categoryName) == 'transfer';

  Category? findByName(String name) {
    return _categories
        .cast<Category?>()
        .firstWhere((c) => c!.name == name, orElse: () => null);
  }
}

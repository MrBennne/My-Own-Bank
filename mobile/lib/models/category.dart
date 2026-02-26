import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String type; // 'income' | 'expense' | 'transfer'
  final String group; // e.g. 'Faste Udgifter', 'Livsstil'
  final String? parentId;
  final String? parentName; // expanded from relation
  final String? color; // hex, e.g. "#0d6efd"
  final int sortOrder;
  final List<String> keywords;

  bool get isSubcategory => parentId != null && parentId!.isNotEmpty;
  String get displayName =>
      isSubcategory && parentName != null ? '$parentName > $name' : name;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    this.group = '',
    this.parentId,
    this.parentName,
    this.color,
    this.sortOrder = 0,
    this.keywords = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    String? parentName;
    final expand = json['expand'] as Map<String, dynamic>?;
    if (expand != null && expand['parent'] != null) {
      parentName =
          (expand['parent'] as Map<String, dynamic>)['name'] as String?;
    }

    List<String> keywords = [];
    final rawKw = json['keywords'];
    if (rawKw is List) {
      keywords = rawKw.map((e) => e.toString()).toList();
    }

    return Category(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'expense',
      group: json['group'] as String? ?? '',
      parentId: json['parent'] as String?,
      parentName: parentName,
      color: json['color'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      keywords: keywords,
    );
  }

  Color? get parsedColor {
    if (color == null || color!.isEmpty) return null;
    final hex = color!.replaceFirst('#', '');
    if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    return null;
  }
}

/// A named group of categories for display.
class CategoryGroup {
  final String groupName;
  final List<Category> categories;

  const CategoryGroup({required this.groupName, this.categories = const []});
}

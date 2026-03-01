import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import 'auth_service.dart';

const String _kBaseUrl = 'http://locserv.tail18bcbb.ts.net:8091';
const String _kFlaskUrl = 'http://locserv.tail18bcbb.ts.net:5000';

class ApiService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  Future<PaginatedTransactions> fetchTransactions({
    int page = 1,
    int perPage = 50,
    String? search,
    String? category,
    String? type,
    String sort = '-date',
    String? dateFilter,
  }) async {
    final filters = <String>[];

    if (search != null && search.isNotEmpty) {
      filters.add('name~"${_escape(search)}"');
    }
    if (category != null && category.isNotEmpty) {
      filters.add('category="${_escape(category)}"');
    }
    if (type != null && type.isNotEmpty && type != 'All') {
      filters.add('type="${_escape(type)}"');
    }
    if (dateFilter != null && dateFilter.isNotEmpty) {
      filters.add(dateFilter);
    }

    final params = <String, String>{
      'page': page.toString(),
      'perPage': perPage.toString(),
      'sort': sort,
      if (filters.isNotEmpty) 'filter': filters.join('&&'),
    };

    final uri = Uri.parse(
      '$_kBaseUrl/api/collections/transactions/records',
    ).replace(queryParameters: params);

    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return PaginatedTransactions.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } else if (response.statusCode == 401) {
      await _auth.login();
      final retryResponse = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 20));
      if (retryResponse.statusCode == 200) {
        return PaginatedTransactions.fromJson(
          jsonDecode(utf8.decode(retryResponse.bodyBytes))
              as Map<String, dynamic>,
        );
      }
    }
    throw Exception(
      'Failed to fetch transactions (${response.statusCode})',
    );
  }

  /// Fetches ALL transactions for a given date filter (for dashboard aggregation).
  /// Uses large perPage to minimise requests; loops if needed.
  Future<List<Transaction>> fetchAllTransactions({
    String? dateFilter,
  }) async {
    const perPage = 500;
    final all = <Transaction>[];
    int page = 1;
    int totalPages = 1;

    do {
      final result = await fetchTransactions(
        page: page,
        perPage: perPage,
        dateFilter: dateFilter,
        sort: '-date',
      );
      all.addAll(result.items);
      totalPages = result.totalPages;
      page++;
    } while (page <= totalPages);

    return all;
  }

  Future<void> updateTransactionCategory(
    String id,
    String category, {
    String subcategory = '',
    String? type,
  }) async {
    final uri = Uri.parse(
      '$_kBaseUrl/api/collections/transactions/records/$id',
    );
    final body = <String, dynamic>{
      'category': category,
      'subcategory': subcategory,
    };
    if (type != null) body['type'] = type;

    final response = await http
        .patch(
          uri,
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update category (${response.statusCode}): ${response.body}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Review Rules — transactions that were originally uncategorized but have
  // since been manually assigned a category.
  // ---------------------------------------------------------------------------

  Future<List<Transaction>> fetchPendingReviews() async {
    final all = <Transaction>[];
    int page = 1, totalPages = 1;
    do {
      final uri =
          Uri.parse('$_kBaseUrl/api/collections/transactions/records').replace(
        queryParameters: {
          'page': '$page',
          'perPage': '200',
          'sort': '-date',
          'filter': 'originally_uncategorized=true&&category!="Uncategorized"',
        },
      );
      final resp = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) break;
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      all.addAll(PaginatedTransactions.fromJson(data).items);
      totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      page++;
    } while (page <= totalPages);
    return all;
  }

  /// Marks a transaction as reviewed by clearing the originally_uncategorized flag.
  Future<void> markReviewed(String id) async {
    final uri =
        Uri.parse('$_kBaseUrl/api/collections/transactions/records/$id');
    await http
        .patch(uri,
            headers: await _authHeaders(),
            body: jsonEncode({'originally_uncategorized': false}))
        .timeout(const Duration(seconds: 15));
  }

  // ---------------------------------------------------------------------------
  // Accounts — distinct account values from PocketBase
  // ---------------------------------------------------------------------------

  Future<List<String>> fetchAccounts() async {
    final all = await fetchAllTransactions();
    final accounts = all
        .map((t) => t.account)
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return accounts;
  }

  // ---------------------------------------------------------------------------
  // Admin — Autocategorizer reset (calls Flask)
  // ---------------------------------------------------------------------------

  Future<void> resetAutoCategorizor() async {
    final uri = Uri.parse('$_kFlaskUrl/api/reset-rules');
    final response = await http.post(uri, headers: {
      'Content-Type': 'application/json'
    }).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Reset failed (${response.statusCode})');
    }
  }

  String _escape(String value) => value.replaceAll('"', '\\"');
}

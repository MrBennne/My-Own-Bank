import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'category_service.dart';
import 'settings_service.dart';

const String _kBaseUrl = 'http://locserv.tail18bcbb.ts.net:8091';

class ImportResult {
  final int parsed;
  final int categorized;
  final int uncategorized;
  final int duplicates;
  final int uploaded;
  final int transfers;
  final List<String> errors;

  ImportResult({
    required this.parsed,
    required this.categorized,
    required this.uncategorized,
    required this.duplicates,
    required this.uploaded,
    required this.transfers,
    required this.errors,
  });

  String get summary {
    final lines = [
      'Parsed $parsed transactions.',
      'Uploaded $uploaded  •  Skipped $duplicates duplicates',
      '$categorized categorized  •  $uncategorized uncategorized',
      if (transfers > 0) '$transfers transfer(s) auto-detected',
    ];
    if (errors.isNotEmpty) {
      lines.add('');
      lines.add('Errors (${errors.length}):');
      lines.addAll(errors.take(5).map((e) => '  • $e'));
      if (errors.length > 5) lines.add('  … and ${errors.length - 5} more');
    }
    return lines.join('\n');
  }
}

// ── Service ──────────────────────────────────────────────────────────────────

class CsvPipelineService {
  final AuthService _auth = AuthService();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // ── CSV Parser (mirrors parser.py) ───────────────────────────────────────

  String _cleanName(String raw) {
    var name = raw.trim().replaceAll('"', '');
    if (name.contains(r'\')) {
      name = name.split(r'\').first.trim();
    }
    name = name.replaceAll(
        RegExp(r'\s+Notanr\s+\S+.*$', caseSensitive: false), '');
    name = name.replaceAll(
        RegExp(r'\s+Nota\s+nr\.\s+\S+.*$', caseSensitive: false), '');
    name = name.replaceAll(
        RegExp(r'\s+Trans\.nr\.\s+\S+.*$', caseSensitive: false), '');
    name = name.replaceAll(
        RegExp(r'\s+bel.b omregnet.*$', caseSensitive: false), '');
    return name.trim();
  }

  double? _parseAmount(String s) {
    s = s.trim().replaceAll('"', '');
    s = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s);
  }

  String? _parseDate(String s) {
    // DD-MM-YYYY → YYYY-MM-DD
    final parts = s.trim().split('-');
    if (parts.length != 3 || parts[2].length != 4) return null;
    return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _parseCsv(String content) {
    final result = <Map<String, dynamic>>[];
    for (final row in content.split(RegExp(r'\r?\n'))) {
      if (row.trim().isEmpty) continue;
      final cols = row.split(';');
      if (cols.length < 4) continue;
      try {
        final date = _parseDate(cols[0]);
        final name = _cleanName(cols[1]);
        final amount = _parseAmount(cols[2]);
        final currency = cols[3].trim();
        if (date == null || amount == null || name.isEmpty) continue;
        result.add({
          'date': date,
          'name': name,
          'amount': amount,
          'currency': currency,
          'type': amount >= 0 ? 'Income' : 'Expense',
        });
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  // ── Deduplicator ─────────────────────────────────────────────────────────

  Future<Set<String>> _existingKeys(
      List<Map<String, dynamic>> transactions) async {
    final dates = transactions.map((t) => t['date'] as String).toList()
      ..sort();
    final minDate = dates.first;
    final maxDate = dates.last;

    final keys = <String>{};
    int page = 1, totalPages = 1;

    do {
      final uri =
          Uri.parse('$_kBaseUrl/api/collections/transactions/records')
              .replace(queryParameters: {
        'perPage': '500',
        'page': '$page',
        'fields': 'date,name,amount',
        'filter': 'date >= "$minDate" && date <= "$maxDate"',
      });
      final resp = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) break;
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      for (final rec in data['items'] as List) {
        keys.add('${rec['date']}|${rec['name']}|${rec['amount']}');
      }
      totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      page++;
    } while (page <= totalPages);

    return keys;
  }

  // ── Uploader ──────────────────────────────────────────────────────────────

  Future<String?> _upload(Map<String, dynamic> tx) async {
    final resp = await http
        .post(
          Uri.parse('$_kBaseUrl/api/collections/transactions/records'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'date': tx['date'],
            'name': tx['name'],
            'amount': tx['amount'],
            'currency': tx['currency'] ?? 'DKK',
            'account': tx['account'] ?? 'Lønkonto',
            'category': tx['category'],
            'subcategory': tx['subcategory'] ?? '',
            'type': tx['type'],
            'originally_uncategorized': tx['category'] == 'Uncategorized',
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return body['id'] as String?;
  }

  // ── Transfer Detection ───────────────────────────────────────────────────

  Future<int> _detectTransfers(
      List<Map<String, dynamic>> uploaded, String currentAccount) async {
    if (uploaded.isEmpty) return 0;

    final dates =
        uploaded.map((t) => DateTime.parse(t['date'] as String)).toList();
    final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = dates.reduce((a, b) => a.isAfter(b) ? a : b);

    final queryFrom = minDate.subtract(const Duration(days: 1));
    final queryTo = maxDate.add(const Duration(days: 1));

    final otherUri =
        Uri.parse('$_kBaseUrl/api/collections/transactions/records')
            .replace(queryParameters: {
      'perPage': '500',
      'fields': 'id,date,amount,account,category,type',
      'filter':
          'date >= "${_fmtDate(queryFrom)}" && date <= "${_fmtDate(queryTo)}" && account != "$currentAccount"',
    });

    final headers = await _authHeaders();
    final otherResp = await http
        .get(otherUri, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (otherResp.statusCode != 200) return 0;

    final otherItems =
        (jsonDecode(otherResp.body)['items'] as List? ?? [])
            .cast<Map<String, dynamic>>();

    int linked = 0;

    for (final tx in uploaded) {
      final amount = (tx['amount'] as num).toDouble();
      final date = DateTime.parse(tx['date'] as String);
      final pbId = tx['pb_id'] as String?;

      final match = otherItems.firstWhere(
        (o) {
          final oAmount = (o['amount'] as num?)?.toDouble() ?? 0;
          final oDate = DateTime.tryParse(o['date'] as String? ?? '');
          if (oDate == null) return false;
          final diff = oDate.difference(date).inDays.abs();
          return (oAmount + amount).abs() < 0.01 && diff <= 1;
        },
        orElse: () => {},
      );

      if (match.isNotEmpty && pbId != null) {
        try {
          await _patch(pbId, 'Overførsel', type: 'Transfer');
          await _patch(match['id'] as String, 'Overførsel', type: 'Transfer');
          otherItems.remove(match);
          linked++;
        } catch (_) {}
      }
    }

    return linked;
  }

  Future<void> _patch(String id, String category, {String? type}) async {
    final body = <String, dynamic>{'category': category};
    if (type != null) body['type'] = type;
    await http
        .patch(
          Uri.parse('$_kBaseUrl/api/collections/transactions/records/$id'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Public entry point ────────────────────────────────────────────────────

  Future<ImportResult> run(
    String csvContent, {
    String account = 'Lønkonto',
    bool skipCategorization = false,
  }) async {
    final errors = <String>[];

    // 1. Parse
    final txs = _parseCsv(csvContent);
    if (txs.isEmpty) {
      return ImportResult(
        parsed: 0,
        categorized: 0,
        uncategorized: 0,
        duplicates: 0,
        uploaded: 0,
        transfers: 0,
        errors: ['No valid transactions found in CSV.'],
      );
    }

    // Attach account to all transactions
    for (final tx in txs) {
      tx['account'] = account;
    }

    // 2. Categorize using CategoryService
    final catService = CategoryService.instance;
    if (!catService.loaded) {
      await catService.load();
    }

    if (skipCategorization || SettingsService.instance.alwaysUncategorized) {
      for (final tx in txs) {
        tx['category'] = 'Uncategorized';
        tx['subcategory'] = '';
      }
    } else {
      for (final tx in txs) {
        final result = catService.categorize(
            tx['name'] as String, tx['type'] as String);
        tx['category'] = result.category;
        tx['subcategory'] = result.subcategory;
        tx['type'] = result.type; // May change to 'Transfer'
      }
    }
    final catCount =
        txs.where((t) => t['category'] != 'Uncategorized').length;
    final uncatCount = txs.length - catCount;

    // 3. Deduplicate
    final existing = await _existingKeys(txs);
    final newTxs = txs.where((tx) {
      return !existing
          .contains('${tx['date']}|${tx['name']}|${tx['amount']}');
    }).toList();
    final dupes = txs.length - newTxs.length;

    // 4. Upload (collect pb_id for transfer detection)
    int uploaded = 0;
    for (final tx in newTxs) {
      try {
        final id = await _upload(tx);
        tx['pb_id'] = id;
        uploaded++;
      } catch (e) {
        errors.add('${tx['name']}: $e');
      }
    }

    // 5. Transfer detection (only if multiple accounts exist)
    int transfers = 0;
    if (SettingsService.instance.accounts.length > 1) {
      try {
        transfers = await _detectTransfers(
          newTxs.where((t) => t['pb_id'] != null).toList(),
          account,
        );
      } catch (_) {}
    }

    // 6. Register account if new
    await SettingsService.instance.addAccount(account);

    return ImportResult(
      parsed: txs.length,
      categorized: catCount,
      uncategorized: uncatCount,
      duplicates: dupes,
      uploaded: uploaded,
      transfers: transfers,
      errors: errors,
    );
  }
}

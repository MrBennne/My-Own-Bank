import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/csv_pipeline_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _pipeline = CsvPipelineService();

  String? _fileName;
  List<int>? _fileBytes;
  bool _running = false;
  String? _resultText;
  bool _resultSuccess = false;

  // Account selection
  late String _selectedAccount;
  final _newAccountController = TextEditingController();
  bool _skipCategorization = false;

  @override
  void initState() {
    super.initState();
    _selectedAccount = SettingsService.instance.accounts.first;
  }

  @override
  void dispose() {
    _newAccountController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _resultText = null;
      _fileName = null;
      _fileBytes = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    List<int>? bytes = file.bytes != null ? List<int>.from(file.bytes!) : null;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes != null) {
      setState(() {
        _fileName = file.name;
        _fileBytes = bytes;
      });
    }
  }

  Future<void> _import() async {
    if (_fileBytes == null) return;
    setState(() {
      _running = true;
      _resultText = null;
    });

    try {
      String content;
      try {
        content = utf8.decode(_fileBytes!);
      } catch (_) {
        content = latin1.decode(_fileBytes!);
      }

      final result = await _pipeline.run(
        content,
        account: _selectedAccount,
        skipCategorization: _skipCategorization,
      );

      if (mounted) {
        setState(() {
          _resultText = result.summary;
          _resultSuccess = result.errors.isEmpty;
          _running = false;
          _fileName = null;
          _fileBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultText = e.toString().replaceFirst('Exception: ', '');
          _resultSuccess = false;
          _running = false;
        });
      }
    }
  }

  Future<void> _showNewAccountDialog() async {
    _newAccountController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('New Account'),
        content: TextField(
          controller: _newAccountController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Account name',
            hintText: 'e.g. Opsparingskonto',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = _newAccountController.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      await SettingsService.instance.addAccount(name);
      setState(() => _selectedAccount = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: ListenableBuilder(
        listenable: SettingsService.instance,
        builder: (context, _) {
          final accounts = SettingsService.instance.accounts;
          // Ensure selected account is still valid
          if (!accounts.contains(_selectedAccount)) {
            _selectedAccount = accounts.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.primary.withAlpha(51)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('Bank CSV Import',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppTheme.primary)),
                      ]),
                      const SizedBox(height: 8),
                      const Text(
                        'Semicolon-delimited bank export. Parses, categorizes, '
                        'deduplicates and pushes directly to PocketBase. '
                        'Transfers between accounts are auto-detected.',
                        style: TextStyle(
                            color: AppTheme.onSurfaceMuted,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCOUNT',
                      style: TextStyle(
                        color: AppTheme.onSurfaceMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedAccount,
                                dropdownColor: AppTheme.surfaceVariant,
                                isExpanded: true,
                                style: const TextStyle(
                                    color: AppTheme.onSurface,
                                    fontSize: 15),
                                items: [
                                  ...accounts.map((a) =>
                                      DropdownMenuItem(
                                          value: a, child: Text(a))),
                                  const DropdownMenuItem(
                                    value: '__new__',
                                    child: Row(children: [
                                      Icon(Icons.add_rounded,
                                          size: 16,
                                          color: AppTheme.primary),
                                      SizedBox(width: 6),
                                      Text('New account…',
                                          style: TextStyle(
                                              color: AppTheme.primary)),
                                    ]),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == '__new__') {
                                    _showNewAccountDialog();
                                  } else if (v != null) {
                                    setState(
                                        () => _selectedAccount = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Skip categorization checkbox
                GestureDetector(
                  onTap: () => setState(
                      () => _skipCategorization = !_skipCategorization),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _skipCategorization
                          ? AppTheme.amber.withAlpha(13)
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _skipCategorization
                            ? AppTheme.amber.withAlpha(80)
                            : AppTheme.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _skipCategorization,
                          onChanged: (v) => setState(
                              () => _skipCategorization = v ?? false),
                          activeColor: AppTheme.amber,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Import as Uncategorized',
                                style: TextStyle(
                                  color: AppTheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Skip keyword matching — all go to Review',
                                style: TextStyle(
                                  color: AppTheme.onSurfaceMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Drop zone
                GestureDetector(
                  onTap: _running ? null : _pickFile,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 130,
                    decoration: BoxDecoration(
                      color: _fileName != null
                          ? AppTheme.income.withAlpha(13)
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _fileName != null
                            ? AppTheme.income.withAlpha(102)
                            : AppTheme.divider,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _fileName != null
                              ? Icons.check_circle_outline_rounded
                              : Icons.upload_file_rounded,
                          size: 36,
                          color: _fileName != null
                              ? AppTheme.income
                              : AppTheme.onSurfaceMuted,
                        ),
                        const SizedBox(height: 10),
                        if (_fileName != null) ...[
                          Text(_fileName!,
                              style: const TextStyle(
                                  color: AppTheme.income,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${(_fileBytes?.length ?? 0) ~/ 1024} KB',
                              style: const TextStyle(
                                  color: AppTheme.onSurfaceMuted,
                                  fontSize: 12)),
                        ] else ...[
                          const Text('Tap to select CSV file',
                              style: TextStyle(
                                  color: AppTheme.onSurfaceMuted,
                                  fontSize: 14)),
                          const SizedBox(height: 2),
                          const Text('.csv files only',
                              style: TextStyle(
                                  color: AppTheme.onSurfaceMuted,
                                  fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _running ? null : _pickFile,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Browse'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          (_fileName != null && !_running) ? _import : null,
                      icon: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(_running ? 'Importing…' : 'Import'),
                      style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ]),

                // Result
                if (_resultText != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _resultSuccess
                          ? AppTheme.income.withAlpha(13)
                          : AppTheme.expense.withAlpha(13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _resultSuccess
                            ? AppTheme.income.withAlpha(77)
                            : AppTheme.expense.withAlpha(77),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            _resultSuccess
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color: _resultSuccess
                                ? AppTheme.income
                                : AppTheme.expense,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _resultSuccess
                                ? 'Import Complete'
                                : 'Import Error',
                            style: TextStyle(
                              color: _resultSuccess
                                  ? AppTheme.income
                                  : AppTheme.expense,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          _resultText!,
                          style: const TextStyle(
                              color: AppTheme.onSurface,
                              fontSize: 13,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

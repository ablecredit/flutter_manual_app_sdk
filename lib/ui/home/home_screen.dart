import 'dart:async';

import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';
import '../../data/model/loan_case_item.dart';
import '../../data/repository/loan_case_repository.dart';
import '../../data/repository/sdk_config_repository.dart';
import 'create_loan_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _loanRepo = LoanCaseRepository();
  final _configRepo = SdkConfigRepository();
  final _fetchRef = TextEditingController();

  List<LoanCaseItem> _loans = [];
  bool _filtersEnabled = false;
  bool _fetchLoading = false;
  bool _createLoading = false;
  final Set<String> _reportLoadingIds = {};

  StreamSubscription<Map<String, dynamic>>? _uploadStatusSub;

  @override
  void initState() {
    super.initState();
    _loadLoans();
    _loadFiltersState();
    _subscribeToUploadStatus();
  }

  void _subscribeToUploadStatus() {
    debugPrint('[AbleCredit] Subscribing to fileUploadStatusStream');
    _uploadStatusSub = AbleCreditSdkBridge.fileUploadStatusStream.listen(
      (event) {
        final type = event['type']?.toString() ?? 'unknown';
        final uniqueId = event['uniqueId']?.toString() ?? '';
        final status = event['status']?.toString() ?? '';
        final message = event['message']?.toString();
        debugPrint('[AbleCredit] Upload status event: type=$type uniqueId=$uniqueId status=$status message=$message');
      },
      onError: (Object error) {
        debugPrint('[AbleCredit] Upload status stream error: $error');
      },
      onDone: () {
        debugPrint('[AbleCredit] Upload status stream closed');
      },
    );
  }


  Future<void> _loadLoans() async {
    final loans = await _loanRepo.loadAll();
    if (mounted) setState(() => _loans = loans);
  }

  Future<void> _loadFiltersState() async {
    final enabled = await _configRepo.getFiltersEnabled();
    if (mounted) setState(() => _filtersEnabled = enabled);
  }

  Future<void> _toggleFilters(bool value) async {
    await _configRepo.setFiltersEnabled(value);
    if (mounted) setState(() => _filtersEnabled = value);
  }

  Future<void> _showCreateLoanDialog() async {
    if (_createLoading) return;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateLoanDialog(),
    );
    if (payload == null || !mounted) return;

    setState(() => _createLoading = true);
    try {
      final result = await AbleCreditSdkBridge.createNewLoanCase(payload);
      if (!mounted) return;
      if (result['success'] == true) {
        final appId = _extractApplicationId(result);
        final loanRef = payload['loan_reference']?.toString() ?? '';
        if (appId != null) {
          final item = LoanCaseItem(
            applicationId: appId,
            loanReference: loanRef,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          await _loanRepo.save(item);
          await _loadLoans();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loan case created')),
          );
        }
      } else {
        final msg = result['message']?.toString() ?? 'Failed to create loan';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _createLoading = false);
    }
  }

  Future<void> _fetchLoan() async {
    final ref = _fetchRef.text.trim();
    if (ref.isEmpty) return;
    setState(() => _fetchLoading = true);
    try {
      final result = await AbleCreditSdkBridge.fetchLoanDetails(ref);
      if (!mounted) return;
      if (result['success'] == true) {
        final appId = _extractApplicationId(result);
        if (appId != null) {
          final item = LoanCaseItem(
            applicationId: appId,
            loanReference: ref,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          await _loanRepo.save(item);
          await _loadLoans();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loan fetched')),
          );
        }
      } else {
        final msg = result['message']?.toString() ?? 'Loan not found';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _fetchLoading = false);
    }
  }

  Future<void> _executeAction(LoanCaseItem loan, String action) async {
    final id = loan.applicationId;
    debugPrint('[AbleCredit] _executeAction: action=$action applicationId=$id');
    if (action == 'report') {
      if (_reportLoadingIds.contains(id)) return;
      setState(() => _reportLoadingIds.add(id));
    }
    try {
      Map<String, dynamic> result;
      switch (action) {
        case 'audio':
          debugPrint('[AbleCredit] Calling recordAudio(loanApplicationId=$id)');
          result = await AbleCreditSdkBridge.recordAudio(loanApplicationId: id);
        case 'business':
          debugPrint('[AbleCredit] Calling captureBusinessPhotos(loanApplicationId=$id)');
          result = await AbleCreditSdkBridge.captureBusinessPhotos(loanApplicationId: id);
        case 'collateral':
          debugPrint('[AbleCredit] Calling captureCollateralPhotos(loanApplicationId=$id)');
          result = await AbleCreditSdkBridge.captureCollateralPhotos(loanApplicationId: id);
        case 'family':
          debugPrint('[AbleCredit] Calling captureFamilyPhotos(loanApplicationId=$id)');
          result = await AbleCreditSdkBridge.captureFamilyPhotos(loanApplicationId: id);
        case 'report':
          debugPrint('[AbleCredit] Calling requestReportGeneration(applicationId=$id)');
          result = await AbleCreditSdkBridge.requestReportGeneration(id);
        default:
          return;
      }
      debugPrint('[AbleCredit] _executeAction result: $result');
      if (!mounted) return;
      if (result['success'] == true) {
        final msg = result['message']?.toString();
        final text = (msg != null && msg.isNotEmpty) ? msg : '$action started successfully';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      } else {
        final msg = result['message']?.toString() ?? 'Action failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint('[AbleCredit] _executeAction error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (action == 'report' && mounted) setState(() => _reportLoadingIds.remove(id));
    }
  }

  static String? _extractApplicationId(Map<String, dynamic> response) {
    final top = response['applicationId'];
    if (top != null && top.toString().trim().isNotEmpty) return top.toString().trim();
    final data = response['data'];
    if (data is Map) {
      final inner = data['data'];
      if (inner is Map) {
        final app = inner['application'];
        if (app is Map && app['_id'] != null) {
          final id = app['_id'].toString().trim();
          if (id.isNotEmpty) return id;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _uploadStatusSub?.cancel();
    _fetchRef.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    _buildFetchSection(),
                    const Divider(height: 1),
                    _buildLoanListHeader(),
                    const Divider(height: 1),
                    if (_loans.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No loan cases yet...',
                          style: TextStyle(color: AppColors.gray600, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._loans.map((loan) => _buildLoanCard(loan)),
                  ],
                ),
              ),
            ],
          ),
          if (_createLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                        ),
                        SizedBox(width: 12),
                        Text('Creating loan...'),
                      ],
                    ),
                  )
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Home',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          OutlinedButton(
            onPressed: _createLoading ? null : _showCreateLoanDialog,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: _createLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                  )
                : const Text('+ New loan'),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _fetchRef,
            decoration: const InputDecoration(labelText: 'Loan reference'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _fetchLoan(),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _fetchLoading ? null : _fetchLoan,
            child: _fetchLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                  )
                : const Text('Fetch'),
          ),
          const SizedBox(height: 4),
          const Text(
            'AbleCredit.fetchLoanDetails(...)',
            style: TextStyle(fontSize: 11, color: AppColors.gray600),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'LOAN CASES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.gray600,
              ),
            ),
          ),
          const Text('Filters', style: TextStyle(fontSize: 13, color: AppColors.gray800)),
          const SizedBox(width: 4),
          Switch(
            value: _filtersEnabled,
            onChanged: _toggleFilters,
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(LoanCaseItem loan) {
    final date = DateTime.fromMillisecondsSinceEpoch(loan.createdAt);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.loanReference,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _buildMoreMenu(loan),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${loan.applicationId}  •  $dateStr',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.gray600,
                  fontFamily: 'monospace',
                ),
              ),
              if (_filtersEnabled) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _actionChip('Audio', () => _executeAction(loan, 'audio')),
                    _actionChip('Business', () => _executeAction(loan, 'business')),
                    _actionChip('Collateral', () => _executeAction(loan, 'collateral')),
                    _actionChip('Family', () => _executeAction(loan, 'family')),
                    _reportLoadingIds.contains(loan.applicationId)
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : _actionChip('Report', () => _executeAction(loan, 'report')),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _actionChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildMoreMenu(LoanCaseItem loan) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.gray600),
      onSelected: (action) => _executeAction(loan, action),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'audio', child: Text('Record audio')),
        PopupMenuItem(value: 'business', child: Text('Business photos')),
        PopupMenuItem(value: 'collateral', child: Text('Collateral photos')),
        PopupMenuItem(value: 'family', child: Text('Family photos')),
        PopupMenuItem(value: 'report', child: Text('Request report')),
      ],
    );
  }
}

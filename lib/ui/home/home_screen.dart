import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';
import '../../data/model/loan_case_item.dart';
import '../../data/repository/flow_steps_repository.dart';
import '../../data/repository/loan_case_repository.dart';
import '../../data/repository/sdk_config_repository.dart';
import '../../data/repository/wrapper_settings_repository.dart';
import '../flow/flow_config_dialog.dart';
import '../testflows/test_flows_screen.dart';
import 'create_loan_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _loanRepo = LoanCaseRepository();
  final _configRepo = SdkConfigRepository();
  final _stepsRepo = FlowStepsRepository();
  final _wrapperSettings = WrapperSettingsRepository();
  final _fetchRef = TextEditingController();
  final _fetchId = TextEditingController();

  List<LoanCaseItem> _loans = [];
  bool _filtersEnabled = false;
  bool _fetchLoading = false;
  bool _createLoading = false;
  final Set<String> _reportLoadingIds = {};
  final Set<String> _directReportLoading = {};

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

        // Loan created by the flow orchestrator — save locally and refresh the list.
        if (type == 'loan_created') {
          final appId = event['applicationId']?.toString() ?? '';
          final loanRef = event['loanReference']?.toString() ?? '';
          if (appId.isNotEmpty) {
            _loanRepo
                .save(LoanCaseItem(
                  applicationId: appId,
                  loanReference: loanRef,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ))
                .then((_) => _loadLoans());
          }
        }
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

  /// Shows the "Create loan only" vs "Create & run flow" chooser, mirroring the
  /// Kotlin sample's new-loan choice dialog.
  Future<void> _showNewLoanChoice() async {
    if (_createLoading) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('New loan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Create loan only'),
              subtitle: const Text('AbleCredit.createNewLoanCase(...)'),
              onTap: () => Navigator.pop(ctx, 'create_only'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Create & run flow'),
              subtitle: const Text('Create the loan, then run the orchestrator flow'),
              onTap: () => Navigator.pop(ctx, 'create_and_flow'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'create_only') {
      await _showCreateLoanDialog();
    } else if (choice == 'create_and_flow') {
      await _showCreateAndRunFlow();
    }
  }

  /// Opens the flow config dialog in new-loan mode; the orchestrator creates the
  /// loan as its first step. Mirrors the Kotlin sample's showCreateLoanThroughFlow.
  Future<void> _showCreateAndRunFlow() async {
    final config = await showDialog<FlowConfig>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FlowConfigDialog(),
    );
    if (config == null || !mounted) return;
    await _startFlow(config);
  }

  /// Runs the orchestrator flow against an existing loan (withExistingLoan).
  /// Mirrors the Kotlin sample's startCompleteFlow.
  Future<void> _startCompleteFlow(LoanCaseItem loan) async {
    if (loan.loanReference.isEmpty) {
      _wrapperSnack('This loan has no reference to run the flow against');
      return;
    }
    final steps = await _stepsRepo.getSteps();
    if (steps.isEmpty) {
      _wrapperSnack('No capture steps configured. Set them in Profile.');
      return;
    }
    await _startFlow(FlowConfig(
      useExistingLoan: true,
      existingLoanApplicationId: loan.applicationId,
      loanReference: loan.loanReference,
      steps: steps,
    ));
  }

  Future<void> _startFlow(FlowConfig config) async {
    try {
      final result = await AbleCreditSdkBridge.startLoanFlow(
        steps: config.steps,
        useExistingLoan: config.useExistingLoan,
        existingLoanApplicationId: config.existingLoanApplicationId,
        payload: config.useExistingLoan
            ? null
            : buildFlowLoanPayload(config.loanReference),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _wrapperSnack('Loan flow started');
      } else {
        // Always show config/validation errors regardless of wrapper-toasts setting.
        final msg = result['message']?.toString() ?? 'Failed to start loan flow';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _copyLoanReference(String loanReference) async {
    if (loanReference.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: loanReference));
    _wrapperSnack('Loan reference copied');
  }

  /// Shows a snackbar only when wrapper toasts are enabled (mirrors kotlin gating).
  Future<void> _wrapperSnack(String message) async {
    if (!mounted) return;
    final enabled = await _wrapperSettings.isWrapperToastsEnabled();
    if (!enabled || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        final loanRef = payload['reference_id']?.toString() ?? '';
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
    final appId = _fetchRef.text.trim();
    if (appId.isEmpty) return;
    setState(() => _fetchLoading = true);
    try {
      final result = await AbleCreditSdkBridge.getLoanByReference(appId);
      if (!mounted) return;
      if (result['success'] == true) {
        final resolvedAppId = _extractApplicationId(result) ?? appId;
        final loanRef = (result['data'] as Map?)?['data']?['application']?['loan_reference']?.toString() ?? '';
        final item = LoanCaseItem(
          applicationId: resolvedAppId,
          loanReference: loanRef,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _loanRepo.save(item);
        await _loadLoans();
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

  Future<void> _fetchLoanById() async {
    final applicationId = _fetchId.text.trim();
    if (applicationId.isEmpty) return;
    setState(() => _fetchLoading = true);
    try {
      final result = await AbleCreditSdkBridge.getLoanById(applicationId);
      if (!mounted) return;
      if (result['success'] == true) {
        final resolvedAppId = _extractApplicationId(result) ?? applicationId;
        final loanRef = (result['data'] as Map?)?['data']?['application']?['loan_reference']?.toString() ?? '';
        final item = LoanCaseItem(
          applicationId: resolvedAppId,
          loanReference: loanRef,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _loanRepo.save(item);
        await _loadLoans();
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
    final appId = loan.applicationId;
    debugPrint('[AbleCredit] _executeAction: action=$action loanApplicationId=$appId');
    if (action == 'report') {
      if (_reportLoadingIds.contains(appId)) return;
      setState(() => _reportLoadingIds.add(appId));
    }
    try {
      Map<String, dynamic> result;
      switch (action) {
        case 'audio':
          debugPrint('[AbleCredit] Calling recordAudio(loanApplicationId=$appId)');
          result = await AbleCreditSdkBridge.recordAudio(loanApplicationId: appId);
        case 'business':
          debugPrint('[AbleCredit] Calling captureBusinessPhotos(loanApplicationId=$appId)');
          result = await AbleCreditSdkBridge.captureBusinessPhotos(loanApplicationId: appId);
        case 'collateral':
          debugPrint('[AbleCredit] Calling captureCollateralPhotos(loanApplicationId=$appId)');
          result = await AbleCreditSdkBridge.captureCollateralPhotos(loanApplicationId: appId);
        case 'family':
          debugPrint('[AbleCredit] Calling captureFamilyPhotos(loanApplicationId=$appId)');
          result = await AbleCreditSdkBridge.captureFamilyPhotos(loanApplicationId: appId);
        case 'report':
          debugPrint('[AbleCredit] Calling requestReportGeneration(loanApplicationId=$appId)');
          result = await AbleCreditSdkBridge.requestReportGeneration(appId);
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
      if (action == 'report' && mounted) setState(() => _reportLoadingIds.remove(appId));
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
    _fetchId.dispose();
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
                    _buildDirectCallSection(),
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TestFlowsScreen()),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Test flows'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _createLoading ? null : _showNewLoanChoice,
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
            'AbleCredit.getLoanByReference(...)',
            style: TextStyle(fontSize: 11, color: AppColors.gray600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fetchId,
            decoration: const InputDecoration(labelText: 'Loan ID'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _fetchLoanById(),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _fetchLoading ? null : _fetchLoanById,
            child: _fetchLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                  )
                : const Text('Fetch by ID'),
          ),
          const SizedBox(height: 4),
          const Text(
            'AbleCredit.getLoanById(...)',
            style: TextStyle(fontSize: 11, color: AppColors.gray600),
          ),
        ],
      ),
    );
  }

  /// "Direct call (no loan created)" section: each chip prompts for a loan
  /// reference and calls one SDK method directly. The reference is passed
  /// verbatim (including blank) so the SDK surfaces its own validation.
  /// Mirrors the Kotlin sample's setupDirectCallSection.
  Widget _buildDirectCallSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DIRECT CALL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.gray600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Calls an SDK method directly without a pre-created loan. Enter any application ID — including blank — to test the SDK\'s own validation.',
            style: TextStyle(fontSize: 12, color: AppColors.gray600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _actionChip('Record audio',
                  () => _promptDirectLoanReference('Record audio', 'audio')),
              _actionChip('Capture business photos',
                  () => _promptDirectLoanReference('Capture business photos', 'business')),
              _actionChip('Capture collateral photos',
                  () => _promptDirectLoanReference('Capture collateral photos', 'collateral')),
              _actionChip('Capture family photos',
                  () => _promptDirectLoanReference('Capture family photos', 'family')),
              _directReportLoading.isNotEmpty
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
                  : _actionChip('Generate report',
                      () => _promptDirectLoanReference('Generate report', 'report')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptDirectLoanReference(String actionLabel, String action) async {
    final controller = TextEditingController();
    final ref = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel (direct call)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Application ID',
            helperText: 'Leave empty to see the SDK reject the call.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    // Dispose after the dialog route has fully detached. Disposing synchronously here trips
    // the framework's "_dependents.isEmpty" assertion because the TextField is still
    // deactivating when this future resumes.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    // ref == null means cancelled; an empty string is a deliberate test input.
    if (ref == null || !mounted) return;
    await _executeDirectAction(action, ref);
  }

  Future<void> _executeDirectAction(String action, String loanApplicationId) async {
    try {
      Map<String, dynamic> result;
      switch (action) {
        case 'audio':
          result = await AbleCreditSdkBridge.recordAudio(loanApplicationId: loanApplicationId);
        case 'business':
          result = await AbleCreditSdkBridge.captureBusinessPhotos(loanApplicationId: loanApplicationId);
        case 'collateral':
          result = await AbleCreditSdkBridge.captureCollateralPhotos(loanApplicationId: loanApplicationId);
        case 'family':
          result = await AbleCreditSdkBridge.captureFamilyPhotos(loanApplicationId: loanApplicationId);
        case 'report':
          setState(() => _directReportLoading.add(loanApplicationId));
          try {
            result = await AbleCreditSdkBridge.requestReportGeneration(loanApplicationId);
          } finally {
            if (mounted) setState(() => _directReportLoading.remove(loanApplicationId));
          }
        default:
          return;
      }
      if (!mounted) return;
      if (result['success'] == true) {
        final msg = result['message']?.toString();
        _wrapperSnack((msg != null && msg.isNotEmpty) ? msg : 'Direct $action submitted');
      } else {
        _wrapperSnack(result['message']?.toString() ?? 'Direct $action failed');
      }
    } catch (e) {
      if (mounted) _wrapperSnack('Error: $e');
    }
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
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.gray600),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copy loan reference',
                    onPressed: () => _copyLoanReference(loan.loanReference),
                  ),
                  _buildMoreMenu(loan),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${loan.applicationId}  •  $dateStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: AppColors.gray600),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copy application ID',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: loan.applicationId));
                      _wrapperSnack('Application ID copied');
                    },
                  ),
                ],
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  label: const Text('Complete flow',
                      style: TextStyle(color: AppColors.white, fontSize: 13)),
                  backgroundColor: AppColors.black,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => _startCompleteFlow(loan),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _actionChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: AppColors.black, fontSize: 13)),
      onPressed: onTap,
      backgroundColor: AppColors.white,
      side: const BorderSide(color: AppColors.black, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
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

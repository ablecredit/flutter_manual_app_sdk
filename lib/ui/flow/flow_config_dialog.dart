import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/repository/flow_steps_repository.dart';

/// Result of [FlowConfigDialog]: the chosen start point and the org-wide ordered
/// set of capture steps (read from FlowStepsRepository — configured once in
/// Profile → Flow config, NOT per run). Mirrors the Kotlin sample's FlowConfigDialog.
class FlowConfig {
  final bool useExistingLoan;
  /// The external loan reference for existing-loan flows (passed to withExistingLoan).
  final String? existingLoanApplicationId;
  /// The new loan reference for new-loan flows (used to build the create payload).
  final String loanReference;
  final List<String> steps;

  const FlowConfig({
    required this.useExistingLoan,
    required this.existingLoanApplicationId,
    required this.loanReference,
    required this.steps,
  });
}

/// Sample payload base for new-loan flows — same shape the app uses elsewhere
/// when creating a loan (see CreateLoanDialog).
const _samplePayload = {
  'loan_reference': 'LN-REF-20260430-9012',
  'client_unique_id': 'CUST-20260430-9012',
  'product_id': 'MUT-IND-3065',
  'branch_id': 'ML1348',
  'source_system': '',
  'user_name': 'Field Agent',
  'branch_name': 'Bangalore Central',
  'business_profile': {
    'product': 'LAP',
    'business_model': 'Trading',
    'industry': 'Fashion Apparel',
  },
  'data': {
    'borrower_details': {
      'state_name': 'karnataka',
      'entity_type': 'individual',
      'name': 'Shwetanka Srivastava',
      'dob': '24/01/1988',
      'mobile': '8197837043',
      'owner_of_business': 'Yes',
    },
    'employment_details': {'nature_of_employment': 'Full-Time'},
    'loan_details': {
      'business_name': 'trends',
      'quantum': '500000',
      'tenure': '24',
    },
  },
};

/// Builds a create-loan payload for a new-loan flow from a loan reference.
Map<String, dynamic> buildFlowLoanPayload(String loanReference) {
  final payload = Map<String, dynamic>.from(_samplePayload);
  payload['loan_reference'] = loanReference;
  return payload;
}

class FlowConfigDialog extends StatefulWidget {
  const FlowConfigDialog({super.key, this.existingLoanApplicationId});

  /// When provided, the dialog opens pre-seeded in existing-loan mode.
  final String? existingLoanApplicationId;

  @override
  State<FlowConfigDialog> createState() => _FlowConfigDialogState();
}

class _FlowConfigDialogState extends State<FlowConfigDialog> {
  final _stepsRepo = FlowStepsRepository();
  final _existingLoanRef = TextEditingController();
  final _loanReference = TextEditingController();

  bool _useExistingLoan = false;
  bool _loading = true;

  /// Org-wide configured steps, read-only here. Set in Profile → Flow config.
  List<String> _steps = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingLoanApplicationId?.trim();
    if (existing != null && existing.isNotEmpty) {
      _useExistingLoan = true;
      _existingLoanRef.text = existing;
    }
    final datePart = _dateStamp();
    final suffix = (DateTime.now().millisecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    _loanReference.text = 'LN-REF-$datePart-$suffix';
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    final saved = await _stepsRepo.getSteps();
    if (!mounted) return;
    setState(() {
      _steps = saved;
      _loading = false;
    });
  }

  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _start() async {
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No flow steps configured. Set them in Profile.')),
      );
      return;
    }

    if (_useExistingLoan) {
      if (_existingLoanRef.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a loan application ID')),
        );
        return;
      }
    } else {
      if (_loanReference.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a loan reference')),
        );
        return;
      }
    }

    Navigator.of(context).pop(FlowConfig(
      useExistingLoan: _useExistingLoan,
      existingLoanApplicationId: _useExistingLoan ? _existingLoanRef.text.trim() : null,
      loanReference: _loanReference.text.trim(),
      steps: _steps,
    ));
  }

  @override
  void dispose() {
    _existingLoanRef.dispose();
    _loanReference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.black),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStartModeToggle(),
                        const SizedBox(height: 16),
                        if (_useExistingLoan)
                          TextField(
                            controller: _existingLoanRef,
                            decoration:
                                const InputDecoration(labelText: 'Application ID *'),
                          )
                        else
                          TextField(
                            controller: _loanReference,
                            decoration:
                                const InputDecoration(labelText: 'Loan Reference *'),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Steps and order are set app-wide in '
                          'Profile → Flow config.',
                          style: TextStyle(fontSize: 12, color: AppColors.gray600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AbleCredit.startLoanFlow(...)',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.gray600),
                        ),
                      ],
                    ),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _loading ? null : _start,
              child: const Text('Start Loan Flow'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Run Loan Flow',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildStartModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'START POINT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.gray600,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('New loan')),
            ButtonSegment(value: true, label: Text('Existing loan')),
          ],
          selected: {_useExistingLoan},
          onSelectionChanged: (s) =>
              setState(() => _useExistingLoan = s.first),
        ),
      ],
    );
  }
}

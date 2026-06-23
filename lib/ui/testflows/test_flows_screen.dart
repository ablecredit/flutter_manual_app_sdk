import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';

/// Flow step options that map to SDK calls.
enum FlowStep {
  audio('Record audio', 'RECORD_AUDIO'),
  business('Business photos', 'CAPTURE_BUSINESS_PHOTOS'),
  collateral('Collateral photos', 'CAPTURE_COLLATERAL_PHOTOS'),
  family('Family photos', 'CAPTURE_FAMILY_PHOTOS'),
  generateReport('Generate report', null);

  const FlowStep(this.label, this.flowStepName);
  final String label;
  final String? flowStepName;
}

/// How the docked button transitions to the next step.
enum TransitionType {
  direct('Direct to SDK step', 'Docked button opens the next SDK screen immediately.'),
  clientScreen('Via client screen', 'Docked button closes the SDK screen and opens a client-owned Flutter screen first.');

  const TransitionType(this.label, this.description);
  final String label;
  final String description;
}

class StepNode {
  FlowStep step;
  TransitionType transition;
  StepNode(this.step, {this.transition = TransitionType.direct});
}

class TestFlowsScreen extends StatefulWidget {
  const TestFlowsScreen({super.key});

  @override
  State<TestFlowsScreen> createState() => _TestFlowsScreenState();
}

class _TestFlowsScreenState extends State<TestFlowsScreen> {
  final _loanApplicationIdController = TextEditingController();

  final List<StepNode> _nodes = [
    StepNode(FlowStep.audio),
    StepNode(FlowStep.business),
  ];

  @override
  void dispose() {
    _loanApplicationIdController.dispose();
    super.dispose();
  }

  String get _loanApplicationId => _loanApplicationIdController.text.trim();

  // --- SDK calls ---

  Future<Map<String, dynamic>> _callStep(
    FlowStep step, {
    String? nextStep,
    String? nextStepLabel,
    String? transition,
  }) async {
    final loanApplicationId = _loanApplicationId.isEmpty ? null : _loanApplicationId;
    try {
      switch (step) {
        case FlowStep.audio:
          return await AbleCreditSdkBridge.recordAudio(
            loanApplicationId: loanApplicationId,
            nextStep: nextStep,
            nextStepLabel: nextStepLabel,
            transition: transition,
          );
        case FlowStep.business:
          return await AbleCreditSdkBridge.captureBusinessPhotos(
            loanApplicationId: loanApplicationId,
            nextStep: nextStep,
            nextStepLabel: nextStepLabel,
            transition: transition,
          );
        case FlowStep.collateral:
          return await AbleCreditSdkBridge.captureCollateralPhotos(
            loanApplicationId: loanApplicationId,
            nextStep: nextStep,
            nextStepLabel: nextStepLabel,
            transition: transition,
          );
        case FlowStep.family:
          return await AbleCreditSdkBridge.captureFamilyPhotos(
            loanApplicationId: loanApplicationId,
            nextStep: nextStep,
            nextStepLabel: nextStepLabel,
            transition: transition,
          );
        case FlowStep.generateReport:
          await _generateReport();
          return {};
      }
    } catch (e) {
      _showSnack('Error: $e');
      return {};
    }
  }

  Future<void> _generateReport() async {
    final loanApplicationId = _loanApplicationId;
    if (loanApplicationId.isEmpty) {
      _showSnack('Enter a loan application ID first');
      return;
    }
    try {
      final res = await AbleCreditSdkBridge.requestReportGeneration(loanApplicationId);
      _showSnack(res['success'] == true
          ? 'Report requested successfully'
          : 'Report failed: ${res['message']}');
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  /// Runs the flow step by step.
  ///
  /// For each step, passes the next step info so native can render a docked button:
  /// - direct: button launches the next step from native. For generateReport, native calls
  ///   AbleCredit.requestReportGeneration directly in the onClick.
  /// - clientScreen: button finishes the SDK screen, Flutter shows MockClientScreen.
  ///   The user taps Continue (or "Generate report" if that is the next step).
  Future<void> _runFlow() async {
    if (_nodes.isEmpty) {
      _showSnack('Add at least one step');
      return;
    }

    int i = 0;
    while (i < _nodes.length) {
      final node = _nodes[i];
      final hasNext = i < _nodes.length - 1;
      final nextNode = hasNext ? _nodes[i + 1] : null;

      // generateReport is not an SDK screen — call it directly when we reach it in the loop
      // (only reached via clientScreen path where Flutter controls the loop).
      if (node.step == FlowStep.generateReport) {
        await _callStep(FlowStep.generateReport);
        return;
      }

      final result = await _callStep(
        node.step,
        nextStep: nextNode != null ? _methodName(nextNode.step) : null,
        nextStepLabel: nextNode?.step.label,
        transition: nextNode != null ? _transitionKey(node.transition) : null,
      );

      // CANCELLED means the user pressed back on the SDK screen (no docked button tap).
      // Go back to the previous step; if already on the first step, exit the flow.
      if (result['status'] == 'CANCELLED') {
        if (i == 0) return;
        i--;
        // If the previous step used clientScreen transition, show MockClientScreen again
        // before relaunching it (mirrors the forward path).
        final prevNode = _nodes[i];
        final curNode = _nodes[i + 1];
        if (prevNode.transition == TransitionType.clientScreen) {
          if (!mounted) return;
          final proceed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => MockClientScreen(
                loanApplicationId: _loanApplicationId,
                fromStep: prevNode.step.label,
                toStep: curNode.step.label,
                isGenerateReport: curNode.step == FlowStep.generateReport,
              ),
            ),
          );
          if (proceed == false) return;
          if (proceed == true) { i++; }
          // proceed == null (back pressed) → stay at i, relaunch prevNode SDK screen
        }
        continue;
      }

      // "DOCKED_BUTTON" means the clientScreen docked button was tapped —
      // the SDK screen already closed. Show MockClientScreen then continue.
      if (result['status'] == 'DOCKED_BUTTON' && hasNext) {
        if (!mounted) return;
        final proceed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MockClientScreen(
              loanApplicationId: _loanApplicationId,
              fromStep: node.step.label,
              toStep: nextNode!.step.label,
              isGenerateReport: nextNode.step == FlowStep.generateReport,
            ),
          ),
        );
        // null = back pressed → re-run the current SDK step so the user returns to it.
        // false = "Stop flow" tapped → exit the flow entirely.
        if (proceed == false) return;
        if (proceed == null) continue; // re-run step at current i (goes back to SDK screen)
        i++;
        continue;
      }

      // For direct transitions the docked button launches the next step natively
      // (including generateReport which native calls via requestReportGeneration) —
      // Flutter's loop exits here to avoid calling the next step a second time.
      if (hasNext && node.transition == TransitionType.direct) {
        break;
      }

      i++;
    }
  }

  String? _methodName(FlowStep step) {
    switch (step) {
      case FlowStep.audio: return 'recordAudio';
      case FlowStep.business: return 'captureBusinessPhotos';
      case FlowStep.collateral: return 'captureCollateralPhotos';
      case FlowStep.family: return 'captureFamilyPhotos';
      case FlowStep.generateReport: return 'generateReport';
    }
  }

  String _transitionKey(TransitionType t) =>
      t == TransitionType.clientScreen ? 'clientScreen' : 'direct';

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // --- Pickers ---

  Future<void> _showStepPicker({FlowStep? current, required ValueChanged<FlowStep> onPick}) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _PickerSheet<FlowStep>(
        title: 'Choose SDK step',
        items: FlowStep.values,
        label: (s) => s.label,
        sublabel: (_) => null,
        selected: current,
        onPick: (s) { Navigator.pop(ctx); onPick(s); },
      ),
    );
  }

  Future<void> _showTransitionPicker({required TransitionType current, required ValueChanged<TransitionType> onPick}) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _PickerSheet<TransitionType>(
        title: 'Choose transition type',
        items: TransitionType.values,
        label: (t) => t.label,
        sublabel: (t) => t.description,
        selected: current,
        onPick: (t) { Navigator.pop(ctx); onPick(t); },
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: const Text('Test Flows',
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildLoanRefInput(),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeader('DIRECT SDK CALLS'),
                  _sectionSubtitle('No flow — launches a single SDK screen directly.'),
                  const SizedBox(height: 10),
                  _flowBtn('Record audio', () => _callStep(FlowStep.audio)),
                  _flowBtn('Business photos', () => _callStep(FlowStep.business)),
                  _flowBtn('Collateral photos', () => _callStep(FlowStep.collateral)),
                  _flowBtn('Family photos', () => _callStep(FlowStep.family)),
                  _divider(),
                  _sectionHeader('FLOW BUILDER'),
                  _sectionSubtitle(
                    'Build any multi-step flow. Tap a step to change it. '
                    'Tap the connector to choose direct or via client screen.',
                  ),
                  const SizedBox(height: 12),
                  _buildFlowNodes(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _flowBtn('+ Add step', () async {
                          await _showStepPicker(onPick: (s) {
                            setState(() => _nodes.add(StepNode(s)));
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _runBtn('▶  Run flow', _runFlow)),
                    ],
                  ),
                  _divider(),
                  _sectionHeader('GENERATE REPORT'),
                  _sectionSubtitle('Request report generation directly.'),
                  const SizedBox(height: 10),
                  _flowBtn('Generate report', _generateReport),
                  _divider(),
                  _sectionHeader('RECORD FLOW'),
                  _sectionSubtitle(
                    'Preview the full record flow with a docked Generate report button.',
                  ),
                  const SizedBox(height: 10),
                  _flowBtn(
                    'Open record flow',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecordFlowScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowNodes() {
    final children = <Widget>[];
    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      final index = i;
      children.add(_buildStepChip(node, index));
      if (i < _nodes.length - 1) {
        children.add(_buildConnector(node));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _buildStepChip(StepNode node, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                await _showStepPicker(
                  current: node.step,
                  onPick: (s) => setState(() => node.step = s),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: const BorderSide(color: AppColors.black),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                minimumSize: const Size.fromHeight(40),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(node.step.label, textAlign: TextAlign.left),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              if (_nodes.length > 1) {
                setState(() => _nodes.removeAt(index));
              } else {
                _showSnack('At least one step required');
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('✕',
                  style: TextStyle(fontSize: 16, color: AppColors.gray600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(StepNode node) {
    final isDirect = node.transition == TransitionType.direct;
    return GestureDetector(
      onTap: () async {
        await _showTransitionPicker(
          current: node.transition,
          onPick: (t) => setState(() => node.transition = t),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: isDirect
            ? null
            : BoxDecoration(
                color: const Color(0xFFFFF3CD),
                border: Border.all(color: const Color(0xFF856404)),
                borderRadius: BorderRadius.circular(4),
              ),
        child: Text(
          isDirect ? '↓  Direct  ↓  (tap to change)' : '↓  [Client screen]  ↓  (tap to change)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isDirect ? FontWeight.normal : FontWeight.bold,
            color: isDirect ? AppColors.gray600 : AppColors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildLoanRefInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APPLICATION ID',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.gray600,
                letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _loanApplicationIdController,
            decoration: const InputDecoration(
              hintText: 'Enter loan application ID',
              hintStyle: TextStyle(color: AppColors.gray600),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 4),
          const Text(
            'All test flows below use this application ID. Leave blank to test SDK error handling.',
            style: TextStyle(fontSize: 11, color: AppColors.gray600),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      );

  Widget _sectionSubtitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.gray600));

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(height: 1, color: Color(0xFFE0E0E0)),
      );

  Widget _flowBtn(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.black,
            side: const BorderSide(color: AppColors.black),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            minimumSize: const Size.fromHeight(48),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(label, textAlign: TextAlign.left),
        ),
      );

  Widget _runBtn(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(label),
        ),
      );
}

// ---------------------------------------------------------------------------
// Record flow screen — shows record steps as a read-only list with a docked
// "Generate report" button at the bottom. Tapping the button prompts for an
// application ID then calls requestReportGeneration.
// ---------------------------------------------------------------------------

class RecordFlowScreen extends StatelessWidget {
  const RecordFlowScreen({super.key});

  static const _recordSteps = [
    (icon: Icons.mic_outlined, label: 'Record audio'),
    (icon: Icons.business_outlined, label: 'Business photos'),
    (icon: Icons.inventory_2_outlined, label: 'Collateral photos'),
    (icon: Icons.family_restroom_outlined, label: 'Family photos'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: const Text('Record Flow',
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'RECORD STEPS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'These steps will be completed before generating the report.',
                    style: TextStyle(fontSize: 12, color: AppColors.gray600),
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < _recordSteps.length; i++) ...[
                    _StepRow(
                      index: i + 1,
                      icon: _recordSteps[i].icon,
                      label: _recordSteps[i].label,
                    ),
                    if (i < _recordSteps.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: SizedBox(
                          height: 24,
                          child: VerticalDivider(
                            width: 1,
                            color: AppColors.gray200,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.gray200),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ElevatedButton(
              onPressed: () => _promptAndGenerateReport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Generate report',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAndGenerateReport(BuildContext context) async {
    final controller = TextEditingController();
    final appId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Report'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Application ID',
            helperText: 'Enter the loan application ID to generate the report.',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (appId == null || !context.mounted) return;
    if (appId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application ID is required')),
      );
      return;
    }
    try {
      final res = await AbleCreditSdkBridge.requestReportGeneration(appId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['success'] == true
              ? 'Report requested successfully'
              : 'Report failed: ${res['message']}'),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.black,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: AppColors.gray800),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mock client screen — pushed by Flutter when a clientScreen docked button is tapped.
// ---------------------------------------------------------------------------

class MockClientScreen extends StatelessWidget {
  const MockClientScreen({
    super.key,
    required this.loanApplicationId,
    required this.fromStep,
    required this.toStep,
    this.isGenerateReport = false,
  });

  final String loanApplicationId;
  final String fromStep;
  final String toStep;
  /// When true the continue button says "Generate report" instead of "Continue to X".
  final bool isGenerateReport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: const Text('Client Screen',
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text('LOAN APPLICATION ID',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray600,
                    letterSpacing: 1.0)),
            const SizedBox(height: 4),
            Text(
              loanApplicationId.isEmpty ? '(none)' : loanApplicationId,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            Text(
              'This is a mock client-owned screen between "$fromStep" and "$toStep".',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'In a real integration the client app would show its own UI here '
              'before handing back to the SDK.',
              style: TextStyle(fontSize: 13, color: AppColors.gray600),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: const BorderSide(color: AppColors.black),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Stop flow'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(isGenerateReport ? 'Generate report' : 'Continue to $toStep →'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable bottom sheet picker
// ---------------------------------------------------------------------------

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onPick,
  });

  final String title;
  final List<T> items;
  final String Function(T) label;
  final String? Function(T) sublabel;
  final T? selected;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final item in items)
              InkWell(
                onTap: () => onPick(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label(item),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: item == selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (sublabel(item) != null) ...[
                              const SizedBox(height: 2),
                              Text(sublabel(item)!,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.gray600)),
                            ],
                          ],
                        ),
                      ),
                      if (item == selected)
                        const Text('✓',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

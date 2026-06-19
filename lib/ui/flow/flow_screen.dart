import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';
import 'flow_config_dialog.dart';

export 'flow_config_dialog.dart';

class FlowScreen extends StatelessWidget {
  const FlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Flow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => _showFlowConfigDialog(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Start loan flow', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AbleCredit.startLoanFlow(...)',
                    style: TextStyle(fontSize: 11, color: AppColors.gray600, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFlowConfigDialog(BuildContext context) async {
    final config = await showDialog<FlowConfig>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FlowConfigDialog(),
    );
    if (config == null || !context.mounted) return;

    final result = await AbleCreditSdkBridge.startLoanFlow(
      steps: config.steps,
      useExistingLoan: config.useExistingLoan,
      existingLoanApplicationId: config.existingLoanApplicationId,
      payload: config.useExistingLoan ? null : buildFlowLoanPayload(config.loanReference),
    );
    if (context.mounted) {
      final msg = result['message']?.toString() ??
          (result['success'] == true ? 'Flow started' : 'Flow failed');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

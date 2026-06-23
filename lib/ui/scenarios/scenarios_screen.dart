import 'dart:async';

import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  StreamSubscription<Map<String, dynamic>>? _uploadSub;

  @override
  void initState() {
    super.initState();
    _uploadSub = AbleCreditSdkBridge.fileUploadStatusStream.listen((event) {
      debugPrint('[Scenarios] upload event: $event');
    });
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    super.dispose();
  }

  Future<void> _runRecordWithDockedReport() async {
    final controller = TextEditingController();
    final appId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Application ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Application ID',
            helperText: 'Leave empty to test SDK error handling.',
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
            child: const Text('Run'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (appId == null || !mounted) return;

    try {
      final result = await AbleCreditSdkBridge.recordAudio(
        loanApplicationId: appId.isEmpty ? null : appId,
        nextStep: 'generateReport',
        nextStepLabel: 'Generate report',
        transition: 'direct',
      );
      if (!mounted) return;
      if (result['status'] == 'CANCELLED') return;
      final msg = result['message']?.toString();
      if (msg != null && msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Scenarios',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                _ScenarioTile(
                  title: 'Record Flow + Docked Button',
                  description:
                      'Calls recordAudio with a docked Generate Report button.',
                  onTap: _runRecordWithDockedReport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(description,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.gray600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.gray400),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

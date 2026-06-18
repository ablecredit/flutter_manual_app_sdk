import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';
import '../../data/repository/flow_steps_repository.dart';
import '../../data/repository/loan_case_repository.dart';
import '../../data/repository/sdk_config_repository.dart';
import '../../data/repository/wrapper_settings_repository.dart';
import '../main/main_screen.dart';

const _stepLabels = <String, String>{
  'CREATE_LOAN_CASE': 'Create loan case',
  'RECORD_AUDIO': 'Record audio',
  'CAPTURE_BUSINESS_PHOTOS': 'Capture business photos',
  'CAPTURE_FAMILY_PHOTOS': 'Capture family photos',
  'CAPTURE_COLLATERAL_PHOTOS': 'Capture collateral photos',
  'GENERATE_REPORT': 'Generate report',
};

class _StepEntry {
  final String name;
  bool enabled;
  _StepEntry({required this.name, required this.enabled});
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _configRepo = SdkConfigRepository();
  final _loanRepo = LoanCaseRepository();
  final _wrapperSettings = WrapperSettingsRepository();
  final _stepsRepo = FlowStepsRepository();

  String _userId = '';
  String _baseUrl = '';
  String _tenantId = '';

  bool _sdkToastsEnabled = true;
  bool _sdkHeaderEnabled = true;
  bool _wrapperToastsEnabled = false;

  List<_StepEntry> _stepEntries = [];

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadSettings();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    final saved = await _stepsRepo.getSteps();
    final entries = <_StepEntry>[
      for (final s in saved) _StepEntry(name: s, enabled: true),
      for (final s in FlowStepsRepository.allSteps)
        if (!saved.contains(s)) _StepEntry(name: s, enabled: false),
    ];
    if (!mounted) return;
    setState(() => _stepEntries = entries);
  }

  Future<void> _saveSteps() async {
    final steps =
        _stepEntries.where((e) => e.enabled).map((e) => e.name).toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one capture step')),
      );
      return;
    }
    await _stepsRepo.saveSteps(steps);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Flow steps saved')),
    );
  }

  Future<void> _loadSession() async {
    final creds = await _configRepo.loadCredentials();
    if (!mounted || creds == null) return;
    setState(() {
      _userId = creds.userId;
      _baseUrl = creds.baseUrl;
      _tenantId = creds.tenantId;
    });
  }

  Future<void> _loadSettings() async {
    final toasts = await _wrapperSettings.isSdkToastsEnabled();
    final header = await _wrapperSettings.isSdkHeaderEnabled();
    final wrapperToasts = await _wrapperSettings.isWrapperToastsEnabled();
    if (!mounted) return;
    setState(() {
      _sdkToastsEnabled = toasts;
      _sdkHeaderEnabled = header;
      _wrapperToastsEnabled = wrapperToasts;
    });
  }

  Future<void> _onSdkToastsChanged(bool enabled) async {
    setState(() => _sdkToastsEnabled = enabled);
    await _wrapperSettings.setSdkToastsEnabled(enabled);
    await AbleCreditSdkBridge.setSdkToastsEnabled(enabled);
  }

  Future<void> _onSdkHeaderChanged(bool enabled) async {
    setState(() => _sdkHeaderEnabled = enabled);
    await _wrapperSettings.setSdkHeaderEnabled(enabled);
    await AbleCreditSdkBridge.setShowSdkHeader(enabled);
  }

  Future<void> _onWrapperToastsChanged(bool enabled) async {
    setState(() => _wrapperToastsEnabled = enabled);
    await _wrapperSettings.setWrapperToastsEnabled(enabled);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('This will clear all SDK data and return to the login screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await AbleCreditSdkBridge.clearSdkData();
    } catch (_) {}

    await _configRepo.clearAll();
    await _loanRepo.clearAll();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader('SESSION'),
                const Divider(height: 1),
                _buildInfoRow('User ID', _userId.isEmpty ? '—' : _userId),
                const Divider(height: 1),
                _buildInfoRow('Base URL', _baseUrl.isEmpty ? '—' : _baseUrl),
                const Divider(height: 1),
                _buildInfoRow('Tenant ID', _tenantId.isEmpty ? '—' : _tenantId),
                const Divider(height: 1),
                const SizedBox(height: 24),
                _buildSectionHeader('SDK SETTINGS'),
                const Divider(height: 1),
                SwitchListTile(
                  value: _sdkToastsEnabled,
                  onChanged: _onSdkToastsChanged,
                  title: const Text('SDK result toasts'),
                  subtitle: const Text(
                    'Let the SDK show its own success/failure toasts. '
                    'AbleCredit.setSdkToastsEnabled(...)',
                    style: TextStyle(fontSize: 12, color: AppColors.gray600),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _sdkHeaderEnabled,
                  onChanged: _onSdkHeaderChanged,
                  title: const Text('Show SDK header'),
                  subtitle: const Text(
                    'Show the SDK capture screens\' own back-arrow header. '
                    'AbleCredit.setShowSdkHeader(...)',
                    style: TextStyle(fontSize: 12, color: AppColors.gray600),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _wrapperToastsEnabled,
                  onChanged: _onWrapperToastsChanged,
                  title: const Text('Wrapper result toasts'),
                  subtitle: const Text(
                    'Show this app\'s own result toasts. Keep one of '
                    'SDK/Wrapper on to avoid duplicates.',
                    style: TextStyle(fontSize: 12, color: AppColors.gray600),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 24),
                _buildSectionHeader('FLOW CONFIG'),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Enable capture steps and drag to reorder. Used by the '
                    'orchestrator flow (top to bottom).',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.gray600),
                  ),
                ),
                _buildStepsList(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: FilledButton(
                    onPressed: _saveSteps,
                    child: const Text('Save flow steps'),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('ACCOUNT'),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: OutlinedButton(
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    'AbleCredit.clearSdkData(...)',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.gray600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final entry = _stepEntries.removeAt(oldIndex);
          _stepEntries.insert(newIndex, entry);
        });
      },
      children: [
        for (int i = 0; i < _stepEntries.length; i++)
          Padding(
            key: ValueKey(_stepEntries[i].name),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _stepEntries[i].enabled,
                    title: Text(
                        _stepLabels[_stepEntries[i].name] ?? _stepEntries[i].name),
                    onChanged: (v) =>
                        setState(() => _stepEntries[i].enabled = v ?? false),
                  ),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_handle, size: 20, color: AppColors.gray400),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToolbar() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        'Profile',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppColors.gray600,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.gray600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

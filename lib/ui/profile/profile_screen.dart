import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';
import '../../data/repository/loan_case_repository.dart';
import '../../data/repository/sdk_config_repository.dart';
import '../main/main_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _configRepo = SdkConfigRepository();
  final _loanRepo = LoanCaseRepository();

  String _userId = '';
  String _baseUrl = '';
  String _tenantId = '';

  @override
  void initState() {
    super.initState();
    _loadSession();
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

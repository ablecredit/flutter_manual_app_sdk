import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';
import '../../data/model/user_sdk_configuration.dart';
import '../../data/repository/sdk_config_repository.dart';
import '../../data/repository/wrapper_settings_repository.dart';
import '../dashboard/dashboard_screen.dart';
import 'sdk_configuration_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _configRepo = SdkConfigRepository();
  final _wrapperSettings = WrapperSettingsRepository();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final initialized = await _configRepo.isSdkInitialized();
    if (!mounted) return;
    if (!initialized) {
      _setLoading(false);
      return;
    }
    final creds = await _configRepo.loadCredentials();
    if (!mounted) return;
    if (creds == null) {
      _setLoading(false);
      return;
    }
    try {
      final result = await AbleCreditSdkBridge.configure(
        sdkKey: creds.apiKey,
        tenantId: creds.tenantId,
        userId: creds.userId,
        baseUrl: creds.baseUrl,
        branchId: creds.branchId,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        await _wrapperSettings.applyToSdk();
        if (!mounted) return;
        _goToDashboard();
      } else {
        _setLoading(false);
      }
    } catch (_) {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _handleImportRequested() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final bytes = result.files.first.bytes;
    if (bytes == null || !mounted) return;

    final jsonText = utf8.decode(bytes);
    int imported = 0;
    String? errorMsg;

    try {
      final root = jsonDecode(jsonText) as Map<String, dynamic>;
      final rawList = root['configurations'];
      if (rawList == null || rawList is! List) {
        errorMsg = "Missing 'configurations' array in JSON";
      } else {
        for (int i = 0; i < rawList.length; i++) {
          final obj = rawList[i] as Map<String, dynamic>;
          final apiKey = obj['apiKey']?.toString() ?? '';
          final tenantId = obj['tenantId']?.toString() ?? '';
          final baseUrl = obj['baseUrl']?.toString() ?? '';
          final userId = obj['userId']?.toString() ?? '';
          if (apiKey.isEmpty || tenantId.isEmpty || baseUrl.isEmpty || userId.isEmpty) {
            errorMsg =
                'Configuration at index $i is missing required fields (apiKey, tenantId, baseUrl, userId)';
            break;
          }
          await _configRepo.saveConfiguration(UserSdkConfiguration(
            id: 'imported:${DateTime.now().millisecondsSinceEpoch}_$i',
            displayName: (obj['name']?.toString().isNotEmpty == true)
                ? obj['name'].toString()
                : 'Imported Config',
            apiKey: apiKey,
            tenantId: tenantId,
            baseUrl: baseUrl,
            userId: userId,
            branchId: obj['branchId']?.toString() ?? '',
          ));
          imported++;
        }
      }
    } on FormatException catch (e) {
      errorMsg = 'Invalid JSON: ${e.message}';
    } catch (e) {
      errorMsg = 'Import error: $e';
    }

    if (!mounted) return;

    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $errorMsg')));
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Imported $imported configuration(s)')));

    if (imported > 0) _openConfigurationDialog();
  }

  Future<void> _openConfigurationDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SdkConfigurationDialog(
        onImportRequested: _handleImportRequested,
        onInitialized: _onSdkInitialized,
      ),
    );
  }

  Future<void> _onSdkInitialized(Map<String, dynamic> credentials) async {
    await _configRepo.saveCredentials(
      apiKey: credentials['apiKey'] as String,
      tenantId: credentials['tenantId'] as String,
      userId: credentials['userId'] as String,
      baseUrl: credentials['baseUrl'] as String,
      branchId: credentials['branchId'] as String? ?? '',
      configId: credentials['configId'] as String? ?? '',
    );
    if (mounted) _goToDashboard();
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => _loading = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Green splash strip (~40% height)
              Expanded(
                flex: 2,
                child: ColoredBox(
                  color: AppColors.navGreen,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'ABLECREDIT\nSDK Client',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Secure client access for the AbleCredit wrapper',
                            style: TextStyle(fontSize: 14, color: AppColors.navGreenSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // White bottom area with CTA
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navGreen,
                          foregroundColor: AppColors.white,
                        ),
                        onPressed: _loading ? null : _openConfigurationDialog,
                        child: const Text('Get started'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            const ColoredBox(
              color: Color(0x992E7D32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.white),
                    SizedBox(height: 16),
                    Text(
                      'Initializing SDK…',
                      style: TextStyle(fontSize: 14, color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

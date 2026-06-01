import 'package:flutter/material.dart';

import '../../ablecredit-bridge.dart';
import '../../app_theme.dart';
import '../../data/model/user_sdk_configuration.dart';
import '../../data/repository/sdk_config_repository.dart';

class SdkConfigurationDialog extends StatefulWidget {
  const SdkConfigurationDialog({
    super.key,
    this.onImportRequested,
    required this.onInitialized,
  });

  final VoidCallback? onImportRequested;
  final void Function(Map<String, dynamic> credentials) onInitialized;

  @override
  State<SdkConfigurationDialog> createState() => _SdkConfigurationDialogState();
}

class _SdkConfigurationDialogState extends State<SdkConfigurationDialog> {
  final _repo = SdkConfigRepository();

  final _apiKey = TextEditingController();
  final _tenantId = TextEditingController();
  final _userId = TextEditingController();
  final _baseUrl = TextEditingController();
  final _branchId = TextEditingController();

  List<UserSdkConfiguration> _configs = [];
  String? _selectedConfigId;
  bool _isInitializing = false;


  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await _repo.loadConfigurations();
    if (!mounted) return;
    setState(() {
      _configs = configs;
      if (configs.isNotEmpty && _selectedConfigId == null) {
        _selectConfig(configs.first.id);
      }
    });
  }

  void _selectConfig(String id) {
    final cfg = _configs.firstWhere((c) => c.id == id);
    setState(() {
      _selectedConfigId = id;
      _apiKey.text = cfg.apiKey;
      _tenantId.text = cfg.tenantId;
      _userId.text = cfg.userId;
      _baseUrl.text = cfg.baseUrl;
      _branchId.text = cfg.branchId;
    });
  }

  Future<void> _saveCurrentConfig() async {
    if (_selectedConfigId == null) return;
    final cfg = _configs.firstWhere((c) => c.id == _selectedConfigId);
    final updated = cfg.copyWith(
      apiKey: _apiKey.text.trim(),
      tenantId: _tenantId.text.trim(),
      userId: _userId.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      branchId: _branchId.text.trim(),
    );
    await _repo.saveConfiguration(updated);
    if (!mounted) return;
    setState(() {
      final idx = _configs.indexWhere((c) => c.id == _selectedConfigId);
      if (idx >= 0) _configs[idx] = updated;
    });
  }

  Future<void> _createNewConfig() async {
    final name = await _showNameDialog();
    if (name == null || name.trim().isEmpty || !mounted) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final cfg = UserSdkConfiguration(
      id: id,
      displayName: name.trim(),
      apiKey: '',
      tenantId: '',
      baseUrl: '',
      userId: '',
    );
    await _repo.saveConfiguration(cfg);
    await _loadConfigs();
    if (!mounted) return;
    _selectConfig(id);
  }

  Future<void> _deleteCurrentConfig() async {
    if (_selectedConfigId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete configuration'),
        content: const Text('Are you sure you want to delete this configuration?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _repo.deleteConfiguration(_selectedConfigId!);
    await _loadConfigs();
    if (!mounted) return;
    setState(() {
      _selectedConfigId = _configs.isNotEmpty ? _configs.first.id : null;
      if (_selectedConfigId != null) {
        _selectConfig(_selectedConfigId!);
      } else {
        _apiKey.clear();
        _tenantId.clear();
        _userId.clear();
        _baseUrl.clear();
        _branchId.clear();
      }
    });
  }

  Future<String?> _showNameDialog({String? initial}) async {
    String value = initial ?? '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Configuration name'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter name'),
            textInputAction: TextInputAction.done,
            onChanged: (v) => value = v,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, value),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _requestImport() {
    Navigator.of(context).pop();
    widget.onImportRequested?.call();
  }

  Future<void> _initialize() async {
    if (_isInitializing) return;

    final apiKey = _apiKey.text.trim();
    final tenantId = _tenantId.text.trim();
    final userId = _userId.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final branchId = _branchId.text.trim();

    if (apiKey.isEmpty || tenantId.isEmpty || userId.isEmpty || baseUrl.isEmpty || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key, tenant ID, user ID, base URL, and branch ID are required')),
      );
      return;
    }
    setState(() {
      _isInitializing = true;
    });
    // Ensure at least one rendered frame so loader is visible before native configure starts.
    await WidgetsBinding.instance.endOfFrame;
    final loadingStartedAt = DateTime.now();

    try {
      final sdkResult = await AbleCreditSdkBridge.configure(
        apiKey: apiKey,
        tenantId: tenantId,
        userId: userId,
        baseUrl: baseUrl,
        branchId: branchId,
      );
      final elapsed = DateTime.now().difference(loadingStartedAt);
      const minLoaderDuration = Duration(seconds: 2);
      if (elapsed < minLoaderDuration) {
        await Future<void>.delayed(minLoaderDuration - elapsed);
      }
      if (!mounted) return;

      if (sdkResult['success'] == true) {
        Navigator.of(context).pop(); // dismiss config dialog
        widget.onInitialized({
          'apiKey': apiKey,
          'tenantId': tenantId,
          'userId': userId,
          'baseUrl': baseUrl,
          'branchId': branchId,
          'configId': _selectedConfigId ?? '',
        });
      } else {
        final msg = sdkResult['message']?.toString() ?? 'Initialization failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(loadingStartedAt);
      const minLoaderDuration = Duration(seconds: 2);
      if (elapsed < minLoaderDuration) {
        await Future<void>.delayed(minLoaderDuration - elapsed);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _tenantId.dispose();
    _userId.dispose();
    _baseUrl.dispose();
    _branchId.dispose();
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConfigSelector(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('CREDENTIALS'),
                  const SizedBox(height: 12),
                  _buildField(_apiKey, 'API Key *'),
                  const SizedBox(height: 12),
                  _buildField(_tenantId, 'Tenant ID *'),
                  const SizedBox(height: 12),
                  _buildField(_userId, 'User ID *'),
                  const SizedBox(height: 12),
                  _buildField(_baseUrl, 'Base URL *'),
                  const SizedBox(height: 12),
                  _buildField(_branchId, 'Branch ID *'),
                  const SizedBox(height: 4),
                  Text(
                    'AbleCredit.configure(...)',
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
              onPressed: _isInitializing ? null : _initialize,
              child: _isInitializing
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Initializing...'),
                      ],
                    )
                  : const Text('Initialize'),
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
              'SDK Configuration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: (!_isInitializing && widget.onImportRequested != null) ? _requestImport : null,
            tooltip: 'Import from JSON',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isInitializing ? null : () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionLabel('CONFIGURATION'),
        const SizedBox(height: 8),
        if (_configs.isEmpty)
          OutlinedButton(
            onPressed: _createNewConfig,
            child: const Text('+ New configuration'),
          )
        else
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedConfigId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _configs
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName)))
                      .toList(),
                  onChanged: (id) {
                    if (id != null) {
                      _saveCurrentConfig().then((_) {
                        if (mounted) _selectConfig(id);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createNewConfig,
                tooltip: 'New configuration',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _configs.length <= 1 ? null : _deleteCurrentConfig,
                tooltip: 'Delete configuration',
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      textInputAction: TextInputAction.next,
    );
  }
}

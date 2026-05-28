import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'ablecredit-bridge.dart';
import 'sdk_local_store.dart';

const _defaultLoanPayloadJson = '''
{
  "loan_reference": "LN-REF-20260430-9012",
  "client_unique_id": "CUST-20260430-9012",
  "product_id": "MUT-IND-3065",
  "branch_id": "ML1348",
  "source_system": "",
  "user_name": "Field Agent",
  "branch_name": "Bangalore Central",
  "business_profile": {
    "product": "LAP",
    "business_model": "Trading",
    "industry": "Fashion Apparel"
  },
  "data": {
    "borrower_details": {
      "state_name": "karnataka",
      "entity_type": "individual",
      "name": "Shwetanka Srivastava",
      "dob": "24/01/1988",
      "mobile": "8197837043",
      "owner_of_business": "Yes"
    },
    "employment_details": {
      "nature_of_employment": "Full-Time"
    },
    "loan_details": {
      "business_name": "trends",
      "quantum": "500000",
      "tenure": "24"
    }
  }
}
''';

/// Single-screen harness for every AbleCredit MethodChannel operation.
class SdkConsoleScreen extends StatefulWidget {
  const SdkConsoleScreen({super.key});

  @override
  State<SdkConsoleScreen> createState() => _SdkConsoleScreenState();
}

class _SdkConsoleScreenState extends State<SdkConsoleScreen> {
  final _apiKey = TextEditingController();
  final _tenantId = TextEditingController();
  final _userId = TextEditingController();
  final _baseUrl = TextEditingController();
  final _loanReference = TextEditingController();
  final _loanApplicationId = TextEditingController();
  final _loanPayloadJson = TextEditingController(text: _defaultLoanPayloadJson.trim());

  final _logLines = <String>[];
  final _scroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _audioSub;

  /// Count of persisted application IDs (after create-loan successes).
  int _savedApplicationIdCount = 0;

  @override
  void initState() {
    super.initState();
    _restorePrefs();
    _audioSub = AbleCreditSdkBridge.audioUploadStatusStream.listen((event) {
      _appendLog('[audioUpload] ${jsonEncode(event)}');
    });
  }

  Future<void> _restorePrefs() async {
    final cfg = await SdkLocalStore.loadConfigureKeys();
    final ids = await SdkLocalStore.loadApplicationIds();
    if (!mounted) return;
    if (cfg != null) {
      _apiKey.text = cfg.apiKey;
      _tenantId.text = cfg.tenantId;
      _userId.text = cfg.userId;
      _baseUrl.text = cfg.baseUrl;
    }
    setState(() => _savedApplicationIdCount = ids.length);
  }

  Future<void> _refreshSavedIdCount() async {
    final n = (await SdkLocalStore.loadApplicationIds()).length;
    if (mounted) setState(() => _savedApplicationIdCount = n);
  }

  /// Reads [applicationId] from the channel map or nested [data].
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
    _audioSub?.cancel();
    _apiKey.dispose();
    _tenantId.dispose();
    _userId.dispose();
    _baseUrl.dispose();
    _loanReference.dispose();
    _loanApplicationId.dispose();
    _loanPayloadJson.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _appendLog(String line) {
    if (!mounted) return;
    setState(() {
      _logLines.add('${DateTime.now().toIso8601String()}  $line');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      _appendLog('ERROR $label: $e\n$st');
    }
  }

  Future<void> _configure() async {
    final apiKey = _apiKey.text.trim();
    final tenantId = _tenantId.text.trim();
    final userId = _userId.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final map = await AbleCreditSdkBridge.configure(
      apiKey: apiKey,
      tenantId: tenantId,
      userId: userId,
      baseUrl: baseUrl,
    );
    _appendLog('configure → ${jsonEncode(map)}');
    if (map['success'] == true) {
      await SdkLocalStore.saveConfigureKeys(
        apiKey: apiKey,
        tenantId: tenantId,
        userId: userId,
        baseUrl: baseUrl,
      );
      _appendLog('configure keys saved locally until clearSdkData');
    }
  }

  Future<void> _createLoan() async {
    late final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(_loanPayloadJson.text.isEmpty ? '{}' : _loanPayloadJson.text);
      payload = Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      _appendLog('createNewLoanCase: invalid JSON — $e');
      return;
    }
    final response = await AbleCreditSdkBridge.createNewLoanCase(payload);
    if (response['success'] == true) {
      _appendLog('Loan case created');
      debugPrint('Loan case created');
      final appId = _extractApplicationId(response);
      if (appId != null) {
        await SdkLocalStore.rememberApplicationId(appId);
        await _refreshSavedIdCount();
        _loanApplicationId.text = appId;
        _appendLog('applicationId saved locally: $appId');
      } else {
        _appendLog('createNewLoanCase: no applicationId in response — not saved locally');
      }
    } else {
      final msg = '${response['message']} (${response['code']})';
      _appendLog('createNewLoanCase error: $msg');
      debugPrint('Error: $msg');
    }
    _appendLog('createNewLoanCase raw → ${jsonEncode(response)}');
  }

  /// Dropdown of persisted IDs (+ manual field). Survives app restart via [SdkLocalStore].
  Future<String?> _pickApplicationId({required String title, required String confirmLabel}) async {
    final ids = await SdkLocalStore.loadApplicationIds();
    final screenFallback = _loanApplicationId.text.trim();

    String? dropdownValue;
    if (ids.isNotEmpty) {
      dropdownValue = ids.contains(screenFallback) ? screenFallback : ids.first;
    }

    final manualCtrl = TextEditingController(text: dropdownValue ?? screenFallback);

    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDlg) {
              return AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ids.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: dropdownValue,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Saved application IDs'),
                          items: [
                            for (final id in ids)
                              DropdownMenuItem(
                                value: id,
                                child: Text(id, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) {
                            setDlg(() {
                              dropdownValue = v;
                              manualCtrl.text = v ?? '';
                            });
                          },
                        ),
                      if (ids.isEmpty)
                        const Text(
                          'No saved application IDs yet. Create a loan case first, or enter an ID manually.',
                          style: TextStyle(fontSize: 13),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: manualCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Application ID',
                          hintText: 'Type or choose from list above',
                        ),
                        autofocus: ids.isEmpty,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {},
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      final typed = manualCtrl.text.trim();
                      final picked = typed.isNotEmpty ? typed : (dropdownValue ?? '');
                      Navigator.pop(ctx, picked.isEmpty ? null : picked);
                    },
                    child: Text(confirmLabel),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      manualCtrl.dispose();
    }
  }

  Future<void> _fetchLoan() async {
    final map = await AbleCreditSdkBridge.fetchLoanDetails(_loanReference.text.trim());
    _appendLog('fetchLoanDetails → ${jsonEncode(map)}');
  }

  Future<void> _requestReport() async {
    final map = await AbleCreditSdkBridge.requestReportGeneration(_loanApplicationId.text.trim());
    _appendLog('requestReportGeneration → ${jsonEncode(map)}');
  }

  Future<void> _viewLoans() async {
    final map = await AbleCreditSdkBridge.viewLoanApplications();
    _appendLog('viewLoanApplications → ${jsonEncode(map)}');
  }

  Future<void> _clearSdk() async {
    final map = await AbleCreditSdkBridge.clearSdkData();
    _appendLog('clearSdkData → ${jsonEncode(map)}');
    if (map['success'] == true) {
      await SdkLocalStore.clearAllAfterSdkClear();
      _apiKey.clear();
      _tenantId.clear();
      _userId.clear();
      _baseUrl.clear();
      await _refreshSavedIdCount();
      _appendLog('Local configure keys and saved application IDs cleared');
    }
  }

  Future<void> _recordAudio() async {
    final id = await _pickApplicationId(title: 'Record audio', confirmLabel: 'Record');
    if (!mounted) return;
    if (id == null) {
      _appendLog('recordAudio cancelled');
      return;
    }
    if (id.isEmpty) {
      _appendLog('recordAudio: loan application id is required');
      return;
    }
    final map = await AbleCreditSdkBridge.recordAudio(loanApplicationId: id);
    _appendLog('recordAudio → ${jsonEncode(map)}');
  }

  Future<void> _captureFamily() async {
    final id = await _pickApplicationId(title: 'Capture family photos', confirmLabel: 'Open');
    if (!mounted || id == null) {
      if (mounted) _appendLog('captureFamilyPhotos cancelled');
      return;
    }
    if (id.isEmpty) {
      _appendLog('captureFamilyPhotos: application id is required');
      return;
    }
    final map = await AbleCreditSdkBridge.captureFamilyPhotos(loanApplicationId: id);
    _appendLog('captureFamilyPhotos → ${jsonEncode(map)}');
  }

  Future<void> _captureBusiness() async {
    final id = await _pickApplicationId(title: 'Capture business photos', confirmLabel: 'Open');
    if (!mounted || id == null) {
      if (mounted) _appendLog('captureBusinessPhotos cancelled');
      return;
    }
    if (id.isEmpty) {
      _appendLog('captureBusinessPhotos: application id is required');
      return;
    }
    final map = await AbleCreditSdkBridge.captureBusinessPhotos(loanApplicationId: id);
    _appendLog('captureBusinessPhotos → ${jsonEncode(map)}');
  }

  Future<void> _captureCollateral() async {
    final id = await _pickApplicationId(title: 'Capture collateral photos', confirmLabel: 'Open');
    if (!mounted || id == null) {
      if (mounted) _appendLog('captureCollateralPhotos cancelled');
      return;
    }
    if (id.isEmpty) {
      _appendLog('captureCollateralPhotos: application id is required');
      return;
    }
    final map = await AbleCreditSdkBridge.captureCollateralPhotos(loanApplicationId: id);
    _appendLog('captureCollateralPhotos → ${jsonEncode(map)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AbleCredit SDK')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Configure', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _apiKey, decoration: const InputDecoration(labelText: 'apiKey')),
                TextField(controller: _tenantId, decoration: const InputDecoration(labelText: 'tenantId')),
                TextField(controller: _userId, decoration: const InputDecoration(labelText: 'userId')),
                TextField(controller: _baseUrl, decoration: const InputDecoration(labelText: 'baseUrl')),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => _run('configure', _configure), child: const Text('configure')),
                Text(
                  'Saved configure keys persist until clearSdkData. Saved application IDs: $_savedApplicationIdCount',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 32),
                const Text('Loan application id (e.g. after create-loan)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _loanApplicationId, decoration: const InputDecoration(labelText: 'loanApplicationId')),
                const Divider(height: 32),
                const Text('Loans', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _loanReference, decoration: const InputDecoration(labelText: 'loanReference (fetch)')),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => _run('createNewLoanCase', _createLoan), child: const Text('createNewLoanCase')),
                const SizedBox(height: 8),
                TextField(
                  controller: _loanPayloadJson,
                  decoration: const InputDecoration(labelText: 'createNewLoanCase JSON payload', alignLabelWithHint: true),
                  maxLines: 4,
                  minLines: 2,
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => _run('fetchLoanDetails', _fetchLoan), child: const Text('fetchLoanDetails')),
                FilledButton(onPressed: () => _run('requestReportGeneration', _requestReport), child: const Text('requestReportGeneration')),
                const Divider(height: 32),
                const Text('Capture & audio (dialog: dropdown of saved IDs + manual)', style: TextStyle(fontWeight: FontWeight.bold)),
                FilledButton.tonal(
                  onPressed: () => _run('recordAudio', _recordAudio),
                  child: const Text('recordAudio'),
                ),
                FilledButton.tonal(onPressed: () => _run('captureFamilyPhotos', _captureFamily), child: const Text('captureFamilyPhotos')),
                FilledButton.tonal(onPressed: () => _run('captureBusinessPhotos', _captureBusiness), child: const Text('captureBusinessPhotos')),
                FilledButton.tonal(onPressed: () => _run('captureCollateralPhotos', _captureCollateral), child: const Text('captureCollateralPhotos')),
                const Divider(height: 32),
                const Text('Other', style: TextStyle(fontWeight: FontWeight.bold)),
                FilledButton(onPressed: () => _run('viewLoanApplications', _viewLoans), child: const Text('viewLoanApplications')),
                FilledButton(onPressed: () => _run('clearSdkData', _clearSdk), child: const Text('clearSdkData')),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 160,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(8),
                itemCount: _logLines.length,
                itemBuilder: (context, i) => SelectableText(_logLines[i], style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

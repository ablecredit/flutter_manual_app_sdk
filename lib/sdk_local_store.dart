import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists configure fields until [clearConfigureKeys]. Application IDs persist
/// until [clearApplicationIds] (called after successful [clearSdkData] in the demo app).
class SdkLocalStore {
  static const _apiKey = 'ac_configure_api_key';
  static const _tenantId = 'ac_configure_tenant_id';
  static const _userId = 'ac_configure_user_id';
  static const _baseUrl = 'ac_configure_base_url';
  static const _applicationIdsJson = 'ac_application_ids_json';

  static Future<void> saveConfigureKeys({
    required String apiKey,
    required String tenantId,
    required String userId,
    required String baseUrl,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_apiKey, apiKey);
    await p.setString(_tenantId, tenantId);
    await p.setString(_userId, userId);
    await p.setString(_baseUrl, baseUrl);
  }

  static Future<({String apiKey, String tenantId, String userId, String baseUrl})?> loadConfigureKeys() async {
    final p = await SharedPreferences.getInstance();
    final key = p.getString(_apiKey);
    if (key == null) return null;
    return (
      apiKey: key,
      tenantId: p.getString(_tenantId) ?? '',
      userId: p.getString(_userId) ?? '',
      baseUrl: p.getString(_baseUrl) ?? '',
    );
  }

  /// Clears saved configure keys only.
  static Future<void> clearConfigureKeys() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_apiKey);
    await p.remove(_tenantId);
    await p.remove(_userId);
    await p.remove(_baseUrl);
  }

  static Future<List<String>> loadApplicationIds() async {
    final p = await SharedPreferences.getInstance();
    return _decodeIdList(p.getString(_applicationIdsJson));
  }

  static Future<void> rememberApplicationId(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = _decodeIdList(p.getString(_applicationIdsJson));
    list.removeWhere((e) => e == trimmed);
    list.insert(0, trimmed);
    await p.setString(_applicationIdsJson, jsonEncode(list));
  }

  static Future<void> clearApplicationIds() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_applicationIdsJson);
  }

  /// After native SDK clear: wipe local configure + remembered application IDs.
  static Future<void> clearAllAfterSdkClear() async {
    await clearConfigureKeys();
    await clearApplicationIds();
  }

  static List<String> _decodeIdList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/user_sdk_configuration.dart';

class SdkConfigRepository {
  static const _keyInitialized = 'sdk_initialized';
  static const _keyApiKey = 'api_key';
  static const _keyTenantId = 'tenant_id';
  static const _keyUserId = 'user_id';
  static const _keyBaseUrl = 'base_url';
  static const _keyBranchId = 'branch_id';
  static const _keyConfigTags = 'config_tags';
  static const _keyUserConfigs = 'user_configs_json';
  static const _keyFiltersEnabled = 'filters_enabled';

  Future<bool> isSdkInitialized() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyInitialized) ?? false;
  }

  Future<void> saveCredentials({
    required String apiKey,
    required String tenantId,
    required String userId,
    required String baseUrl,
    String branchId = '',
    String configId = '',
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyInitialized, true);
    await p.setString(_keyApiKey, apiKey);
    await p.setString(_keyTenantId, tenantId);
    await p.setString(_keyUserId, userId);
    await p.setString(_keyBaseUrl, baseUrl);
    await p.setString(_keyBranchId, branchId);
    if (configId.isNotEmpty) await p.setString(_keyConfigTags, configId);
  }

  Future<
      ({
        String apiKey,
        String tenantId,
        String userId,
        String baseUrl,
        String branchId,
      })?> loadCredentials() async {
    final p = await SharedPreferences.getInstance();
    final key = p.getString(_keyApiKey);
    if (key == null || key.isEmpty) return null;
    return (
      apiKey: key,
      tenantId: p.getString(_keyTenantId) ?? '',
      userId: p.getString(_keyUserId) ?? '',
      baseUrl: p.getString(_keyBaseUrl) ?? '',
      branchId: p.getString(_keyBranchId) ?? '',
    );
  }

  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyInitialized);
    await p.remove(_keyApiKey);
    await p.remove(_keyTenantId);
    await p.remove(_keyUserId);
    await p.remove(_keyBaseUrl);
    await p.remove(_keyBranchId);
    await p.remove(_keyConfigTags);
  }

  Future<List<UserSdkConfiguration>> loadConfigurations() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyUserConfigs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UserSdkConfiguration.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConfiguration(UserSdkConfiguration config) async {
    final configs = await loadConfigurations();
    final idx = configs.indexWhere((c) => c.id == config.id);
    if (idx >= 0) {
      configs[idx] = config;
    } else {
      configs.add(config);
    }
    await _persistConfigurations(configs);
  }

  Future<void> deleteConfiguration(String id) async {
    final configs = await loadConfigurations();
    configs.removeWhere((c) => c.id == id);
    await _persistConfigurations(configs);
  }

  Future<void> _persistConfigurations(List<UserSdkConfiguration> configs) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyUserConfigs, jsonEncode(configs.map((c) => c.toJson()).toList()));
  }

  Future<bool> getFiltersEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyFiltersEnabled) ?? false;
  }

  Future<void> setFiltersEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyFiltersEnabled, value);
  }
}

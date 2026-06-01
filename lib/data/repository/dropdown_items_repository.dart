import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DropdownItemsRepository {
  static const _keyProducts = 'dropdown_products';
  static const _keyBusinessModels = 'dropdown_business_models';

  static const _defaultProducts = ['LAP', 'Unsecured'];
  static const _defaultBusinessModels = [
    'Trading',
    'Manufacturing',
    'Service',
    'Agri',
    'Job Work',
    'Daily Wages',
    'Salaried',
  ];

  Future<List<String>> loadProducts() async {
    return _load(_keyProducts, _defaultProducts);
  }

  Future<List<String>> loadBusinessModels() async {
    return _load(_keyBusinessModels, _defaultBusinessModels);
  }

  Future<void> addProduct(String value) async {
    await _addItem(_keyProducts, _defaultProducts, value);
  }

  Future<void> addBusinessModel(String value) async {
    await _addItem(_keyBusinessModels, _defaultBusinessModels, value);
  }

  Future<List<String>> _load(String key, List<String> defaults) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return List.from(defaults);
    try {
      final list = (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
      final merged = [...defaults];
      for (final item in list) {
        if (!merged.any((d) => d.toLowerCase() == item.toLowerCase())) {
          merged.add(item);
        }
      }
      return merged;
    } catch (_) {
      return List.from(defaults);
    }
  }

  Future<void> _addItem(String key, List<String> defaults, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final current = await _load(key, defaults);
    if (current.any((e) => e.toLowerCase() == trimmed.toLowerCase())) return;
    final customItems = current.where((e) => !defaults.contains(e)).toList();
    customItems.add(trimmed);
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(customItems));
  }
}

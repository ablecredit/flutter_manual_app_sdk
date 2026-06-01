import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/loan_case_item.dart';

class LoanCaseRepository {
  static const _key = 'loan_cases_json';

  Future<List<LoanCaseItem>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map((e) => LoanCaseItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(LoanCaseItem item) async {
    final items = await loadAll();
    items.removeWhere((i) => i.applicationId == item.applicationId);
    items.insert(0, item);
    await _persist(items);
  }

  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  Future<void> _persist(List<LoanCaseItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(items.map((i) => i.toJson()).toList()));
  }
}

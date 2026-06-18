import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FlowStepsRepository {
  static const _key = 'flow_steps_json';

  static const defaultSteps = [
    'RECORD_AUDIO',
    'CAPTURE_BUSINESS_PHOTOS',
    'CAPTURE_FAMILY_PHOTOS',
    'CAPTURE_COLLATERAL_PHOTOS',
    'CREATE_LOAN_CASE',
  ];

  static const allSteps = [
    'CREATE_LOAN_CASE',
    'RECORD_AUDIO',
    'CAPTURE_BUSINESS_PHOTOS',
    'CAPTURE_FAMILY_PHOTOS',
    'CAPTURE_COLLATERAL_PHOTOS',
    'GENERATE_REPORT',
  ];

  Future<List<String>> getSteps() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return List.from(defaultSteps);
    try {
      final list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      return list.isEmpty ? List.from(defaultSteps) : list;
    } catch (_) {
      return List.from(defaultSteps);
    }
  }

  Future<void> saveSteps(List<String> steps) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(steps));
  }

  static String labelForStep(String step) {
    switch (step) {
      case 'CREATE_LOAN_CASE':
        return 'Create loan case';
      case 'RECORD_AUDIO':
        return 'Record audio';
      case 'CAPTURE_BUSINESS_PHOTOS':
        return 'Capture business photos';
      case 'CAPTURE_FAMILY_PHOTOS':
        return 'Capture family photos';
      case 'CAPTURE_COLLATERAL_PHOTOS':
        return 'Capture collateral photos';
      case 'GENERATE_REPORT':
        return 'Generate report';
      default:
        return step;
    }
  }
}

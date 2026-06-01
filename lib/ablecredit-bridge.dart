// lib/ablecredit_sdk_bridge.dart
import 'package:flutter/services.dart';

class AbleCreditSdkBridge {
  static const MethodChannel _channel = MethodChannel('ablecredit/wrapper_sdk');
  static const EventChannel _audioUploadStatusChannel = EventChannel('ablecredit/audio_upload_status');

  static Future<Map<String, dynamic>> configure({
    required String apiKey,
    required String tenantId,
    required String userId,
    required String baseUrl,
    String branchId = '',
  }) async {
    final args = <String, dynamic>{
      'apiKey': apiKey,
      'tenantId': tenantId,
      'userId': userId,
      'baseUrl': baseUrl,
    };
    if (branchId.trim().isNotEmpty) args['branchId'] = branchId.trim();
    final dynamic res = await _channel.invokeMethod('configure', args);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> createNewLoanCase(Map<String, dynamic> payload) async {
    final dynamic res = await _channel.invokeMethod('createNewLoanCase', {
      'payload': payload,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> fetchLoanDetails(String loanReference) async {
    final dynamic res = await _channel.invokeMethod('fetchLoanDetails', {
      'loanReference': loanReference,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> requestReportGeneration(String loanApplicationId) async {
    final dynamic res = await _channel.invokeMethod('requestReportGeneration', {
      'loanApplicationId': loanApplicationId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> viewLoanApplications() async {
    final dynamic res = await _channel.invokeMethod('viewLoanApplications');
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> clearSdkData() async {
    final dynamic res = await _channel.invokeMethod('clearSdkData');
    return Map<String, dynamic>.from(res as Map);
  }

  /// [loanApplicationId] omitted or null lets the native side receive no id (same as empty).
  static Future<Map<String, dynamic>> recordAudio({String? loanApplicationId}) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    final dynamic res = await _channel.invokeMethod('recordAudio', args);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> captureFamilyPhotos({String? loanApplicationId}) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    final dynamic res = await _channel.invokeMethod('captureFamilyPhotos', args);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> captureBusinessPhotos({String? loanApplicationId}) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    final dynamic res = await _channel.invokeMethod('captureBusinessPhotos', args);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> captureCollateralPhotos({String? loanApplicationId}) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    final dynamic res = await _channel.invokeMethod('captureCollateralPhotos', args);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Emits upload status events for all media types.
  /// Each event contains: `type` (audio|family_photos|business_photos|collateral_photos),
  /// `uniqueId`, `status` (AbleCreditFileStatus name), `message`.
  static Stream<Map<String, dynamic>> get fileUploadStatusStream {
    return _audioUploadStatusChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
    );
  }

  @Deprecated('Use fileUploadStatusStream')
  static Stream<Map<String, dynamic>> get audioUploadStatusStream => fileUploadStatusStream;
}
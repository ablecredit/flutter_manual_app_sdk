// lib/ablecredit_sdk_bridge.dart
import 'package:flutter/services.dart';

class AbleCreditSdkBridge {
  static const MethodChannel _channel = MethodChannel('ablecredit/wrapper_sdk');
  static const EventChannel _audioUploadStatusChannel = EventChannel('ablecredit/audio_upload_status');

  static Future<Map<String, dynamic>> configure({
    required String sdkKey,
    required String tenantId,
    required String userId,
    required String baseUrl,
    String branchId = '',
  }) async {
    final args = <String, dynamic>{
      'sdkKey': sdkKey,
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

  static Future<Map<String, dynamic>> getLoanById(String applicationId) async {
    final dynamic res = await _channel.invokeMethod('getLoanById', {
      'applicationId': applicationId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> getLoanByReference(String loanReference) async {
    final dynamic res = await _channel.invokeMethod('getLoanByReference', {
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

  /// [loanApplicationId] is the server-generated `_id` (loan reference) returned by createNewLoanCase.
  /// Omitted or null lets the native side receive no id (so the SDK rejects the call) — useful for
  /// testing the SDK's own validation.
  /// [nextStep] is the method name of the next capture step (e.g. 'captureBusinessPhotos').
  /// When provided, the native side renders a docked button inside the SDK screen that
  /// launches the next step directly — matching AbleCreditDockedButton chaining in the
  /// Kotlin client. [nextStepLabel] is the human-readable label shown on the button.
  /// [nextStep] method name of the next capture step (e.g. 'captureBusinessPhotos').
  /// [nextStepLabel] human-readable label shown on the docked button.
  /// [transition] either 'direct' (button launches next SDK screen) or
  /// 'clientScreen' (button triggers Flutter to push MockClientScreen first).
  static Future<Map<String, dynamic>> recordAudio({
    String? loanApplicationId,
    String? nextStep,
    String? nextStepLabel,
    String? transition,
  }) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    if (nextStep != null) args['nextStep'] = nextStep;
    if (nextStepLabel != null) args['nextStepLabel'] = nextStepLabel;
    if (transition != null) args['transition'] = transition;
    final dynamic res = await _channel.invokeMethod('recordAudio', args);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> captureFamilyPhotos({
    String? loanApplicationId,
    String? nextStep,
    String? nextStepLabel,
    String? transition,
  }) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    if (nextStep != null) args['nextStep'] = nextStep;
    if (nextStepLabel != null) args['nextStepLabel'] = nextStepLabel;
    if (transition != null) args['transition'] = transition;
    final dynamic res = await _channel.invokeMethod('captureFamilyPhotos', args);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> captureBusinessPhotos({
    String? loanApplicationId,
    String? nextStep,
    String? nextStepLabel,
    String? transition,
  }) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    if (nextStep != null) args['nextStep'] = nextStep;
    if (nextStepLabel != null) args['nextStepLabel'] = nextStepLabel;
    if (transition != null) args['transition'] = transition;
    final dynamic res = await _channel.invokeMethod('captureBusinessPhotos', args);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> captureCollateralPhotos({
    String? loanApplicationId,
    String? nextStep,
    String? nextStepLabel,
    String? transition,
  }) async {
    final args = <String, dynamic>{};
    final id = loanApplicationId?.trim();
    if (id != null && id.isNotEmpty) args['loanApplicationId'] = id;
    if (nextStep != null) args['nextStep'] = nextStep;
    if (nextStepLabel != null) args['nextStepLabel'] = nextStepLabel;
    if (transition != null) args['transition'] = transition;
    final dynamic res = await _channel.invokeMethod('captureCollateralPhotos', args);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Starts the orchestrator loan flow: runs the given capture [steps] in order.
  /// [steps] are AbleCreditFlowStep enum names (RECORD_AUDIO, CAPTURE_BUSINESS_PHOTOS,
  /// CAPTURE_FAMILY_PHOTOS, CAPTURE_COLLATERAL_PHOTOS).
  /// When [useExistingLoan] is true, [existingLoanApplicationId] is required; otherwise [payload]
  /// is used to create a new loan.
  static Future<Map<String, dynamic>> startLoanFlow({
    required List<String> steps,
    required bool useExistingLoan,
    String? existingLoanApplicationId,
    Map<String, dynamic>? payload,
  }) async {
    final args = <String, dynamic>{
      'steps': steps,
      'useExistingLoan': useExistingLoan,
    };
    final ref = existingLoanApplicationId?.trim();
    if (ref != null && ref.isNotEmpty) args['existingLoanApplicationId'] = ref;
    if (payload != null) args['payload'] = payload;
    final dynamic res = await _channel.invokeMethod('startLoanFlow', args);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Controls whether the SDK capture screens show their own header row (back arrow + title).
  /// Default on the SDK side is true. Set to false if the host app provides its own toolbar.
  static Future<void> setShowSdkHeader(bool show) async {
    await _channel.invokeMethod('setShowSdkHeader', {'show': show});
  }

  /// Controls whether the SDK shows its own operation result toasts. Default on the SDK side
  /// is true. Set to false if the host app shows its own result UI.
  static Future<void> setSdkToastsEnabled(bool enabled) async {
    await _channel.invokeMethod('setSdkToastsEnabled', {'enabled': enabled});
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
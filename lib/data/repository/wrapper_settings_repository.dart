import 'package:shared_preferences/shared_preferences.dart';

import '../../ablecredit-bridge.dart';

/// Persists wrapper-controlled SDK behaviour toggles. The SDK's own flags
/// (setShowSdkHeader / setSdkToastsEnabled) are in-memory and reset on app
/// restart, so we persist the chosen values here and re-apply them on launch.
/// Mirrors the Kotlin sample's WrapperSettingsRepository.
class WrapperSettingsRepository {
  static const _keySdkToasts = 'sdk_toasts_enabled';
  static const _keySdkHeader = 'sdk_header_enabled';
  static const _keyWrapperToasts = 'wrapper_toasts_enabled';

  /// Whether THIS app shows its own result toasts/snackbars (separate from the SDK's).
  /// Defaults to false so SDK + wrapper toasts don't double up out of the box.
  Future<bool> isWrapperToastsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyWrapperToasts) ?? false;
  }

  Future<void> setWrapperToastsEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyWrapperToasts, enabled);
  }

  /// Whether the SDK shows its own result toasts. Defaults to true (SDK default).
  Future<bool> isSdkToastsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySdkToasts) ?? true;
  }

  Future<void> setSdkToastsEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySdkToasts, enabled);
  }

  /// Whether the SDK shows its own in-screen header. Defaults to true (SDK default).
  Future<bool> isSdkHeaderEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySdkHeader) ?? true;
  }

  Future<void> setSdkHeaderEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySdkHeader, enabled);
  }

  /// Re-applies the persisted toggles to the SDK. Call this after every successful
  /// configure, since the SDK flags are in-memory and reset on app restart.
  Future<void> applyToSdk() async {
    await AbleCreditSdkBridge.setSdkToastsEnabled(await isSdkToastsEnabled());
    await AbleCreditSdkBridge.setShowSdkHeader(await isSdkHeaderEnabled());
  }
}

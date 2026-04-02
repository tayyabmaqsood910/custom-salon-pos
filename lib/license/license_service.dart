import 'dart:async';
import 'dart:io' show SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'license_models.dart';

class LicenseService {
  static const supportContact = '+92-313-6625199';

  static const _kShopId = 'license_shop_id';
  static const _kActivationKey = 'license_activation_key';
  static const _kExpiryDate = 'license_expiry_date';
  static const _kClientName = 'license_client_name';
  static const _kClientPhone = 'license_client_phone';
  static const _kStatus = 'license_status';
  static const _kLastOnlineCheck = 'license_last_online_check';

  final EncryptedSharedPreferences _prefs = EncryptedSharedPreferences();

  Future<String?> _getString(String key) async {
    try {
      return await _prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  Future<void> _clearAll() async {
    await _prefs.remove(_kShopId);
    await _prefs.remove(_kActivationKey);
    await _prefs.remove(_kExpiryDate);
    await _prefs.remove(_kClientName);
    await _prefs.remove(_kClientPhone);
    await _prefs.remove(_kStatus);
    await _prefs.remove(_kLastOnlineCheck);
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  DateTime _todayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<bool> _hasInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.any((c) => c != ConnectivityResult.none);
  }

  Future<LocalLicense?> readLocalLicense() async {
    final shopId = await _getString(_kShopId);
    final activationKey = await _getString(_kActivationKey);
    final expiryRaw = await _getString(_kExpiryDate);
    final clientName = await _getString(_kClientName) ?? '';
    final clientPhone = await _getString(_kClientPhone) ?? '';
    final status = await _getString(_kStatus) ?? 'inactive';
    final lastCheckRaw = await _getString(_kLastOnlineCheck);
    final expiry = _parseDate(expiryRaw);
    if (shopId == null ||
        shopId.isEmpty ||
        activationKey == null ||
        activationKey.isEmpty ||
        expiry == null) {
      return null;
    }
    return LocalLicense(
      shopId: shopId,
      activationKey: activationKey,
      clientName: clientName,
      clientPhone: clientPhone,
      expiryDate: expiry,
      status: status,
      lastOnlineCheck: _parseDate(lastCheckRaw),
    );
  }

  Future<void> saveValidatedLicense({
    required String shopId,
    required String activationKey,
    required DateTime expiryDate,
    required String clientName,
    required String clientPhone,
    required String status,
    required DateTime lastOnlineCheck,
  }) async {
    await _setString(_kShopId, shopId);
    await _setString(_kActivationKey, activationKey);
    await _setString(_kExpiryDate, expiryDate.toIso8601String());
    await _setString(_kClientName, clientName);
    await _setString(_kClientPhone, clientPhone);
    await _setString(_kStatus, status);
    await _setString(_kLastOnlineCheck, lastOnlineCheck.toIso8601String());
  }

  Future<LicenseGateResult> evaluateOnLaunch() async {
    final local = await readLocalLicense();
    if (local == null) {
      return const LicenseGateResult(state: LicenseGateState.notActivated);
    }

    final now = DateTime.now();
    if (_todayOnly(local.expiryDate).isBefore(_todayOnly(now))) {
      return LicenseGateResult(
        state: LicenseGateState.expired,
        license: local,
      );
    }

    if (!local.isActiveStatus) {
      return LicenseGateResult(
        state: LicenseGateState.deactivated,
        license: local,
      );
    }

    final lastCheck = local.lastOnlineCheck;
    final needsMonthlyCheck =
        lastCheck == null || now.difference(lastCheck).inDays > 30;
    if (!needsMonthlyCheck) {
      return LicenseGateResult(
        state: LicenseGateState.active,
        license: local,
      );
    }

    final online = await _hasInternetConnection();
    if (!online) {
      return LicenseGateResult(
        state: LicenseGateState.onlineCheckRequired,
        license: local,
        message:
            'Please connect to WiFi to verify your license. Contact: $supportContact',
      );
    }

    final validation = await _validateAgainstServer(
      shopId: local.shopId,
      activationKey: local.activationKey,
      allowOfflineFallback: true,
    );
    if (validation.state == LicenseGateState.active) {
      return validation;
    }

    // Allow app if server is temporarily unreachable, using local license.
    if (validation.message != null &&
        validation.message!.toLowerCase().contains('temporarily')) {
      return LicenseGateResult(
        state: LicenseGateState.active,
        license: local,
      );
    }
    return validation;
  }

  Future<LicenseGateResult> activate({
    required String shopId,
    required String activationKey,
  }) async {
    // Do not rely only on connectivity_plus here. On some desktop setups
    // it can report "none" even when internet is available.
    // We validate directly against Supabase and map real network failures.
    return _validateAgainstServer(
      shopId: shopId.trim().toUpperCase(),
      activationKey: activationKey.trim().toUpperCase(),
      allowOfflineFallback: false,
    );
  }

  Future<LicenseGateResult> _validateAgainstServer({
    required String shopId,
    required String activationKey,
    required bool allowOfflineFallback,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      // Query by shop_id first, then validate activation key in app code.
      // This avoids hard failures when some deployments use different column names.
      final raw = await supabase
          .from('licenses')
          .select('*')
          .eq('shop_id', shopId)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));

      if (raw == null) {
        return const LicenseGateResult(
          state: LicenseGateState.notActivated,
          message: 'Shop ID not found.',
        );
      }

      final dbActivationKey =
          (raw['activation_key'] as String?) ??
          (raw['license_key'] as String?) ??
          (raw['key'] as String?);
      if (dbActivationKey == null || dbActivationKey.trim().isEmpty) {
        return const LicenseGateResult(
          state: LicenseGateState.notActivated,
          message:
              'License record is missing activation key column/value. Add `activation_key` in Supabase.',
        );
      }
      if (dbActivationKey.trim().toUpperCase() != activationKey) {
        return const LicenseGateResult(
          state: LicenseGateState.notActivated,
          message: 'Invalid Activation Key for this Shop ID.',
        );
      }

      final status = (raw['status'] as String? ?? 'inactive').toLowerCase();
      final expiryRaw =
          (raw['expiry_date'] as String?) ?? (raw['expires_at'] as String?);
      final expiryDate = DateTime.tryParse(expiryRaw ?? '');
      if (expiryDate == null) {
        return const LicenseGateResult(
          state: LicenseGateState.notActivated,
          message:
              'License data is incomplete. Missing expiry_date/expires_at.',
        );
      }

      final license = LocalLicense(
        shopId: (raw['shop_id'] as String?) ?? shopId,
        activationKey: dbActivationKey,
        clientName: (raw['client_name'] as String?) ?? '',
        clientPhone: (raw['client_phone'] as String?) ?? '',
        expiryDate: expiryDate,
        status: status,
        lastOnlineCheck: DateTime.now(),
      );

      if (_todayOnly(expiryDate).isBefore(_todayOnly(DateTime.now()))) {
        await saveValidatedLicense(
          shopId: license.shopId,
          activationKey: license.activationKey,
          expiryDate: license.expiryDate,
          clientName: license.clientName,
          clientPhone: license.clientPhone,
          status: 'expired',
          lastOnlineCheck: DateTime.now(),
        );
        return LicenseGateResult(
          state: LicenseGateState.expired,
          license: license,
        );
      }

      if (status != 'active') {
        await saveValidatedLicense(
          shopId: license.shopId,
          activationKey: license.activationKey,
          expiryDate: license.expiryDate,
          clientName: license.clientName,
          clientPhone: license.clientPhone,
          status: status,
          lastOnlineCheck: DateTime.now(),
        );
        return LicenseGateResult(
          state: LicenseGateState.deactivated,
          license: license,
        );
      }

      await _touchLastPosCheck(
        supabase: supabase,
        shopId: license.shopId,
        activationKey: license.activationKey,
      );

      await saveValidatedLicense(
        shopId: license.shopId,
        activationKey: license.activationKey,
        expiryDate: license.expiryDate,
        clientName: license.clientName,
        clientPhone: license.clientPhone,
        status: 'active',
        lastOnlineCheck: DateTime.now(),
      );

      return LicenseGateResult(
        state: LicenseGateState.active,
        license: license,
      );
    } on TimeoutException {
      if (allowOfflineFallback) {
        return const LicenseGateResult(
          state: LicenseGateState.active,
          message: 'Server timeout. Using local license.',
        );
      }
      return const LicenseGateResult(
        state: LicenseGateState.notActivated,
        message:
            'License server timeout. Please check internet and try again.',
      );
    } on PostgrestException catch (e) {
      debugPrint('License check PostgrestException: ${e.message}');
      if (allowOfflineFallback) {
        return const LicenseGateResult(
          state: LicenseGateState.active,
          message: 'Server temporarily unavailable. Using local license.',
        );
      }
      return const LicenseGateResult(
        state: LicenseGateState.notActivated,
        message:
            'Could not verify license (database policy/config issue). Check licenses table access and try again.',
      );
    } on SocketException {
      if (allowOfflineFallback) {
        return const LicenseGateResult(
          state: LicenseGateState.active,
          message: 'Server temporarily unavailable. Using local license.',
        );
      }
      return const LicenseGateResult(
        state: LicenseGateState.notActivated,
        message: 'Network error. Please check internet and try again.',
      );
    } catch (e) {
      debugPrint('License check error: $e');
      if (allowOfflineFallback) {
        return const LicenseGateResult(
          state: LicenseGateState.active,
          message: 'Server temporarily unavailable. Using local license.',
        );
      }
      return const LicenseGateResult(
        state: LicenseGateState.notActivated,
        message: 'Could not verify license right now. Please try again.',
      );
    }
  }

  Future<void> _touchLastPosCheck({
    required SupabaseClient supabase,
    required String shopId,
    required String activationKey,
  }) async {
    try {
      await supabase
          .from('licenses')
          .update({
            'last_pos_check': DateTime.now().toIso8601String(),
            'last_checked': DateTime.now().toIso8601String(),
          })
          .eq('shop_id', shopId)
          .eq('activation_key', activationKey)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      // Fallback for schemas without activation_key in update filters.
      try {
        await supabase
            .from('licenses')
            .update({
              'last_pos_check': DateTime.now().toIso8601String(),
              'last_checked': DateTime.now().toIso8601String(),
            })
            .eq('shop_id', shopId)
            .timeout(const Duration(seconds: 8));
      } catch (e2) {
        // Do not block activation if timestamp write is rejected.
        debugPrint('Could not update last_pos_check/last_checked: $e / $e2');
      }
    }
  }

  String formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<int?> daysRemaining() async {
    final local = await readLocalLicense();
    if (local == null) return null;
    return _todayOnly(local.expiryDate).difference(_todayOnly(DateTime.now())).inDays;
  }

  Future<void> clearLocalLicense() => _clearAll();
}

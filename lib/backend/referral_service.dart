import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enlaces de promotores: subastaloaqui.com/?ref=CODIGO
/// Al abrir la app se guarda el código; al crear la cuenta se reclama
/// (el servidor decide si cuenta: solo cuentas nuevas y una vez).
class ReferralService {
  ReferralService._();
  static final instance = ReferralService._();
  static const _key = 'pending_ref_code';

  /// Llamar al arrancar: guarda ?ref= de la URL (web).
  Future<void> captureFromUrl() async {
    try {
      final raw = Uri.base.queryParameters['ref'] ?? '';
      final code = raw.trim().toUpperCase();
      if (!RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(code)) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (e) {
      debugPrint('ref: $e');
    }
  }

  /// Llamar cuando ya existe el perfil. Nunca bloquea ni muestra errores.
  Future<void> claimPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code == null) return;
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('claimReferral')
          .call<dynamic>({'code': code});
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('claimReferral: $e');
    }
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

/// Notificaciones push (Firebase Cloud Messaging).
///
/// - Pide permiso y guarda el token del dispositivo en
///   users/{uid}/fcm_tokens/{token}.
/// - Con la app abierta, muestra el aviso como barra inferior.
/// - Al tocar una notificación, abre el lote correspondiente.
///
/// En web se necesita la "clave VAPID" de Firebase:
///   flutter run -d chrome --dart-define=FCM_VAPID_KEY=tu_clave
///   flutter build web --dart-define=FCM_VAPID_KEY=tu_clave
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  final _messaging = FirebaseMessaging.instance;
  String? _uid;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  /// Abre una ruta (la define main.dart con el router de la app).
  void Function(String link)? onOpenLink;

  /// Muestra un mensaje con la app abierta (lo define main.dart).
  void Function(String title, String body, String link)? onForegroundMessage;

  String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Llamar cuando el usuario inicia sesión.
  Future<void> register(String uid) async {
    if (_uid == uid && _token != null) return;
    _uid = uid;
    try {
      final settings = await _messaging.requestPermission(
          alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      if (kIsWeb && _vapidKey.isEmpty) {
        debugPrint('Push web desactivado: falta --dart-define=FCM_VAPID_KEY');
        return;
      }
      final token =
          await _messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
      if (token != null) await _saveToken(uid, token);

      _refreshSub ??= _messaging.onTokenRefresh.listen((t) {
        final current = _uid;
        if (current != null) _saveToken(current, t);
      });

      _foregroundSub ??= FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        onForegroundMessage?.call(
            n.title ?? 'BidStream', n.body ?? '', _linkOf(m));
      });

      _openedSub ??= FirebaseMessaging.onMessageOpenedApp
          .listen((m) => onOpenLink?.call(_linkOf(m)));

      // La app estaba cerrada y se abrió tocando la notificación.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) onOpenLink?.call(_linkOf(initial));
    } catch (e) {
      // Sin push la app sigue funcionando (los avisos se ven dentro).
      debugPrint('No se pudo activar push: $e');
    }
  }

  /// Llamar ANTES de cerrar sesión: este dispositivo deja de recibir avisos.
  Future<void> unregister() async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    final token = _token;
    _uid = null;
    _token = null;
    if (uid == null || token == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(token)
          .delete();
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('No se pudo borrar el token: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    _token = token;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcm_tokens')
        .doc(token)
        .set({
      'platform': _platform,
      'updated_time': FieldValue.serverTimestamp(),
    });
  }

  String _linkOf(RemoteMessage m) {
    final link = m.data['link'];
    if (link is String && link.startsWith('/')) return link;
    final lotId = m.data['lot_id'];
    if (lotId is String && lotId.isNotEmpty) {
      return '/lotDetailView?lotId=${Uri.encodeQueryComponent(lotId)}';
    }
    return '/auctionNotifications';
  }
}

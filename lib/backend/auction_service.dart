import 'dart:convert' show base64Encode;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'demo_lots.dart';
import 'schema/bidding_record.dart';
import 'storage_upload.dart';
import 'schema/bids_record.dart';
import 'schema/lots_record.dart';
import 'schema/notifications_record.dart';
import 'schema/users_record.dart';

/// Categorías generales del marketplace.
const kLotCategories = <String>[
  'Vehículos',
  'Ganado y caballos',
  'Maquinaria y herramientas',
  'Electrónica',
  'Hogar y muebles',
  'Joyería y relojes',
  'Arte y colección',
  'Deportes',
  'Ropa y accesorios',
  'Otros',
];

/// Estado del artículo. Deben coincidir con CONDITIONS de functions/ai.js.
const kLotConditions = <String, String>{
  'new': 'Nuevo',
  'like_new': 'Como nuevo',
  'used_good': 'Usado — buen estado',
  'used_fair': 'Usado — con detalles',
  'for_parts': 'Para reparar / refacciones',
};

/// Propuesta del asistente de IA para una publicación.
class AiLotSuggestion {
  AiLotSuggestion(Map<String, dynamic> d)
      : title = (d['title'] ?? '').toString(),
        category = (d['category'] ?? '').toString(),
        description = (d['description'] ?? '').toString(),
        detectedIssues = _strList(d['detected_issues']),
        missingInfo = _strList(d['missing_info']),
        conditionMismatch = (d['condition_mismatch'] ?? '').toString(),
        prohibited = d['prohibited'] == true,
        prohibitedReason = (d['prohibited_reason'] ?? '').toString();

  static List<String> _strList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const <String>[];

  final String title;
  final String category;
  final String description;
  final List<String> detectedIssues;
  final List<String> missingInfo;
  final String conditionMismatch;
  final bool prohibited;
  final String prohibitedReason;
}

/// Resultado de una oferta proxy (puja máxima secreta).
class PlaceBidResult {
  const PlaceBidResult.success({
    required this.outcome,
    required this.leading,
    required this.currentBid,
    required this.yourMax,
    required this.extended,
    this.message,
  })  : ok = true,
        minimum = null,
        depositRequired = false,
        identityRequired = false;

  const PlaceBidResult.failure(this.message,
      {this.minimum,
      this.depositRequired = false,
      this.identityRequired = false})
      : ok = false,
        outcome = null,
        leading = false,
        currentBid = null,
        yourMax = null,
        extended = false;

  final bool ok;

  /// first | leading | outbid | max_raised
  final String? outcome;

  /// ¿Vas ganando después de esta oferta?
  final bool leading;

  /// Precio visible después de la oferta.
  final double? currentBid;

  /// Tu máximo secreto registrado.
  final double? yourMax;

  /// ¿Se extendió el cierre por anti-sniping (30 s)?
  final bool extended;
  final String? message;
  final double? minimum;

  /// El servidor rechazó porque falta el depósito de garantía.
  final bool depositRequired;

  /// El servidor pide identidad verificada (INE) para este monto.
  final bool identityRequired;

  /// Compatibilidad: monto visible tras la oferta.
  double? get amount => currentBid;
}

/// Todo el acceso a datos de la app pasa por aquí.
/// Las pantallas no hablan directo con Firestore/Functions/Storage.
class AuctionService {
  AuctionService._();
  static final AuctionService instance = AuctionService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ------------------------------------------------------------------
  // Lotes
  // ------------------------------------------------------------------

  /// Subastas abiertas, las que terminan primero arriba. En la vista previa
  /// (DEMO_LOTS=true) se agregan lotes de demostración.
  Stream<List<LotsRecord>> activeLots({int limit = 100}) {
    final real = LotsRecord.collection
        .where('status', isEqualTo: 'active')
        .orderBy('end_time')
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(LotsRecord.fromSnapshot).toList());
    if (!kShowDemoLots) return real;
    return _withDemos(real);
  }

  /// En la vista previa, los lotes de ejemplo se muestran de inmediato y
  /// aunque Firestore falle (sin conexión, reglas, índices).
  Stream<List<LotsRecord>> _withDemos(Stream<List<LotsRecord>> real) async* {
    List<LotsRecord> merge(List<LotsRecord> lots) {
      final all = [...lots, ...demoLots()];
      all.sort((a, b) =>
          (a.endTime ?? DateTime(2100)).compareTo(b.endTime ?? DateTime(2100)));
      return all;
    }

    yield merge(const []);
    try {
      await for (final lots in real) {
        yield merge(lots);
      }
    } catch (e) {
      debugPrint('Lotes reales no disponibles: $e');
    }
  }

  Stream<LotsRecord?> lot(String lotId) => isDemoLotId(lotId)
      ? Stream<LotsRecord?>.value(demoLot(lotId))
      : LotsRecord.collection.doc(lotId).snapshots().map(
            (s) => s.exists ? LotsRecord.fromSnapshot(s) : null,
          );

  Stream<List<BidsRecord>> bids(String lotId, {int limit = 30}) => isDemoLotId(lotId)
      ? Stream<List<BidsRecord>>.value(demoBids(lotId))
      : BidsRecord.collection(LotsRecord.collection.doc(lotId))
          .orderBy('created_time', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(BidsRecord.fromSnapshot).toList());

  Stream<List<LotsRecord>> myListings() => LotsRecord.collection
      .where('seller_uid', isEqualTo: _uid)
      .orderBy('created_time', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(LotsRecord.fromSnapshot).toList());

  /// Fija, baja o quita (null) el precio de reserva. Lo valida el servidor.
  Future<void> setReservePrice(String lotId, double? amount) async {
    try {
      await _functions
          .httpsCallable('setReservePrice')
          .call<dynamic>({'lotId': lotId, 'amount': amount});
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'No se pudo guardar la reserva.');
    }
  }

  /// Lotes activos de un vendedor (perfil público).
  Stream<List<LotsRecord>> sellerActiveLots(String sellerUid) {
    if (sellerUid == 'demo-seller') return Stream.value(demoLots());
    return LotsRecord.collection
        .where('seller_uid', isEqualTo: sellerUid)
        .orderBy('created_time', descending: true)
        .limit(60)
        .snapshots()
        .map((s) => s.docs
            .map(LotsRecord.fromSnapshot)
            .where((l) => l.status == 'active')
            .toList());
  }

  Stream<List<LotsRecord>> wonLots() => LotsRecord.collection
      .where('winner_uid', isEqualTo: _uid)
      .orderBy('end_time', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(LotsRecord.fromSnapshot).toList());

  Stream<List<BiddingRecord>> myBidding() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <BiddingRecord>[]);
    return BiddingRecord.collection(uid)
        .orderBy('last_bid_time', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(BiddingRecord.fromSnapshot).toList());
  }

  /// Sube una foto y regresa su URL pública de descarga.
  Future<String> uploadLotImage(Uint8List bytes, {String? contentType}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sin sesión');
    final type = contentType ?? 'image/jpeg';
    final ext = type.split('/').last.replaceAll('jpeg', 'jpg');
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance.ref('lots/$uid/$name');
    await uploadWithTimeout(ref, bytes, type);
    return ref.getDownloadURL();
  }

  Future<String> createLot({
    required String title,
    required String description,
    required String category,
    required double startingPrice,
    required double minimumIncrement,
    required DateTime startTime,
    required DateTime endTime,
    required String format,
    required String condition,
    required List<String> imageUrls,
    String streamUrl = '',
    Map<String, String> specs = const {},
    String municipality = 'otro',
    Map<String, dynamic>? delivery,
    String saleType = 'auction',
    double? buyNowPrice,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sin sesión');
    final ref = await LotsRecord.collection.add({
      ...createLotsRecordData(
      title: title.trim(),
      description: description.trim(),
      category: category,
      startingPrice: startingPrice,
      minimumIncrement: minimumIncrement,
      startTime: startTime,
      endTime: endTime,
      format: format,
      condition: condition,
      sellerUid: uid,
      imageUrls: imageUrls,
      streamUrl: streamUrl.trim(),
      ),
      if (specs.isNotEmpty) 'specs': specs,
      'municipality': municipality,
      'delivery': delivery ?? {'pickup': true, 'regional': false},
      'sale_type': saleType,
      if (saleType == 'fixed') 'buy_now_price': startingPrice,
      if (saleType != 'fixed' && buyNowPrice != null && buyNowPrice > 0)
        'buy_now_price': buyNowPrice,
    });
    return ref.id;
  }

  /// Pide a la IA título, categoría y descripción a partir de las fotos.
  /// [photos]: (bytes, mime) de hasta 4 fotos.
  Future<AiLotSuggestion> suggestLotContent({
    required List<(Uint8List, String)> photos,
    required String condition,
    String notes = '',
  }) async {
    final res = await _functions
        .httpsCallable('generateLotDescription',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 120)))
        .call<dynamic>({
      'images': [
        for (final p in photos.take(4))
          {'mime': p.$2, 'data': base64Encode(p.$1)},
      ],
      'condition': condition,
      'notes': notes,
    });
    final raw = res.data;
    return AiLotSuggestion(
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
  }

  /// Solo funciona si el lote no tiene pujas (lo exige firestore.rules).
  Future<void> deleteLot(String lotId) =>
      LotsRecord.collection.doc(lotId).delete();

  Future<void> updateStreamUrl(String lotId, String url) =>
      LotsRecord.collection.doc(lotId).update({'stream_url': url.trim()});

  // ------------------------------------------------------------------
  // Pujas (siempre por el servidor)
  // ------------------------------------------------------------------

  /// Envía tu MÁXIMO secreto. El servidor puja por ti automáticamente
  /// hasta ese límite (puja proxy) y aplica el anti-sniping de 30 s.
  /// Comprar ahora (precio fijo o subasta sin pujas). El servidor cierra la
  /// venta en una transacción; si alguien compró antes, responde el error.
  Future<BuyNowResult> buyNow(String lotId) async {
    if (isDemoLotId(lotId)) {
      return const BuyNowResult.failure(
          'Este es un artículo de demostración: no se puede comprar. Las compras reales se activan al lanzar.');
    }
    try {
      final res = await _functions
          .httpsCallable('buyNow')
          .call<dynamic>({'lotId': lotId});
      final raw = res.data;
      final data = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
      return BuyNowResult.success(
        message: data['message']?.toString() ?? '¡Es tuyo!',
        paymentUrl: data['url']?.toString(),
        settled: data['settled'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map ? details['code']?.toString() : null;
      return BuyNowResult.failure(e.message ?? 'No se pudo completar la compra.', code: code);
    } catch (_) {
      return const BuyNowResult.failure('No se pudo completar la compra. Revisa tu conexión.');
    }
  }

  Future<PlaceBidResult> placeBid(String lotId, double maxAmount) async {
    if (isDemoLotId(lotId)) {
      return const PlaceBidResult.failure(
          'Este es un lote de demostración: no se puede pujar. Las pujas reales se activan al lanzar.');
    }
    try {
      final res = await _functions
          .httpsCallable('placeBid')
          .call<dynamic>({'lotId': lotId, 'max_amount': maxAmount});
      final raw = res.data;
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      return PlaceBidResult.success(
        outcome: (data['outcome'] ?? 'leading').toString(),
        leading: data['leading'] == true,
        currentBid: (data['current_bid'] as num?)?.toDouble(),
        yourMax: (data['your_max'] as num?)?.toDouble() ?? maxAmount,
        extended: data['extended'] == true,
        message: data['message']?.toString(),
      );
    } on FirebaseFunctionsException catch (e) {
      double? minimum;
      var depositRequired = false;
      var identityRequired = false;
      final details = e.details;
      if (details is Map) {
        if (details['minimum'] is num) {
          minimum = (details['minimum'] as num).toDouble();
        }
        depositRequired = details['code'] == 'DEPOSIT_REQUIRED';
        identityRequired = details['code'] == 'IDENTITY_REQUIRED';
      }
      return PlaceBidResult.failure(
        e.message ?? 'No se pudo registrar la puja.',
        minimum: minimum,
        depositRequired: depositRequired,
        identityRequired: identityRequired,
      );
    } catch (_) {
      return const PlaceBidResult.failure(
          'Sin conexión con el servidor. Intenta de nuevo.');
    }
  }

  // ------------------------------------------------------------------
  // Perfil
  // ------------------------------------------------------------------

  Stream<UsersRecord?> myProfile() {
    final uid = _uid;
    if (uid == null) return Stream<UsersRecord?>.value(null);
    return UsersRecord.doc(uid)
        .snapshots()
        .map((s) => s.exists ? UsersRecord.fromSnapshot(s) : null);
  }

  /// Crea el perfil si no existe (al registrarse o al iniciar sesión).
  Future<void> ensureProfile({String? fullName}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = UsersRecord.doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': (user.email ?? '').toLowerCase(),
        'full_name': (fullName ?? user.displayName ?? '').trim(),
        'phone': '',
        'city': '',
        'accepted_terms': false,
        'created_time': FieldValue.serverTimestamp(),
      });
    } else if (fullName != null && fullName.trim().isNotEmpty) {
      await ref.update({'full_name': fullName.trim()});
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String city,
    required bool acceptedTerms,
    String payoutClabe = '',
    String payoutHolder = '',
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await UsersRecord.doc(uid).set({
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'accepted_terms': acceptedTerms,
      'payout_clabe': payoutClabe.replaceAll(RegExp(r'\s'), ''),
      'payout_holder': payoutHolder.trim(),
    }, SetOptions(merge: true));
  }

  /// Recarga el usuario para saber si ya verificó su correo, y renueva
  /// el token para que las reglas de seguridad lo reconozcan.
  Future<bool> refreshEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser;
    if (fresh?.emailVerified == true) {
      await fresh!.getIdToken(true);
      return true;
    }
    return false;
  }

  bool get emailVerified =>
      FirebaseAuth.instance.currentUser?.emailVerified ?? false;

  // ------------------------------------------------------------------
  // Notificaciones
  // ------------------------------------------------------------------

  Stream<List<NotificationsRecord>> notifications({int limit = 50}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const <NotificationsRecord>[]);
    return NotificationsRecord.collection(uid)
        .orderBy('created_time', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(NotificationsRecord.fromSnapshot).toList());
  }

  Stream<int> unreadCount() {
    final uid = _uid;
    if (uid == null) return Stream<int>.value(0);
    return NotificationsRecord.collection(uid)
        .where('read', isEqualTo: false)
        .limit(99)
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> markRead(NotificationsRecord n) =>
      n.reference.update({'read': true});

  Future<void> markAllRead(List<NotificationsRecord> items) async {
    final batch = _db.batch();
    for (final n in items.where((n) => !n.read)) {
      batch.update(n.reference, {'read': true});
    }
    await batch.commit();
  }
}


/// Resultado de Comprar ahora.
class BuyNowResult {
  const BuyNowResult.success({required this.message, this.paymentUrl, this.settled = false})
      : ok = true,
        code = null;
  const BuyNowResult.failure(this.message, {this.code})
      : ok = false,
        paymentUrl = null,
        settled = false;

  final bool ok;
  final String message;
  final String? paymentUrl;
  final bool settled;

  /// Código del servidor (p. ej. DEPOSIT_REQUIRED, IDENTITY_REQUIRED, NOT_ACTIVE).
  final String? code;
}

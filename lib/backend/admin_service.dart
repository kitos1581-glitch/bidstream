import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Solicitud de verificación de identidad (verifications/{uid}).
class VerificationRequest {
  VerificationRequest(this.uid, Map<String, dynamic> d)
      : status = (d['status'] ?? 'none').toString(),
        fullName = (d['full_name'] ?? '').toString(),
        email = (d['email'] ?? '').toString(),
        rejectReason = (d['reject_reason'] ?? '').toString(),
        files = Map<String, String>.from(
            (d['files'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {}),
        submitted = (d['submitted_time'] is Timestamp)
            ? (d['submitted_time'] as Timestamp).toDate()
            : null;

  final String uid;
  final String status; // none | pending | approved | rejected
  final String fullName;
  final String email;
  final String rejectReason;
  final Map<String, String> files;
  final DateTime? submitted;
}

/// Un documento de payments/ (payout, refund, deposit...).
class PaymentDoc {
  PaymentDoc(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get kind => (data['kind'] ?? '').toString();
  String get status => (data['status'] ?? '').toString();
  String get reason => (data['reason'] ?? '').toString();
  String get uid => (data['uid'] ?? '').toString();
  String get lotId => (data['lot_id'] ?? '').toString();
  double get amount => (data['amount'] as num?)?.toDouble() ?? 0;
  DateTime? get created => data['created_time'] is Timestamp
      ? (data['created_time'] as Timestamp).toDate()
      : null;
}

/// Verificación de identidad (para cualquier usuario) y acciones de
/// administrador (solo si el token tiene admin == true; el servidor
/// lo vuelve a revisar en cada función).
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'us-central1');
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ------------------------------------------------------------------
  // Verificación de identidad (usuario)
  // ------------------------------------------------------------------

  Stream<VerificationRequest?> myVerification() {
    final uid = _uid;
    if (uid == null) return Stream<VerificationRequest?>.value(null);
    return _db.collection('verifications').doc(uid).snapshots().map(
        (s) => s.exists ? VerificationRequest(uid, s.data()!) : null);
  }

  /// Sube una foto (ine_front | ine_back | selfie) y regresa su ruta.
  Future<String> uploadIdPhoto(String key, Uint8List bytes, String mime) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sin sesión');
    final ext = mime.contains('png') ? 'png' : 'jpg';
    final path =
        'verifications/$uid/${key}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await FirebaseStorage.instance
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: mime));
    return path;
  }

  Future<void> submitVerification(Map<String, String> files) async {
    await _fn
        .httpsCallable('submitIdentityVerification')
        .call<dynamic>({'files': files});
  }

  // ------------------------------------------------------------------
  // ¿Soy administrador?
  // ------------------------------------------------------------------

  Future<bool> isAdmin({bool refresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(refresh);
    return token.claims?['admin'] == true;
  }

  // ------------------------------------------------------------------
  // Consultas del panel
  // ------------------------------------------------------------------

  Stream<List<VerificationRequest>> pendingVerifications() => _db
      .collection('verifications')
      .where('status', isEqualTo: 'pending')
      .limit(100)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => VerificationRequest(d.id, d.data())).toList());

  Stream<List<PaymentDoc>> readyPayouts() => _db
      .collection('payments')
      .where('kind', isEqualTo: 'payout')
      .where('status', isEqualTo: 'ready')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentDoc(d.id, d.data())).toList());

  /// Liquidaciones que quedaron en revisión (p. ej. configuración de
  /// comisiones inválida en el servidor).
  Stream<List<PaymentDoc>> payoutsNeedingReview() => _db
      .collection('payments')
      .where('kind', isEqualTo: 'payout')
      .where('status', isEqualTo: 'needs_review')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentDoc(d.id, d.data())).toList());

  Stream<List<PaymentDoc>> failedRefunds() => _db
      .collection('payments')
      .where('kind', isEqualTo: 'refund')
      .where('status', isEqualTo: 'failed')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentDoc(d.id, d.data())).toList());

  /// Lotes cuyo cobro al ganador falló al crearse.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> paymentErrors() =>
      _db
          .collection('lots')
          .where('payment_status', isEqualTo: 'payment_error')
          .limit(100)
          .snapshots()
          .map((s) => s.docs);

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> findUsersByEmail(
      String email) async {
    final s = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(10)
        .get();
    return s.docs;
  }

  Future<String> fileUrl(String path) =>
      FirebaseStorage.instance.ref(path).getDownloadURL();

  // ------------------------------------------------------------------
  // Acciones (Cloud Functions)
  // ------------------------------------------------------------------

  Future<void> reviewVerification(String uid,
          {required bool approve, String reason = ''}) =>
      _fn.httpsCallable('adminReviewVerification').call<dynamic>(
          {'uid': uid, 'approve': approve, 'reason': reason});

  Future<void> setBan(String uid, {required bool banned, String reason = ''}) =>
      _fn.httpsCallable('adminSetBan').call<dynamic>(
          {'uid': uid, 'banned': banned, 'reason': reason});

  Future<void> markPayoutSent(String paymentId, String reference) =>
      _fn.httpsCallable('adminMarkPayoutSent').call<dynamic>(
          {'paymentId': paymentId, 'reference': reference});

  Future<void> recalculatePayout(String paymentId) => _fn
      .httpsCallable('adminRecalculatePayout')
      .call<dynamic>({'paymentId': paymentId});

  Future<void> retryWinnerPayment(String lotId) => _fn
      .httpsCallable('adminRetryWinnerPayment')
      .call<dynamic>({'lotId': lotId});

  Future<void> cancelLot(String lotId, String reason) => _fn
      .httpsCallable('adminCancelLot')
      .call<dynamic>({'lotId': lotId, 'reason': reason});
}

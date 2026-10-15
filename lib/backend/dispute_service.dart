import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'storage_upload.dart';

/// Motivos de reclamo (deben coincidir con REASONS de functions/disputes.js).
const kDisputeReasons = <String, String>{
  'not_delivered': 'No llegó',
  'not_as_described': 'No coincide con lo publicado',
  'missing_documents': 'Faltan documentos',
  'undisclosed_defect': 'Defecto que no se dijo',
  'other': 'Otro',
};

class Dispute {
  Dispute(this.id, Map<String, dynamic> d)
      : status = (d['status'] ?? '').toString(),
        reason = (d['reason'] ?? '').toString(),
        details = (d['details'] ?? '').toString(),
        lotTitle = (d['lot_title'] ?? '').toString(),
        buyerUid = (d['buyer_uid'] ?? '').toString(),
        sellerUid = (d['seller_uid'] ?? '').toString(),
        finalPrice = (d['final_price'] as num?)?.toDouble() ?? 0,
        photos = d['photos'] is List ? (d['photos'] as List).map((e) => '$e').toList() : const [],
        payoutAlreadySent = d['payout_already_sent'] == true,
        resolution = (d['resolution'] ?? '').toString(),
        created = d['created_time'] is Timestamp ? (d['created_time'] as Timestamp).toDate() : null;

  final String id; // = lotId
  final String status; // open | resolving | refund_failed | resolved
  final String reason;
  final String details;
  final String lotTitle;
  final String buyerUid;
  final String sellerUid;
  final double finalPrice;
  final List<String> photos;
  final bool payoutAlreadySent;
  final String resolution;
  final DateTime? created;
}

class DisputeFailure implements Exception {
  const DisputeFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class DisputeService {
  DisputeService._();
  static final DisputeService instance = DisputeService._();

  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String> uploadEvidence(Uint8List bytes, String mime) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sin sesión');
    final ext = mime.contains('png') ? 'png' : (mime.startsWith('video/') ? 'mp4' : 'jpg');
    final path = 'disputes/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await uploadWithTimeout(FirebaseStorage.instance.ref(path), bytes, mime);
    return path;
  }

  Future<void> open(String lotId, String reason, String details, List<String> photos) =>
      _call('openDispute', {'lotId': lotId, 'reason': reason, 'details': details, 'photos': photos});

  Future<void> resolve(String disputeId, String resolution, {double? amount, String note = ''}) =>
      _call('adminResolveDispute', {
        'disputeId': disputeId,
        'resolution': resolution,
        if (amount != null) 'amount': amount,
        'note': note,
      });

  Stream<List<Dispute>> pending() => FirebaseFirestore.instance
      .collection('disputes')
      .where('status', whereIn: ['open', 'refund_failed'])
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => Dispute(d.id, d.data())).toList());

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await _fn.httpsCallable(name).call<dynamic>(data);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const {};
      throw DisputeFailure((details['code'] ?? e.code).toString(), e.message ?? 'No se pudo completar.');
    }
  }
}

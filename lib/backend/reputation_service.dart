import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Perfil público de un vendedor (public_profiles/{uid}). Solo datos
/// públicos: nunca teléfono ni correo.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    this.displayName = '',
    this.verified = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.salesCount = 0,
    this.badges = const [],
  });

  factory PublicProfile.fromMap(String uid, Map<String, dynamic> d) => PublicProfile(
        uid: uid,
        displayName: (d['display_name'] ?? '').toString(),
        verified: d['verified'] == true,
        ratingAvg: (d['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: (d['rating_count'] as num?)?.toInt() ?? 0,
        salesCount: (d['sales_count'] as num?)?.toInt() ?? 0,
        badges: (d['badges'] is List)
            ? (d['badges'] as List).map((e) => '$e').toList()
            : const [],
      );

  final String uid;
  final String displayName;
  final bool verified;
  final double ratingAvg;
  final int ratingCount;
  final int salesCount;
  final List<String> badges;
}

/// Una calificación (feedback/{lotId}).
class FeedbackEntry {
  FeedbackEntry(this.lotId, Map<String, dynamic> d)
      : rating = (d['rating'] as num?)?.toInt() ?? 0,
        comment = (d['comment'] ?? '').toString(),
        authorName = (d['author_name'] ?? '').toString(),
        authorUid = (d['author_uid'] ?? '').toString(),
        lotTitle = (d['lot_title'] ?? '').toString(),
        created = d['created_time'] is Timestamp
            ? (d['created_time'] as Timestamp).toDate()
            : null,
        editableUntil = d['editable_until'] is Timestamp
            ? (d['editable_until'] as Timestamp).toDate()
            : null;

  final String lotId;
  final int rating;
  final String comment;
  final String authorName;
  final String authorUid;
  final String lotTitle;
  final DateTime? created;
  final DateTime? editableUntil;

  bool get canEdit => editableUntil != null && editableUntil!.isAfter(DateTime.now());
}

/// Texto y color de cada insignia.
const kBadgeLabels = <String, String>{
  'verificado': 'Verificado',
  'fundador': 'Vendedor fundador',
  'destacado': 'Vendedor destacado',
  'nuevo': 'Nuevo',
};

class ReputationFailure implements Exception {
  const ReputationFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class ReputationService {
  ReputationService._();
  static final ReputationService instance = ReputationService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: 'us-central1');

  Stream<PublicProfile> profile(String uid) {
    if (uid == 'demo-seller') {
      return Stream.value(const PublicProfile(
        uid: 'demo-seller',
        displayName: 'Vendedor Demo',
        verified: true,
        ratingAvg: 4.8,
        ratingCount: 37,
        salesCount: 52,
        badges: ['verificado', 'destacado'],
      ));
    }
    return _db.collection('public_profiles').doc(uid).snapshots().map((s) =>
        s.exists ? PublicProfile.fromMap(uid, s.data()!) : PublicProfile(uid: uid));
  }

  Stream<List<FeedbackEntry>> sellerFeedback(String uid, {int limit = 30}) {
    if (uid == 'demo-seller') return Stream.value(const []);
    return _db
        .collection('feedback')
        .where('seller_uid', isEqualTo: uid)
        .orderBy('created_time', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => FeedbackEntry(d.id, d.data())).toList());
  }

  Stream<FeedbackEntry?> feedbackFor(String lotId) => _db
      .collection('feedback')
      .doc(lotId)
      .snapshots()
      .map((s) => s.exists ? FeedbackEntry(s.id, s.data()!) : null);

  Future<void> submit(String lotId, int rating, String comment, {bool edit = false}) async {
    try {
      await _fn
          .httpsCallable(edit ? 'updateFeedback' : 'submitFeedback')
          .call<dynamic>({'lotId': lotId, 'rating': rating, 'comment': comment});
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const {};
      throw ReputationFailure((details['code'] ?? e.code).toString(),
          e.message ?? 'No se pudo guardar tu calificación.');
    }
  }
}

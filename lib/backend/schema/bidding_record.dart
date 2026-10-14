import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import 'record_helpers.dart';

/// Subastas en las que el usuario ha pujado.
/// Ruta: users/{uid}/bidding/{lotId}. La mantiene el servidor.
class BiddingRecord extends FirestoreRecord {
  BiddingRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data);

  String get lotId => asString(snapshotData['lot_id'], reference.id);
  String get lotTitle => asString(snapshotData['lot_title']);
  String get lotImage => asString(snapshotData['lot_image']);
  double get myMaxBid => asDouble(snapshotData['my_max_bid']);
  DateTime? get lastBidTime => asDate(snapshotData['last_bid_time']);

  static CollectionReference collection(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('bidding');

  static BiddingRecord fromSnapshot(DocumentSnapshot snapshot) =>
      BiddingRecord._(
        snapshot.reference,
        mapFromFirestore((snapshot.data() as Map<String, dynamic>?) ?? {}),
      );
}

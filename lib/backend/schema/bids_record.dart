import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import 'record_helpers.dart';

/// Una puja. Ruta: lots/{lotId}/bids/{bidId}. Solo la crea el servidor.
class BidsRecord extends FirestoreRecord {
  BidsRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data);

  String get bidderUid => asString(snapshotData['bidder_uid']);
  String get bidderName => asString(snapshotData['bidder_name'], 'Postor');
  double get amount => asDouble(snapshotData['amount']);
  DateTime? get createdTime => asDate(snapshotData['created_time']);

  static CollectionReference collection(DocumentReference lotRef) =>
      lotRef.collection('bids');

  static BidsRecord fromSnapshot(DocumentSnapshot snapshot) => BidsRecord._(
        snapshot.reference,
        mapFromFirestore((snapshot.data() as Map<String, dynamic>?) ?? {}),
      );

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is BidsRecord && reference.path == other.reference.path;
}

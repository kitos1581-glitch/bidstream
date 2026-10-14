import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import 'record_helpers.dart';

/// Entrada del HISTORIAL PÚBLICO de pujas. Ruta: lots/{lotId}/history/{id}.
/// No incluye máximos secretos (esos viven en lots/{lotId}/bids, privados).
/// `auto == true` significa que la puja la hizo el sistema proxy por el líder.
class BidsRecord extends FirestoreRecord {
  BidsRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data);

  String get bidderUid => asString(snapshotData['bidder_uid']);
  String get bidderName => asString(snapshotData['bidder_name'], 'Postor');
  double get amount => asDouble(snapshotData['amount']);
  DateTime? get createdTime => asDate(snapshotData['created_time']);
  bool get auto => asBool(snapshotData['auto']);

  static CollectionReference collection(DocumentReference lotRef) =>
      lotRef.collection('history');

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

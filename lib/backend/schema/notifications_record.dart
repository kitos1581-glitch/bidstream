import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import 'record_helpers.dart';

/// Notificación dentro de la app. Ruta: users/{uid}/notifications/{id}.
/// Tipos: outbid (te superaron), won (ganaste), sold (vendiste), unsold.
class NotificationsRecord extends FirestoreRecord {
  NotificationsRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data);

  String get type => asString(snapshotData['type']);
  String get title => asString(snapshotData['title']);
  String get body => asString(snapshotData['body']);
  String get lotId => asString(snapshotData['lot_id']);
  bool get read => asBool(snapshotData['read']);
  DateTime? get createdTime => asDate(snapshotData['created_time']);

  static CollectionReference collection(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

  static NotificationsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      NotificationsRecord._(
        snapshot.reference,
        mapFromFirestore((snapshot.data() as Map<String, dynamic>?) ?? {}),
      );
}

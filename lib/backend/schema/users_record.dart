import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import 'record_helpers.dart';

/// Perfil privado del usuario. Ruta: users/{uid}.
/// `verified`, `role` y `banned` solo los cambia un administrador.
class UsersRecord extends FirestoreRecord {
  UsersRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data);

  String get email => asString(snapshotData['email']);
  String get fullName => asString(snapshotData['full_name']);
  String get phone => asString(snapshotData['phone']);
  String get city => asString(snapshotData['city']);
  String get photoUrl => asString(snapshotData['photo_url']);
  bool get acceptedTerms => asBool(snapshotData['accepted_terms']);
  bool get verified => asBool(snapshotData['verified']);
  bool get banned => asBool(snapshotData['banned']);
  DateTime? get createdTime => asDate(snapshotData['created_time']);

  /// Lo mismo que exige la función `placeBid` del servidor.
  bool get isProfileComplete =>
      fullName.trim().isNotEmpty && phone.trim().isNotEmpty && acceptedTerms;

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('users');

  static DocumentReference doc(String uid) => collection.doc(uid);

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsersRecord.fromSnapshot(s));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromFirestore((snapshot.data() as Map<String, dynamic>?) ?? {}),
      );

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord && reference.path == other.reference.path;
}

import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// title, description, category, current_bid, starting_price,
/// minimum_increment, end_time, status, image_urls
class LotsRecord extends FirestoreRecord {
  LotsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "category" field.
  String? _category;
  String get category => _category ?? '';
  bool hasCategory() => _category != null;

  // "current_bid" field.
  double? _currentBid;
  double get currentBid => _currentBid ?? 0.0;
  bool hasCurrentBid() => _currentBid != null;

  // "starting_price" field.
  double? _startingPrice;
  double get startingPrice => _startingPrice ?? 0.0;
  bool hasStartingPrice() => _startingPrice != null;

  // "minimum_increment" field.
  double? _minimumIncrement;
  double get minimumIncrement => _minimumIncrement ?? 0.0;
  bool hasMinimumIncrement() => _minimumIncrement != null;

  // "end_time" field.
  DateTime? _endTime;
  DateTime? get endTime => _endTime;
  bool hasEndTime() => _endTime != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "image_urls" field.
  List<String>? _imageUrls;
  List<String> get imageUrls => _imageUrls ?? const [];
  bool hasImageUrls() => _imageUrls != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _description = snapshotData['description'] as String?;
    _category = snapshotData['category'] as String?;
    _currentBid = castToType<double>(snapshotData['current_bid']);
    _startingPrice = castToType<double>(snapshotData['starting_price']);
    _minimumIncrement = castToType<double>(snapshotData['minimum_increment']);
    _endTime = snapshotData['end_time'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _imageUrls = getDataList(snapshotData['image_urls']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('lots');

  static Stream<LotsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => LotsRecord.fromSnapshot(s));

  static Future<LotsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => LotsRecord.fromSnapshot(s));

  static LotsRecord fromSnapshot(DocumentSnapshot snapshot) => LotsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static LotsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      LotsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'LotsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is LotsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createLotsRecordData({
  String? title,
  String? description,
  String? category,
  double? currentBid,
  double? startingPrice,
  double? minimumIncrement,
  DateTime? endTime,
  String? status,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'description': description,
      'category': category,
      'current_bid': currentBid,
      'starting_price': startingPrice,
      'minimum_increment': minimumIncrement,
      'end_time': endTime,
      'status': status,
    }.withoutNulls,
  );

  return firestoreData;
}

class LotsRecordDocumentEquality implements Equality<LotsRecord> {
  const LotsRecordDocumentEquality();

  @override
  bool equals(LotsRecord? e1, LotsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.category == e2?.category &&
        e1?.currentBid == e2?.currentBid &&
        e1?.startingPrice == e2?.startingPrice &&
        e1?.minimumIncrement == e2?.minimumIncrement &&
        e1?.endTime == e2?.endTime &&
        e1?.status == e2?.status &&
        listEquality.equals(e1?.imageUrls, e2?.imageUrls);
  }

  @override
  int hash(LotsRecord? e) => const ListEquality().hash([
        e?.title,
        e?.description,
        e?.category,
        e?.currentBid,
        e?.startingPrice,
        e?.minimumIncrement,
        e?.endTime,
        e?.status,
        const ListEquality().hash(e?.imageUrls)
      ]);

  @override
  bool isValidKey(Object? o) => o is LotsRecord;
}

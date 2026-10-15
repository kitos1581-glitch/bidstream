import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import 'record_helpers.dart';

/// Un lote en subasta.
///
/// Campos que SOLO escribe el servidor (Cloud Functions):
/// current_bid (después de la primera puja), bid_count, highest_bidder_*,
/// winner_*, final_price, status = 'ended', seller_name.
class LotsRecord extends FirestoreRecord {
  LotsRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data);

  // ---- Datos descriptivos ----
  String get title => asString(snapshotData['title']);
  String get description => asString(snapshotData['description']);
  String get category => asString(snapshotData['category']);

  /// new | like_new | used_good | used_fair | for_parts
  String get condition => asString(snapshotData['condition']);

  /// Métodos con los que el ganador puede pagar (los fija el servidor).
  List<String> get paymentOptions {
    final raw = snapshotData['payment_options'];
    return raw is List ? raw.map((e) => '$e').toList() : const ['mercadopago'];
  }

  /// true si ya se generó una referencia SPEI (los datos se piden al servidor).
  bool get hasSpeiReference => asString(snapshotData['spei_charge_id']).isNotEmpty;

  /// Características declaradas por el vendedor (ver lot_specs.dart).
  Map<String, String> get specs {
    final raw = snapshotData['specs'];
    if (raw is! Map) return const {};
    return {for (final e in raw.entries) '${e.key}': '${e.value}'};
  }
  List<String> get imageUrls => asStringList(snapshotData['image_urls']);
  String get firstImage => imageUrls.isEmpty ? '' : imageUrls.first;

  // ---- Precio ----
  double get startingPrice => asDouble(snapshotData['starting_price']);
  double get currentBid => asDouble(snapshotData['current_bid']);
  double get minimumIncrement => asDouble(snapshotData['minimum_increment']);
  int get bidCount => asInt(snapshotData['bid_count']);
  double? get finalPrice => snapshotData['final_price'] == null
      ? null
      : asDouble(snapshotData['final_price']);

  // ---- Tiempo y estado ----
  DateTime? get startTime => asDate(snapshotData['start_time']);
  DateTime? get endTime => asDate(snapshotData['end_time']);
  DateTime? get createdTime => asDate(snapshotData['created_time']);

  /// 'active' | 'ended'
  String get status => asString(snapshotData['status']);

  /// 'timed' (por tiempo) | 'live' (con transmisión en vivo)
  String get format => asString(snapshotData['format'], 'timed');
  String get streamUrl => asString(snapshotData['stream_url']);

  // ---- Pago del ganador (lo controla el servidor) ----
  /// none | processing | pending | paid | forfeited | payment_error
  String get paymentStatus => asString(snapshotData['payment_status'], 'none');
  String get winnerPaymentUrl => asString(snapshotData['winner_payment_url']);
  double get amountDue => asDouble(snapshotData['amount_due']);
  DateTime? get paymentDueTime => asDate(snapshotData['payment_due_time']);
  bool get isCancelled => status == 'cancelled';
  String get cancelReason => asString(snapshotData['cancel_reason']);

  // ---- Personas ----
  String get sellerUid => asString(snapshotData['seller_uid']);
  String get sellerName => asString(snapshotData['seller_name'], 'Vendedor');
  String get highestBidderUid => asString(snapshotData['highest_bidder_uid']);
  String get highestBidderName => asString(snapshotData['highest_bidder_name']);
  String get winnerUid => asString(snapshotData['winner_uid']);
  String get winnerName => asString(snapshotData['winner_name']);

  // ---- Lógica de ayuda (la validación real está en el servidor) ----
  bool get isLiveFormat => format == 'live';

  bool hasStarted([DateTime? now]) =>
      startTime == null || !(now ?? DateTime.now()).isBefore(startTime!);

  bool isEnded([DateTime? now]) =>
      status != 'active' ||
      endTime == null ||
      !(now ?? DateTime.now()).isBefore(endTime!);

  bool isOpenForBids([DateTime? now]) => hasStarted(now) && !isEnded(now);

  /// En vivo ahora: formato en vivo, ya empezó y no ha terminado.
  bool isLiveNow([DateTime? now]) => isLiveFormat && isOpenForBids(now);

  /// La siguiente puja mínima. Igual que `minimumNextBid` del servidor.
  double get minimumNextBid =>
      bidCount == 0 ? currentBid : currentBid + minimumIncrement;

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('lots');

  static Stream<LotsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => LotsRecord.fromSnapshot(s));

  static Future<LotsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => LotsRecord.fromSnapshot(s));

  /// Lote de demostración (no existe en Firestore; id empieza con "demo-").
  bool get isDemo => reference.id.startsWith('demo-');

  /// Construye un lote desde datos en memoria (lotes de demostración).
  static LotsRecord fromMap(DocumentReference ref, Map<String, dynamic> data) =>
      LotsRecord._(ref, mapFromFirestore(data));

  static LotsRecord fromSnapshot(DocumentSnapshot snapshot) => LotsRecord._(
        snapshot.reference,
        mapFromFirestore((snapshot.data() as Map<String, dynamic>?) ?? {}),
      );

  @override
  String toString() =>
      'LotsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is LotsRecord && reference.path == other.reference.path;
}

/// Datos para crear un lote nuevo. Cumple con firestore.rules.
Map<String, dynamic> createLotsRecordData({
  required String title,
  required String description,
  required String category,
  required double startingPrice,
  required double minimumIncrement,
  required DateTime startTime,
  required DateTime endTime,
  required String format,
  required String condition,
  required String sellerUid,
  required List<String> imageUrls,
  String streamUrl = '',
}) =>
    {
      'title': title,
      'description': description,
      'category': category,
      'starting_price': startingPrice,
      'current_bid': startingPrice,
      'minimum_increment': minimumIncrement,
      'bid_count': 0,
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'status': 'active',
      'format': format,
      'condition': condition,
      'stream_url': streamUrl,
      'seller_uid': sellerUid,
      'image_urls': imageUrls,
      'created_time': FieldValue.serverTimestamp(),
    };

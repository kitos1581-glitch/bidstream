import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversores tolerantes: si un campo falta o viene con otro tipo,
/// regresan un valor seguro en lugar de tronar la app.

String asString(dynamic v, [String fallback = '']) =>
    v is String ? v : (v == null ? fallback : v.toString());

double asDouble(dynamic v) => v is num ? v.toDouble() : 0.0;

int asInt(dynamic v) => v is num ? v.toInt() : 0;

bool asBool(dynamic v) => v == true;

DateTime? asDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  return null;
}

List<String> asStringList(dynamic v) =>
    v is Iterable ? v.whereType<String>().toList() : const <String>[];

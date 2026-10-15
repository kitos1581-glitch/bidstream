import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Sube bytes a Storage con un límite de tiempo. Por defecto Firebase
/// reintenta hasta 10 minutos si algo falla (reglas, bucket inexistente,
/// sin conexión) y la pantalla parece trabada. Aquí se corta a los
/// [timeout] segundos con un mensaje claro.
Future<void> uploadWithTimeout(
  Reference ref,
  Uint8List bytes,
  String contentType, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 20));
  final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
  try {
    await task.timeout(timeout);
  } on TimeoutException {
    await task.cancel();
    throw UploadException(
        'La foto no se pudo subir (tiempo agotado). Revisa tu conexión o '
        'intenta más tarde; si sigue pasando, el almacenamiento del servidor '
        'aún no está configurado.');
  } on FirebaseException catch (e) {
    if (e.code == 'unauthorized' || e.code == 'permission-denied') {
      throw UploadException('El servidor no permite subir esta foto todavía '
          '(reglas de almacenamiento no publicadas).');
    }
    if (e.code == 'retry-limit-exceeded' || e.code == 'bucket-not-found') {
      throw UploadException('El almacenamiento del servidor no respondió. '
          'Intenta más tarde.');
    }
    rethrow;
  }
}

/// Error de subida con mensaje listo para mostrar al usuario.
class UploadException implements Exception {
  const UploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

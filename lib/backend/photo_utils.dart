import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Deja la foto lista para subir y para la IA: máximo 1600 px y JPEG.
///
/// En el navegador, image_picker no comprime PNG (la "calidad" solo aplica a
/// JPEG), así que una imagen PNG o una foto pesada puede pasar de 1.5 MB y la
/// IA la rechaza ("Una foto es demasiado grande"). Aquí se reconvierte.
/// Si algo falla, regresa la foto original.
(Uint8List, String) prepareLotPhoto(Uint8List bytes, String mime) {
  const maxSide = 1600;
  const smallEnough = 900 * 1024;
  if (bytes.lengthInBytes <= smallEnough && mime == 'image/jpeg') return (bytes, mime);
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return (bytes, mime);
    var out = decoded;
    if (decoded.width > maxSide || decoded.height > maxSide) {
      out = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxSide)
          : img.copyResize(decoded, height: maxSide);
    }
    var quality = 82;
    var jpg = Uint8List.fromList(img.encodeJpg(out, quality: quality));
    while (jpg.lengthInBytes > 1200 * 1024 && quality > 50) {
      quality -= 12;
      jpg = Uint8List.fromList(img.encodeJpg(out, quality: quality));
    }
    return (jpg, 'image/jpeg');
  } catch (_) {
    return (bytes, mime);
  }
}

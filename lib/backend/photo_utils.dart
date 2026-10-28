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

/// "Mejorar foto": la MISMA foto con mejor luz. No cambia el producto ni el
/// fondo (eso engañaría al comprador). Pasos: orientación correcta, estirar
/// niveles (quita lo opaco/oscuro sin quemar), un poco de contraste y color.
/// Regresa JPEG; si algo falla, la original.
Uint8List enhanceLotPhoto(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    var im = img.bakeOrientation(decoded);
    // Histograma de luminancia para niveles automáticos (1 % – 99 %).
    final hist = List<int>.filled(256, 0);
    var total = 0;
    for (final p in im) {
      final l = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
      hist[l]++;
      total++;
    }
    int pct(double q) {
      final target = total * q;
      var acc = 0;
      for (var i = 0; i < 256; i++) {
        acc += hist[i];
        if (acc >= target) return i;
      }
      return 255;
    }
    final lo = pct(0.01);
    final hi = pct(0.99);
    if (hi - lo > 20 && (lo > 4 || hi < 251)) {
      final scale = 255 / (hi - lo);
      for (final p in im) {
        p.r = ((p.r - lo) * scale).clamp(0, 255);
        p.g = ((p.g - lo) * scale).clamp(0, 255);
        p.b = ((p.b - lo) * scale).clamp(0, 255);
      }
    }
    im = img.adjustColor(im, contrast: 1.06, saturation: 1.08);
    return Uint8List.fromList(img.encodeJpg(im, quality: 85));
  } catch (_) {
    return bytes;
  }
}

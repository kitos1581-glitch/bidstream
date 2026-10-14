import 'package:flutter_test/flutter_test.dart';

import 'package:bid_stream/ui/ui_kit.dart';
import 'package:bid_stream/ui/youtube.dart';
import 'package:bid_stream/ui/clabe.dart';

void main() {
  group('youtubeIdFrom', () {
    test('reconoce los formatos comunes de YouTube', () {
      expect(youtubeIdFrom('https://www.youtube.com/watch?v=abc123XYZ'), 'abc123XYZ');
      expect(youtubeIdFrom('https://youtu.be/abc123XYZ'), 'abc123XYZ');
      expect(youtubeIdFrom('https://youtube.com/live/abc123XYZ?feature=share'), 'abc123XYZ');
      expect(youtubeIdFrom('https://m.youtube.com/watch?v=abc123XYZ'), 'abc123XYZ');
      expect(youtubeIdFrom('https://www.youtube.com/embed/abc123XYZ'), 'abc123XYZ');
    });

    test('regresa null si no es YouTube', () {
      expect(youtubeIdFrom('https://www.facebook.com/live/123'), isNull);
      expect(youtubeIdFrom('no es un enlace'), isNull);
      expect(youtubeIdFrom(''), isNull);
    });
  });

  group('formatos', () {
    test('cuenta regresiva', () {
      expect(formatRemaining(const Duration(hours: 2, minutes: 5, seconds: 9)), '02:05:09');
      expect(formatRemaining(const Duration(days: 1, hours: 3)), '1d 03:00:00');
      expect(formatRemaining(const Duration(seconds: -1)), 'Terminada');
    });

    test('dinero en pesos', () {
      expect(formatMoney(14500), '\$14,500');
      expect(formatMoney(99.5), '\$99.50');
    });
  });

  group('CLABE', () {
    test('acepta una CLABE con dígito verificador correcto', () {
      expect(isValidClabe('032180000118359719'), isTrue);
      expect(isValidClabe('0321 8000 0118 3597 19'), isTrue);
    });
    test('rechaza dígito verificador o longitud incorrecta', () {
      expect(isValidClabe('032180000118359718'), isFalse);
      expect(isValidClabe('12345'), isFalse);
      expect(isValidClabe('03218000011835971A'), isFalse);
    });
  });
}

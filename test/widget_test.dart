import 'package:flutter/material.dart';
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

  group('Fase de la subasta (LotPhaseBuilder)', () {
    final now = DateTime(2026, 10, 14, 12);
    test('próximo cambio: primero el inicio, luego el cierre', () {
      final start = now.add(const Duration(minutes: 5));
      final end = now.add(const Duration(hours: 1));
      expect(nextPhaseChange(start, end, now), start);
      expect(nextPhaseChange(start, end, start.add(const Duration(seconds: 1))), end);
    });
    test('sin cambios futuros: null (no programa nada)', () {
      final past = now.subtract(const Duration(minutes: 1));
      expect(nextPhaseChange(past, past, now), isNull);
      expect(nextPhaseChange(null, null, now), isNull);
    });
  });

  group('Mensajes de error', () {
    test('traduce permisos y conexión', () {
      expect(friendlyError('[cloud_firestore/permission-denied] x'), contains('permiso'));
      expect(friendlyError('[cloud_firestore/unavailable] x'), contains('conexión'));
      expect(friendlyError('otro'), contains('error'));
    });
  });

  testWidgets('LotPhaseBuilder se reconstruye al llegar el cierre sin snapshots',
      (tester) async {
    var builds = 0;
    var fakeNow = DateTime(2026, 10, 14, 12);
    final end = fakeNow.add(const Duration(seconds: 2));
    await tester.pumpWidget(MaterialApp(
      home: LotPhaseBuilder(
        start: null,
        end: end,
        clock: () => fakeNow,
        builder: (_) {
          builds++;
          return const SizedBox();
        },
      ),
    ));
    expect(builds, 1);
    fakeNow = fakeNow.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(builds, 2);
    // Ya no hay cambios futuros: no se vuelve a reconstruir.
    await tester.pump(const Duration(seconds: 10));
    expect(builds, 2);
  });
}

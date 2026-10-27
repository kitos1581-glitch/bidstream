import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resultado de intentar crear el depósito de garantía.
class DepositIntent {
  const DepositIntent({required this.initPoint, required this.amount});

  /// URL del checkout de Mercado Pago (web y móvil vía navegador).
  final String initPoint;
  final double amount;
}

/// Método con el que el ganador liquida el lote.
enum FinalPaymentMethod { mercadopago, spei }

/// Respuesta tipada de chooseWinnerPaymentMethod.
class FinalPaymentChoice {
  const FinalPaymentChoice._({
    required this.method,
    required this.amount,
    this.url = '',
    this.clabe = '',
    this.bank = '',
    this.reference = '',
    this.dueTime,
  });

  factory FinalPaymentChoice.fromMap(Map<String, dynamic> d) {
    final method = d['method'] == 'spei'
        ? FinalPaymentMethod.spei
        : FinalPaymentMethod.mercadopago;
    return FinalPaymentChoice._(
      method: method,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      url: (d['url'] ?? '').toString(),
      clabe: (d['clabe'] ?? '').toString(),
      bank: (d['bank'] ?? '').toString(),
      reference: (d['reference'] ?? '').toString(),
      dueTime: DateTime.tryParse((d['dueTime'] ?? '').toString())?.toLocal(),
    );
  }

  final FinalPaymentMethod method;
  final double amount;
  final String url; // Mercado Pago
  final String clabe; // SPEI
  final String bank;
  final String reference;
  final DateTime? dueTime;
}

/// Error tipado de pagos: [code] viene del servidor (ERROR_CODES de spei.js).
class PaymentFailure implements Exception {
  const PaymentFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Todo lo relacionado con pagos pasa por aquí.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Genera la preferencia de depósito en Mercado Pago y devuelve la URL
  /// del checkout para abrirla con [openCheckout].
  Future<DepositIntent> createDeposit() async {
    final res =
        await _functions.httpsCallable('createDeposit').call<dynamic>({});
    final data = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : const <String, dynamic>{};
    final url = (data['initPoint'] ?? '').toString();
    if (url.isEmpty) {
      throw StateError('Mercado Pago no devolvió un enlace de pago.');
    }
    return DepositIntent(
      initPoint: url,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Pide el reembolso del depósito. El servidor valida que el usuario no
  /// esté ganando ninguna subasta activa ni deba pagos pendientes.
  /// Devuelve el monto reembolsado.
  Future<double> requestDepositRefund() async {
    final res =
        await _functions.httpsCallable('requestDepositRefund').call<dynamic>({});
    final data = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : const <String, dynamic>{};
    return (data['amount'] as num?)?.toDouble() ?? 0;
  }

  /// El ganador elige cómo pagar. SPEI devuelve CLABE y referencia (siempre
  /// la misma para el lote); Mercado Pago devuelve la liga del checkout.
  Future<FinalPaymentChoice> chooseFinalPayment(
      String lotId, FinalPaymentMethod method) async {
    try {
      final res = await _functions
          .httpsCallable('chooseWinnerPaymentMethod')
          .call<dynamic>({'lotId': lotId, 'method': method.name});
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      if (data['ok'] != true) {
        throw const PaymentFailure('BAD_RESPONSE', 'Respuesta inesperada del servidor.');
      }
      return FinalPaymentChoice.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const {};
      throw PaymentFailure(
        (details['code'] ?? e.code).toString(),
        e.message ?? 'No se pudo preparar el pago. Intenta de nuevo.',
      );
    }
  }

  /// Responde a una "segunda oportunidad" (el ganador no pagó y el lote se
  /// le ofrece al subcampeón por su máximo). Devuelve true si aceptó.
  Future<bool> respondSecondChance(String lotId, {required bool accept}) async {
    try {
      final res = await _functions
          .httpsCallable('respondSecondChance')
          .call<dynamic>({'lotId': lotId, 'accept': accept});
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : const <String, dynamic>{};
      return data['accepted'] == true;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const {};
      throw PaymentFailure((details['code'] ?? e.code).toString(), e.message ?? 'No se pudo responder.');
    }
  }

  /// El ganador elige cómo recibir el artículo (si el vendedor ofrece ambas
  /// modalidades). Con envío, el costo se suma al pago.
  Future<double> chooseDelivery(String lotId, String mode, {String destination = ''}) async {
    try {
      final res = await _functions.httpsCallable('chooseDelivery').call<dynamic>(
          {'lotId': lotId, 'mode': mode, if (destination.isNotEmpty) 'destination': destination});
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : const <String, dynamic>{};
      return (data['amountDue'] as num?)?.toDouble() ?? 0;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const {};
      throw PaymentFailure((details['code'] ?? e.code).toString(), e.message ?? 'No se pudo guardar la entrega.');
    }
  }

  /// Código de entrega en persona del comprador (solo él lo puede leer).
  Stream<String?> deliveryCode(String lotId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('delivery_codes')
        .doc(lotId)
        .snapshots()
        .map((s) => s.exists ? (s.data()!['code'] ?? '').toString() : null);
  }

  /// El vendedor captura el código que le dio el comprador al entregar:
  /// su pago se libera al instante.
  Future<void> confirmDeliveryCode(String lotId, String code) async {
    try {
      await _functions
          .httpsCallable('confirmDeliveryCode')
          .call<dynamic>({'lotId': lotId, 'code': code});
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const {};
      throw PaymentFailure((details['code'] ?? e.code).toString(), e.message ?? 'No se pudo confirmar la entrega.');
    }
  }

  /// El comprador confirma que recibió el artículo: libera el pago al vendedor.
  Future<void> confirmReceipt(String lotId) async {
    try {
      await _functions.httpsCallable('confirmReceipt').call<dynamic>({'lotId': lotId});
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const {};
      throw PaymentFailure((details['code'] ?? e.code).toString(), e.message ?? 'No se pudo confirmar.');
    }
  }

  /// Abre el checkout de Mercado Pago. En móvil abre el navegador (o la
  /// app de MP si está instalada); en web, una pestaña nueva.
  /// En web se abre en la MISMA pestaña: Safari (iPhone) y otros navegadores
  /// bloquean una pestaña nueva que se abre después de esperar al servidor
  /// (no la cuentan como clic del usuario) y el botón "no hacía nada".
  Future<bool> openCheckout(String url) => launchUrl(
        Uri.parse(url),
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
}

/// Estados posibles del depósito (users/{uid}.deposit.status).
class DepositStatus {
  static const none = 'none'; // sin depósito
  static const held = 'held'; // retenido: puede pujar
  static const applied = 'applied'; // aplicado a una compra ganada
  static const refunded = 'refunded'; // devuelto al postor
  static const forfeited = 'forfeited'; // incumplió un pago: se lo dio al vendedor
}

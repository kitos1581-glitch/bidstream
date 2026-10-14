import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resultado de intentar crear el depósito de garantía.
class DepositIntent {
  const DepositIntent({required this.initPoint, required this.amount});

  /// URL del checkout de Mercado Pago (web y móvil vía navegador).
  final String initPoint;
  final double amount;
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

  /// Abre el checkout de Mercado Pago. En móvil abre el navegador (o la
  /// app de MP si está instalada); en web, una pestaña nueva.
  Future<bool> openCheckout(String url) => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
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

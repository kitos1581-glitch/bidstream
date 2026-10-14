import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../backend/auction_service.dart';
import '../../backend/payment_service.dart';
import '../../backend/schema/users_record.dart';

/// Depósito de garantía para poder pujar.
///
/// Muestra el estado actual (sin depósito / retenido / reembolsable) y
/// permite pagarlo (checkout de Mercado Pago) o pedir el reembolso.
///
/// La pantalla es auto-contenida: no depende del UI kit de FlutterFlow,
/// así que puedes abrirla desde cualquier botón:
///
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => const DepositGarantiaWidget(),
/// ));
/// ```
class DepositGarantiaWidget extends StatefulWidget {
  const DepositGarantiaWidget({super.key});

  @override
  State<DepositGarantiaWidget> createState() => _DepositGarantiaWidgetState();
}

class _DepositGarantiaWidgetState extends State<DepositGarantiaWidget> {
  bool _busy = false;
  String? _error;
  String? _info;

  Future<void> _payDeposit() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final intent = await PaymentService.instance.createDeposit();
      await PaymentService.instance.openCheckout(intent.initPoint);
      setState(() => _info =
          'Se abrió Mercado Pago. Al aprobar tu pago podrás pujar (tarda unos segundos en reflejarse).');
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'No se pudo iniciar el pago.');
    } catch (_) {
      setState(() => _error = 'Sin conexión con el servidor. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestRefund() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final amount = await PaymentService.instance.requestDepositRefund();
      setState(() => _info =
          'Reembolso de \$$amount solicitado. Mercado Pago lo devuelve en 3-15 días hábiles según el método de pago.');
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'No se pudo solicitar el reembolso.');
    } catch (_) {
      setState(() => _error = 'Sin conexión con el servidor. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Depósito de garantía')),
      body: StreamBuilder<UsersRecord?>(
        stream: AuctionService.instance.myProfile(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final deposit = user?.snapshotData?['deposit'];
          final status = deposit?['status']?.toString() ?? DepositStatus.none;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusCard(status: status, amount: deposit?['amount']),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_info != null)
                Text(_info!, style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 16),
              if (status == DepositStatus.none || status == DepositStatus.refunded)
                FilledButton.icon(
                  onPressed: _busy ? null : _payDeposit,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Dejar depósito y poder pujar'),
                )
              else if (status == DepositStatus.held)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _requestRefund,
                  icon: const Icon(Icons.undo),
                  label: const Text('Pedir reembolso del depósito'),
                )
              else
                const Text(
                  'Tu depósito ya fue aplicado a una compra o transferido por incumplimiento.',
                ),
              if (_busy) const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 24),
              const Text(
                '¿Cómo funciona?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• El depósito se retiene mientras pujas y se aplica si ganas.\n'
                '• Si no ganas, puedes pedirlo de vuelta cuando quieras.\n'
                '• Si ganas, pagas solo la diferencia entre el precio final y tu depósito.\n'
                '• Si ganas y no pagas en 24 horas, pierdes el depósito (se le transfiere al vendedor) y tu cuenta puede suspenderse.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, this.amount});

  final String status;
  final dynamic amount;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      DepositStatus.held => ('Depósito retenido: puedes pujar', Colors.green, Icons.verified_user),
      DepositStatus.applied => ('Depósito aplicado a tu compra', Colors.blue, Icons.check_circle),
      DepositStatus.refunded => ('Depósito reembolsado', Colors.grey, Icons.undo),
      DepositStatus.forfeited => ('Depósito transferido por incumplimiento', Colors.red, Icons.warning),
      _ => ('Sin depósito: aún no puedes pujar', Colors.orange, Icons.lock),
    };
    return Card(
      color: color.withOpacity(0.08),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        subtitle: amount != null ? Text('Monto: \$$amount') : null,
      ),
    );
  }
}

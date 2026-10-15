import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/backend/admin_service.dart';
import '/backend/dispute_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/ui_kit.dart';

/// Panel de administrador: verificaciones, pagos, usuarios y lotes.
/// Solo funciona con el claim admin == true (el servidor lo revisa en
/// cada acción, así que esconder la pantalla no es la única protección).
class AdminPanelWidget extends StatefulWidget {
  const AdminPanelWidget({super.key});

  static String routeName = 'AdminPanel';
  static String routePath = '/adminPanel';

  @override
  State<AdminPanelWidget> createState() => _AdminPanelWidgetState();
}

class _AdminPanelWidgetState extends State<AdminPanelWidget> {
  late final Future<bool> _isAdmin = AdminService.instance.isAdmin(refresh: true);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return FutureBuilder<bool>(
      future: _isAdmin,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(backgroundColor: theme.primaryBackground, body: const Loading());
        }
        if (snap.data != true) {
          return Scaffold(
            backgroundColor: theme.primaryBackground,
            appBar: AppBar(backgroundColor: theme.primaryBackground, foregroundColor: theme.primaryText, elevation: 0),
            body: const EmptyState(icon: Icons.lock_outline, title: 'Solo administradores'),
          );
        }
        return DefaultTabController(
          length: 5,
          child: Scaffold(
            backgroundColor: theme.primaryBackground,
            appBar: AppBar(
              backgroundColor: theme.primaryBackground,
              foregroundColor: theme.primaryText,
              elevation: 0,
              title: Text('Administración',
                  style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
              bottom: TabBar(
                isScrollable: true,
                labelColor: theme.primary,
                unselectedLabelColor: theme.secondaryText,
                indicatorColor: theme.primary,
                tabs: const [
                  Tab(text: 'Reclamos'),
                  Tab(text: 'Identidad'),
                  Tab(text: 'Pagos'),
                  Tab(text: 'Usuarios'),
                  Tab(text: 'Lotes'),
                ],
              ),
            ),
            body: const TabBarView(children: [
              _DisputesTab(),
              _VerificationsTab(),
              _PaymentsTab(),
              _UsersTab(),
              _LotsTab(),
            ]),
          ),
        );
      },
    );
  }
}

/// Pide un texto (motivo, referencia...). Regresa null si se cancela.
Future<String?> _askText(BuildContext context, String title, String hint) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(c, ctrl.text.trim()),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return (r == null || r.isEmpty) ? null : r;
}

Future<void> _run(BuildContext context, Future<void> Function() action, String ok) async {
  try {
    await action();
    if (context.mounted) showMessage(context, ok);
  } catch (e) {
    if (context.mounted) showMessage(context, 'Error: $e', error: true);
  }
}

// =====================================================================
// Verificaciones de identidad
// =====================================================================
class _VerificationsTab extends StatelessWidget {
  const _VerificationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VerificationRequest>>(
      stream: AdminService.instance.pendingVerifications(),
      builder: (context, snap) {
        if (snap.hasError) return EmptyState(icon: Icons.error_outline, title: '${snap.error}');
        if (!snap.hasData) return const Loading();
        final items = snap.data!;
        if (items.isEmpty) {
          return const EmptyState(icon: Icons.verified_outlined, title: 'Sin solicitudes pendientes');
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final r in items) _VerificationCard(req: r)],
        );
      },
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.req});
  final VerificationRequest req;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    const labels = {'ine_front': 'INE frente', 'ine_back': 'INE reverso', 'selfie': 'Selfie'};
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(req.fullName.isEmpty ? req.uid : req.fullName, style: theme.titleSmall),
        Text('${req.email} · enviado ${timeAgo(req.submitted)}', style: theme.bodySmall),
        const SizedBox(height: 8),
        Text('Revisa: el nombre de la INE coincide con el perfil, la selfie es la misma persona y la INE está vigente.',
            style: theme.bodySmall.copyWith(color: theme.secondaryText)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final key in ['ine_front', 'ine_back', 'selfie'])
            if (req.files[key] != null)
              FutureBuilder<String>(
                future: AdminService.instance.fileUrl(req.files[key]!),
                builder: (context, s) => InkWell(
                  onTap: s.hasData
                      ? () => showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              child: InteractiveViewer(child: Image.network(s.data!)),
                            ),
                          )
                      : null,
                  child: Column(children: [
                    SizedBox(
                      width: 140,
                      height: 100,
                      child: s.hasData
                          ? Image.network(s.data!, fit: BoxFit.cover)
                          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    Text(labels[key]!, style: theme.labelSmall),
                  ]),
                ),
              ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final reason = await _askText(context, 'Motivo del rechazo', 'Ej. INE borrosa');
                if (reason == null || !context.mounted) return;
                await _run(
                    context,
                    () => AdminService.instance.reviewVerification(req.uid, approve: false, reason: reason),
                    'Rechazada');
              },
              child: const Text('Rechazar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => _run(context,
                  () => AdminService.instance.reviewVerification(req.uid, approve: true), 'Aprobada'),
              child: const Text('Aprobar'),
            ),
          ),
        ]),
      ]),
    );
  }
}

// =====================================================================
// Pagos: transferencias a vendedores, cobros fallidos, reembolsos fallidos
// =====================================================================
class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      const SectionTitle('Transferir a vendedores'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Transfiere desde tu cuenta de Mercado Pago o banco y registra aquí la referencia (clave de rastreo SPEI o folio).',
          style: theme.bodySmall.copyWith(color: theme.secondaryText),
        ),
      ),
      StreamBuilder<List<PaymentDoc>>(
        stream: AdminService.instance.readyPayouts(),
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(icon: Icons.error_outline, title: '${snap.error}');
          if (!snap.hasData) return const Loading();
          if (snap.data!.isEmpty) {
            return const EmptyState(icon: Icons.check_circle_outline, title: 'Nada pendiente de transferir');
          }
          return Column(children: [
            for (final p in snap.data!)
              _Row(
                title: '${formatMoney(p.amount)} · ${p.reason == 'deposit_forfeit' ? 'Compensación por depósito' : 'Venta'}',
                subtitle: 'Lote ${p.lotId} · ${timeAgo(p.created)}',
                extra: _SellerBankInfo(uid: p.uid),
                action: 'Marcar enviado',
                onTap: () async {
                  final ref = await _askText(context, 'Referencia de la transferencia', 'Clave de rastreo / folio');
                  if (ref == null || !context.mounted) return;
                  await _run(context, () => AdminService.instance.markPayoutSent(p.id, ref), 'Registrado');
                },
              ),
          ]);
        },
      ),
      const SectionTitle('Retenidas (esperando la entrega)'),
      StreamBuilder<List<PaymentDoc>>(
        stream: AdminService.instance.heldPayouts(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error);
          if (!snap.hasData) return const Loading();
          if (snap.data!.isEmpty) {
            return const EmptyState(icon: Icons.hourglass_empty, title: 'Nada retenido');
          }
          return Column(children: [
            for (final p in snap.data!)
              _Row(
                title: '${formatMoney(p.amount)} · ${p.status == 'on_hold' ? 'En disputa' : 'Esperando entrega'}',
                subtitle: 'Lote ${p.lotId} · se libera al confirmar el comprador o por plazo',
                onOpen: () => context.pushNamed('LotDetailView', queryParameters: {'lotId': p.lotId}),
              ),
          ]);
        },
      ),
      const SectionTitle('Liquidaciones en revisión'),
      StreamBuilder<List<PaymentDoc>>(
        stream: AdminService.instance.payoutsNeedingReview(),
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(icon: Icons.error_outline, title: '${snap.error}');
          if (!snap.hasData) return const Loading();
          if (snap.data!.isEmpty) {
            return const EmptyState(icon: Icons.check_circle_outline, title: 'Ninguna en revisión');
          }
          return Column(children: [
            for (final p in snap.data!)
              _Row(
                title: 'Venta de ${formatMoney((p.data['final_price'] as num?)?.toDouble() ?? 0)} · lote ${p.lotId}',
                subtitle: '${p.data['error'] ?? ''}\nCorrige la configuración de comisiones, redespliega y recalcula.',
                action: 'Recalcular',
                onTap: () => _run(context, () => AdminService.instance.recalculatePayout(p.id), 'Liquidación lista'),
              ),
          ]);
        },
      ),
      const SectionTitle('Cobros que fallaron al generarse'),
      StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: AdminService.instance.paymentErrors(),
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          if (snap.data!.isEmpty) {
            return const EmptyState(icon: Icons.check_circle_outline, title: 'Sin errores');
          }
          return Column(children: [
            for (final d in snap.data!)
              _Row(
                title: (d.data()['title'] ?? d.id).toString(),
                subtitle: 'Precio final ${formatMoney((d.data()['current_bid'] as num?)?.toDouble() ?? 0)}',
                action: 'Reintentar cobro',
                onTap: () => _run(context, () => AdminService.instance.retryWinnerPayment(d.id), 'Cobro generado'),
              ),
          ]);
        },
      ),
      const SectionTitle('Reembolsos que fallaron'),
      StreamBuilder<List<PaymentDoc>>(
        stream: AdminService.instance.failedRefunds(),
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          if (snap.data!.isEmpty) {
            return const EmptyState(icon: Icons.check_circle_outline, title: 'Sin reembolsos fallidos');
          }
          return Column(children: [
            for (final p in snap.data!)
              _Row(
                title: 'Pago MP ${p.data['mp_payment_id']} · ${p.reason}',
                subtitle: 'Hazlo manual desde el panel de Mercado Pago. ${p.data['error'] ?? ''}',
              ),
          ]);
        },
      ),
    ]);
  }
}

// =====================================================================
// Usuarios: buscar por correo, suspender / reactivar
// =====================================================================
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _email = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _results;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final r = await AdminService.instance.findUsersByEmail(_email.text);
    setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(hintText: 'Correo exacto del usuario'),
          ),
        ),
        IconButton(icon: const Icon(Icons.search), onPressed: _search),
      ]),
      const SizedBox(height: 12),
      if (_results != null && _results!.isEmpty) const EmptyState(icon: Icons.person_off_outlined, title: 'No encontrado'),
      for (final d in _results ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
        Builder(builder: (context) {
          final u = d.data();
          final banned = u['banned'] == true;
          final dep = u['deposit'] is Map ? (u['deposit']['status'] ?? 'none') : 'none';
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${u['full_name'] ?? ''}', style: theme.titleSmall),
              Text('${u['email'] ?? ''} · tel ${u['phone'] ?? '—'} · ${u['city'] ?? ''}', style: theme.bodySmall),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Tag(u['verified'] == true ? 'INE verificada' : 'Sin verificar'),
                Tag('Depósito: $dep'),
                Tag('Strikes: ${u['strikes'] ?? 0}'),
                Tag('Strikes vendedor: ${u['seller_strikes'] ?? 0}'),
                if (u['seller_plan'] == 'store')
                  Tag('Tienda Oficial: ${u['store_name'] ?? ''}'
                      '${u['store_plan_until'] is Timestamp ? ' hasta ${formatDateTime((u['store_plan_until'] as Timestamp).toDate())}' : ''}'),
                if (banned) Tag('Suspendido', background: theme.error, foreground: Colors.white),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(u['seller_plan'] == 'store' ? 'Renovar tienda' : 'Hacer Tienda Oficial'),
                  onPressed: () async {
                    final name = await _askText(context, 'Nombre de la tienda', 'Ej. Ferretería López');
                    if (name == null || !context.mounted) return;
                    final m = await _askText(context, 'Meses de membresía (1 a 24)', 'Ej. 12');
                    final months = int.tryParse(m ?? '');
                    if (months == null || !context.mounted) return;
                    await _run(context, () => AdminService.instance.setStorePlan(d.id, months, storeName: name),
                        'Membresía actualizada');
                    _search();
                  },
                ),
                if (u['seller_plan'] == 'store')
                  TextButton(
                    onPressed: () async {
                      await _run(context, () => AdminService.instance.setStorePlan(d.id, 0), 'Membresía cancelada');
                      _search();
                    },
                    child: const Text('Cancelar tienda'),
                  ),
              ]),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: banned
                    ? OutlinedButton(
                        onPressed: () async {
                          await _run(context, () => AdminService.instance.setBan(d.id, banned: false), 'Reactivado');
                          _search();
                        },
                        child: const Text('Reactivar'))
                    : OutlinedButton(
                        onPressed: () async {
                          final reason = await _askText(context, 'Motivo de la suspensión', 'Ej. fraude');
                          if (reason == null || !context.mounted) return;
                          await _run(context,
                              () => AdminService.instance.setBan(d.id, banned: true, reason: reason), 'Suspendido');
                          _search();
                        },
                        child: const Text('Suspender')),
              ),
            ]),
          );
        }),
    ]);
  }
}

// =====================================================================
// Lotes activos: cancelar por fraude o contenido prohibido
// =====================================================================
class _LotsTab extends StatelessWidget {
  const _LotsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('lots')
          .where('status', isEqualTo: 'active')
          .orderBy('end_time')
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return EmptyState(icon: Icons.error_outline, title: '${snap.error}');
        if (!snap.hasData) return const Loading();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Sin subastas activas');
        return ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
          for (final d in docs)
            _Row(
              title: (d.data()['title'] ?? '').toString(),
              subtitle:
                  '${d.data()['category'] ?? ''} · ${formatMoney((d.data()['current_bid'] as num?)?.toDouble() ?? 0)} · vende ${d.data()['seller_name'] ?? ''}',
              action: 'Cancelar',
              onOpen: () => context.pushNamed('LotDetailView', queryParameters: {'lotId': d.id}),
              onTap: () async {
                final reason = await _askText(context, 'Motivo de la cancelación', 'Ej. artículo prohibido');
                if (reason == null || !context.mounted) return;
                await _run(context, () => AdminService.instance.cancelLot(d.id, reason), 'Subasta cancelada');
              },
            ),
        ]);
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    this.action,
    this.onTap,
    this.onOpen,
    this.extra,
  });
  final Widget? extra;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.titleSmall),
              Text(subtitle, style: theme.bodySmall),
              if (extra != null) extra!,
            ]),
          ),
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
        ]),
      ),
    );
  }
}

/// Datos bancarios del vendedor para hacerle la transferencia.
class _SellerBankInfo extends StatelessWidget {
  const _SellerBankInfo({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, s) {
        final u = s.data?.data() ?? const <String, dynamic>{};
        final clabe = (u['payout_clabe'] ?? '').toString();
        return SelectableText(
          clabe.isEmpty
              ? '${u['full_name'] ?? uid} · SIN CLABE registrada (pídesela: ${u['phone'] ?? ''})'
              : '${u['payout_holder'] ?? u['full_name'] ?? ''} · CLABE $clabe',
          style: theme.bodySmall.copyWith(
              fontWeight: FontWeight.w700, color: clabe.isEmpty ? theme.error : theme.primaryText),
        );
      },
    );
  }
}


/// Reclamos de compradores: ver pruebas y resolver (reembolso total,
/// parcial o rechazar). El servidor mueve el dinero con idempotencia.
class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Dispute>>(
      stream: DisputeService.instance.pending(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Loading();
        final list = snap.data!;
        if (list.isEmpty) {
          return const EmptyState(icon: Icons.verified_user_outlined, title: 'Sin reclamos pendientes');
        }
        return ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
          for (final d in list)
            _Row(
              title: '${d.lotTitle} · ${formatMoney(d.finalPrice)}',
              subtitle:
                  '${kDisputeReasons[d.reason] ?? d.reason}${d.status == 'refund_failed' ? ' · REEMBOLSO FALLÓ: reintentar' : ''}'
                  '${d.payoutAlreadySent ? ' · ya se pagó al vendedor (habrá clawback)' : ''}\n${d.details}',
              extra: d.photos.isEmpty
                  ? null
                  : Wrap(spacing: 6, children: [
                      for (final p in d.photos)
                        TextButton(
                          onPressed: () async {
                            final url = await AdminService.instance.fileUrl(p);
                            await launchURL(url);
                          },
                          child: const Text('Ver prueba'),
                        ),
                    ]),
              action: 'Resolver',
              onOpen: () => context.pushNamed('LotDetailView', queryParameters: {'lotId': d.id}),
              onTap: () => _resolve(context, d),
            ),
        ]);
      },
    );
  }

  Future<void> _resolve(BuildContext context, Dispute d) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('Reembolso total'),
            subtitle: Text('Se devuelven ${formatMoney(d.finalPrice)} y se cancela la liquidación'),
            onTap: () => Navigator.pop(c, 'refund_full'),
          ),
          ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Reembolso parcial'),
            onTap: () => Navigator.pop(c, 'refund_partial'),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('No procede'),
            subtitle: const Text('Se libera la liquidación al vendedor'),
            onTap: () => Navigator.pop(c, 'reject'),
          ),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    double? amount;
    if (choice == 'refund_partial') {
      final txt = await _askText(context, 'Monto a devolver (MXN)', 'Ej. 1500');
      amount = double.tryParse((txt ?? '').replaceAll(',', ''));
      if (amount == null) return;
    }
    if (!context.mounted) return;
    final note = await _askText(context, 'Nota para el registro', 'Ej. fotos confirman el daño') ?? '';
    if (!context.mounted) return;
    await _run(context, () async {
      try {
        await DisputeService.instance.resolve(d.id, choice, amount: amount, note: note);
      } on DisputeFailure catch (e) {
        throw Exception(e.message);
      }
    }, 'Reclamo resuelto');
  }
}

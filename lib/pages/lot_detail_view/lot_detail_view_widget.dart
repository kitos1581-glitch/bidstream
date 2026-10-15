import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/lot_specs.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/payment_service.dart';
import '/ui/ui_kit.dart';

/// Detalle de un lote: fotos, precio, cuenta regresiva e historial de pujas.
class LotDetailViewWidget extends StatefulWidget {
  const LotDetailViewWidget({super.key, required this.lotId});

  final String lotId;

  static String routeName = 'LotDetailView';
  static String routePath = '/lotDetailView';

  @override
  State<LotDetailViewWidget> createState() => _LotDetailViewWidgetState();
}

class _LotDetailViewWidgetState extends State<LotDetailViewWidget> {
  late Stream<LotsRecord?> _lot = AuctionService.instance.lot(widget.lotId);
  late Stream<List<BidsRecord>> _bids =
      AuctionService.instance.bids(widget.lotId);

  void _retry() => setState(() {
        _lot = AuctionService.instance.lot(widget.lotId);
        _bids = AuctionService.instance.bids(widget.lotId);
      });
  int _photo = 0;

  Future<void> _delete(LotsRecord lot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar este lote?'),
        content: const Text('Solo se puede eliminar si nadie ha pujado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuctionService.instance.deleteLot(lot.reference.id);
      if (!mounted) return;
      showMessage(context, 'Lote eliminado.');
      context.safePop();
    } catch (e) {
      if (mounted) {
        showMessage(context, 'No se pudo eliminar: ya tiene pujas.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<LotsRecord?>(
      stream: _lot,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: theme.primaryBackground,
            appBar: AppBar(backgroundColor: theme.primaryBackground, elevation: 0,
                foregroundColor: theme.primaryText),
            body: ErrorState(error: snap.error, onRetry: _retry),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
              backgroundColor: theme.primaryBackground, body: const Loading());
        }
        final lot = snap.data;
        if (lot == null) {
          return Scaffold(
            backgroundColor: theme.primaryBackground,
            appBar: AppBar(backgroundColor: theme.primaryBackground, elevation: 0,
                foregroundColor: theme.primaryText),
            body: const EmptyState(
                icon: Icons.search_off,
                title: 'Este lote ya no existe',
                message: 'Pudo haber sido eliminado por el vendedor.'),
          );
        }

        // Se reconstruye solo al iniciar/terminar la subasta.
        return LotPhaseBuilder(
          start: lot.startTime,
          end: lot.endTime,
          builder: (context) => _buildLot(context, lot),
        );
      },
    );
  }

  /// Liga para compartir. Con SHARE_BASE_URL (dominio en Firebase Hosting)
  /// usa /l/{id}, que muestra foto y precio en WhatsApp/Facebook; si no,
  /// la dirección actual del lote.
  Future<void> _share(LotsRecord lot) async {
    const base = String.fromEnvironment('SHARE_BASE_URL');
    final url = base.isNotEmpty
        ? '$base/l/${lot.reference.id}'
        : (kIsWeb
            ? Uri.base.toString()
            : '${const String.fromEnvironment('WEB_APP_URL', defaultValue: 'https://kitos1581-glitch.github.io/bidstream')}'
                '/lotDetailView?lotId=${lot.reference.id}');
    await Clipboard.setData(ClipboardData(text: '${lot.title} — $url'));
    if (mounted) showMessage(context, 'Liga copiada. Pégala en WhatsApp o Facebook.');
  }

  Widget _buildLot(BuildContext context, LotsRecord lot) {
    final theme = FlutterFlowTheme.of(context);
    {
        final isSeller = lot.sellerUid == currentUserUid;
        final iAmWinning =
            lot.highestBidderUid.isNotEmpty && lot.highestBidderUid == currentUserUid;
        final open = lot.isOpenForBids();

        return Scaffold(
          backgroundColor: theme.primaryBackground,
          appBar: AppBar(
            backgroundColor: theme.primaryBackground,
            foregroundColor: theme.primaryText,
            elevation: 0,
            title: Text(lot.category.isEmpty ? 'Lote' : lot.category,
                style: theme.titleSmall),
            actions: [
              IconButton(
                tooltip: 'Compartir',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(lot),
              ),
              if (isSeller && lot.bidCount == 0 && lot.status == 'active')
                IconButton(
                  tooltip: 'Eliminar lote',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(lot),
                ),
            ],
          ),
          bottomNavigationBar: _BottomBar(
            lot: lot,
            isSeller: isSeller,
            iAmWinning: iAmWinning,
            open: open,
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // ---------------- Fotos ----------------
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(children: [
                  PageView.builder(
                    itemCount: lot.imageUrls.isEmpty ? 1 : lot.imageUrls.length,
                    onPageChanged: (i) => setState(() => _photo = i),
                    itemBuilder: (_, i) => LotImage(
                        lot.imageUrls.isEmpty ? '' : lot.imageUrls[i],
                        fit: BoxFit.contain),
                  ),
                  if (lot.imageUrls.length > 1)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Tag('${_photo + 1}/${lot.imageUrls.length}'),
                    ),
                  if (lot.isLiveNow())
                    const Positioned(left: 10, top: 10, child: LiveTag()),
                ]),
              ),

              // ---------------- Título y precio ----------------
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lot.title,
                        style: theme.headlineSmall
                            .copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    if (kLotConditions[lot.condition] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Tag(kLotConditions[lot.condition]!,
                            background: lot.condition == 'new'
                                ? theme.surfaceVariant
                                : theme.secondaryBackground),
                      ),
                    Text('Vende: ${lot.sellerName}',
                        style: theme.bodySmall
                            .copyWith(color: theme.secondaryText)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  lot.status == 'ended'
                                      ? 'Precio final'
                                      : (lot.bidCount == 0
                                          ? 'Precio inicial'
                                          : 'Puja actual'),
                                  style: theme.labelSmall),
                              Text(formatMoney(lot.currentBid),
                                  style: theme.headlineSmall.copyWith(
                                      color: theme.primary,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  '${lot.bidCount} ${lot.bidCount == 1 ? 'puja' : 'pujas'}'
                                  ' · incremento ${formatMoney(lot.minimumIncrement)}',
                                  style: theme.bodySmall),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(lot.hasStarted() ? 'Termina en' : '',
                                style: theme.labelSmall),
                            Countdown(
                                lot: lot,
                                style: theme.titleMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                            Text(formatDateTime(lot.endTime),
                                style: theme.bodySmall),
                          ],
                        ),
                      ]),
                    ),
                    if (iAmWinning && lot.status != 'ended') ...[
                      const SizedBox(height: 10),
                      Tag('Vas ganando',
                          background: theme.surfaceVariant,
                          icon: Icons.emoji_events_outlined),
                    ],
                    if (lot.isCancelled) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Subasta cancelada por la plataforma${lot.cancelReason.isEmpty ? '' : ': ${lot.cancelReason}'}.',
                        style: theme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700, color: theme.error),
                      ),
                    ],
                    if (lot.status == 'ended') ...[
                      const SizedBox(height: 10),
                      Text(
                        lot.winnerUid.isEmpty
                            ? 'Terminó sin pujas.'
                            : (currentUserUid.isNotEmpty && lot.winnerUid == currentUserUid
                                ? '¡Ganaste esta subasta!'
                                : 'Ganó ${lot.winnerName}.'),
                        style: theme.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (currentUserUid.isNotEmpty && lot.winnerUid == currentUserUid) ...[
                        const SizedBox(height: 8),
                        _WinnerPaymentBox(lot: lot),
                      ],
                    ],
                    if (lot.isLiveFormat) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Icon(Icons.videocam_outlined, color: theme.tertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lot.hasStarted()
                                ? 'Subasta con transmisión en vivo.'
                                : 'Transmisión en vivo: ${formatDateTime(lot.startTime)}',
                            style: theme.bodyMedium,
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),

              // ---------------- Características ----------------
              if (specRows(lot.category, lot.specs).isNotEmpty) ...[
                const SectionTitle('Características del artículo'),
                _SpecsTable(rows: [
                  if (kLotConditions[lot.condition] != null)
                    ('Estado', kLotConditions[lot.condition]!),
                  ...specRows(lot.category, lot.specs),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    'Datos declarados por el vendedor, que responde por ellos según el reglamento.',
                    style: theme.bodySmall.copyWith(color: theme.secondaryText),
                  ),
                ),
              ],

              // ---------------- Descripción ----------------
              if (lot.description.isNotEmpty) ...[
                const SectionTitle('Descripción'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(lot.description, style: theme.bodyMedium),
                ),
              ],

              // ---------------- Historial ----------------
              const SectionTitle('Historial de pujas'),
              StreamBuilder<List<BidsRecord>>(
                stream: _bids,
                builder: (context, s) {
                  if (s.hasError) return ErrorState(error: s.error, onRetry: _retry);
                  if (!s.hasData) return const Loading();
                  final bids = s.data!;
                  if (bids.isEmpty) {
                    return const EmptyState(
                        icon: Icons.gavel_outlined,
                        title: 'Sin pujas todavía',
                        message: '¡La primera puja puede ser la tuya!');
                  }
                  return Column(children: [
                    for (var i = 0; i < bids.length; i++)
                      BidTile(bid: bids[i], isTop: i == 0),
                  ]);
                },
              ),
            ],
          ),
        );
    }
  }
}

/// Fila del historial de pujas (se usa también en la subasta en vivo).
class BidTile extends StatelessWidget {
  const BidTile({super.key, required this.bid, this.isTop = false});

  final BidsRecord bid;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final mine = bid.bidderUid == currentUserUid;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTop ? theme.surfaceVariant : theme.secondaryBackground,
        border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: mine ? theme.primary : theme.secondary,
          child: Text(
              bid.bidderName.isEmpty ? '?' : bid.bidderName[0].toUpperCase(),
              style: theme.labelMedium.copyWith(color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${mine ? 'Tú' : bid.bidderName}${bid.auto ? ' · automática' : ''}',
                  style: theme.titleSmall),
              Text(timeAgo(bid.createdTime), style: theme.bodySmall),
            ],
          ),
        ),
        Text(formatMoney(bid.amount),
            style: theme.titleMedium.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.lot,
    required this.isSeller,
    required this.iAmWinning,
    required this.open,
  });

  final LotsRecord lot;
  final bool isSeller;
  final bool iAmWinning;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final id = lot.reference.id;
    final buttons = <Widget>[];

    if (lot.isLiveFormat && lot.status != 'ended') {
      buttons.add(Expanded(
        child: BigButton(
          label: 'Ver en vivo',
          icon: Icons.play_circle_outline,
          secondary: true,
          onPressed: () => context
              .pushNamed('LiveStreamAuction', queryParameters: {'lotId': id}),
        ),
      ));
    }

    if (!isSeller && lot.status != 'ended') {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
      buttons.add(Expanded(
        child: BigButton(
          label: !lot.hasStarted()
              ? 'Aún no inicia'
              : (lot.isEnded()
                  ? 'Cerrando…'
                  : (iAmWinning ? 'Subir mi máximo' : 'Pujar')),
          icon: Icons.gavel_rounded,
          onPressed: open
              ? () => context.pushNamed('BidConfirmationModal',
                  queryParameters: {'lotId': id})
              : null,
        ),
      ));
    }

    if (isSeller && lot.status != 'ended' && buttons.isEmpty) {
      buttons.add(Expanded(
        child: Text('Este es tu lote. No puedes pujar en él.',
            textAlign: TextAlign.center, style: theme.bodyMedium),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(top: BorderSide(color: theme.alternate)),
      ),
      child: SafeArea(top: false, child: Row(children: buttons)),
    );
  }
}

/// Estado del pago para el ganador, con botón "Pagar ahora".
class _WinnerPaymentBox extends StatelessWidget {
  const _WinnerPaymentBox({required this.lot});
  final LotsRecord lot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    switch (lot.paymentStatus) {
      case 'pending':
        return _PaymentMethodSelector(lot: lot);
      case 'paid':
        return Tag('Pagado — revisa tus avisos para coordinar la entrega',
            icon: Icons.check_circle_outline);
      case 'forfeited':
        return Tag('No se pagó a tiempo', background: theme.error, foreground: Colors.white);
      default:
        return Text('Estamos generando tu enlace de pago…', style: theme.bodySmall);
    }
  }
}

/// Selección del método para el PAGO FINAL (distinto del depósito de
/// garantía, que se deja antes de pujar desde "Mi cuenta").
class _PaymentMethodSelector extends StatefulWidget {
  const _PaymentMethodSelector({required this.lot});
  final LotsRecord lot;

  @override
  State<_PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<_PaymentMethodSelector> {
  late FinalPaymentMethod _method = _initial();
  bool _busy = false;
  FinalPaymentChoice? _spei;

  bool get _speiAvailable => widget.lot.paymentOptions.contains('spei');

  FinalPaymentMethod _initial() {
    final lot = widget.lot;
    if (lot.hasSpeiReference) return FinalPaymentMethod.spei;
    // SPEI primero en montos altos: comisión mucho menor y sin contracargos.
    if (lot.paymentOptions.contains('spei') && lot.amountDue >= 20000) {
      return FinalPaymentMethod.spei;
    }
    return FinalPaymentMethod.mercadopago;
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      final r = await PaymentService.instance
          .chooseFinalPayment(widget.lot.reference.id, _method);
      if (!mounted) return;
      if (r.method == FinalPaymentMethod.mercadopago) {
        await PaymentService.instance.openCheckout(r.url);
      } else {
        setState(() => _spei = r);
      }
    } on PaymentFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final lot = widget.lot;
    final spei = _spei;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        'Debes pagar ${formatMoney(lot.amountDue)} antes del ${formatDateTime(lot.paymentDueTime)}. '
        'Si no pagas a tiempo pierdes tu depósito.',
        style: theme.bodySmall,
      ),
      const SizedBox(height: 10),
      if (spei != null)
        _SpeiInstructions(choice: spei)
      else ...[
        Text('¿Cómo quieres pagar?',
            style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (_speiAvailable)
          _MethodTile(
            selected: _method == FinalPaymentMethod.spei,
            icon: Icons.account_balance_outlined,
            title: 'Transferencia SPEI',
            subtitle: 'Desde tu banco. Recomendado para montos altos.',
            onTap: () => setState(() => _method = FinalPaymentMethod.spei),
          ),
        _MethodTile(
          selected: _method == FinalPaymentMethod.mercadopago,
          icon: Icons.credit_card,
          title: 'Tarjeta o saldo Mercado Pago',
          subtitle: 'Crédito, débito o tu cuenta de Mercado Pago.',
          onTap: () => setState(() => _method = FinalPaymentMethod.mercadopago),
        ),
        const SizedBox(height: 8),
        BigButton(
          label: _method == FinalPaymentMethod.spei
              ? (lot.hasSpeiReference ? 'Ver datos para transferir' : 'Obtener datos para transferir')
              : 'Pagar ahora',
          icon: Icons.lock_outline,
          loading: _busy,
          onPressed: _continue,
        ),
      ],
    ]);
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? theme.primary : theme.alternate, width: selected ? 2 : 1),
            color: selected ? theme.primaryContainer : theme.secondaryBackground,
          ),
          child: Row(children: [
            Icon(icon, color: theme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: theme.bodySmall.copyWith(color: theme.secondaryText)),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? theme.primary : theme.secondaryText),
          ]),
        ),
      ),
    );
  }
}

class _SpeiInstructions extends StatelessWidget {
  const _SpeiInstructions({required this.choice});
  final FinalPaymentChoice choice;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget row(String label, String value, {bool copy = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
                width: 110,
                child: Text(label, style: theme.bodySmall.copyWith(color: theme.secondaryText))),
            Expanded(
                child: SelectableText(value,
                    style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w700))),
            if (copy)
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  showMessage(context, '$label copiada');
                },
              ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Transfiere desde tu banco por SPEI',
            style: theme.titleSmall.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        row('CLABE', choice.clabe, copy: true),
        if (choice.bank.isNotEmpty) row('Banco', choice.bank),
        if (choice.reference.isNotEmpty) row('Referencia', choice.reference, copy: true),
        row('Monto exacto', formatMoney(choice.amount)),
        if (choice.dueTime != null) row('Antes del', formatDateTime(choice.dueTime)),
        const SizedBox(height: 4),
        Text(
          'Transfiere el monto exacto. Te avisamos en cuanto se confirme; '
          'no necesitas mandar comprobante.',
          style: theme.bodySmall,
        ),
      ]),
    );
  }
}


/// Tabla de dos columnas (etiqueta | valor), estilo "Características".
class _SpecsTable extends StatelessWidget {
  const _SpecsTable({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.alternate),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            color: i.isEven ? theme.secondaryContainer : theme.secondaryBackground,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 2,
                child: Text(rows[i].$1,
                    style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(rows[i].$2,
                    style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
      ]),
    );
  }
}

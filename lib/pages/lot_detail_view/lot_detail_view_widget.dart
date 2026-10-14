import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
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
  late final Stream<LotsRecord?> _lot = AuctionService.instance.lot(widget.lotId);
  late final Stream<List<BidsRecord>> _bids =
      AuctionService.instance.bids(widget.lotId);
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
                    Text('Vende: ${lot.sellerName}',
                        style: theme.bodySmall
                            .copyWith(color: theme.secondaryText)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        border: Border.all(color: theme.secondary, width: 2),
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
                            : (lot.winnerUid == currentUserUid
                                ? '¡Ganaste esta subasta!'
                                : 'Ganó ${lot.winnerName}.'),
                        style: theme.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (lot.winnerUid == currentUserUid) ...[
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
      },
    );
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
        border: Border.all(color: theme.secondary, width: 1.5),
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
              : (iAmWinning ? 'Subir mi máximo' : 'Pujar'),
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
        border: Border(top: BorderSide(color: theme.secondary, width: 2)),
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
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Debes pagar ${formatMoney(lot.amountDue)} antes del ${formatDateTime(lot.paymentDueTime)}. '
            'Si no pagas a tiempo pierdes tu depósito.',
            style: theme.bodySmall,
          ),
          const SizedBox(height: 8),
          BigButton(
            label: 'Pagar ahora',
            icon: Icons.lock_outline,
            onPressed: lot.winnerPaymentUrl.isEmpty
                ? null
                : () => PaymentService.instance.openCheckout(lot.winnerPaymentUrl),
          ),
        ]);
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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/lot_specs.dart';
import '/backend/regions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/payment_service.dart';
import '/backend/reputation_service.dart';
import '/backend/dispute_service.dart';
import 'package:image_picker/image_picker.dart';
import '/pages/deposit_guarantia/deposit_guarantia_widget.dart';
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
                    _SellerCard(lot: lot),
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
                                  lot.isFixedPrice
                                      ? (lot.isHeld
                                          ? 'Apartado'
                                          : lot.status == 'ended' && lot.winnerUid.isNotEmpty
                                          ? 'Vendido en'
                                          : 'Precio')
                                      : lot.status == 'ended'
                                      ? 'Precio final'
                                      : lot.endedUnsoldReserve
                                          ? 'Puja más alta'
                                      : (lot.bidCount == 0
                                          ? 'Precio inicial'
                                          : 'Puja actual'),
                                  style: theme.labelSmall),
                              Text(formatMoney(lot.currentBid),
                                  style: theme.headlineSmall.copyWith(
                                      color: theme.primary,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  lot.isFixedPrice
                                      ? 'Precio fijo · Comprar ahora'
                                      : '${lot.bidCount} ${lot.bidCount == 1 ? 'puja' : 'pujas'}'
                                          ' · incremento ${formatMoney(lot.minimumIncrement)}',
                                  style: theme.bodySmall),
                              if (!lot.isFixedPrice && lot.canBuyNow())
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Tag('Comprar ahora: ${formatMoney(lot.buyNowPrice ?? 0)}',
                                      background: theme.surfaceVariant,
                                      icon: Icons.bolt_rounded),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(lot.hasStarted() ? (lot.isFixedPrice ? 'Disponible' : 'Termina en') : '',
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
                    if (lot.secondChance['status'] == 'offered' &&
                        currentUserUid.isNotEmpty &&
                        lot.secondChance['uid'] == currentUserUid) ...[
                      const SizedBox(height: 10),
                      _SecondChanceCard(lot: lot),
                    ],
                    if (isSeller &&
                        lot.paymentStatus == 'paid' &&
                        lot.receivedTime == null &&
                        lot.deliveryChoice != 'regional' &&
                        !lot.isDemo) ...[
                      const SizedBox(height: 10),
                      _SellerCodeBox(lot: lot),
                    ],
                    if (lot.hasReserve && lot.status == 'active') ...[
                      const SizedBox(height: 10),
                      _ReserveRow(lot: lot, isSeller: isSeller),
                    ],
                    if (lot.endedUnsoldReserve) ...[
                      const SizedBox(height: 10),
                      Text('Terminó sin venta: no se alcanzó el precio de reserva del vendedor.',
                          style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    ],
                    if (lot.status == 'ended') ...[
                      const SizedBox(height: 10),
                      Text(
                        lot.isHeld
                            ? (currentUserUid.isNotEmpty && lot.winnerUid == currentUserUid
                                ? 'Lo apartaste: paga para que sea tuyo. Si no pagas a tiempo, vuelve a la venta.'
                                : 'Apartado: alguien lo está pagando. Si no completa el pago, vuelve a estar disponible.')
                            : lot.winnerUid.isEmpty
                            ? (lot.isFixedPrice ? 'Terminó sin venta.' : 'Terminó sin pujas.')
                            : (currentUserUid.isNotEmpty && lot.winnerUid == currentUserUid
                                ? (lot.soldByBuyNow ? '¡Lo compraste!' : '¡Ganaste esta subasta!')
                                : (lot.soldByBuyNow
                                    ? 'Vendido a ${lot.winnerName} (Comprar ahora).'
                                    : 'Ganó ${lot.winnerName}.')),
                        style: theme.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (currentUserUid.isNotEmpty && lot.winnerUid == currentUserUid) ...[
                        const SizedBox(height: 8),
                        _WinnerPaymentBox(lot: lot),
                        if (lot.paymentStatus == 'paid') ...[
                          const SizedBox(height: 12),
                          _DisputeBox(lot: lot),
                          const SizedBox(height: 12),
                          _FeedbackBox(lot: lot),
                        ],
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

              // ---------------- Ubicación y entrega ----------------
              const SectionTitle('Ubicación y entrega'),
              _DeliveryInfo(lot: lot),

              // ---------------- Descripción ----------------
              if (lot.description.isNotEmpty) ...[
                const SectionTitle('Descripción'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(lot.description, style: theme.bodyMedium),
                ),
              ],

              // ---------------- Historial (solo subastas) ----------------
              if (!lot.isFixedPrice) const SectionTitle('Historial de pujas'),
              if (!lot.isFixedPrice) StreamBuilder<List<BidsRecord>>(
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

    if (!isSeller && lot.status != 'ended' && lot.isFixedPrice) {
      buttons.add(Expanded(child: _BuyNowButton(lot: lot, primary: true)));
    } else if (!isSeller && lot.status != 'ended') {
      if (lot.canBuyNow()) {
        if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
        buttons.add(Expanded(child: _BuyNowButton(lot: lot, primary: false)));
      }
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
        child: Text(lot.isFixedPrice ? 'Esta es tu publicación.' : 'Este es tu lote. No puedes pujar en él.',
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

/// Botón "Comprar ahora" (precio fijo o subasta sin pujas). Confirma, llama
/// al servidor (que decide con una transacción) y lleva al pago.
class _BuyNowButton extends StatefulWidget {
  const _BuyNowButton({required this.lot, required this.primary});

  final LotsRecord lot;
  final bool primary;

  @override
  State<_BuyNowButton> createState() => _BuyNowButtonState();
}

class _BuyNowButtonState extends State<_BuyNowButton> {
  bool _busy = false;

  Future<void> _buy() async {
    final lot = widget.lot;
    final price = lot.buyNowPrice ?? 0;
    if (currentUserUid.isEmpty) {
      context.pushNamed('BidderAccess');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Comprar por ${formatMoney(price)}?'),
        content: Text(lot.isFixedPrice
            ? 'Te lo apartamos unos minutos mientras pagas con tarjeta o Mercado Pago. No necesitas depósito. '
                'Si no pagas a tiempo, vuelve a estar a la venta. Tu pago queda protegido hasta que recibas el artículo.'
            : 'Al confirmar, el artículo es tuyo. Tienes 24 horas para pagar (tu depósito se descuenta). '
                'Si no pagas, pierdes tu depósito. El pago queda protegido hasta que recibas el artículo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Comprar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await AuctionService.instance.buyNow(lot.reference.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      final url = r.paymentUrl;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(r.payFirst ? '¡Apartado!' : '¡Es tuyo!'),
          content: Text(r.message),
          actions: [
            if (url != null && url.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  PaymentService.instance.openCheckout(url);
                },
                child: const Text('Pagar ahora'),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Listo')),
          ],
        ),
      );
    } else if (r.code == 'DEPOSIT_REQUIRED') {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Falta tu depósito de garantía'),
          content: Text(r.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ahora no')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Dejar depósito')),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const DepositGarantiaWidget(),
        ));
      }
    } else if (r.code == 'IDENTITY_REQUIRED') {
      showMessage(context, r.message, error: true);
      context.pushNamed('IdentityVerification');
    } else {
      showMessage(context, r.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lot = widget.lot;
    final enabled = lot.canBuyNow();
    return BigButton(
      label: !lot.hasStarted()
          ? 'Aún no inicia'
          : widget.primary
              ? 'Comprar ahora · ${formatMoney(lot.buyNowPrice ?? 0)}'
              : 'Comprar ${formatMoney(lot.buyNowPrice ?? 0)}',
      icon: Icons.bolt_rounded,
      secondary: !widget.primary,
      loading: _busy,
      onPressed: enabled && !_busy ? _buy : null,
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
      if (lot.offlinePaymentPending) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Ya generaste tu ficha de pago'
            '${lot.offlinePaymentMethod == 'oxxo' ? ' de OXXO' : ''}. '
            'Págala antes del ${formatDateTime(lot.cashPaymentUntil ?? lot.paymentDueTime)}. '
            'Te llegó también a tu correo. En cuanto Mercado Pago confirme el pago, '
            'tu compra queda pagada aquí.',
            style: theme.bodySmall,
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (lot.needsDeliveryChoice && !lot.offlinePaymentPending)
        _DeliveryChooser(lot: lot)
      else if (spei != null)
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
          title: lot.cashPaymentUntil != null
              ? 'Tarjeta, OXXO o Mercado Pago'
              : 'Tarjeta o saldo Mercado Pago',
          subtitle: lot.cashPaymentUntil != null
              ? 'Crédito, débito, saldo MP o efectivo en OXXO y tiendas '
                  '(efectivo hasta el ${formatDateTime(lot.cashPaymentUntil)}).'
              : 'Crédito, débito o tu cuenta de Mercado Pago.',
          onTap: () => setState(() => _method = FinalPaymentMethod.mercadopago),
        ),
        const SizedBox(height: 8),
        BigButton(
          label: _method == FinalPaymentMethod.spei
              ? (lot.hasSpeiReference ? 'Ver datos para transferir' : 'Obtener datos para transferir')
              : (lot.offlinePaymentPending ? 'Pagar con tarjeta en su lugar' : 'Pagar ahora'),
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


/// Tarjeta del vendedor: nombre público, estrellas, ventas e insignias.
/// Lleva al perfil público (sin datos de contacto).
class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.lot});
  final LotsRecord lot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.pushNamed('SellerProfile', queryParameters: {'uid': lot.sellerUid}),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.alternate),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: theme.primaryContainer,
            child: Icon(Icons.storefront_outlined, color: theme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lot.sellerName.isEmpty ? 'Vendedor' : lot.sellerName,
                  style: theme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              if (lot.sellerRatingCount > 0)
                Row(children: [
                  RatingStars(value: lot.sellerRatingAvg, size: 14),
                  const SizedBox(width: 6),
                  Text('${lot.sellerRatingAvg.toStringAsFixed(1)} · ${lot.sellerSalesCount} ventas',
                      style: theme.bodySmall),
                ])
              else
                Text('Vendedor nuevo', style: theme.bodySmall.copyWith(color: theme.secondaryText)),
              if (lot.sellerBadges.isNotEmpty) ...[
                const SizedBox(height: 6),
                SellerBadges(badges: lot.sellerBadges),
              ],
            ]),
          ),
          Icon(Icons.chevron_right, color: theme.secondaryText),
        ]),
      ),
    );
  }
}

/// El comprador califica al vendedor (una vez; editable 7 días).
class _FeedbackBox extends StatefulWidget {
  const _FeedbackBox({required this.lot});
  final LotsRecord lot;

  @override
  State<_FeedbackBox> createState() => _FeedbackBoxState();
}

class _FeedbackBoxState extends State<_FeedbackBox> {
  late final Stream<FeedbackEntry?> _existing =
      ReputationService.instance.feedbackFor(widget.lot.reference.id);
  final _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  bool _editing = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save(bool edit) async {
    if (_rating == 0) {
      showMessage(context, 'Elige de 1 a 5 estrellas.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ReputationService.instance
          .submit(widget.lot.reference.id, _rating, _comment.text, edit: edit);
      if (!mounted) return;
      setState(() => _editing = false);
      showMessage(context, '¡Gracias! Tu opinión ayuda a otros compradores.');
    } on ReputationFailure catch (e) {
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
    if (widget.lot.isDemo) return const SizedBox.shrink();
    return StreamBuilder<FeedbackEntry?>(
      stream: _existing,
      builder: (context, s) {
        final existing = s.data;
        if (existing != null && !_editing) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tu opinión', style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            RatingStars(value: existing.rating.toDouble()),
            if (existing.comment.isNotEmpty) Text(existing.comment, style: theme.bodySmall),
            if (existing.canEdit)
              TextButton(
                onPressed: () => setState(() {
                  _editing = true;
                  _rating = existing.rating;
                  _comment.text = existing.comment;
                }),
                child: const Text('Editar (hasta 7 días)'),
              ),
          ]);
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('¿Cómo te fue con el vendedor?',
                style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700)),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i',
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF5AF02), size: 30),
                ),
            ]),
            TextField(
              controller: _comment,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '¿Llegó como se describió? ¿Cumplió en la entrega?',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 6),
            BigButton(
              label: existing != null ? 'Guardar cambios' : 'Publicar opinión',
              loading: _busy,
              onPressed: () => _save(existing != null),
            ),
          ]),
        );
      },
    );
  }
}


/// Protección al comprador: reclamar dentro de 72 h si no llegó o llegó distinto.
class _DisputeBox extends StatelessWidget {
  const _DisputeBox({required this.lot});
  final LotsRecord lot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (lot.isDemo) return const SizedBox.shrink();
    if (lot.disputeStatus == 'open') {
      return Tag('Reclamo en revisión: te avisaremos la resolución', icon: Icons.support_agent);
    }
    if (lot.disputeStatus == 'resolved') {
      final txt = lot.disputeResolution == 'reject'
          ? 'Reclamo revisado: no procedió'
          : 'Reclamo resuelto con reembolso';
      return Tag(txt, icon: Icons.task_alt);
    }
    if (lot.receivedTime != null) {
      return Tag('Confirmaste que recibiste. ¡Gracias!', icon: Icons.inventory_2_outlined);
    }
    if (!lot.canOpenDispute) return const SizedBox.shrink();
    final until = lot.escrowReleaseAt!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (lot.deliveryChoice != 'regional') ...[
        _BuyerCodeCard(lot: lot),
        const SizedBox(height: 10),
      ],
      Text(
        'Tu pago está protegido: el vendedor lo recibe cuando confirmes que te llegó '
        '(o el ${formatDateTime(until)} si no reclamas).',
        style: theme.bodySmall,
      ),
      const SizedBox(height: 8),
      BigButton(
        label: 'Ya lo recibí y está bien',
        icon: Icons.check_circle_outline,
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('¿Confirmas que recibiste el artículo?'),
              content: const Text(
                  'Al confirmar, liberamos el pago al vendedor y ya no podrás abrir un reclamo.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Todavía no')),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, lo recibí')),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          try {
            await PaymentService.instance.confirmReceipt(lot.reference.id);
            if (context.mounted) showMessage(context, 'Listo. Ahora puedes calificar al vendedor.');
          } on PaymentFailure catch (e) {
            if (context.mounted) showMessage(context, e.message, error: true);
          }
        },
      ),
      const SizedBox(height: 8),
      _disputeButton(context, theme, until),
    ]);
  }

  Widget _disputeButton(BuildContext context, FlutterFlowTheme theme, DateTime until) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.error,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: const Icon(Icons.report_problem_outlined),
      label: Text('¿No llegó o llegó distinto? Reclamar (hasta ${formatDateTime(until)})'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _DisputeForm(lot: lot),
      ),
    );
  }
}

class _DisputeForm extends StatefulWidget {
  const _DisputeForm({required this.lot});
  final LotsRecord lot;

  @override
  State<_DisputeForm> createState() => _DisputeFormState();
}

class _DisputeFormState extends State<_DisputeForm> {
  String? _reason;
  final _details = TextEditingController();
  final List<String> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (f == null) return;
    setState(() => _busy = true);
    try {
      final path = await DisputeService.instance
          .uploadEvidence(await f.readAsBytes(), f.mimeType ?? 'image/jpeg');
      setState(() => _photos.add(path));
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_reason == null) {
      showMessage(context, 'Elige el motivo.', error: true);
      return;
    }
    if (_details.text.trim().length < 20) {
      showMessage(context, 'Describe el problema (mínimo 20 caracteres).', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await DisputeService.instance
          .open(widget.lot.reference.id, _reason!, _details.text.trim(), _photos);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Recibimos tu reclamo. El pago al vendedor queda en pausa mientras lo revisamos.');
    } on DisputeFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Reclamar esta compra', style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Mientras revisamos, el pago al vendedor queda en pausa. Resolvemos en máximo 5 días hábiles.',
              style: theme.bodySmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            items: [
              for (final e in kDisputeReasons.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _reason = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _details,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
                labelText: '¿Qué pasó?',
                hintText: 'Ej. La silla llegó con la piel rota y en la publicación no se dijo.',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
          ),
          Row(children: [
            TextButton.icon(
              onPressed: _busy || _photos.length >= 6 ? null : _addPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text('Agregar foto (${_photos.length}/6)'),
            ),
          ]),
          BigButton(label: 'Enviar reclamo', loading: _busy, onPressed: _send),
        ]),
      ),
    );
  }
}


/// "Segunda oportunidad": el ganador no pagó y se te ofrece por tu máximo.
class _SecondChanceCard extends StatefulWidget {
  const _SecondChanceCard({required this.lot});
  final LotsRecord lot;

  @override
  State<_SecondChanceCard> createState() => _SecondChanceCardState();
}

class _SecondChanceCardState extends State<_SecondChanceCard> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    try {
      final ok = await PaymentService.instance
          .respondSecondChance(widget.lot.reference.id, accept: accept);
      if (!mounted) return;
      showMessage(context, ok ? '¡Es tuyo! Ahora elige cómo pagar.' : 'Listo, rechazaste la oferta.');
    } on PaymentFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final sc = widget.lot.secondChance;
    final amount = (sc['amount'] as num?)?.toDouble() ?? 0;
    final expires = sc['expires_at'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Segunda oportunidad', style: theme.titleMedium.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'El ganador no pagó. Llévatelo por tu máximo de ${formatMoney(amount)}'
          '${expires is DateTime ? ' (acepta antes del ${formatDateTime(expires)})' : ''}. '
          'Si no te interesa, rechazar no tiene ninguna penalización.',
          style: theme.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _respond(false),
              style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
              child: const Text('No, gracias'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BigButton(label: 'Lo quiero', loading: _busy, onPressed: () => _respond(true)),
          ),
        ]),
      ]),
    );
  }
}


/// "Tiene precio de reserva": alcanzada o no (el monto nunca se muestra).
/// El vendedor puede bajarla o quitarla.
class _ReserveRow extends StatelessWidget {
  const _ReserveRow({required this.lot, required this.isSeller});
  final LotsRecord lot;
  final bool isSeller;

  Future<void> _change(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cambiar precio de reserva'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '\$ ',
            helperText: 'Con pujas solo puedes bajarla. Déjalo vacío para quitarla.',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await AuctionService.instance.setReservePrice(
          lot.reference.id, result.isEmpty ? null : double.tryParse(result.replaceAll(',', '')));
      if (context.mounted) showMessage(context, 'Reserva actualizada.');
    } catch (e) {
      if (context.mounted) showMessage(context, '$e'.replaceFirst('Bad state: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(children: [
      Tag(lot.reserveMet ? 'Reserva alcanzada' : 'Reserva no alcanzada',
          icon: lot.reserveMet ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          background: lot.reserveMet ? theme.primaryContainer : theme.surfaceVariant),
      const Spacer(),
      if (isSeller && !lot.isDemo)
        TextButton(onPressed: () => _change(context), child: const Text('Cambiar reserva')),
    ]);
  }
}


/// Municipio de origen y formas de entrega que ofrece el vendedor.
class _DeliveryInfo extends StatelessWidget {
  const _DeliveryInfo({required this.lot});
  final LotsRecord lot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final rows = <(IconData, String)>[
      if (municipalityName(lot.municipality).isNotEmpty)
        (Icons.place_outlined, 'Está en ${municipalityName(lot.municipality)}, Chih.'),
      if (lot.offersPickup) (Icons.handshake_outlined, 'Entrega a acordar con el vendedor (sin costo)'),
      if (lot.offersRegional)
        (
          Icons.local_shipping_outlined,
          'Envío regional ${lot.shippingIncluded ? '(incluido en el precio)' : 'por ${formatMoney(lot.shippingCost)}'}'
              '${lot.shippingDestinations.isEmpty ? ' a toda la región' : ' a ${lot.shippingDestinations.map(municipalityName).join(', ')}'}',
        ),
      if (lot.deliveryChoice == 'regional' && lot.deliveryDestination.isNotEmpty)
        (Icons.check_circle_outline, 'Elegiste envío a ${municipalityName(lot.deliveryDestination)}'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(r.$1, size: 20, color: theme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(r.$2, style: theme.bodyMedium)),
            ]),
          ),
      ]),
    );
  }
}

/// El ganador elige cómo recibirlo cuando el vendedor ofrece ambas formas.
class _DeliveryChooser extends StatefulWidget {
  const _DeliveryChooser({required this.lot});
  final LotsRecord lot;

  @override
  State<_DeliveryChooser> createState() => _DeliveryChooserState();
}

class _DeliveryChooserState extends State<_DeliveryChooser> {
  String _mode = 'pickup';
  String? _dest;
  bool _busy = false;

  Future<void> _save() async {
    if (_mode == 'regional' && _dest == null) {
      showMessage(context, 'Elige a qué municipio te lo envían.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final amount = await PaymentService.instance
          .chooseDelivery(widget.lot.reference.id, _mode, destination: _dest ?? '');
      if (mounted) showMessage(context, 'Listo. Total a pagar: ${formatMoney(amount)}');
    } on PaymentFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final lot = widget.lot;
    final dests = lot.shippingDestinations.isEmpty
        ? kMunicipalities.keys.where((k) => k != 'otro' && k != lot.municipality).toList()
        : lot.shippingDestinations;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Primero, ¿cómo quieres recibirlo?',
          style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700)),
      RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        value: 'pickup',
        groupValue: _mode,
        onChanged: (v) => setState(() => _mode = v!),
        title: const Text('Entrega a acordar con el vendedor'),
        subtitle: Text('Sin costo · en ${municipalityName(lot.municipality).isEmpty ? 'su municipio' : municipalityName(lot.municipality)}'),
      ),
      RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        value: 'regional',
        groupValue: _mode,
        onChanged: (v) => setState(() => _mode = v!),
        title: const Text('Envío a mi municipio'),
        subtitle: Text(lot.shippingIncluded ? 'Incluido en el precio' : '+ ${formatMoney(lot.shippingCost)}'),
      ),
      if (_mode == 'regional')
        DropdownButtonFormField<String>(
          value: _dest,
          decoration: const InputDecoration(
              labelText: 'Municipio de destino',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
          items: [for (final k in dests) DropdownMenuItem(value: k, child: Text(municipalityName(k)))],
          onChanged: (v) => setState(() => _dest = v),
        ),
      const SizedBox(height: 8),
      BigButton(label: 'Continuar al pago', loading: _busy, onPressed: _save),
    ]);
  }
}


/// Comprador: su código de entrega en persona.
class _BuyerCodeCard extends StatelessWidget {
  const _BuyerCodeCard({required this.lot});
  final LotsRecord lot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<String?>(
      stream: PaymentService.instance.deliveryCode(lot.reference.id),
      builder: (context, s) {
        final code = s.data;
        if (code == null || code.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: theme.primaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tu código de entrega', style: theme.titleSmall.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            SelectableText(
              '${code.substring(0, 3)} ${code.substring(3)}',
              style: theme.headlineMedium.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4, color: theme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              'Dáselo al vendedor SOLO cuando tengas el artículo en tus manos y lo hayas revisado. '
              'Con este código se le libera el pago y ya no podrás reclamar.',
              style: theme.bodySmall,
            ),
          ]),
        );
      },
    );
  }
}

/// Vendedor: captura el código que le da el comprador al entregar en persona.
class _SellerCodeBox extends StatefulWidget {
  const _SellerCodeBox({required this.lot});
  final LotsRecord lot;

  @override
  State<_SellerCodeBox> createState() => _SellerCodeBoxState();
}

class _SellerCodeBoxState extends State<_SellerCodeBox> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await PaymentService.instance.confirmDeliveryCode(widget.lot.reference.id, _code.text);
      if (mounted) showMessage(context, '¡Entrega confirmada! Tu pago quedó liberado.');
    } on PaymentFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('¿Entregaste en persona?', style: theme.titleSmall.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Pide al comprador su código de 6 dígitos al entregarle el artículo. '
            'Al capturarlo, tu pago se libera al instante.', style: theme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Código de entrega',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        const SizedBox(height: 8),
        BigButton(label: 'Confirmar entrega', icon: Icons.verified_outlined, loading: _busy, onPressed: _send),
      ]),
    );
  }
}

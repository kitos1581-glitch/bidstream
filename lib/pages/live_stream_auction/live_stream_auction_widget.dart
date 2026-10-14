import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/lot_detail_view/lot_detail_view_widget.dart' show BidTile;
import '/ui/ui_kit.dart';
import '/ui/youtube.dart';

/// Subasta en vivo: video + puja actual + pujas rápidas.
class LiveStreamAuctionWidget extends StatefulWidget {
  const LiveStreamAuctionWidget({super.key, required this.lotId});

  final String lotId;

  static String routeName = 'LiveStreamAuction';
  static String routePath = '/liveStreamAuction';

  @override
  State<LiveStreamAuctionWidget> createState() =>
      _LiveStreamAuctionWidgetState();
}

class _LiveStreamAuctionWidgetState extends State<LiveStreamAuctionWidget> {
  late final Stream<LotsRecord?> _lot = AuctionService.instance.lot(widget.lotId);
  late final Stream<List<BidsRecord>> _bids =
      AuctionService.instance.bids(widget.lotId, limit: 10);
  late final Stream<UsersRecord?> _profile = AuctionService.instance.myProfile();

  YoutubePlayerController? _player;
  String? _playerVideoId;
  bool _sending = false;

  @override
  void dispose() {
    _player?.close();
    super.dispose();
  }

  /// Crea (o cambia) el reproductor solo cuando cambia la URL.
  YoutubePlayerController? _controllerFor(String url) {
    final id = youtubeIdFrom(url);
    if (id == null) return null;
    if (_player == null || _playerVideoId != id) {
      _player?.close();
      _playerVideoId = id;
      _player = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
          strictRelatedVideos: true,
        ),
      );
    }
    return _player;
  }

  Future<void> _quickBid(LotsRecord lot, double amount, UsersRecord? profile) async {
    if (!AuctionService.instance.emailVerified ||
        !(profile?.isProfileComplete ?? false)) {
      showMessage(context, 'Completa tu cuenta para pujar.', error: true);
      context.pushNamed('OnboardingVerification');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Pujar ${formatMoney(amount)}?'),
        content: const Text('Si ganas, te comprometes a comprar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Pujar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    final r = await AuctionService.instance.placeBid(lot.reference.id, amount);
    if (!mounted) return;
    setState(() => _sending = false);
    showMessage(
      context,
      r.ok ? '¡Puja de ${formatMoney(r.amount ?? amount)} registrada!' : (r.message ?? 'Error'),
      error: !r.ok,
    );
  }

  Future<void> _editStreamUrl(LotsRecord lot) async {
    final ctrl = TextEditingController(text: lot.streamUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enlace de la transmisión'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              hintText: 'https://youtube.com/live/…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
    if (url == null) return;
    await AuctionService.instance.updateStreamUrl(lot.reference.id, url);
    if (mounted) showMessage(context, 'Enlace actualizado.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.secondary,
      body: SafeArea(
        child: StreamBuilder<UsersRecord?>(
          stream: _profile,
          builder: (context, profileSnap) => StreamBuilder<LotsRecord?>(
            stream: _lot,
            builder: (context, snap) {
              if (!snap.hasData) {
                return snap.connectionState == ConnectionState.waiting
                    ? const Loading()
                    : const EmptyState(
                        icon: Icons.search_off, title: 'Este lote ya no existe');
              }
              final lot = snap.data!;
              final isSeller = lot.sellerUid == currentUserUid;
              final winning = lot.highestBidderUid == currentUserUid &&
                  lot.highestBidderUid.isNotEmpty;
              final min = lot.minimumNextBid;
              final step =
                  lot.minimumIncrement > 0 ? lot.minimumIncrement : 1.0;

              return Column(children: [
                // ---------------- Barra superior ----------------
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.safePop(),
                  ),
                  Expanded(
                    child: Text(lot.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall.copyWith(color: Colors.white)),
                  ),
                  if (lot.isLiveNow()) const LiveTag(),
                  if (isSeller)
                    IconButton(
                      tooltip: 'Cambiar enlace',
                      icon: const Icon(Icons.link, color: Colors.white),
                      onPressed: () => _editStreamUrl(lot),
                    ),
                  const SizedBox(width: 8),
                ]),

                // ---------------- Video ----------------
                AspectRatio(aspectRatio: 16 / 9, child: _video(lot)),

                // ---------------- Panel de pujas ----------------
                Expanded(
                  child: Container(
                    color: theme.primaryBackground,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      lot.bidCount == 0
                                          ? 'Precio inicial'
                                          : 'Puja actual',
                                      style: theme.labelSmall),
                                  Text(formatMoney(lot.currentBid),
                                      style: theme.headlineMedium.copyWith(
                                          color: theme.primary,
                                          fontWeight: FontWeight.w800)),
                                  if (lot.highestBidderName.isNotEmpty)
                                    Text(
                                        winning
                                            ? 'Vas ganando tú'
                                            : 'Va ganando ${lot.highestBidderName}',
                                        style: theme.bodySmall),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Tiempo', style: theme.labelSmall),
                                Countdown(
                                    lot: lot,
                                    style: theme.titleLarge.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ])),
                              ],
                            ),
                          ]),
                        ),
                        if (!isSeller && lot.isOpenForBids())
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: winning
                                ? Tag('Vas ganando — espera a que alguien te supere',
                                    icon: Icons.emoji_events_outlined)
                                : Row(children: [
                                    for (final a in [min, min + step, min + step * 2]) ...[
                                      Expanded(
                                        child: BigButton(
                                          label: formatMoney(a),
                                          loading: _sending,
                                          secondary: a != min,
                                          onPressed: () => _quickBid(
                                              lot, a, profileSnap.data),
                                        ),
                                      ),
                                      if (a != min + step * 2)
                                        const SizedBox(width: 8),
                                    ],
                                  ]),
                          ),
                        if (!lot.hasStarted())
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                                'Las pujas abren el ${formatDateTime(lot.startTime)}.',
                                style: theme.bodyMedium),
                          ),
                        if (!isSeller && lot.isOpenForBids())
                          TextButton(
                            onPressed: () => context.pushNamed(
                                'BidConfirmationModal',
                                queryParameters: {'lotId': lot.reference.id}),
                            child: const Text('Otro monto…'),
                          ),
                        const SectionTitle('Últimas pujas'),
                        StreamBuilder<List<BidsRecord>>(
                          stream: _bids,
                          builder: (context, s) {
                            final bids = s.data ?? const <BidsRecord>[];
                            if (bids.isEmpty) {
                              return const EmptyState(
                                  icon: Icons.gavel_outlined,
                                  title: 'Aún no hay pujas');
                            }
                            return Column(children: [
                              for (var i = 0; i < bids.length; i++)
                                BidTile(bid: bids[i], isTop: i == 0),
                            ]);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _video(LotsRecord lot) {
    final theme = FlutterFlowTheme.of(context);
    final url = lot.streamUrl;
    final controller = url.isEmpty ? null : _controllerFor(url);
    if (controller != null) {
      return YoutubePlayer(controller: controller, aspectRatio: 16 / 9);
    }
    // Sin enlace, o enlace que no es de YouTube (Facebook, TikTok, etc.)
    return Stack(fit: StackFit.expand, children: [
      LotImage(lot.firstImage),
      Container(color: const Color(0x99000000)),
      Center(
        child: url.isEmpty
            ? Text(
                lot.hasStarted()
                    ? 'El vendedor aún no agrega la transmisión'
                    : 'La transmisión empieza ${formatDateTime(lot.startTime)}',
                textAlign: TextAlign.center,
                style: theme.titleSmall.copyWith(color: Colors.white),
              )
            : SizedBox(
                width: 240,
                child: BigButton(
                  label: 'Abrir transmisión',
                  icon: Icons.open_in_new,
                  onPressed: () => launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication),
                ),
              ),
      ),
    ]);
  }
}

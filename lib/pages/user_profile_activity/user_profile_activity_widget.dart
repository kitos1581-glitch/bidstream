import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/ui_kit.dart';

/// Mi cuenta: perfil + mis pujas, lotes ganados y mis publicaciones.
class UserProfileActivityWidget extends StatefulWidget {
  const UserProfileActivityWidget({super.key});

  static String routeName = 'UserProfileActivity';
  static String routePath = '/userProfileActivity';

  @override
  State<UserProfileActivityWidget> createState() =>
      _UserProfileActivityWidgetState();
}

class _UserProfileActivityWidgetState extends State<UserProfileActivityWidget> {
  final _svc = AuctionService.instance;
  late final Stream<UsersRecord?> _profile = _svc.myProfile();
  late final Stream<List<BiddingRecord>> _bidding = _svc.myBidding();
  late final Stream<List<LotsRecord>> _won = _svc.wonLots();
  late final Stream<List<LotsRecord>> _mine = _svc.myListings();

  Future<void> _signOut() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    GoRouter.of(context).clearRedirectLocation();
    if (mounted) context.goNamedAuth('BidderAccess', context.mounted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        bottomNavigationBar: const AppBottomNav(current: NavTab.cuenta),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: theme.primaryBackground,
          foregroundColor: theme.primaryText,
          elevation: 0,
          title: Text('Mi cuenta',
              style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ],
        ),
        body: Column(children: [
          // ---------------- Tarjeta de perfil ----------------
          StreamBuilder<UsersRecord?>(
            stream: _profile,
            builder: (context, snap) {
              final p = snap.data;
              final complete = (p?.isProfileComplete ?? false) &&
                  _svc.emailVerified;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  border: Border.all(color: theme.secondary, width: 2),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primary,
                    child: Text(
                      (p?.fullName.isNotEmpty ?? false)
                          ? p!.fullName[0].toUpperCase()
                          : '?',
                      style: theme.titleMedium.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            (p?.fullName.isNotEmpty ?? false)
                                ? p!.fullName
                                : 'Sin nombre',
                            style: theme.titleSmall),
                        Text(currentUserEmail, style: theme.bodySmall),
                        const SizedBox(height: 6),
                        complete
                            ? Tag('Cuenta lista para pujar',
                                icon: Icons.check_circle_outline)
                            : Tag('Cuenta incompleta',
                                background: theme.tertiary,
                                foreground: Colors.white,
                                icon: Icons.error_outline),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushNamed('OnboardingVerification'),
                    child: Text(complete ? 'Editar' : 'Completar'),
                  ),
                ]),
              );
            },
          ),
          TabBar(
            labelColor: theme.primary,
            unselectedLabelColor: theme.secondaryText,
            indicatorColor: theme.primary,
            labelStyle: theme.labelMedium.copyWith(fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'Mis pujas'),
              Tab(text: 'Ganadas'),
              Tab(text: 'Mis ventas'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _MyBidsTab(stream: _bidding),
              _LotsList(
                stream: _won,
                empty: const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'Aún no ganas subastas',
                    message: 'Cuando ganes, aparecerán aquí.'),
              ),
              _LotsList(
                stream: _mine,
                showStatus: true,
                empty: EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No has publicado lotes',
                  action: SizedBox(
                    width: 220,
                    child: BigButton(
                        label: 'Publicar',
                        onPressed: () =>
                            context.goNamed('CreateLotManagement')),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Lista de subastas donde pujé, con estado en tiempo real
/// (ganando / superado / ganada / perdida).
class _MyBidsTab extends StatelessWidget {
  const _MyBidsTab({required this.stream});

  final Stream<List<BiddingRecord>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BiddingRecord>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final items = snap.data!;
        if (items.isEmpty) {
          return const EmptyState(
              icon: Icons.gavel_outlined,
              title: 'Aún no has pujado',
              message: 'Explora las subastas y haz tu primera puja.');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, i) => _BiddingTile(item: items[i]),
        );
      },
    );
  }
}

class _BiddingTile extends StatelessWidget {
  const _BiddingTile({required this.item});

  final BiddingRecord item;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<LotsRecord?>(
      stream: AuctionService.instance.lot(item.lotId),
      builder: (context, snap) {
        final lot = snap.data;
        String status = '…';
        Color color = theme.accent3;
        if (lot != null) {
          final winning = lot.highestBidderUid == currentUserUid;
          if (lot.status == 'ended') {
            final won = lot.winnerUid == currentUserUid;
            status = won ? 'GANASTE' : 'PERDIDA';
            color = won ? theme.primary : theme.accent3;
          } else {
            status = winning ? 'GANANDO' : 'SUPERADO';
            color = winning ? theme.primary : theme.tertiary;
          }
        }
        return InkWell(
          onTap: () => context.pushNamed('LotDetailView',
              queryParameters: {'lotId': item.lotId}),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              border: Border.all(color: theme.secondary, width: 1.5),
            ),
            child: Row(children: [
              SizedBox(width: 56, height: 56, child: LotImage(item.lotImage)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.lotTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall),
                    Text('Mi máximo: ${formatMoney(item.myMaxBid)}',
                        style: theme.bodySmall),
                    if (lot != null)
                      Text('Actual: ${formatMoney(lot.currentBid)}',
                          style: theme.bodySmall),
                  ],
                ),
              ),
              Tag(status, background: color, foreground: Colors.white),
            ]),
          ),
        );
      },
    );
  }
}

class _LotsList extends StatelessWidget {
  const _LotsList({
    required this.stream,
    required this.empty,
    this.showStatus = false,
  });

  final Stream<List<LotsRecord>> stream;
  final Widget empty;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<List<LotsRecord>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
              icon: Icons.error_outline,
              title: 'Error al cargar',
              message: '${snap.error}');
        }
        if (!snap.hasData) return const Loading();
        final lots = snap.data!;
        if (lots.isEmpty) return empty;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: lots.length,
          itemBuilder: (context, i) {
            final lot = lots[i];
            final ended = lot.isEnded();
            return InkWell(
              onTap: () => context.pushNamed('LotDetailView',
                  queryParameters: {'lotId': lot.reference.id}),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  border: Border.all(color: theme.secondary, width: 1.5),
                ),
                child: Row(children: [
                  SizedBox(
                      width: 56, height: 56, child: LotImage(lot.firstImage)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lot.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleSmall),
                        Text(
                            '${formatMoney(lot.currentBid)} · ${lot.bidCount} pujas',
                            style: theme.bodySmall),
                        if (!ended) Countdown(lot: lot),
                      ],
                    ),
                  ),
                  if (showStatus)
                    Tag(
                      ended
                          ? (lot.winnerUid.isNotEmpty ? 'Vendido' : 'Sin pujas')
                          : 'Activa',
                      background: ended ? theme.accent3 : theme.surfaceVariant,
                    ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

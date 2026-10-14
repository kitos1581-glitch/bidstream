import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/ui_kit.dart';

/// Avisos: te superaron, ganaste, vendiste, sin pujas.
class AuctionNotificationsWidget extends StatefulWidget {
  const AuctionNotificationsWidget({super.key});

  static String routeName = 'AuctionNotifications';
  static String routePath = '/auctionNotifications';

  @override
  State<AuctionNotificationsWidget> createState() =>
      _AuctionNotificationsWidgetState();
}

class _AuctionNotificationsWidgetState
    extends State<AuctionNotificationsWidget> {
  late final Stream<List<NotificationsRecord>> _items =
      AuctionService.instance.notifications();
  List<NotificationsRecord> _latest = const [];

  IconData _icon(String type) => switch (type) {
        'outbid' => Icons.trending_up,
        'won' => Icons.emoji_events_outlined,
        'sold' => Icons.sell_outlined,
        'unsold' => Icons.inventory_2_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      bottomNavigationBar: const AppBottomNav(current: NavTab.avisos),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.primaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Avisos',
            style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () => AuctionService.instance.markAllRead(_latest),
            child: const Text('Marcar todo leído'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationsRecord>>(
        stream: _items,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
                icon: Icons.error_outline,
                title: 'Error al cargar',
                message: '${snap.error}');
          }
          if (!snap.hasData) return const Loading();
          final items = snap.data!;
          _latest = items;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Sin avisos',
              message:
                  'Aquí te avisaremos si te superan en una puja o si ganas.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return InkWell(
                onTap: () {
                  if (!n.read) AuctionService.instance.markRead(n);
                  if (n.lotId.isNotEmpty) {
                    context.pushNamed('LotDetailView',
                        queryParameters: {'lotId': n.lotId});
                  }
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: n.read
                        ? theme.secondaryBackground
                        : theme.primaryContainer,
                    border: Border.all(color: theme.secondary, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon(n.type),
                          color: n.type == 'outbid'
                              ? theme.tertiary
                              : theme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title,
                                style: theme.titleSmall.copyWith(
                                    fontWeight: n.read
                                        ? FontWeight.w600
                                        : FontWeight.w800)),
                            const SizedBox(height: 2),
                            SelectableText(n.body, style: theme.bodySmall),
                            const SizedBox(height: 4),
                            Text(timeAgo(n.createdTime),
                                style: theme.labelSmall),
                          ],
                        ),
                      ),
                      if (!n.read)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          color: theme.tertiary,
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

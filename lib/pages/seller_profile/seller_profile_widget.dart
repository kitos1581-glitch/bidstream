import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/backend/reputation_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/ui/ui_kit.dart';

/// Perfil público del vendedor: nombre público, calificación, ventas,
/// insignias, lotes activos y opiniones. Sin datos de contacto.
class SellerProfileWidget extends StatefulWidget {
  const SellerProfileWidget({super.key, required this.uid});
  final String uid;

  static String routeName = 'SellerProfile';
  static String routePath = '/vendedor';

  @override
  State<SellerProfileWidget> createState() => _SellerProfileWidgetState();
}

class _SellerProfileWidgetState extends State<SellerProfileWidget> {
  late final Stream<PublicProfile> _profile =
      ReputationService.instance.profile(widget.uid);
  late final Stream<List<LotsRecord>> _lots =
      AuctionService.instance.sellerActiveLots(widget.uid);
  late final Stream<List<FeedbackEntry>> _feedback =
      ReputationService.instance.sellerFeedback(widget.uid);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text('Vendedor'),
        leading: const BackOrHomeButton(),
        foregroundColor: theme.primaryText,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            StreamBuilder<PublicProfile>(
              stream: _profile,
              builder: (context, s) {
                if (s.hasError) return ErrorState(error: s.error);
                if (!s.hasData) return const Loading();
                final p = s.data!;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.primaryContainer,
                        child: Text(
                          p.displayName.isEmpty ? '?' : p.displayName.characters.first,
                          style: theme.headlineSmall.copyWith(color: theme.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.displayName.isEmpty ? 'Vendedor' : p.displayName,
                              style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          if (p.ratingCount > 0)
                            Row(children: [
                              RatingStars(value: p.ratingAvg),
                              const SizedBox(width: 6),
                              Text('${p.ratingAvg.toStringAsFixed(1)} (${p.ratingCount} opiniones)',
                                  style: theme.bodySmall),
                            ])
                          else
                            Text('Sin opiniones todavía', style: theme.bodySmall),
                          Text('${p.salesCount} ${p.salesCount == 1 ? 'venta' : 'ventas'} completadas',
                              style: theme.bodySmall.copyWith(color: theme.secondaryText)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SellerBadges(badges: p.badges),
                  ]),
                );
              },
            ),
            const SectionTitle('Subastas activas'),
            StreamBuilder<List<LotsRecord>>(
              stream: _lots,
              builder: (context, s) {
                if (s.hasError) return ErrorState(error: s.error);
                if (!s.hasData) return const Loading();
                if (s.data!.isEmpty) {
                  return const EmptyState(
                      icon: Icons.inventory_2_outlined, title: 'No tiene subastas activas');
                }
                return SizedBox(
                  height: 220 * 3 / 4 + 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: s.data!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => LotCard(lot: s.data![i], width: 220),
                  ),
                );
              },
            ),
            const SectionTitle('Opiniones de compradores'),
            StreamBuilder<List<FeedbackEntry>>(
              stream: _feedback,
              builder: (context, s) {
                if (s.hasError) return ErrorState(error: s.error);
                if (!s.hasData) return const Loading();
                if (s.data!.isEmpty) {
                  return const EmptyState(
                      icon: Icons.reviews_outlined, title: 'Todavía no hay opiniones');
                }
                return Column(children: [
                  for (final f in s.data!) FeedbackTile(entry: f),
                ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class FeedbackTile extends StatelessWidget {
  const FeedbackTile({super.key, required this.entry});
  final FeedbackEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.alternate),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RatingStars(value: entry.rating.toDouble(), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${entry.authorName} · ${entry.lotTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall.copyWith(color: theme.secondaryText)),
          ),
        ]),
        if (entry.comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(entry.comment, style: theme.bodyMedium),
        ],
      ]),
    );
  }
}

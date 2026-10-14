import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/ui_kit.dart';

/// Pantalla principal: subastas en vivo + catálogo con búsqueda y categorías.
class AuctionDashboardWidget extends StatefulWidget {
  const AuctionDashboardWidget({super.key});

  static String routeName = 'AuctionDashboard';
  static String routePath = '/auctionDashboard';

  @override
  State<AuctionDashboardWidget> createState() => _AuctionDashboardWidgetState();
}

class _AuctionDashboardWidgetState extends State<AuctionDashboardWidget> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  late final Stream<List<LotsRecord>> _lots =
      AuctionService.instance.activeLots();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LotsRecord> _filter(List<LotsRecord> lots) {
    final q = _query.trim().toLowerCase();
    return lots.where((l) {
      if (_category != null && l.category != _category) return false;
      if (q.isEmpty) return true;
      return l.title.toLowerCase().contains(q) ||
          l.description.toLowerCase().contains(q) ||
          l.category.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1100 ? 4 : (width > 700 ? 3 : 2);
    // Alto de tarjeta = foto 4:3 + bloque de texto.
    final cellWidth = (width - 32 - 12 * (columns - 1)) / columns;
    final cardHeight = cellWidth * 3 / 4 + 166;

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      bottomNavigationBar: const AppBottomNav(current: NavTab.inicio),
      body: SafeArea(
        child: StreamBuilder<List<LotsRecord>>(
          stream: _lots,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'No pudimos cargar las subastas',
                message: '${snap.error}',
              );
            }
            if (!snap.hasData) return const Loading();

            final now = DateTime.now();
            final all = snap.data!;
            final live = all.where((l) => l.isLiveNow(now)).toList();
            final filtered = _filter(all);

            return CustomScrollView(slivers: [
              // ---------------- Encabezado + búsqueda ----------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subastas',
                          style: theme.headlineMedium
                              .copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar lotes o categorías…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          filled: true,
                          fillColor: theme.secondaryBackground,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide:
                                  BorderSide(color: theme.secondary, width: 2)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide:
                                  BorderSide(color: theme.primary, width: 2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ---------------- Categorías ----------------
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    children: [
                      _chip('Todas', _category == null,
                          () => setState(() => _category = null)),
                      for (final c in kLotCategories)
                        _chip(c, _category == c,
                            () => setState(() => _category = c)),
                    ],
                  ),
                ),
              ),

              // ---------------- En vivo ahora ----------------
              if (live.isNotEmpty && _query.isEmpty && _category == null) ...[
                const SliverToBoxAdapter(child: SectionTitle('En vivo ahora')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: live.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _LiveBanner(lot: live[i]),
                    ),
                  ),
                ),
              ],

              // ---------------- Catálogo ----------------
              SliverToBoxAdapter(
                child: SectionTitle(
                  _category ?? 'Todas las subastas',
                  trailing: Text('${filtered.length}',
                      style: theme.labelMedium),
                ),
              ),
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: all.isEmpty
                        ? 'Todavía no hay subastas'
                        : 'Nada coincide con tu búsqueda',
                    message: all.isEmpty
                        ? 'Sé el primero en publicar un lote.'
                        : 'Prueba con otra palabra o categoría.',
                    action: all.isEmpty
                        ? SizedBox(
                            width: 220,
                            child: BigButton(
                              label: 'Publicar lote',
                              onPressed: () =>
                                  context.goNamed('CreateLotManagement'),
                            ),
                          )
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: cardHeight,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => LotCard(lot: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? theme.secondary : theme.secondaryBackground,
            border: Border.all(color: theme.secondary, width: 1.5),
          ),
          child: Text(label,
              style: theme.labelMedium.copyWith(
                  color: selected ? Colors.white : theme.primaryText)),
        ),
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.lot});

  final LotsRecord lot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: () => context.pushNamed('LiveStreamAuction',
          queryParameters: {'lotId': lot.reference.id}),
      child: Container(
        width: 280,
        decoration:
            BoxDecoration(border: Border.all(color: theme.secondary, width: 2)),
        child: Stack(fit: StackFit.expand, children: [
          LotImage(lot.firstImage),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
              ),
            ),
          ),
          const Positioned(left: 10, top: 10, child: LiveTag()),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lot.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleSmall.copyWith(color: Colors.white)),
                Row(children: [
                  Text(formatMoney(lot.currentBid),
                      style: theme.titleMedium.copyWith(
                          color: theme.surfaceVariant,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('ENTRAR ▸',
                      style: theme.labelMedium.copyWith(color: Colors.white)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

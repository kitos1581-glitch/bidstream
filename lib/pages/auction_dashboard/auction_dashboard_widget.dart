import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/regions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/help_center/help_center_widget.dart';
import '/ui/ui_kit.dart';

/// Inicio estilo marketplace: buscador, banner, categorías, filas de
/// "En vivo" y "Terminan pronto", y el catálogo completo.
class AuctionDashboardWidget extends StatefulWidget {
  const AuctionDashboardWidget({super.key});

  static String routeName = 'AuctionDashboard';
  static String routePath = '/auctionDashboard';

  @override
  State<AuctionDashboardWidget> createState() => _AuctionDashboardWidgetState();
}

/// Ícono (Material, una sola familia) y tono de cada categoría.
const _categoryStyle = <String, (IconData, int)>{
  'Vehículos': (Icons.directions_car_outlined, 0xFF2563EB),
  'Ganado y caballos': (Icons.pets_outlined, 0xFFB45309),
  'Maquinaria y herramientas': (Icons.agriculture_outlined, 0xFF15803D),
  'Electrónica': (Icons.smartphone_outlined, 0xFF7C3AED),
  'Hogar y muebles': (Icons.chair_outlined, 0xFF475569),
  'Joyería y relojes': (Icons.watch_outlined, 0xFFA16207),
  'Arte y colección': (Icons.palette_outlined, 0xFFBE185D),
  'Deportes': (Icons.sports_soccer_outlined, 0xFF0F766E),
  'Ropa y accesorios': (Icons.checkroom_outlined, 0xFF4338CA),
  'Otros': (Icons.category_outlined, 0xFF78716C),
};

/// Con menos lotes que esto, el inicio muestra el panel de "estamos arrancando".
const _fewLots = 6;

class _AuctionDashboardWidgetState extends State<AuctionDashboardWidget> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  late Stream<List<LotsRecord>> _lots = AuctionService.instance.activeLots();

  /// Municipio para filtrar ('' = toda la región). Se recuerda en el equipo.
  String _region = '';

  /// Para que "Ver subastas" del banner baje al catálogo.
  final _catalogKey = GlobalKey();

  void _scrollToCatalog() {
    final ctx = _catalogKey.currentContext;
    if (ctx == null) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Scrollable.ensureVisible(ctx,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic);
  }

  @override
  void initState() {
    super.initState();
    RegionPreference.load().then((v) {
      if (mounted && v != _region) setState(() => _region = v);
    });
  }

  void _setRegion(String v) {
    setState(() => _region = v);
    RegionPreference.save(v);
  }

  Future<void> _pickRegion() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Toda la región'),
            trailing: _region.isEmpty ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(c, ''),
          ),
          for (final e in kMunicipalities.entries)
            if (e.key != 'otro')
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(e.value),
                trailing: _region == e.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(c, e.key),
              ),
        ]),
      ),
    );
    if (v != null) _setRegion(v);
  }

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

  bool get _browsing => _query.trim().isNotEmpty || _category != null;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1100 ? 5 : (width > 800 ? 4 : (width > 560 ? 3 : 2));
    final contentWidth = width > 1280 ? 1280.0 : width;
    final cellWidth = (contentWidth - 32 - 12 * (columns - 1)) / columns;
    final cardHeight = lotCardHeight(cellWidth);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      bottomNavigationBar: const AppBottomNav(current: NavTab.inicio),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: StreamBuilder<List<LotsRecord>>(
              stream: _lots,
              builder: (context, snap) {
                final header = _Header(
                  controller: _search,
                  query: _query,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                );
                if (snap.hasError) {
                  return Column(children: [
                    header,
                    Expanded(
                      child: ErrorState(
                        error: snap.error,
                        onRetry: () => setState(
                            () => _lots = AuctionService.instance.activeLots()),
                      ),
                    ),
                  ]);
                }
                if (!snap.hasData) {
                  return CustomScrollView(physics: const NeverScrollableScrollPhysics(), slivers: [
                    SliverToBoxAdapter(child: header),
                    const SliverToBoxAdapter(child: _HeroSkeleton()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: cardHeight,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => const LotCardSkeleton(),
                          childCount: columns * 2,
                        ),
                      ),
                    ),
                  ]);
                }

                final now = DateTime.now();
                // Filtro por municipio: "Toda la región" o solo el elegido.
                final all = _region.isEmpty
                    ? snap.data!
                    : snap.data!.where((l) => l.municipality == _region).toList();
                final live = all.where((l) => l.isLiveNow(now)).toList();
                final endingSoon = all
                    .where((l) =>
                        l.isOpenForBids(now) &&
                        l.endTime!.difference(now) < const Duration(hours: 24))
                    .toList();
                final filtered = _filter(all);

                return CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: header),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(children: [
                        ActionChip(
                          avatar: Icon(_region.isEmpty ? Icons.public : Icons.place,
                              size: 18, color: theme.primary),
                          label: Text(_region.isEmpty
                              ? 'Toda la región'
                              : municipalityName(_region)),
                          onPressed: _pickRegion,
                          shape: const StadiumBorder(),
                        ),
                        if (_region.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => _setRegion(''),
                            child: const Text('Ver toda la región'),
                          ),
                        ],
                      ]),
                    ),
                  ),

                  if (!_browsing)
                    SliverToBoxAdapter(
                      child: _Hero(
                        liveCount: live.length,
                        activeCount: all.length,
                        onBrowse: _scrollToCatalog,
                      ),
                    ),
                  if (_query.trim().isEmpty) ...[
                    const SliverToBoxAdapter(child: SectionTitle('Explora por categoría')),
                    SliverToBoxAdapter(
                      child: _CategoryRow(
                        selected: _category,
                        onSelect: (c) => setState(() => _category = c == _category ? null : c),
                      ),
                    ),
                  ],
                  if (!_browsing) ...[
                    if (live.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: SectionTitle('En vivo ahora',
                            leading: const _LiveDot(),
                            trailing: Text('${live.length}', style: theme.labelMedium)),
                      ),
                      SliverToBoxAdapter(child: _LotRow(lots: live, cardWidth: 220)),
                    ],
                    if (endingSoon.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: SectionTitle('Terminan pronto',
                            leading: Icon(Icons.timer_outlined, color: theme.tertiary)),
                      ),
                      SliverToBoxAdapter(child: _LotRow(lots: endingSoon, cardWidth: 220)),
                    ],
                  ],

                  // ---------------- Catálogo ----------------
                  SliverToBoxAdapter(
                    key: _catalogKey,
                    child: SectionTitle(
                      _category ?? (_query.isNotEmpty ? 'Resultados' : 'Todas las subastas'),
                      trailing: _browsing
                          ? TextButton.icon(
                              onPressed: () {
                                _search.clear();
                                setState(() {
                                  _query = '';
                                  _category = null;
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Quitar filtros'),
                            )
                          : Text('${filtered.length} lotes',
                              style: theme.bodySmall.copyWith(color: theme.secondaryText)),
                    ),
                  ),
                  if (all.isEmpty && !_browsing)
                    SliverToBoxAdapter(
                      child: _StartingPanel(
                        big: true,
                        region: _region.isEmpty ? '' : municipalityName(_region),
                        onSeeRegion: _region.isEmpty ? null : () => _setRegion(''),
                      ),
                    )
                  else if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nada coincide con tu búsqueda',
                        message: 'Prueba con otra palabra, otra categoría o toda la región.',
                        action: OutlinedButton.icon(
                          onPressed: () {
                            _search.clear();
                            setState(() {
                              _query = '';
                              _category = null;
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Quitar filtros'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
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
                  if (!_browsing && all.isNotEmpty && all.length < _fewLots)
                    const SliverToBoxAdapter(child: _StartingPanel(big: false)),
                  const SliverToBoxAdapter(child: SectionTitle('Así funciona')),
                  const SliverToBoxAdapter(child: HowItWorks()),
                  const SliverToBoxAdapter(child: HelpLinks()),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Encabezado: logo, buscador y avisos
// =====================================================================
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final logo = RichText(
      text: TextSpan(
        style: theme.headlineSmall.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        children: [
          TextSpan(text: 'Subástalo ', style: TextStyle(color: theme.primary)),
          TextSpan(text: 'Aquí', style: TextStyle(color: theme.tertiary)),
        ],
      ),
    );
    return Container(
      color: theme.secondaryBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(children: [
        Row(children: [
          logo,
          const Spacer(),
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => context.pushNamed('HelpCenter'),
          ),
          IconButton(
            tooltip: 'Avisos',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.goNamed('AuctionNotifications'),
          ),
          if (currentUserUid.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => context.pushNamed('BidderAccess'),
                child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            )
          else
            IconButton(
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => context.goNamed('UserProfileActivity'),
            ),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar caballos, camionetas, celulares…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: onClear),
              filled: true,
              fillColor: theme.secondaryContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: theme.primary, width: 2),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Banner principal: propuesta de valor, dos acciones y confianza
// =====================================================================
class _Hero extends StatelessWidget {
  const _Hero({
    required this.liveCount,
    required this.activeCount,
    required this.onBrowse,
  });

  final int liveCount;
  final int activeCount;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final wide = MediaQuery.sizeOf(context).width > 760;
    const fg = Colors.white;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.place_outlined, size: 14, color: fg),
            const SizedBox(width: 4),
            Text('Centro-sur de Chihuahua',
                style: theme.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Compra y vende en subasta, '),
            TextSpan(text: 'con tu pago protegido', style: TextStyle(color: theme.tertiary)),
          ]),
          style: (wide ? theme.displaySmall : theme.headlineSmall).copyWith(
              color: fg, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -0.5),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Camargo, Delicias, Meoqui, Saucillo, Jiménez y más. '
            'Tu dinero se le libera al vendedor hasta que recibes el artículo.',
            style: theme.bodyMedium.copyWith(color: fg.withOpacity(0.86), height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.tertiary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: const StadiumBorder(),
            ),
            onPressed: onBrowse,
            icon: const Icon(Icons.gavel_rounded, size: 20),
            label: const Text('Ver subastas', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              side: BorderSide(color: Colors.white.withOpacity(0.55)),
              shape: const StadiumBorder(),
            ),
            onPressed: () => context.pushNamed('CreateLotManagement'),
            icon: const Icon(Icons.add_a_photo_outlined, size: 20),
            label: const Text('Vender gratis', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 16, runSpacing: 8, children: const [
          _TrustItem(Icons.verified_user_outlined, 'Pago protegido'),
          _TrustItem(Icons.badge_outlined, 'Vendedores con INE'),
          _TrustItem(Icons.percent_rounded, '0 % de comisión hasta marzo'),
        ]),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14305C), Color(0xFF1B3A6B), Color(0xFF285192)],
          ),
        ),
        child: Stack(children: [
          // Formas decorativas (no informativas).
          Positioned(
            right: -60,
            top: -60,
            child: _Blob(size: 220, color: theme.tertiary.withOpacity(0.22)),
          ),
          Positioned(
            right: wide ? 180 : -30,
            bottom: -80,
            child: _Blob(size: 180, color: Colors.white.withOpacity(0.06)),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 36 : 22),
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(flex: 3, child: copy),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: _HeroStats(liveCount: liveCount, activeCount: activeCount),
                    ),
                  ])
                : copy,
          ),
        ]),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
      const SizedBox(width: 6),
      Text(text,
          style: theme.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Lado derecho del banner en pantallas anchas: cifras en tiempo real.
class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.liveCount, required this.activeCount});
  final int liveCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget tile(IconData icon, String value, String label, {Widget? lead}) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Row(children: [
            lead ?? Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: theme.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                Text(label,
                    style: theme.bodySmall.copyWith(color: Colors.white.withOpacity(0.8))),
              ]),
            ),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      tile(Icons.circle, '$liveCount', liveCount == 1 ? 'subasta en vivo' : 'subastas en vivo',
          lead: const _LiveDot(size: 12)),
      const SizedBox(height: 10),
      tile(Icons.inventory_2_outlined, '$activeCount',
          activeCount == 1 ? 'lote activo' : 'lotes activos'),
      const SizedBox(height: 10),
      tile(Icons.schedule_rounded, '40 s', 'extra si alguien puja al final'),
    ]);
  }
}

/// Esqueleto del banner mientras carga (mismo alto aproximado, sin saltos).
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: wide ? 300 : 330,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14305C), Color(0xFF285192)],
          ),
        ),
      ),
    );
  }
}

/// Punto rojo que late (indicador de "en vivo"). Quieto con reduce-motion.
class _LiveDot extends StatefulWidget {
  const _LiveDot({this.size = 10});
  final double size;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE11D48);
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
    );
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return dot;
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Container(
            width: widget.size * (1 + _c.value),
            height: widget.size * (1 + _c.value),
            decoration: BoxDecoration(
              color: red.withOpacity(0.35 * (1 - _c.value)),
              shape: BoxShape.circle,
            ),
          ),
        ),
        dot,
      ]),
    );
  }
}

// =====================================================================
// Categorías: mosaico con ícono y estado seleccionado
// =====================================================================
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kLotCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = kLotCategories[i];
          final style = _categoryStyle[c] ?? (Icons.category_outlined, 0xFF78716C);
          final tone = Color(style.$2);
          final isSel = c == selected;
          return Semantics(
            selected: isSel,
            button: true,
            child: Material(
              color: isSel ? tone.withOpacity(0.12) : theme.secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: isSel ? tone : theme.alternate, width: isSel ? 1.5 : 1),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                onTap: () => onSelect(c),
                child: SizedBox(
                  width: 96,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                    child: Column(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tone.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(style.$1, color: tone, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(c,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall.copyWith(
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              height: 1.2)),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =====================================================================
// Estado vacío / pocos lotes: "estamos arrancando"
// =====================================================================
class _StartingPanel extends StatelessWidget {
  const _StartingPanel({required this.big, this.region = '', this.onSeeRegion});

  /// true = no hay ningún lote (panel completo); false = pocos lotes (franja).
  final bool big;
  final String region;
  final VoidCallback? onSeeRegion;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final wide = MediaQuery.sizeOf(context).width > 700;
    final title = big
        ? (region.isNotEmpty
            ? 'Aún no hay lotes en $region'
            : 'Los primeros lotes ya vienen en camino')
        : 'Apenas estamos arrancando';
    final message = big
        ? 'Publica el tuyo y aparece hasta arriba. Vender cuesta 0 % de comisión '
            'hasta el 31 de marzo de 2027 y solo te toma unos minutos con fotos del celular.'
        : 'Hay pocos lotes por ahora. Si tienes algo que vender, este es el mejor momento: '
            '0 % de comisión y más visibilidad.';

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.primary,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: const StadiumBorder(),
          ),
          onPressed: () => context.pushNamed('CreateLotManagement'),
          icon: const Icon(Icons.add_a_photo_outlined, size: 20),
          label: const Text('Publicar gratis', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (onSeeRegion != null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48), shape: const StadiumBorder()),
            onPressed: onSeeRegion,
            child: const Text('Ver toda la región'),
          )
        else
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48), shape: const StadiumBorder()),
            onPressed: () => context.pushNamed('HelpCenter'),
            child: const Text('¿Cómo funciona?'),
          ),
      ],
    );

    final text = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: (big ? theme.headlineSmall : theme.titleLarge)
                .copyWith(fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 8),
        Text(message,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: theme.bodyMedium.copyWith(color: theme.secondaryText, height: 1.5)),
        const SizedBox(height: 16),
        actions,
      ],
    );

    final art = _StartingArt(size: big ? 150 : 110);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, big ? 8 : 0, 16, 8),
      child: Container(
        padding: EdgeInsets.all(wide ? 28 : 22),
        decoration: BoxDecoration(
          color: theme.primaryContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.primary.withOpacity(0.12)),
        ),
        child: wide
            ? Row(children: [art, const SizedBox(width: 28), Expanded(child: text)])
            : Column(children: [art, const SizedBox(height: 16), text]),
      ),
    );
  }
}

/// Ilustración hecha con formas: tres tarjetas encimadas con íconos.
class _StartingArt extends StatelessWidget {
  const _StartingArt({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget card(IconData icon, Color bg, Color fg, double angle, Offset offset) =>
        Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: size * 0.56,
              height: size * 0.66,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: softShadow(0.10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: fg, size: size * 0.26),
            ),
          ),
        );
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          card(Icons.sell_outlined, theme.secondaryBackground, theme.secondaryText, -0.22,
              Offset(-size * 0.2, size * 0.04)),
          card(Icons.local_shipping_outlined, theme.secondaryBackground, theme.secondaryText,
              0.22, Offset(size * 0.2, size * 0.04)),
          card(Icons.gavel_rounded, theme.tertiary, Colors.white, 0, Offset(0, -size * 0.04)),
        ]),
      ),
    );
  }
}

// =====================================================================
// Fila horizontal de lotes
// =====================================================================
class _LotRow extends StatelessWidget {
  const _LotRow({required this.lots, required this.cardWidth});
  final List<LotsRecord> lots;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: lotCardHeight(cardWidth) + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: lots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => LotCard(lot: lots[i], width: cardWidth),
      ),
    );
  }
}

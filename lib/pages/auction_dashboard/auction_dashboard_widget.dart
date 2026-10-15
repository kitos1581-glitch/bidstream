import 'dart:async';

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

/// Ícono y color de cada categoría para las tarjetas.
const _categoryStyle = <String, (String, int)>{
  'Vehículos': ('🚗', 0xFFE3F2FD),
  'Ganado y caballos': ('🐎', 0xFFFFF3E0),
  'Maquinaria y herramientas': ('🚜', 0xFFF1F8E9),
  'Electrónica': ('📱', 0xFFEDE7F6),
  'Hogar y muebles': ('🛋️', 0xFFF5F5F5),
  'Joyería y relojes': ('⌚', 0xFFFFF8E1),
  'Arte y colección': ('🎨', 0xFFFCE4EC),
  'Deportes': ('⚽', 0xFFE0F2F1),
  'Ropa y accesorios': ('👟', 0xFFE8EAF6),
  'Otros': ('📦', 0xFFEFEBE9),
};

class _AuctionDashboardWidgetState extends State<AuctionDashboardWidget> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  late Stream<List<LotsRecord>> _lots = AuctionService.instance.activeLots();

  /// Municipio para filtrar ('' = toda la región). Se recuerda en el equipo.
  String _region = '';

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
    final cardHeight = cellWidth * 3 / 4 + 132;

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
                if (!snap.hasData) return Column(children: [header, const Expanded(child: Loading())]);

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

                  if (!_browsing) ...[
                    const SliverToBoxAdapter(child: _HeroCarousel()),
                    const SliverToBoxAdapter(child: SectionTitle('Explora por categoría')),
                    SliverToBoxAdapter(
                      child: _CategoryRow(
                        onSelect: (c) => setState(() => _category = c),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SectionTitle('Así funciona')),
                    const SliverToBoxAdapter(child: HowItWorks()),
                    if (live.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: SectionTitle('🔴 En vivo ahora',
                            trailing: Text('${live.length}', style: theme.labelMedium)),
                      ),
                      SliverToBoxAdapter(child: _LotRow(lots: live, cardWidth: 220)),
                    ],
                    if (endingSoon.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SectionTitle('⏰ Terminan pronto')),
                      SliverToBoxAdapter(child: _LotRow(lots: endingSoon, cardWidth: 220)),
                    ],
                  ],

                  // ---------------- Catálogo ----------------
                  SliverToBoxAdapter(
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
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: all.isEmpty && _region.isNotEmpty
                            ? 'Aún no hay subastas en ${municipalityName(_region)}'
                            : all.isEmpty
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
                                  onPressed: () => context.goNamed('CreateLotManagement'),
                                ),
                              )
                            : null,
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
// Banner rotativo
// =====================================================================
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroSlide {
  const _HeroSlide(this.title, this.subtitle, this.cta, this.route, this.emoji, this.c1, this.c2);
  final String title, subtitle, cta, route, emoji;
  final Color c1, c2;
}

class _HeroCarouselState extends State<_HeroCarousel> {
  static const _slides = [
    _HeroSlide('Subastas en vivo, desde tu celular', 'Mira la transmisión y puja en tiempo real.',
        'Ver subastas', 'AuctionDashboard', '🔴', Color(0xFF1B3A6B), Color(0xFF2F5A9E)),
    _HeroSlide('Vende en 2 minutos con IA', 'Sube fotos y la IA escribe tu publicación.',
        'Publicar ahora', 'CreateLotManagement', '✨', Color(0xFFF47920), Color(0xFFFFA65C)),
    _HeroSlide('Ganado, caballos y maquinaria', 'Compra y vende con vendedores verificados.',
        'Explorar', 'AuctionDashboard', '🐎', Color(0xFF0E8A00), Color(0xFF6BC25B)),
  ];

  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final wide = MediaQuery.sizeOf(context).width > 700;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        SizedBox(
          height: wide ? 240 : 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final s = _slides[i];
              const fg = Colors.white;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [s.c1, s.c2]),
                ),
                padding: EdgeInsets.all(wide ? 28 : 20),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.title,
                            maxLines: 2,
                            style: (wide ? theme.headlineMedium : theme.titleLarge).copyWith(
                                color: fg, fontWeight: FontWeight.w800, height: 1.15)),
                        const SizedBox(height: 6),
                        Text(s.subtitle,
                            maxLines: 2,
                            style: theme.bodyMedium.copyWith(color: fg.withOpacity(0.9))),
                        const SizedBox(height: 14),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: s.c1,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => context.goNamed(s.route),
                          child: Text(s.cta, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  Text(s.emoji, style: TextStyle(fontSize: wide ? 110 : 64)),
                ]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _slides.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _page ? theme.primaryText : theme.alternate,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ]),
      ]),
    );
  }
}

// =====================================================================
// Categorías (tarjetas redondas con ícono)
// =====================================================================
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kLotCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = kLotCategories[i];
          final style = _categoryStyle[c] ?? ('📦', 0xFFF5F5F5);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(c),
            child: SizedBox(
              width: 82,
              child: Column(children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Color(style.$2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(style.$1, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 6),
                Text(c,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall.copyWith(fontWeight: FontWeight.w600, height: 1.2)),
              ]),
            ),
          );
        },
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
      height: cardWidth * 3 / 4 + 140,
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

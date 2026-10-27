import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '/backend/backend.dart';
import '/backend/regions.dart';
import '/flutter_flow/flutter_flow_theme.dart';

// =====================================================================
// Formatos
// =====================================================================

final _money = NumberFormat.currency(
    locale: 'es_MX', symbol: '\$', decimalDigits: 0);
final _moneyCents = NumberFormat.currency(
    locale: 'es_MX', symbol: '\$', decimalDigits: 2);

/// $14,500  (muestra centavos solo si los hay)
String formatMoney(double value) =>
    value == value.roundToDouble() ? _money.format(value) : _moneyCents.format(value);

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
];

/// 14 oct, 18:30
String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_meses[d.month - 1]}, $h:$m';
}

/// "hace 5 min"
String timeAgo(DateTime? d) {
  if (d == null) return 'ahora';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return formatDateTime(d);
}

/// "2d 04:12:09" / "04:12:09" / "Terminada"
String formatRemaining(Duration d) {
  if (d.isNegative || d == Duration.zero) return 'Terminada';
  final days = d.inDays;
  final h = (d.inHours % 24).toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return days > 0 ? '${days}d $h:$m:$s' : '$h:$m:$s';
}

// =====================================================================
// Mensajes
// =====================================================================

void showMessage(BuildContext context, String text, {bool error = false}) {
  final theme = FlutterFlowTheme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? theme.error : theme.secondary,
      behavior: SnackBarBehavior.floating,
    ));
}

// =====================================================================
// Cuenta regresiva que se actualiza cada segundo
// =====================================================================

class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.lot,
    this.style,
    this.prefix = '',
  });

  final LotsRecord lot;
  final TextStyle? style;
  final String prefix;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lot = widget.lot;
    final now = DateTime.now();
    String text;
    if (lot.status == 'cancelled') {
      text = 'Cancelada';
    } else if (lot.status != 'active') {
      text = 'Terminada';
    } else if (!lot.hasStarted(now)) {
      text = 'Inicia en ${formatRemaining(lot.startTime!.difference(now))}';
    } else if (lot.endTime == null) {
      text = '—';
    } else {
      final left = lot.endTime!.difference(now);
      text = left.isNegative ? 'Cerrando…' : formatRemaining(left);
    }
    final theme = FlutterFlowTheme.of(context);
    return Text(
      '${widget.prefix}$text',
      style: widget.style ??
          theme.labelMedium.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}

// =====================================================================
// Imagen de lote con respaldo. Acepta URLs normales o, para los lotes
// de demostración, "emoji:🐎:0xFF8D6E63:0xFFD7CCC8" (emoji y degradado).
// =====================================================================

class LotImage extends StatelessWidget {
  const LotImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (url.startsWith('emoji:')) {
      final parts = url.split(':');
      Color c(int i, Color d) {
        final v = parts.length > i ? int.tryParse(parts[i]) : null;
        return v == null ? d : Color(v);
      }
      return LayoutBuilder(
        builder: (context, box) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c(2, theme.primaryContainer), c(3, theme.secondaryContainer)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(parts.length > 1 ? parts[1] : '📦',
              style: TextStyle(fontSize: (box.maxHeight * 0.45).clamp(24, 160))),
        ),
      );
    }
    final placeholder = Container(
      color: theme.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: theme.accent3, size: 32),
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

// =====================================================================
// Etiquetas (píldoras)
// =====================================================================

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.background, this.foreground, this.icon});

  final String text;
  final Color? background;
  final Color? foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final fg = foreground ?? theme.primaryText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? theme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: theme.labelSmall.copyWith(
                  color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
        ),
      ]),
    );
  }
}

class LiveTag extends StatelessWidget {
  const LiveTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Tag('EN VIVO',
        background: theme.tertiary,
        foreground: Colors.white,
        icon: Icons.circle);
  }
}

/// Sombra suave estándar de las tarjetas.
List<BoxShadow> softShadow([double opacity = 0.08]) => [
      BoxShadow(
        color: Colors.black.withOpacity(opacity),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];

// =====================================================================
// Tarjeta de lote (estilo marketplace)
// =====================================================================

class LotCard extends StatelessWidget {
  const LotCard({super.key, required this.lot, this.onTap, this.width});

  final LotsRecord lot;
  final VoidCallback? onTap;

  /// Ancho fijo (para filas horizontales). Null = ocupa la celda.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final card = Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            () => context.pushNamed('LotDetailView',
                queryParameters: {'lotId': lot.reference.id}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(fit: StackFit.expand, children: [
                LotImage(lot.firstImage),
                Positioned(
                  left: 8,
                  top: 8,
                  child: lot.isLiveNow() ? const LiveTag() : const SizedBox(),
                ),
                if (lot.isDemo)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Tag('Demo',
                        background: Colors.black.withOpacity(0.55),
                        foreground: Colors.white),
                  ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: _TimeChip(lot: lot),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lot.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(
                      [
                        if (municipalityName(lot.municipality).isNotEmpty &&
                            lot.municipality != 'otro')
                          '📍 ${municipalityName(lot.municipality)}',
                        kLotConditions[lot.condition] ??
                            (lot.category.isEmpty ? 'Lote' : lot.category),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall.copyWith(color: theme.secondaryText)),
                  const SizedBox(height: 6),
                  Text(formatMoney(lot.currentBid),
                      style: theme.titleLarge.copyWith(
                          fontWeight: FontWeight.w800, fontSize: 20)),
                  Text(
                      (lot.isFixedPrice
                              ? 'Precio fijo · Comprar ahora'
                              : lot.canBuyNow()
                                  ? 'Sin pujas · o cómpralo en ${formatMoney(lot.buyNowPrice ?? 0)}'
                              : lot.bidCount == 0
                              ? 'Precio inicial · sin pujas'
                              : '${lot.bidCount} ${lot.bidCount == 1 ? 'puja' : 'pujas'}') +
                          (lot.sellerRatingCount > 0
                              ? ' · ★ ${lot.sellerRatingAvg.toStringAsFixed(1)}'
                              : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall.copyWith(color: theme.secondaryText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.alternate),
        boxShadow: softShadow(0.04),
      ),
      child: card,
    );
  }
}

/// Píldora de tiempo sobre la foto: roja si queda menos de 1 hora.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.lot});
  final LotsRecord lot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final end = lot.endTime;
    final urgent = end != null &&
        lot.hasStarted() &&
        end.difference(DateTime.now()) < const Duration(hours: 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: urgent ? theme.tertiary : Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Countdown(
          lot: lot,
          style: theme.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ]),
    );
  }
}

// =====================================================================
// Botón principal (píldora)
// =====================================================================

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.secondary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool secondary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final enabled = onPressed != null && !loading;
    final bg = secondary ? theme.secondaryBackground : theme.primary;
    final fg = secondary ? theme.primary : theme.onPrimary;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: Material(
        color: enabled ? bg : theme.secondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: secondary
              ? BorderSide(color: enabled ? theme.primary : theme.alternate, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: secondary ? theme.primary : Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, color: enabled ? fg : theme.accent3, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall.copyWith(
                              color: enabled ? fg : theme.accent3,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Estados vacíos y de carga
// =====================================================================

/// Flecha de regreso que SIEMPRE funciona: si hay pantalla anterior regresa;
/// si se entró directo (enlace compartido, recarga, app instalada) va al inicio.
class BackOrHomeButton extends StatelessWidget {
  const BackOrHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Regresar',
      icon: Icon(Icons.arrow_back, color: FlutterFlowTheme.of(context).primaryText),
      onPressed: () => context.canPop() ? context.pop() : context.goNamed('AuctionDashboard'),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: theme.primaryContainer, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: theme.primary),
        ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: theme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: theme.bodySmall.copyWith(color: theme.secondaryText)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(
              color: FlutterFlowTheme.of(context).primary),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(children: [
        Expanded(
          child: Text(text,
              style: theme.titleLarge
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// =====================================================================
// Barra de navegación inferior
// =====================================================================

enum NavTab { inicio, publicar, avisos, cuenta }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});

  final NavTab current;

  static const _routes = {
    NavTab.inicio: 'AuctionDashboard',
    NavTab.publicar: 'CreateLotManagement',
    NavTab.avisos: 'AuctionNotifications',
    NavTab.cuenta: 'UserProfileActivity',
  };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget item(NavTab tab, IconData icon, IconData activeIcon, String label,
        {int badge = 0}) {
      final selected = tab == current;
      final color = selected ? theme.primary : theme.secondaryText;
      return Expanded(
        child: InkWell(
          onTap: selected ? null : () => context.goNamed(_routes[tab]!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 9 ? '9+' : '$badge'),
                backgroundColor: theme.tertiary,
                child: Icon(selected ? activeIcon : icon, color: color),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: theme.labelSmall.copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        boxShadow: softShadow(0.06),
      ),
      child: SafeArea(
        top: false,
        child: StreamBuilder<int>(
          stream: AuctionService.instance.unreadCount(),
          builder: (context, snap) => Row(children: [
            item(NavTab.inicio, Icons.home_outlined, Icons.home_rounded, 'Inicio'),
            item(NavTab.publicar, Icons.add_circle_outline, Icons.add_circle,
                'Vender'),
            item(NavTab.avisos, Icons.notifications_none_rounded,
                Icons.notifications_rounded, 'Avisos',
                badge: snap.data ?? 0),
            item(NavTab.cuenta, Icons.person_outline_rounded,
                Icons.person_rounded, 'Mi cuenta'),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================
// Reconstruye la pantalla justo cuando la subasta INICIA o TERMINA,
// aunque no llegue ningún cambio nuevo de Firestore. También al volver
// la app del segundo plano.
// =====================================================================

/// Siguiente momento (después de [now]) en que cambia la fase del lote.
DateTime? nextPhaseChange(DateTime? start, DateTime? end, DateTime now) {
  DateTime? next;
  for (final d in [start, end]) {
    if (d != null && d.isAfter(now) && (next == null || d.isBefore(next))) {
      next = d;
    }
  }
  return next;
}

DateTime _systemNow() => DateTime.now();

class LotPhaseBuilder extends StatefulWidget {
  const LotPhaseBuilder({
    super.key,
    required this.start,
    required this.end,
    required this.builder,
    this.clock = _systemNow,
  });

  final DateTime? start;
  final DateTime? end;
  final WidgetBuilder builder;

  /// Reloj (inyectable para pruebas).
  final DateTime Function() clock;

  @override
  State<LotPhaseBuilder> createState() => _LotPhaseBuilderState();
}

class _LotPhaseBuilderState extends State<LotPhaseBuilder>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(LotPhaseBuilder old) {
    super.didUpdateWidget(old);
    if (old.start != widget.start || old.end != widget.end) _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final now = widget.clock();
    final next = nextPhaseChange(widget.start, widget.end, now);
    if (next == null) return;
    // +300 ms para caer del otro lado del límite.
    _timer = Timer(next.difference(now) + const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// =====================================================================
// Error de lectura: siempre se muestra (nunca carga infinita).
// =====================================================================

String friendlyError(Object? error) {
  final s = '$error';
  if (s.contains('permission-denied')) {
    return 'No tienes permiso para ver esta información.';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'Sin conexión con el servidor. Revisa tu internet.';
  }
  if (s.contains('failed-precondition') && s.contains('index')) {
    return 'Falta un índice en la base de datos (avisa al administrador).';
  }
  return 'Ocurrió un error al cargar. Intenta de nuevo.';
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    debugPrint('ErrorState: $error');
    final detail = '$error';
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'No pudimos cargar la información',
      message: friendlyError(error),
      action: Column(mainAxisSize: MainAxisSize.min, children: [
        if (onRetry != null)
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        const SizedBox(height: 8),
        // Detalle técnico (pequeño) para poder diagnosticar.
        Text(detail.length > 160 ? '${detail.substring(0, 160)}…' : detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}


/// Estrellas de calificación (solo lectura).
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, this.size = 16});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFF5AF02);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          value >= i
              ? Icons.star_rounded
              : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: size,
          color: color,
        ),
    ]);
  }
}

/// Insignias del vendedor (Verificado, Vendedor destacado, Nuevo).
class SellerBadges extends StatelessWidget {
  const SellerBadges({super.key, required this.badges});
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget chip(String key) {
      final (label, icon, bg, fg) = switch (key) {
        'tienda_oficial' => ('Tienda Oficial', Icons.storefront_rounded, theme.primary, Colors.white),
        'fundador' => ('Vendedor fundador', Icons.military_tech_rounded, const Color(0xFFFDE6D2), const Color(0xFF8A3B00)),
        'en_disputa' => ('En disputa', Icons.gavel_rounded, const Color(0xFFFDECEA), theme.error),
        'verificado' => ('Verificado', Icons.verified_rounded, theme.primaryContainer, theme.primary),
        'destacado' => ('Vendedor destacado', Icons.workspace_premium_rounded, const Color(0xFFFFF1C7), const Color(0xFF8A5A00)),
        'nuevo' => ('Nuevo', Icons.fiber_new_rounded, theme.secondaryContainer, theme.secondaryText),
        _ => (key, Icons.label_outline, theme.secondaryContainer, theme.secondaryText),
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: theme.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: [for (final b in badges) chip(b)]);
  }
}

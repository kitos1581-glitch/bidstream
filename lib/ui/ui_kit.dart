import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '/backend/backend.dart';
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
// Imagen de lote con respaldo
// =====================================================================

class LotImage extends StatelessWidget {
  const LotImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final placeholder = Container(
      color: theme.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: theme.secondaryText, size: 32),
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
// Etiquetas
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? theme.surfaceVariant,
        border: Border.all(color: theme.secondary, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
        ],
        Text(text.toUpperCase(),
            style: theme.labelSmall.copyWith(color: fg, letterSpacing: 0.6)),
      ]),
    );
  }
}

class LiveTag extends StatelessWidget {
  const LiveTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Tag('En vivo',
        background: theme.tertiary,
        foreground: Colors.white,
        icon: Icons.circle);
  }
}

// =====================================================================
// Tarjeta de lote
// =====================================================================

class LotCard extends StatelessWidget {
  const LotCard({super.key, required this.lot, this.onTap});

  final LotsRecord lot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: onTap ??
          () => context.pushNamed('LotDetailView',
              queryParameters: {'lotId': lot.reference.id}),
      child: Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          border: Border.all(color: theme.secondary, width: 2),
        ),
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
                  child: lot.isLiveNow()
                      ? const LiveTag()
                      : Tag(lot.category.isEmpty ? 'Lote' : lot.category),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lot.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall),
                  if (lot.condition == 'new')
                    Text('NUEVO',
                        style: theme.labelSmall.copyWith(
                            color: theme.primary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(lot.bidCount == 0 ? 'Precio inicial' : 'Puja actual',
                      style: theme.labelSmall),
                  Text(formatMoney(lot.currentBid),
                      style: theme.titleMedium.copyWith(
                          color: theme.primary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.timer_outlined,
                        size: 14, color: theme.secondaryText),
                    const SizedBox(width: 4),
                    Expanded(child: Countdown(lot: lot)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Botón principal
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
    final fg = secondary ? theme.primaryText : theme.onPrimary;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Material(
        color: enabled ? bg : theme.accent3,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.secondary, width: 2)),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, color: fg, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(label.toUpperCase(),
                        style: theme.labelLarge.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
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
        Icon(icon, size: 44, color: theme.secondaryText),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: theme.titleMedium),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: theme.labelLarge
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
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
    Widget item(NavTab tab, IconData icon, String label, {int badge = 0}) {
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
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: theme.labelSmall.copyWith(
                      color: color,
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
        border: Border(top: BorderSide(color: theme.secondary, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: StreamBuilder<int>(
          stream: AuctionService.instance.unreadCount(),
          builder: (context, snap) => Row(children: [
            item(NavTab.inicio, Icons.gavel_rounded, 'Subastas'),
            item(NavTab.publicar, Icons.add_box_outlined, 'Publicar'),
            item(NavTab.avisos, Icons.notifications_none_rounded, 'Avisos',
                badge: snap.data ?? 0),
            item(NavTab.cuenta, Icons.person_outline_rounded, 'Mi cuenta'),
          ]),
        ),
      ),
    );
  }
}

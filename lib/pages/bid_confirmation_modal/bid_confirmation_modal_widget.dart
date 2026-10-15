import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/deposit_guarantia/deposit_guarantia_widget.dart';
import '/ui/ui_kit.dart';

/// Elegir monto y confirmar la puja. La validación final la hace el servidor.
class BidConfirmationModalWidget extends StatefulWidget {
  const BidConfirmationModalWidget({super.key, required this.lotId});

  final String lotId;

  static String routeName = 'BidConfirmationModal';
  static String routePath = '/bidConfirmationModal';

  @override
  State<BidConfirmationModalWidget> createState() =>
      _BidConfirmationModalWidgetState();
}

class _BidConfirmationModalWidgetState
    extends State<BidConfirmationModalWidget> {
  late final Stream<LotsRecord?> _lot = AuctionService.instance.lot(widget.lotId);
  late final Stream<UsersRecord?> _profile = AuctionService.instance.myProfile();
  final _custom = TextEditingController();
  double? _amount;
  bool _sending = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _confirm(LotsRecord lot, double amount) async {
    setState(() => _sending = true);
    final result = await AuctionService.instance.placeBid(lot.reference.id, amount);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.ok) {
      final title = switch (result.outcome) {
        'outbid' => 'Otro postor tiene un máximo mayor',
        'max_raised' => 'Máximo actualizado',
        _ => '¡Vas ganando!',
      };
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(
            '${result.message ?? 'Tu máximo: ${formatMoney(result.yourMax ?? amount)}.'}'
            '${result.leading ? '\n\nEl sistema pujará por ti automáticamente hasta tu máximo. Te avisaremos si alguien lo supera.' : ''}'
            '${result.extended ? '\n\nLa subasta se extendió 30 segundos por puja de último momento.' : ''}',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Listo')),
          ],
        ),
      );
      // Si te superaron al instante, te quedas en la pantalla para ofrecer más.
      if (mounted && result.leading) context.safePop();
    } else if (result.identityRequired) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Verifica tu identidad'),
          content: Text(result.message ?? 'Para este monto necesitas verificar tu INE.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Ahora no')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Verificar INE')),
          ],
        ),
      );
      if (go == true && mounted) context.pushNamed('IdentityVerification');
    } else if (result.depositRequired) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Falta tu depósito de garantía'),
          content: Text(result.message ?? 'Deja tu depósito para poder pujar.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Ahora no')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Dejar depósito')),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const DepositGarantiaWidget(),
        ));
      }
    } else {
      showMessage(context, result.message ?? 'No se pudo pujar.', error: true);
      if (result.minimum != null) {
        setState(() {
          _amount = result.minimum;
          _custom.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Confirmar puja', style: theme.titleMedium),
      ),
      body: StreamBuilder<UsersRecord?>(
        stream: _profile,
        builder: (context, profileSnap) => StreamBuilder<LotsRecord?>(
          stream: _lot,
          builder: (context, snap) {
            // Errores de lectura: se muestran, nunca carga infinita.
            if (snap.hasError || profileSnap.hasError) {
              return ErrorState(error: snap.error ?? profileSnap.error);
            }
            if (snap.connectionState == ConnectionState.waiting ||
                profileSnap.connectionState == ConnectionState.waiting) {
              return const Loading();
            }
            // El lote dejó de existir (o nunca existió): mensaje claro.
            final lot = snap.data;
            if (lot == null) {
              return const EmptyState(
                  icon: Icons.search_off, title: 'Este lote ya no existe');
            }
            final profile = profileSnap.data;
            // Se reconstruye al iniciar/terminar la subasta aunque no
            // lleguen cambios de Firestore.
            return LotPhaseBuilder(
              start: lot.startTime,
              end: lot.endTime,
              builder: (context) {
            final emailOk = AuctionService.instance.emailVerified;
            final profileOk = profile?.isProfileComplete ?? false;

            if (!emailOk || !profileOk) {
              return EmptyState(
                icon: Icons.verified_user_outlined,
                title: 'Completa tu cuenta para pujar',
                message: [
                  if (!emailOk) '• Verifica tu correo electrónico.',
                  if (!profileOk) '• Agrega tu nombre, teléfono y acepta los términos.',
                ].join('\n'),
                action: SizedBox(
                  width: 240,
                  child: BigButton(
                    label: 'Completar ahora',
                    onPressed: () => context.pushNamed('OnboardingVerification'),
                  ),
                ),
              );
            }

            if (!lot.isOpenForBids()) {
              return EmptyState(
                icon: Icons.timer_off_outlined,
                title: lot.hasStarted()
                    ? 'Esta subasta ya terminó'
                    : 'Esta subasta aún no comienza',
              );
            }

            final min = lot.minimumNextBid;
            final step = lot.minimumIncrement > 0 ? lot.minimumIncrement : 1.0;
            // Si alguien pujó mientras estabas aquí, sube el monto al nuevo mínimo.
            final customText = _custom.text.trim();
            final double amount = customText.isNotEmpty
                ? (double.tryParse(customText) ?? 0)
                : ((_amount == null || _amount! < min) ? min : _amount!);
            final options = <double>[min, min + step, min + step * 2, min + step * 5];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  SizedBox(
                      width: 72, height: 72, child: LotImage(lot.firstImage)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lot.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleSmall),
                        const SizedBox(height: 4),
                        Text('Actual: ${formatMoney(lot.currentBid)}',
                            style: theme.bodySmall),
                        Countdown(lot: lot, prefix: 'Termina en '),
                      ],
                    ),
                  ),
                ]),
                const SectionTitle('Tu puja máxima (secreta)'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Pon lo MÁXIMO que estás dispuesto a pagar. Nadie lo ve: '
                    'el sistema puja por ti solo lo necesario para ir ganando, '
                    'de ${formatMoney(lot.minimumIncrement)} en ${formatMoney(lot.minimumIncrement)}, '
                    'sin pasarse de tu máximo.',
                    style: theme.bodySmall.copyWith(color: theme.secondaryText),
                  ),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in options)
                    ChoiceChip(
                      label: Text(formatMoney(o)),
                      selected: amount == o && _custom.text.isEmpty,
                      selectedColor: theme.surfaceVariant,
                      onSelected: (_) => setState(() {
                        _amount = o;
                        _custom.clear();
                      }),
                    ),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _custom,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Otro máximo',
                    helperText: 'Mínimo ${formatMoney(min)}',
                    errorText: customText.isNotEmpty && amount < min
                        ? 'Debe ser al menos ${formatMoney(min)}'
                        : null,
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: theme.secondaryBackground,
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    _row(context, 'Tu máximo', formatMoney(amount), bold: true),
                    const SizedBox(height: 6),
                    Text(
                      'Al confirmar te comprometes a comprar si ganas. '
                      'Las pujas no se pueden cancelar.',
                      style: theme.bodySmall
                          .copyWith(color: theme.secondaryText),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                BigButton(
                  label: 'Confirmar máximo ${formatMoney(amount)}',
                  loading: _sending,
                  onPressed: amount >= min ? () => _confirm(lot, amount) : null,
                ),
              ],
            );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final theme = FlutterFlowTheme.of(context);
    return Row(children: [
      Expanded(child: Text(label, style: theme.bodyMedium)),
      Text(value,
          style: (bold ? theme.titleLarge : theme.bodyMedium).copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
              color: bold ? theme.primary : null)),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/youtube.dart';
import '/ui/ui_kit.dart';

class _PickedPhoto {
  _PickedPhoto(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

/// Publicar un lote nuevo.
class CreateLotManagementWidget extends StatefulWidget {
  const CreateLotManagementWidget({super.key});

  static String routeName = 'CreateLotManagement';
  static String routePath = '/createLotManagement';

  @override
  State<CreateLotManagementWidget> createState() =>
      _CreateLotManagementWidgetState();
}

class _CreateLotManagementWidgetState extends State<CreateLotManagementWidget> {
  static const _maxPhotos = 10;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _increment = TextEditingController();
  final _streamUrl = TextEditingController();
  late final Stream<UsersRecord?> _profile = AuctionService.instance.myProfile();

  String? _category;
  String _format = 'timed';
  int _timedDays = 3;
  DateTime? _liveStart;
  int _liveMinutes = 30;
  final List<_PickedPhoto> _photos = [];
  bool _saving = false;
  String _progress = '';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _increment.dispose();
    _streamUrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
        maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    for (final f in files) {
      if (_photos.length >= _maxPhotos) break;
      final bytes = await f.readAsBytes();
      final name = f.name.toLowerCase();
      final mime = f.mimeType ??
          (name.endsWith('.png')
              ? 'image/png'
              : name.endsWith('.webp')
                  ? 'image/webp'
                  : 'image/jpeg');
      _photos.add(_PickedPhoto(bytes, mime));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickLiveStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _liveStart ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _liveStart ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() => _liveStart =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _suggestIncrement() {
    final p = double.tryParse(_price.text) ?? 0;
    if (p <= 0 || _increment.text.isNotEmpty) return;
    // Sugerencia: ~5% del precio, redondeado a un número "bonito".
    final raw = p * 0.05;
    final step = raw < 50
        ? 10
        : raw < 500
            ? 50
            : raw < 5000
                ? 100
                : 1000;
    final suggested = ((raw / step).ceil() * step).toDouble();
    _increment.text = suggested.toStringAsFixed(0);
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      showMessage(context, 'Agrega al menos una foto.', error: true);
      return;
    }
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;
    if (_format == 'live') {
      if (_liveStart == null) {
        showMessage(context, 'Elige la fecha y hora de la transmisión.',
            error: true);
        return;
      }
      start = _liveStart!.isBefore(now) ? now : _liveStart!;
      end = start.add(Duration(minutes: _liveMinutes));
    } else {
      start = now;
      end = now.add(Duration(days: _timedDays));
    }

    setState(() {
      _saving = true;
      _progress = 'Subiendo fotos…';
    });
    try {
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        setState(() => _progress = 'Subiendo foto ${i + 1} de ${_photos.length}…');
        urls.add(await AuctionService.instance
            .uploadLotImage(_photos[i].bytes, contentType: _photos[i].mime));
      }
      setState(() => _progress = 'Publicando…');
      final id = await AuctionService.instance.createLot(
        title: _title.text,
        description: _description.text,
        category: _category!,
        startingPrice: double.parse(_price.text),
        minimumIncrement: double.parse(_increment.text),
        startTime: start,
        endTime: end,
        format: _format,
        imageUrls: urls,
        streamUrl: _format == 'live' ? _streamUrl.text : '',
      );
      if (!mounted) return;
      showMessage(context, '¡Tu lote ya está publicado!');
      context.pushReplacementNamed('LotDetailView',
          queryParameters: {'lotId': id});
    } catch (e) {
      if (mounted) {
        showMessage(context, 'No se pudo publicar: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? helper, String? prefix}) {
    final theme = FlutterFlowTheme.of(context);
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      prefixText: prefix,
      filled: true,
      fillColor: theme.secondaryBackground,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: theme.secondary, width: 2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: theme.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: theme.error, width: 2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: theme.error, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      bottomNavigationBar: const AppBottomNav(current: NavTab.publicar),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.primaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Publicar lote',
            style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<UsersRecord?>(
        stream: _profile,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Loading();
          }
          final ready = AuctionService.instance.emailVerified &&
              (snap.data?.isProfileComplete ?? false);
          if (!ready) {
            return EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Completa tu cuenta para vender',
              message:
                  'Necesitas verificar tu correo y completar tu perfil (nombre, teléfono y términos).',
              action: SizedBox(
                width: 240,
                child: BigButton(
                  label: 'Completar ahora',
                  onPressed: () => context.pushNamed('OnboardingVerification'),
                ),
              ),
            );
          }
          return _form(theme);
        },
      ),
    );
  }

  Widget _form(FlutterFlowTheme theme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // ---------------- Fotos ----------------
          const SectionTitle('Fotos'),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (_photos.length < _maxPhotos)
                  InkWell(
                    onTap: _saving ? null : _pickPhotos,
                    child: Container(
                      width: 96,
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        border: Border.all(color: theme.secondary, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined),
                          const SizedBox(height: 4),
                          Text('${_photos.length}/$_maxPhotos',
                              style: theme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                for (var i = 0; i < _photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                            border:
                                Border.all(color: theme.secondary, width: 2)),
                        child: Image.memory(_photos[i].bytes, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: _saving
                              ? null
                              : () => setState(() => _photos.removeAt(i)),
                          child: Container(
                            color: theme.secondary,
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      if (i == 0)
                        const Positioned(left: 4, bottom: 4, child: Tag('Portada')),
                    ]),
                  ),
              ],
            ),
          ),

          // ---------------- Datos ----------------
          const SectionTitle('Datos del lote'),
          TextFormField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec('Título',
                helper: 'Ej. "Camioneta Ford Lobo 2015, 120 mil km"'),
            validator: (v) =>
                (v ?? '').trim().length < 3 ? 'Escribe un título' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: _dec('Categoría'),
            items: [
              for (final c in kLotCategories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Elige una categoría' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            minLines: 4,
            maxLines: 10,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec('Descripción',
                helper:
                    'Estado, medidas, defectos, papeles, dónde se entrega. Entre más claro, más pujas.'),
            validator: (v) => (v ?? '').trim().length < 20
                ? 'Describe el lote (mínimo 20 caracteres)'
                : null,
          ),

          // ---------------- Precio ----------------
          const SectionTitle('Precio'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Focus(
                onFocusChange: (f) {
                  if (!f) setState(_suggestIncrement);
                },
                child: TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec('Precio inicial', prefix: '\$ '),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Requerido'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _increment,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('Incremento mínimo', prefix: '\$ '),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Requerido'
                    : null,
              ),
            ),
          ]),

          // ---------------- Formato ----------------
          const SectionTitle('Tipo de subasta'),
          Row(children: [
            _formatOption('timed', Icons.timer_outlined, 'Por tiempo',
                'Abierta varios días'),
            const SizedBox(width: 10),
            _formatOption('live', Icons.videocam_outlined, 'En vivo',
                'Con transmisión'),
          ]),
          const SizedBox(height: 14),
          if (_format == 'timed')
            Wrap(spacing: 8, children: [
              for (final d in [1, 3, 5, 7])
                ChoiceChip(
                  label: Text('$d ${d == 1 ? 'día' : 'días'}'),
                  selected: _timedDays == d,
                  selectedColor: theme.surfaceVariant,
                  onSelected: (_) => setState(() => _timedDays = d),
                ),
            ])
          else ...[
            OutlinedButton.icon(
              onPressed: _pickLiveStart,
              icon: const Icon(Icons.event),
              label: Text(_liveStart == null
                  ? 'Elegir fecha y hora de inicio'
                  : 'Inicia: ${formatDateTime(_liveStart)}'),
            ),
            const SizedBox(height: 10),
            Text('Duración de las pujas', style: theme.labelMedium),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final m in [15, 30, 60, 120])
                ChoiceChip(
                  label: Text(m < 60 ? '$m min' : '${m ~/ 60} h'),
                  selected: _liveMinutes == m,
                  selectedColor: theme.surfaceVariant,
                  onSelected: (_) => setState(() => _liveMinutes = m),
                ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _streamUrl,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: _dec('Enlace de YouTube Live (opcional)',
                  helper:
                      'Puedes agregarlo después. Con YouTube el video se ve dentro de la app; otros enlaces se abren aparte.'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final uri = Uri.tryParse(t);
                if (uri == null || !uri.hasScheme) {
                  return 'Pega el enlace completo (https://…)';
                }
                return null;
              },
            ),
            if (_streamUrl.text.isNotEmpty &&
                youtubeIdFrom(_streamUrl.text) == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'No es de YouTube: los compradores lo abrirán en otra app.',
                    style: theme.bodySmall),
              ),
          ],

          const SizedBox(height: 28),
          if (_saving)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_progress,
                  textAlign: TextAlign.center, style: theme.bodySmall),
            ),
          BigButton(
            label: 'Publicar',
            loading: _saving,
            onPressed: _publish,
          ),
        ],
      ),
    );
  }

  Widget _formatOption(
      String value, IconData icon, String title, String subtitle) {
    final theme = FlutterFlowTheme.of(context);
    final selected = _format == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _format = value),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? theme.secondary : theme.secondaryBackground,
            border: Border.all(color: theme.secondary, width: 2),
          ),
          child: Column(children: [
            Icon(icon, color: selected ? Colors.white : theme.primaryText),
            const SizedBox(height: 4),
            Text(title,
                style: theme.titleSmall.copyWith(
                    color: selected ? Colors.white : theme.primaryText)),
            Text(subtitle,
                style: theme.bodySmall.copyWith(
                    color: selected ? Colors.white70 : theme.secondaryText)),
          ]),
        ),
      ),
    );
  }
}

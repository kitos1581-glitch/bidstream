import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';

import '/backend/backend.dart';
import '/backend/photo_utils.dart';
import '/backend/lot_specs.dart';
import '/backend/regions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/youtube.dart';
import '/ui/ui_kit.dart';

class _PickedPhoto {
  _PickedPhoto(this.bytes, this.mime) : original = bytes;
  Uint8List bytes;
  String mime;
  /// Foto tal como la tomó el vendedor (para "Deshacer").
  final Uint8List original;
  bool get enhanced => !identical(bytes, original);
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
  final _photosKey = GlobalKey();
  final _conditionKey = GlobalKey();
  final _locationKey = GlobalKey();

  /// Muestra el aviso y sube/baja la pantalla hasta el campo que falta.
  void _missing(GlobalKey key, String msg) {
    showMessage(context, msg, error: true);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), alignment: 0.1);
    }
  }

  /// Lleva al primer campo de texto con error (de arriba hacia abajo).
  void _scrollToFirstError() {
    FormFieldState<dynamic>? first;
    void visit(Element e) {
      if (first != null) return;
      if (e is StatefulElement && e.state is FormFieldState && (e.state as FormFieldState).hasError) {
        first = e.state as FormFieldState;
        return;
      }
      e.visitChildren(visit);
    }
    final root = _formKey.currentContext;
    if (root is Element) root.visitChildren(visit);
    final ctx = first?.context;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), alignment: 0.2);
    }
    showMessage(context, 'Revisa el campo marcado en rojo.', error: true);
  }
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _increment = TextEditingController();
  final _streamUrl = TextEditingController();
  final _reserve = TextEditingController();
  final _buyNow = TextEditingController();
  final _shipCost = TextEditingController();
  String? _municipality;
  bool _pickup = true;
  bool _regional = false;
  bool _shipIncluded = false;
  final Set<String> _destinations = {};
  late final Stream<UsersRecord?> _profile = AuctionService.instance.myProfile();

  String? _category;
  String? _condition;
  final Map<String, String> _specs = {};
  final _aiNotes = TextEditingController();
  bool _aiLoading = false;
  AiLotSuggestion? _ai;
  String _format = 'timed';
  /// 'auction' (subasta) | 'fixed' (precio fijo, 1 pieza) — ROADMAP R-10.
  String _saleType = 'auction';
  int _fixedDays = 30;
  bool get _isFixed => _saleType == 'fixed';
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
    _reserve.dispose();
    _buyNow.dispose();
    _shipCost.dispose();
    _aiNotes.dispose();
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
      final (ready, readyMime) = prepareLotPhoto(bytes, mime);
      _photos.add(_PickedPhoto(ready, readyMime));
    }
    if (mounted) setState(() {});
  }

  /// ✨ Mejora la luz de una foto, o la regresa a la original.
  Future<void> _toggleEnhance(int i) async {
    final p = _photos[i];
    if (p.enhanced) {
      setState(() {
        p.bytes = p.original;
      });
      return;
    }
    showMessage(context, 'Mejorando la foto…');
    await Future<void>.delayed(const Duration(milliseconds: 50)); // deja pintar el aviso
    final better = enhanceLotPhoto(p.bytes);
    if (!mounted) return;
    setState(() {
      p.bytes = better;
      p.mime = 'image/jpeg';
    });
    showMessage(context, 'Listo: misma foto con mejor luz. Toca ↶ para deshacer.');
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

  /// Llena título, categoría y descripción con la IA. Si ya hay texto,
  /// pregunta antes de reemplazarlo.
  Future<void> _fillWithAi() async {
    if (_photos.isEmpty) {
      showMessage(context, 'Primero agrega fotos.', error: true);
      return;
    }
    if (_condition == null) {
      showMessage(context, 'Indica si es nuevo o usado.', error: true);
      return;
    }
    if (_title.text.isNotEmpty || _description.text.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Reemplazar lo que escribiste?'),
          content: const Text('La IA llenará título, categoría y descripción.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reemplazar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _aiLoading = true);
    try {
      final r = await AuctionService.instance.suggestLotContent(
        photos: [for (final p in _photos) (p.bytes, p.mime)],
        condition: _condition!,
        notes: _aiNotes.text,
      );
      if (!mounted) return;
      setState(() {
        _ai = r;
        _title.text = r.title;
        _description.text = r.description;
        if (kLotCategories.contains(r.category)) _category = r.category;
      });
      showMessage(context, 'Listo. Revisa y corrige lo que haga falta antes de publicar.');
    } catch (e) {
      if (mounted) {
        final msg = e is FirebaseFunctionsException ? (e.message ?? '$e') : '$e';
        showMessage(context, msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _publish() async {
    if (_photos.isEmpty) {
      _missing(_photosKey, 'Agrega al menos una foto.');
      return;
    }
    if (_condition == null) {
      _missing(_conditionKey, 'Indica el estado del artículo (nuevo o usado).');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }
    if (_municipality == null) {
      _missing(_locationKey, 'Indica en qué municipio está el artículo.');
      return;
    }
    if (!_pickup && !_regional) {
      _missing(_locationKey, 'Elige al menos una forma de entrega.');
      return;
    }
    if (_regional && !_shipIncluded && (double.tryParse(_shipCost.text) ?? 0) <= 0) {
      _missing(_locationKey, 'Escribe el costo del envío o marca que ya va incluido.');
      return;
    }
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;
    if (_isFixed) {
      start = now;
      end = now.add(Duration(days: _fixedDays));
    } else if (_format == 'live') {
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
        minimumIncrement: _isFixed ? 1 : double.parse(_increment.text),
        startTime: start,
        endTime: end,
        format: _isFixed ? 'timed' : _format,
        saleType: _saleType,
        buyNowPrice: _isFixed
            ? null
            : (_format == 'timed' ? double.tryParse(_buyNow.text) : null),
        condition: _condition!,
        imageUrls: urls,
        streamUrl: !_isFixed && _format == 'live' ? _streamUrl.text : '',
        municipality: _municipality!,
        delivery: {
          'pickup': _pickup,
          'regional': _regional,
          'shipping_cost': _regional && !_shipIncluded ? (double.tryParse(_shipCost.text) ?? 0) : 0,
          'shipping_included': _regional && _shipIncluded,
          'destinations': _regional ? _destinations.toList() : <String>[],
        },
        specs: {
          for (final f in specsFor(_category!))
            if ((_specs[f.key] ?? '').trim().isNotEmpty) f.key: _specs[f.key]!.trim(),
        },
      );
      final reserve = double.tryParse(_reserve.text);
      var reserveFailed = false;
      if (!_isFixed && _format == 'timed' && reserve != null && reserve > 0) {
        setState(() => _progress = 'Guardando precio de reserva…');
        try {
          await AuctionService.instance.setReservePrice(id, reserve);
        } catch (e) {
          reserveFailed = true;
        }
      }
      if (!mounted) return;
      showMessage(
          context,
          reserveFailed
              ? 'Tu lote se publicó, pero no pudimos guardar la reserva. Agrégala desde el lote antes de que alguien puje.'
              : (_isFixed ? '¡Tu artículo ya está a la venta!' : '¡Tu lote ya está publicado!'),
          error: reserveFailed);
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

  Widget _specField(SpecField f) {
    final label = f.required ? '${f.label} *' : f.label;
    String? check(String? v) =>
        f.required && (v ?? '').trim().isEmpty ? 'Obligatorio' : null;
    if (f.options != null) {
      final current = _specs[f.key];
      return DropdownButtonFormField<String>(
        key: ValueKey('spec-$_category-${f.key}'),
        value: f.options!.contains(current) ? current : null,
        isExpanded: true,
        decoration: _dec(label),
        items: [
          for (final o in f.options!) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => setState(() => _specs[f.key] = v ?? ''),
        validator: check,
      );
    }
    return TextFormField(
      key: ValueKey('spec-$_category-${f.key}'),
      initialValue: _specs[f.key],
      maxLength: 120,
      keyboardType: f.numeric ? TextInputType.number : TextInputType.text,
      inputFormatters:
          f.numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: _dec(label, helper: f.hint.isEmpty ? null : 'Ej. ${f.hint}')
          .copyWith(counterText: ''),
      onChanged: (v) => _specs[f.key] = v,
      validator: check,
    );
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
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: theme.alternate)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: theme.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: theme.error, width: 2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
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
          if (snap.hasError) return ErrorState(error: snap.error);
          if (snap.connectionState == ConnectionState.waiting) {
            return const Loading();
          }
          final ready = AuctionService.instance.emailVerified &&
              (snap.data?.isProfileComplete ?? false);
          if (ready && snap.data?.verified != true) {
            final pending = snap.data?.verificationStatus == 'pending';
            return EmptyState(
              icon: Icons.badge_outlined,
              title: pending
                  ? 'Estamos revisando tu identidad'
                  : 'Verifica tu identidad para vender',
              message: pending
                  ? 'Te avisaremos en cuanto quede aprobada.'
                  : 'Por seguridad de los compradores, para publicar necesitas verificar tu INE.',
              action: pending
                  ? null
                  : SizedBox(
                      width: 240,
                      child: BigButton(
                        label: 'Verificar INE',
                        onPressed: () => context.pushNamed('IdentityVerification'),
                      ),
                    ),
            );
          }
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
      // Column (no ListView): todos los campos existen siempre, así se validan
      // aunque no estén en pantalla y se puede llevar al usuario al que falta.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- Fotos ----------------
          KeyedSubtree(key: _photosKey, child: const SectionTitle('Fotos')),
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
                        border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
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
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.alternate)),
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
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: _saving ? null : () => _toggleEnhance(i),
                          child: Container(
                            color: _photos[i].enhanced ? theme.primary : Colors.black54,
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                                _photos[i].enhanced ? Icons.undo : Icons.auto_fix_high,
                                size: 16,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Text(
            'Tips para vender más: luz natural (cerca de una ventana), fondo liso y sin estorbos, '
            'una foto de cada lado y una de la etiqueta o los detalles. Toca ✨ en una foto para mejorar su luz.',
            style: theme.bodySmall.copyWith(color: theme.secondaryText),
          ),

          // ---------------- Datos ----------------
          // ---------------- Estado + asistente IA ----------------
          KeyedSubtree(key: _conditionKey, child: const SectionTitle('Estado del artículo')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kLotConditions.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _condition == e.key,
                selectedColor: theme.surfaceVariant,
                onSelected: (_) => setState(() => _condition = e.key),
              ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryContainer,
              border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome, color: theme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Deja que la IA escriba tu publicación',
                        style: theme.titleSmall),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Lee tus fotos y propone título, categoría y una descripción honesta. '
                  'Tú revisas y corriges antes de publicar.',
                  style: theme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _aiNotes,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText:
                        'Opcional: lo que no se ve en las fotos (año, km, si funciona, fallas, qué incluye, papeles…)',
                    filled: true,
                    fillColor: theme.secondaryBackground,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                BigButton(
                  label: 'Llenar con IA',
                  icon: Icons.auto_awesome,
                  loading: _aiLoading,
                  onPressed: _saving || _photos.isEmpty ? null : _fillWithAi,
                ),
                if (_ai != null) _AiReport(ai: _ai!),
              ],
            ),
          ),

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
          if (_category != null && specsFor(_category!).isNotEmpty) ...[
            SectionTitle('Características del artículo',
                trailing: Text('* obligatorio',
                    style: FlutterFlowTheme.of(context).bodySmall)),
            Text(
              'Sé específico: los compradores pujan más cuando no tienen que preguntar. '
              'Lo que declares aquí es parte del reglamento: si no coincide, el comprador puede reclamar.',
              style: FlutterFlowTheme.of(context).bodySmall.copyWith(
                  color: FlutterFlowTheme.of(context).secondaryText),
            ),
            const SizedBox(height: 10),
            for (final f in specsFor(_category!)) ...[
              _specField(f),
              const SizedBox(height: 10),
            ],
          ],

          // ---------------- Precio ----------------
          // ---------------- Ubicación y entrega ----------------
          KeyedSubtree(key: _locationKey, child: const SectionTitle('Ubicación y entrega')),
          DropdownButtonFormField<String>(
            value: _municipality,
            isExpanded: true,
            decoration: _dec('¿En qué municipio está el artículo?'),
            items: [
              for (final e in kMunicipalities.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _municipality = v),
            validator: (v) => v == null ? 'Elige el municipio' : null,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _pickup,
            onChanged: (v) => setState(() => _pickup = v ?? false),
            title: const Text('Entrega a acordar con el comprador'),
            subtitle: const Text('Sin costo. Al pagar, ambos reciben el contacto para verse en un punto acordado.'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _regional,
            onChanged: (v) => setState(() => _regional = v ?? false),
            title: const Text('Envío regional / intermunicipal'),
            subtitle: const Text('Tú envías el artículo a otro municipio de la región.'),
          ),
          if (_regional) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _shipIncluded,
              onChanged: (v) => setState(() => _shipIncluded = v),
              title: const Text('El envío ya va incluido en el precio'),
            ),
            if (!_shipIncluded)
              TextFormField(
                controller: _shipCost,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('Costo del envío', prefix: '\$ ',
                    helper: 'Lo paga el comprador junto con el artículo y te llega completo (sin comisión).'),
              ),
            const SizedBox(height: 8),
            Text('¿A qué municipios envías? (sin marcar = toda la región)',
                style: FlutterFlowTheme.of(context).bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in kMunicipalities.entries)
                if (e.key != 'otro' && e.key != _municipality)
                  FilterChip(
                    label: Text(e.value),
                    selected: _destinations.contains(e.key),
                    onSelected: (v) => setState(() => v ? _destinations.add(e.key) : _destinations.remove(e.key)),
                  ),
            ]),
          ],

          // ---------------- Cómo vender (R-10) ----------------
          const SectionTitle('¿Cómo quieres vender?'),
          Row(children: [
            _choice(!_isFixed, () => setState(() => _saleType = 'auction'),
                Icons.gavel_rounded, 'Subasta', 'El mejor postor gana'),
            const SizedBox(width: 10),
            _choice(_isFixed, () => setState(() => _saleType = 'fixed'),
                Icons.sell_outlined, 'Precio fijo', 'El primero que compre'),
          ]),
          const SizedBox(height: 6),
          if (_isFixed) ...[
            const SectionTitle('Precio'),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('Precio de venta', prefix: '\$ ',
                  helper: 'Una sola pieza. El primero que dé "Comprar ahora" se la lleva y paga con la misma protección que una subasta.'),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Requerido'
                  : null,
            ),
            const SizedBox(height: 14),
            Text('¿Cuánto tiempo estará publicado?', style: theme.labelMedium),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final d in [7, 15, 30, 60])
                ChoiceChip(
                  label: Text('$d días'),
                  selected: _fixedDays == d,
                  selectedColor: theme.surfaceVariant,
                  onSelected: (_) => setState(() => _fixedDays = d),
                ),
            ]),
          ] else ...[
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
          if (_format == 'timed') ...[
            Wrap(spacing: 8, children: [
              for (final d in [1, 3, 5, 7])
                ChoiceChip(
                  label: Text('$d ${d == 1 ? 'día' : 'días'}'),
                  selected: _timedDays == d,
                  selectedColor: theme.surfaceVariant,
                  onSelected: (_) => setState(() => _timedDays = d),
                ),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _reserve,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('Precio de reserva (opcional, secreto)',
                  prefix: '\$ ',
                  helper:
                      'El mínimo al que aceptas vender. Nadie lo ve; si no se alcanza, no hay venta ni comisión. '
                      'Puedes empezar con un precio inicial bajo para atraer pujas.'),
              validator: (v) {
                final r = double.tryParse(v ?? '');
                if ((v ?? '').isEmpty) return null;
                final p = double.tryParse(_price.text) ?? 0;
                if (r == null || r <= p) return 'Debe ser mayor que el precio inicial';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyNow,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('Precio "Comprar ahora" (opcional)',
                  prefix: '\$ ',
                  helper:
                      'Si alguien paga esto antes de la primera puja, se lo lleva al instante. '
                      'Desaparece en cuanto alguien puja.'),
              validator: (v) {
                if ((v ?? '').isEmpty) return null;
                final b = double.tryParse(v!);
                final p = double.tryParse(_price.text) ?? 0;
                if (b == null || b <= p) return 'Debe ser mayor que el precio inicial';
                final r = double.tryParse(_reserve.text);
                if (r != null && r > 0 && r >= b) return 'Debe ser mayor que tu reserva';
                return null;
              },
            ),
          ] else ...[
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
      ),
    );
  }

  Widget _formatOption(
          String value, IconData icon, String title, String subtitle) =>
      _choice(_format == value, () => setState(() => _format = value), icon,
          title, subtitle);

  Widget _choice(bool selected, VoidCallback onTap, IconData icon,
      String title, String subtitle) {
    final theme = FlutterFlowTheme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? theme.secondary : theme.secondaryBackground,
            border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(14),
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

/// Avisos de la IA: defectos vistos, datos faltantes, estado que no
/// coincide y artículos posiblemente prohibidos.
class _AiReport extends StatelessWidget {
  const _AiReport({required this.ai});
  final AiLotSuggestion ai;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget block(IconData icon, Color color, String title, List<String> items) =>
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: theme.titleSmall.copyWith(color: color))),
            ]),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text('• $i', style: theme.bodySmall),
              ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (ai.prohibited)
        block(Icons.block, theme.error, 'Este artículo podría estar prohibido',
            [ai.prohibitedReason.isEmpty ? 'Revisa los términos antes de publicar.' : ai.prohibitedReason]),
      if (ai.conditionMismatch.isNotEmpty)
        block(Icons.warning_amber_rounded, theme.tertiary,
            'El estado que elegiste no coincide con las fotos', [ai.conditionMismatch]),
      if (ai.detectedIssues.isNotEmpty)
        block(Icons.visibility_outlined, theme.primaryText,
            'Detalles que vio la IA (ya están en la descripción)', ai.detectedIssues),
      if (ai.missingInfo.isNotEmpty)
        block(Icons.help_outline, theme.primary,
            'Los compradores van a preguntar esto; agrégalo a la descripción', ai.missingInfo),
    ]);
  }
}

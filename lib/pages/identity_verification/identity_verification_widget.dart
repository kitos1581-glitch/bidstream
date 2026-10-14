import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '/backend/admin_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/ui_kit.dart';

/// Verificación de identidad: INE (frente y reverso) + selfie con la INE.
/// Un administrador la revisa a mano desde el panel.
class IdentityVerificationWidget extends StatefulWidget {
  const IdentityVerificationWidget({super.key});

  static String routeName = 'IdentityVerification';
  static String routePath = '/identityVerification';

  @override
  State<IdentityVerificationWidget> createState() =>
      _IdentityVerificationWidgetState();
}

class _Shot {
  _Shot(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

class _IdentityVerificationWidgetState
    extends State<IdentityVerificationWidget> {
  static const _steps = <String, (String, String, IconData)>{
    'ine_front': ('INE — frente', 'Que se lean nombre y foto.', Icons.badge_outlined),
    'ine_back': ('INE — reverso', 'Que se vea el código de barras.', Icons.qr_code_2),
    'selfie': (
      'Selfie con tu INE',
      'Tu cara y la INE junto a ella, ambas claras.',
      Icons.face_retouching_natural
    ),
  };

  late final Stream<VerificationRequest?> _request =
      AdminService.instance.myVerification();
  final Map<String, _Shot> _shots = {};
  bool _sending = false;
  String _progress = '';

  Future<void> _pick(String key, ImageSource source) async {
    final f = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
      preferredCameraDevice:
          key == 'selfie' ? CameraDevice.front : CameraDevice.rear,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final mime = f.mimeType ??
        (f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    setState(() => _shots[key] = _Shot(bytes, mime));
  }

  Future<void> _send() async {
    if (_shots.length < _steps.length) {
      showMessage(context, 'Faltan fotos.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final paths = <String, String>{};
      var i = 0;
      for (final key in _steps.keys) {
        i++;
        setState(() => _progress = 'Subiendo foto $i de ${_steps.length}…');
        final s = _shots[key]!;
        paths[key] = await AdminService.instance.uploadIdPhoto(key, s.bytes, s.mime);
      }
      setState(() => _progress = 'Enviando…');
      await AdminService.instance.submitVerification(paths);
      if (!mounted) return;
      _shots.clear();
      showMessage(context, 'Enviado. Te avisaremos cuando lo revisemos.');
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo enviar: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
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
        title: Text('Verificar identidad', style: theme.titleMedium),
      ),
      body: StreamBuilder<VerificationRequest?>(
        stream: _request,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Loading();
          }
          final req = snap.data;
          if (req?.status == 'approved') {
            return const EmptyState(
              icon: Icons.verified,
              title: 'Tu identidad está verificada',
              message: 'Ya puedes publicar lotes y hacer pujas altas.',
            );
          }
          if (req?.status == 'pending') {
            return const EmptyState(
              icon: Icons.hourglass_top,
              title: 'En revisión',
              message:
                  'Recibimos tus fotos. Normalmente revisamos en menos de 24 horas y te avisamos.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (req?.status == 'rejected')
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  color: theme.error10,
                  child: Text(
                      'Tu solicitud anterior fue rechazada: ${req!.rejectReason}. Vuelve a enviar tus fotos.',
                      style: theme.bodyMedium),
                ),
              Text(
                'Para vender y para pujas altas necesitamos confirmar que eres tú. '
                'Tus fotos son privadas: solo las ve el equipo de revisión.',
                style: theme.bodyMedium.copyWith(color: theme.secondaryText),
              ),
              const SizedBox(height: 8),
              for (final e in _steps.entries) _shotCard(e.key, e.value),
              const SizedBox(height: 20),
              if (_sending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_progress,
                      textAlign: TextAlign.center, style: theme.bodySmall),
                ),
              BigButton(
                label: 'Enviar a revisión',
                loading: _sending,
                onPressed: _shots.length == _steps.length ? _send : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _shotCard(String key, (String, String, IconData) info) {
    final theme = FlutterFlowTheme.of(context);
    final shot = _shots[key];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border.all(color: theme.secondary, width: 2),
      ),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          color: theme.secondaryContainer,
          child: shot == null
              ? Icon(info.$3, size: 32)
              : Image.memory(shot.bytes, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.$1, style: theme.titleSmall),
              Text(info.$2, style: theme.bodySmall),
              Row(children: [
                TextButton.icon(
                  onPressed: _sending ? null : () => _pick(key, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Cámara'),
                ),
                TextButton.icon(
                  onPressed: _sending ? null : () => _pick(key, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galería'),
                ),
              ]),
            ],
          ),
        ),
        if (shot != null) Icon(Icons.check_circle, color: theme.primary),
      ]),
    );
  }
}

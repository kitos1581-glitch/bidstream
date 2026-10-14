import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/ui_kit.dart';

/// Completar cuenta: verificar correo + datos de contacto + términos.
/// Es lo mínimo que exige el servidor para pujar o vender.
class OnboardingVerificationWidget extends StatefulWidget {
  const OnboardingVerificationWidget({super.key});

  static String routeName = 'OnboardingVerification';
  static String routePath = '/onboardingVerification';

  @override
  State<OnboardingVerificationWidget> createState() =>
      _OnboardingVerificationWidgetState();
}

class _OnboardingVerificationWidgetState
    extends State<OnboardingVerificationWidget> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  bool _terms = false;
  bool _loaded = false;
  bool _saving = false;
  bool _checking = false;
  bool _emailVerified = AuctionService.instance.emailVerified;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await AuctionService.instance.myProfile().first;
    if (!mounted) return;
    setState(() {
      _name.text = profile?.fullName ?? '';
      _phone.text = profile?.phone ?? '';
      _city.text = profile?.city ?? '';
      _terms = profile?.acceptedTerms ?? false;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _checkEmail() async {
    setState(() => _checking = true);
    final ok = await AuctionService.instance.refreshEmailVerified();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _emailVerified = ok;
    });
    showMessage(
        context,
        ok
            ? '¡Correo verificado!'
            : 'Aún no aparece verificado. Abre el enlace del correo y vuelve a intentar.',
        error: !ok);
  }

  Future<void> _resend() async {
    await authManager.sendEmailVerification();
    if (mounted) {
      showMessage(context, 'Te reenviamos el correo a $currentUserEmail.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_terms) {
      showMessage(context, 'Debes aceptar los términos para continuar.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await AuctionService.instance.updateProfile(
        fullName: _name.text,
        phone: _phone.text,
        city: _city.text,
        acceptedTerms: _terms,
      );
      if (!mounted) return;
      showMessage(context, 'Perfil guardado.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed('AuctionDashboard');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo guardar: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    InputDecoration dec(String label, {String? helper}) => InputDecoration(
          labelText: label,
          helperText: helper,
          filled: true,
          fillColor: theme.secondaryBackground,
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: theme.secondary, width: 2)),
        );

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Completa tu cuenta', style: theme.titleMedium),
      ),
      body: !_loaded
          ? const Loading()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Para pujar o vender necesitamos saber quién eres. '
                    'Tus datos de contacto solo se comparten con la otra parte '
                    'cuando se cierra una venta.',
                    style: theme.bodyMedium
                        .copyWith(color: theme.secondaryText),
                  ),

                  // ---------------- Paso 1: correo ----------------
                  const SectionTitle('1. Verifica tu correo'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _emailVerified
                          ? theme.surfaceVariant
                          : theme.secondaryBackground,
                      border: Border.all(color: theme.secondary, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              _emailVerified
                                  ? Icons.check_circle
                                  : Icons.mark_email_unread_outlined,
                              color: _emailVerified
                                  ? theme.primary
                                  : theme.tertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(currentUserEmail,
                                style: theme.titleSmall),
                          ),
                        ]),
                        if (!_emailVerified) ...[
                          const SizedBox(height: 8),
                          Text(
                              'Abre el enlace que te enviamos (revisa también "Spam") y luego toca "Ya lo verifiqué".',
                              style: theme.bodySmall),
                          const SizedBox(height: 8),
                          Row(children: [
                            TextButton(
                                onPressed: _resend,
                                child: const Text('Reenviar correo')),
                            const Spacer(),
                            FilledButton(
                              onPressed: _checking ? null : _checkEmail,
                              child: Text(_checking
                                  ? 'Revisando…'
                                  : 'Ya lo verifiqué'),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),

                  // ---------------- Paso 2: datos ----------------
                  const SectionTitle('2. Tus datos'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: dec('Nombre completo',
                        helper: 'En el historial solo se ve "Nombre + inicial".'),
                    validator: (v) =>
                        (v ?? '').trim().split(RegExp(r'\s+')).length < 2
                            ? 'Escribe nombre y apellido'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: dec('Teléfono (WhatsApp)'),
                    validator: (v) =>
                        (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                            ? 'Escribe un teléfono de 10 dígitos'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    decoration: dec('Ciudad y estado'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Requerido' : null,
                  ),

                  // ---------------- Paso 3: términos ----------------
                  const SectionTitle('3. Términos'),
                  CheckboxListTile(
                    value: _terms,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => _terms = v ?? false),
                    title: Text(
                      'Acepto que cada puja es un compromiso de compra, que '
                      'no puedo cancelar pujas y que la entrega y el pago se '
                      'acuerdan entre comprador y vendedor.',
                      style: theme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 20),
                  BigButton(
                      label: 'Guardar', loading: _saving, onPressed: _save),
                ],
              ),
            ),
    );
  }
}

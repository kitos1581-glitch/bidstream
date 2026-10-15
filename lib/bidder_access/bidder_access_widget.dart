import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/ui/ui_kit.dart';

/// Inicio de sesión / registro.
class BidderAccessWidget extends StatefulWidget {
  const BidderAccessWidget({super.key});

  static String routeName = 'BidderAccess';
  static String routePath = '/bidderAccess';

  @override
  State<BidderAccessWidget> createState() => _BidderAccessWidgetState();
}

class _BidderAccessWidgetState extends State<BidderAccessWidget> {
  bool _isSignUp = false;
  bool _loading = false;
  bool _showPassword = false;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      if (_isSignUp) {
        final user = await authManager.createAccountWithEmail(
            context, _email.text.trim(), _password.text);
        if (user == null) return;
        await _safeEnsureProfile(fullName: _name.text);
        await authManager.sendEmailVerification();
        if (!mounted) return;
        context.goNamedAuth('OnboardingVerification', context.mounted);
      } else {
        final user = await authManager.signInWithEmail(
            context, _email.text.trim(), _password.text);
        if (user == null) return;
        await _safeEnsureProfile();
        if (!mounted) return;
        context.goNamedAuth('AuctionDashboard', context.mounted);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Crear el perfil no debe impedir entrar a la app: si falla (sin
  /// conexión, reglas no desplegadas...), se avisa y se reintenta después
  /// desde "Completa tu cuenta".
  Future<void> _safeEnsureProfile({String? fullName}) async {
    try {
      await AuctionService.instance.ensureProfile(fullName: fullName);
    } catch (e) {
      debugPrint('No se pudo crear el perfil: $e');
      if (mounted) {
        showMessage(context,
            'Entraste, pero no pudimos guardar tu perfil. Complétalo en "Mi cuenta".',
            error: true);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      showMessage(context, 'Escribe tu correo arriba y vuelve a tocar aquí.',
          error: true);
      return;
    }
    await authManager.resetPassword(email: email, context: context);
  }

  InputDecoration _decoration(String label, {Widget? suffix}) {
    final theme = FlutterFlowTheme.of(context);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.secondaryBackground,
      suffixIcon: suffix,
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                              colors: [theme.primary, const Color(0xFF2F5A9E)]),
                          boxShadow: softShadow(),
                        ),
                        child: const Icon(Icons.gavel_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: theme.headlineMedium.copyWith(
                              fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          children: [
                            TextSpan(text: 'Subástalo ', style: TextStyle(color: theme.primary)),
                            TextSpan(text: 'Aquí', style: TextStyle(color: theme.tertiary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Subastas en línea y en vivo. Puja, gana y vende.',
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium
                            .copyWith(color: theme.secondaryText)),
                    const SizedBox(height: 28),
                    // Selector Iniciar sesión / Crear cuenta
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(children: [
                      _tab('Iniciar sesión', !_isSignUp,
                          () => setState(() => _isSignUp = false)),
                      _tab('Crear cuenta', _isSignUp,
                          () => setState(() => _isSignUp = true)),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration('Nombre completo'),
                        validator: (v) => (v ?? '').trim().split(' ').length < 2
                            ? 'Escribe nombre y apellido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: _decoration('Correo electrónico'),
                      validator: (v) => (v ?? '').contains('@')
                          ? null
                          : 'Escribe un correo válido',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: _decoration('Contraseña',
                          suffix: IconButton(
                            icon: Icon(_showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          )),
                      validator: (v) => (v ?? '').length < 6
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: !_showPassword,
                        decoration: _decoration('Confirmar contraseña'),
                        validator: (v) => v != _password.text
                            ? 'Las contraseñas no coinciden'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 20),
                    BigButton(
                      label: _isSignUp ? 'Crear cuenta' : 'Entrar',
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    if (!_isSignUp)
                      TextButton(
                        onPressed: _forgotPassword,
                        child: Text('¿Olvidaste tu contraseña?',
                            style: theme.bodyMedium
                                .copyWith(color: theme.primary)),
                      ),
                    TextButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.goNamed('AuctionDashboard'),
                      child: Text('Ver subastas sin cuenta',
                          style: theme.bodyMedium.copyWith(
                              color: theme.secondaryText,
                              decoration: TextDecoration.underline)),
                    ),
                    if (_isSignUp)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Te enviaremos un correo para verificar tu cuenta. '
                          'Necesitas verificarlo para pujar o publicar.',
                          textAlign: TextAlign.center,
                          style: theme.bodySmall
                              .copyWith(color: theme.secondaryText),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    final theme = FlutterFlowTheme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? theme.secondaryBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? softShadow() : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: theme.labelLarge.copyWith(
                  color: selected ? theme.primaryText : theme.secondaryText,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

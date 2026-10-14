import '/components/button/button_widget.dart';
import '/components/step_indicator/step_indicator_widget.dart';
import '/components/verification_card/verification_card_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'onboarding_verification_model.dart';
export 'onboarding_verification_model.dart';

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
  late OnboardingVerificationModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OnboardingVerificationModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primaryBackground,
                shape: BoxShape.rectangle,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(24.0, 40.0, 24.0, 32.0),
                child: Container(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VERIFICATION',
                        style: FlutterFlowTheme.of(context).labelLarge.override(
                              font: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.w900,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelLarge
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).primary,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w900,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelLarge
                                  .fontStyle,
                              lineHeight: 1.2,
                            ),
                      ),
                      Text(
                        'Secure Your Bidding Identity',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w800,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              fontSize: 42.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w800,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                              lineHeight: 1.1,
                            ),
                      ),
                      Text(
                        'BidStream Pro requires verified credentials for high-value asset auctions.',
                        style: FlutterFlowTheme.of(context).bodyLarge.override(
                              font: GoogleFonts.spaceGrotesk(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyLarge
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyLarge
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer70,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .fontStyle,
                              lineHeight: 1.5,
                            ),
                      ),
                    ].divide(SizedBox(height: 16.0)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: wrapWithModel(
                          model: _model.stepIndicatorModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: StepIndicatorWidget(
                            label: 'Identity',
                            active: true,
                            complete: false,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: wrapWithModel(
                          model: _model.stepIndicatorModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: StepIndicatorWidget(
                            label: 'Payment',
                            active: false,
                            complete: false,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: wrapWithModel(
                          model: _model.stepIndicatorModel3,
                          updateCallback: () => safeSetState(() {}),
                          child: StepIndicatorWidget(
                            label: 'Finalize',
                            active: false,
                            complete: false,
                          ),
                        ),
                      ),
                    ].divide(SizedBox(width: 16.0)),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Account Standing',
                        style: FlutterFlowTheme.of(context).titleLarge.override(
                              font: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w800,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleLarge
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).primaryText,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w800,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleLarge
                                  .fontStyle,
                              lineHeight: 1.3,
                            ),
                      ),
                      wrapWithModel(
                        model: _model.verificationCardModel1,
                        updateCallback: () => safeSetState(() {}),
                        child: VerificationCardWidget(
                          icon: Icon(
                            Icons.badge_rounded,
                            color: FlutterFlowTheme.of(context).success,
                            size: 24.0,
                          ),
                          subtitle: 'Passport or National ID required',
                          title: 'Identity Document',
                          verified: true,
                        ),
                      ),
                      wrapWithModel(
                        model: _model.verificationCardModel2,
                        updateCallback: () => safeSetState(() {}),
                        child: VerificationCardWidget(
                          icon: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: FlutterFlowTheme.of(context).primary,
                            size: 24.0,
                          ),
                          subtitle: 'Credit card or Bank wire setup',
                          title: 'Payment Method',
                          verified: false,
                        ),
                      ),
                      wrapWithModel(
                        model: _model.verificationCardModel3,
                        updateCallback: () => safeSetState(() {}),
                        child: VerificationCardWidget(
                          icon: Icon(
                            Icons.shield_rounded,
                            color: FlutterFlowTheme.of(context).primary,
                            size: 24.0,
                          ),
                          subtitle: 'Required for lots over \$50,000',
                          title: 'Proof of Funds',
                          verified: false,
                        ),
                      ),
                    ].divide(SizedBox(height: 24.0)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).onPrimaryContainer,
                      shape: BoxShape.rectangle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Container(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NOTE ON SECURITY',
                              style: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .override(
                                    font: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .surfaceVariant,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                    lineHeight: 1.2,
                                  ),
                            ),
                            Text(
                              'Encryption protocols ensure your sensitive data is never stored on our public servers. Verification typically takes 2-4 hours.',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.spaceGrotesk(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                    lineHeight: 1.5,
                                  ),
                            ),
                          ].divide(SizedBox(height: 8.0)),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          context.goNamed(UserProfileActivityWidget.routeName);
                        },
                        child: wrapWithModel(
                          model: _model.buttonModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: ButtonWidget(
                            iconPresent: false,
                            iconEnd: Icon(
                              Icons.arrow_forward_rounded,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 24.0,
                            ),
                            iconEndPresent: true,
                            content: 'Complete Payment Setup',
                            variant: 'primary',
                            size: 'large',
                            fullWidth: false,
                            loading: false,
                            disabled: false,
                          ),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.buttonModel2,
                        updateCallback: () => safeSetState(() {}),
                        child: ButtonWidget(
                          iconPresent: false,
                          iconEndPresent: false,
                          content: 'Save Progress',
                          variant: 'ghost',
                          size: 'medium',
                          fullWidth: false,
                          loading: false,
                          disabled: false,
                        ),
                      ),
                      Container(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Container(
                            child: Container(
                              alignment: AlignmentDirectional(0.0, 0.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 14.0,
                                  ),
                                  Text(
                                    'Bank-grade 256-bit SSL Encryption',
                                    style: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .override(
                                          font: GoogleFonts.jetBrainsMono(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontStyle,
                                          lineHeight: 1.2,
                                        ),
                                  ),
                                ].divide(SizedBox(width: 4.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ].divide(SizedBox(height: 16.0)),
                  ),
                ].divide(SizedBox(height: 32.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

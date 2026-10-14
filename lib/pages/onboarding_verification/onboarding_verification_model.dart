import '/components/button/button_widget.dart';
import '/components/step_indicator/step_indicator_widget.dart';
import '/components/verification_card/verification_card_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'onboarding_verification_widget.dart' show OnboardingVerificationWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class OnboardingVerificationModel
    extends FlutterFlowModel<OnboardingVerificationWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for StepIndicator.
  late StepIndicatorModel stepIndicatorModel1;
  // Model for StepIndicator.
  late StepIndicatorModel stepIndicatorModel2;
  // Model for StepIndicator.
  late StepIndicatorModel stepIndicatorModel3;
  // Model for VerificationCard.
  late VerificationCardModel verificationCardModel1;
  // Model for VerificationCard.
  late VerificationCardModel verificationCardModel2;
  // Model for VerificationCard.
  late VerificationCardModel verificationCardModel3;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    stepIndicatorModel1 = createModel(context, () => StepIndicatorModel());
    stepIndicatorModel2 = createModel(context, () => StepIndicatorModel());
    stepIndicatorModel3 = createModel(context, () => StepIndicatorModel());
    verificationCardModel1 =
        createModel(context, () => VerificationCardModel());
    verificationCardModel2 =
        createModel(context, () => VerificationCardModel());
    verificationCardModel3 =
        createModel(context, () => VerificationCardModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    stepIndicatorModel1.dispose();
    stepIndicatorModel2.dispose();
    stepIndicatorModel3.dispose();
    verificationCardModel1.dispose();
    verificationCardModel2.dispose();
    verificationCardModel3.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
  }
}

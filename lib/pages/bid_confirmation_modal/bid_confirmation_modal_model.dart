import '/components/button/button_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'bid_confirmation_modal_widget.dart' show BidConfirmationModalWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class BidConfirmationModalModel
    extends FlutterFlowModel<BidConfirmationModalWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;
  // Model for Button.
  late ButtonModel buttonModel3;
  // Model for TextField.
  late TextFieldModel textFieldModel;
  // Model for Button.
  late ButtonModel buttonModel4;
  // Model for Button.
  late ButtonModel buttonModel5;

  @override
  void initState(BuildContext context) {
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
    buttonModel3 = createModel(context, () => ButtonModel());
    textFieldModel = createModel(context, () => TextFieldModel());
    buttonModel4 = createModel(context, () => ButtonModel());
    buttonModel5 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel1.dispose();
    buttonModel2.dispose();
    buttonModel3.dispose();
    textFieldModel.dispose();
    buttonModel4.dispose();
    buttonModel5.dispose();
  }
}

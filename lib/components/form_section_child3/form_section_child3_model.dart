import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'form_section_child3_widget.dart' show FormSectionChild3Widget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FormSectionChild3Model extends FlutterFlowModel<FormSectionChild3Widget> {
  ///  State fields for stateful widgets in this component.

  // Model for TextField.
  late TextFieldModel textFieldModel1;
  // Model for TextField.
  late TextFieldModel textFieldModel2;
  // Model for TextField.
  late TextFieldModel textFieldModel3;

  @override
  void initState(BuildContext context) {
    textFieldModel1 = createModel(context, () => TextFieldModel());
    textFieldModel2 = createModel(context, () => TextFieldModel());
    textFieldModel3 = createModel(context, () => TextFieldModel());
  }

  @override
  void dispose() {
    textFieldModel1.dispose();
    textFieldModel2.dispose();
    textFieldModel3.dispose();
  }
}

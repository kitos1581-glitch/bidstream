import '/components/switch_component/switch_component_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'form_section_child4_widget.dart' show FormSectionChild4Widget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FormSectionChild4Model extends FlutterFlowModel<FormSectionChild4Widget> {
  ///  State fields for stateful widgets in this component.

  // Model for Switch.
  late SwitchComponentModel switchModel;
  // Model for TextField.
  late TextFieldModel textFieldModel1;
  // Model for TextField.
  late TextFieldModel textFieldModel2;
  // Model for TextField.
  late TextFieldModel textFieldModel3;
  // Model for TextField.
  late TextFieldModel textFieldModel4;

  @override
  void initState(BuildContext context) {
    switchModel = createModel(context, () => SwitchComponentModel());
    textFieldModel1 = createModel(context, () => TextFieldModel());
    textFieldModel2 = createModel(context, () => TextFieldModel());
    textFieldModel3 = createModel(context, () => TextFieldModel());
    textFieldModel4 = createModel(context, () => TextFieldModel());
  }

  @override
  void dispose() {
    switchModel.dispose();
    textFieldModel1.dispose();
    textFieldModel2.dispose();
    textFieldModel3.dispose();
    textFieldModel4.dispose();
  }
}

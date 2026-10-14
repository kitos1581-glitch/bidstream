import '/components/button/button_widget.dart';
import '/components/form_section/form_section_widget.dart';
import '/components/form_section_child/form_section_child_widget.dart';
import '/components/form_section_child2/form_section_child2_widget.dart';
import '/components/form_section_child3/form_section_child3_widget.dart';
import '/components/form_section_child4/form_section_child4_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'create_lot_management_widget.dart' show CreateLotManagementWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateLotManagementModel
    extends FlutterFlowModel<CreateLotManagementWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for FormSection.
  late FormSectionModel formSectionModel1;
  // Model for FormSection.
  late FormSectionModel formSectionModel2;
  // Model for FormSection.
  late FormSectionModel formSectionModel3;
  // Model for FormSection.
  late FormSectionModel formSectionModel4;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    formSectionModel1 = createModel(context, () => FormSectionModel());
    formSectionModel2 = createModel(context, () => FormSectionModel());
    formSectionModel3 = createModel(context, () => FormSectionModel());
    formSectionModel4 = createModel(context, () => FormSectionModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    formSectionModel1.dispose();
    formSectionModel2.dispose();
    formSectionModel3.dispose();
    formSectionModel4.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
  }
}

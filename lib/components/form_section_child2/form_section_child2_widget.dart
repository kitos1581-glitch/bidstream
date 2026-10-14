import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'form_section_child2_model.dart';
export 'form_section_child2_model.dart';

class FormSectionChild2Widget extends StatefulWidget {
  const FormSectionChild2Widget({super.key});

  @override
  State<FormSectionChild2Widget> createState() =>
      _FormSectionChild2WidgetState();
}

class _FormSectionChild2WidgetState extends State<FormSectionChild2Widget> {
  late FormSectionChild2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormSectionChild2Model());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        wrapWithModel(
          model: _model.textFieldModel1,
          updateCallback: () => safeSetState(() {}),
          child: TextFieldWidget(
            label: 'Lot Title',
            labelPresent: true,
            helper: '',
            helperPresent: false,
            leadingIconPresent: false,
            trailingIconPresent: false,
            hint: 'e.g. 1964 Rolex Submariner Ref. 5513',
            value: '',
            onChange: '',
            onSubmit: '',
            variant: 'outlined',
            error: false,
          ),
        ),
        wrapWithModel(
          model: _model.textFieldModel2,
          updateCallback: () => safeSetState(() {}),
          child: TextFieldWidget(
            label: 'Description',
            labelPresent: true,
            helper: '',
            helperPresent: false,
            leadingIconPresent: false,
            trailingIconPresent: false,
            hint: 'Detailed provenance, condition, and specifications...',
            value: '',
            onChange: '',
            onSubmit: '',
            variant: 'outlined',
            error: false,
          ),
        ),
        FlutterFlowDropDown<String>(
          controller: _model.dropdownValueController ??=
              FormFieldController<String>(
            _model.dropdownValue ??= 'Watches',
          ),
          options: [
            'Watches',
            'Fine Art',
            'Automobiles',
            'Jewelry',
            'Collectibles'
          ],
          onChanged: (val) => safeSetState(() => _model.dropdownValue = val),
          width: 200.0,
          height: 40.0,
          textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                font: GoogleFonts.spaceGrotesk(
                  fontWeight:
                      FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                lineHeight: 1.5,
              ),
          hintText: 'Watches',
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: FlutterFlowTheme.of(context).secondaryText,
            size: 24.0,
          ),
          fillColor: Colors.transparent,
          elevation: 2.0,
          borderColor: FlutterFlowTheme.of(context).alternate,
          borderWidth: 1.0,
          borderRadius: 4.0,
          margin: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
          hidesUnderline: true,
          isOverButton: false,
          isSearchable: false,
          isMultiSelect: false,
          labelText: 'Category',
          labelTextStyle: FlutterFlowTheme.of(context).labelMedium.override(
                font: GoogleFonts.jetBrainsMono(
                  fontWeight:
                      FlutterFlowTheme.of(context).labelMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).labelMedium.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                lineHeight: 1.2,
              ),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }
}

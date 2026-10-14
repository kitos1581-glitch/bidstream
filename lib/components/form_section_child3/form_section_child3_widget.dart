import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'form_section_child3_model.dart';
export 'form_section_child3_model.dart';

class FormSectionChild3Widget extends StatefulWidget {
  const FormSectionChild3Widget({super.key});

  @override
  State<FormSectionChild3Widget> createState() =>
      _FormSectionChild3WidgetState();
}

class _FormSectionChild3WidgetState extends State<FormSectionChild3Widget> {
  late FormSectionChild3Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormSectionChild3Model());
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
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: wrapWithModel(
                model: _model.textFieldModel1,
                updateCallback: () => safeSetState(() {}),
                child: TextFieldWidget(
                  label: 'Starting Price',
                  labelPresent: true,
                  helper: '',
                  helperPresent: false,
                  leadingIcon: Icon(
                    Icons.payments_rounded,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                  leadingIconPresent: true,
                  trailingIconPresent: false,
                  hint: '\$0.00',
                  value: '',
                  onChange: '',
                  onSubmit: '',
                  variant: 'outlined',
                  error: false,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: wrapWithModel(
                model: _model.textFieldModel2,
                updateCallback: () => safeSetState(() {}),
                child: TextFieldWidget(
                  label: 'Reserve Price',
                  labelPresent: true,
                  helper: '',
                  helperPresent: false,
                  leadingIcon: Icon(
                    Icons.shield_rounded,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                  leadingIconPresent: true,
                  trailingIconPresent: false,
                  hint: '\$0.00',
                  value: '',
                  onChange: '',
                  onSubmit: '',
                  variant: 'outlined',
                  error: false,
                ),
              ),
            ),
          ].divide(SizedBox(width: 16.0)),
        ),
        wrapWithModel(
          model: _model.textFieldModel3,
          updateCallback: () => safeSetState(() {}),
          child: TextFieldWidget(
            label: 'Minimum Increment',
            labelPresent: true,
            helper: 'Smallest allowable bid increase',
            helperPresent: true,
            leadingIconPresent: false,
            trailingIconPresent: false,
            hint: 'Type here...',
            value: '\$100',
            onChange: '',
            onSubmit: '',
            variant: 'outlined',
            error: false,
          ),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }
}

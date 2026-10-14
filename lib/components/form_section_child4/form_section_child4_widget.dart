import '/components/switch_component/switch_component_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'form_section_child4_model.dart';
export 'form_section_child4_model.dart';

class FormSectionChild4Widget extends StatefulWidget {
  const FormSectionChild4Widget({super.key});

  @override
  State<FormSectionChild4Widget> createState() =>
      _FormSectionChild4WidgetState();
}

class _FormSectionChild4WidgetState extends State<FormSectionChild4Widget> {
  late FormSectionChild4Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormSectionChild4Model());
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
        Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary5,
            borderRadius: BorderRadius.circular(4.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: FlutterFlowTheme.of(context).primary20,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              child: wrapWithModel(
                model: _model.switchModel,
                updateCallback: () => safeSetState(() {}),
                child: SwitchComponentWidget(
                  label: 'Enable Live Stream',
                  labelPresent: true,
                  variant: 'iOS 26+',
                  active: true,
                ),
              ),
            ),
          ),
        ),
        Column(
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
                      label: 'Start Date',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.calendar_today_rounded,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'Type here...',
                      value: 'Oct 24, 2024',
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
                      label: 'Start Time',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.schedule_rounded,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'Type here...',
                      value: '10:00 AM',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                ),
              ].divide(SizedBox(width: 16.0)),
            ),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 1,
                  child: wrapWithModel(
                    model: _model.textFieldModel3,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'End Date',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.event_available_rounded,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'Type here...',
                      value: 'Oct 31, 2024',
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
                    model: _model.textFieldModel4,
                    updateCallback: () => safeSetState(() {}),
                    child: TextFieldWidget(
                      label: 'End Time',
                      labelPresent: true,
                      helper: '',
                      helperPresent: false,
                      leadingIcon: Icon(
                        Icons.history_rounded,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                      leadingIconPresent: true,
                      trailingIconPresent: false,
                      hint: 'Type here...',
                      value: '06:00 PM',
                      onChange: '',
                      onSubmit: '',
                      variant: 'outlined',
                      error: false,
                    ),
                  ),
                ),
              ].divide(SizedBox(width: 16.0)),
            ),
          ].divide(SizedBox(height: 16.0)),
        ),
      ].divide(SizedBox(height: 24.0)),
    );
  }
}

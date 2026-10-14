import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'form_section_model.dart';
export 'form_section_model.dart';

class FormSectionWidget extends StatefulWidget {
  const FormSectionWidget({
    super.key,
    String? subtitle,
    String? title,
    this.child,
  })  : this.subtitle =
            subtitle ?? 'Add up to 10 high-resolution photos of the item.',
        this.title = title ?? 'Visual Assets';

  final String subtitle;
  final String title;
  final Widget Function()? child;

  @override
  State<FormSectionWidget> createState() => _FormSectionWidgetState();
}

class _FormSectionWidgetState extends State<FormSectionWidget> {
  late FormSectionModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormSectionModel());
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              valueOrDefault<String>(
                widget!.title,
                'Visual Assets',
              ),
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).primaryText,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.bold,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    lineHeight: 1.3,
                  ),
            ),
            Text(
              valueOrDefault<String>(
                widget!.subtitle,
                'Add up to 10 high-resolution photos of the item.',
              ),
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.spaceGrotesk(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    lineHeight: 1.5,
                  ),
            ),
          ].divide(SizedBox(height: 4.0)),
        ),
        Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Container(
              child: Builder(builder: (_) {
                return widget.child != null
                    ? widget.child!()
                    : SizedBox.shrink();
              }),
            ),
          ),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }
}

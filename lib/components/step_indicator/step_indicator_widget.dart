import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'step_indicator_model.dart';
export 'step_indicator_model.dart';

class StepIndicatorWidget extends StatefulWidget {
  const StepIndicatorWidget({
    super.key,
    String? label,
    bool? active,
    bool? complete,
  })  : this.label = label ?? 'Identity',
        this.active = active ?? true,
        this.complete = complete ?? false;

  final String label;
  final bool active;
  final bool complete;

  @override
  State<StepIndicatorWidget> createState() => _StepIndicatorWidgetState();
}

class _StepIndicatorWidgetState extends State<StepIndicatorWidget> {
  late StepIndicatorModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StepIndicatorModel());
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
          height: 4.0,
          decoration: BoxDecoration(
            color: valueOrDefault<Color>(
              () {
                if (valueOrDefault<bool>(
                  widget!.complete,
                  false,
                )) {
                  return FlutterFlowTheme.of(context).success;
                } else if (valueOrDefault<bool>(
                  widget!.active,
                  true,
                )) {
                  return FlutterFlowTheme.of(context).primary;
                } else {
                  return FlutterFlowTheme.of(context).alternate;
                }
              }(),
              FlutterFlowTheme.of(context).primary,
            ),
            borderRadius: BorderRadius.circular(9999.0),
            shape: BoxShape.rectangle,
          ),
        ),
        Text(
          valueOrDefault<String>(
            widget!.label,
            'Identity',
          ),
          style: FlutterFlowTheme.of(context).labelSmall.override(
                font: GoogleFonts.jetBrainsMono(
                  fontWeight:
                      FlutterFlowTheme.of(context).labelSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                ),
                color: valueOrDefault<Color>(
                  valueOrDefault<bool>(
                    widget!.active,
                    true,
                  )
                      ? FlutterFlowTheme.of(context).primaryText
                      : FlutterFlowTheme.of(context).secondaryText,
                  FlutterFlowTheme.of(context).primaryText,
                ),
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                lineHeight: 1.2,
              ),
        ),
      ].divide(SizedBox(height: 4.0)),
    );
  }
}

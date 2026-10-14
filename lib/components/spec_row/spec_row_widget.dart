import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'spec_row_model.dart';
export 'spec_row_model.dart';

class SpecRowWidget extends StatefulWidget {
  const SpecRowWidget({
    super.key,
    String? label,
    String? value,
  })  : this.label = label ?? 'Movement',
        this.value = value ?? 'Automatic Cal. 27-460 Q';

  final String label;
  final String value;

  @override
  State<SpecRowWidget> createState() => _SpecRowWidgetState();
}

class _SpecRowWidgetState extends State<SpecRowWidget> {
  late SpecRowModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SpecRowModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            valueOrDefault<String>(
              widget!.label,
              'Movement',
            ),
            style: FlutterFlowTheme.of(context).labelLarge.override(
                  font: GoogleFonts.jetBrainsMono(
                    fontWeight:
                        FlutterFlowTheme.of(context).labelLarge.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelLarge.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).labelLarge.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelLarge.fontStyle,
                  lineHeight: 1.2,
                ),
          ),
          Text(
            valueOrDefault<String>(
              widget!.value,
              'Automatic Cal. 27-460 Q',
            ),
            style: FlutterFlowTheme.of(context).bodyLarge.override(
                  font: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                  lineHeight: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

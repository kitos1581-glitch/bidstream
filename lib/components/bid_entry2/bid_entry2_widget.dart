import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'bid_entry2_model.dart';
export 'bid_entry2_model.dart';

class BidEntry2Widget extends StatefulWidget {
  const BidEntry2Widget({
    super.key,
    String? amount,
    String? time,
    String? user,
    bool? isMine,
  })  : this.amount = amount ?? '\$14,500',
        this.time = time ?? 'Just now',
        this.user = user ?? 'JD',
        this.isMine = isMine ?? true;

  final String amount;
  final String time;
  final String user;
  final bool isMine;

  @override
  State<BidEntry2Widget> createState() => _BidEntry2WidgetState();
}

class _BidEntry2WidgetState extends State<BidEntry2Widget> {
  late BidEntry2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BidEntry2Model());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          valueOrDefault<bool>(
            widget!.isMine,
            true,
          )
              ? FlutterFlowTheme.of(context).primary10
              : Colors.transparent,
          FlutterFlowTheme.of(context).primary10,
        ),
        borderRadius: BorderRadius.circular(4.0),
        shape: BoxShape.rectangle,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 4.0, 16.0, 4.0),
        child: Container(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 24.0,
                    height: 24.0,
                    decoration: BoxDecoration(
                      color: valueOrDefault<Color>(
                        valueOrDefault<bool>(
                          widget!.isMine,
                          true,
                        )
                            ? FlutterFlowTheme.of(context).primary
                            : FlutterFlowTheme.of(context).surfaceVariant,
                        FlutterFlowTheme.of(context).primary,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Text(
                      valueOrDefault<String>(
                        widget!.user,
                        'JD',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: FlutterFlowTheme.of(context).labelMedium.override(
                            font: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .fontStyle,
                            ),
                            color: valueOrDefault<Color>(
                              valueOrDefault<bool>(
                                widget!.isMine,
                                true,
                              )
                                  ? FlutterFlowTheme.of(context).onPrimary
                                  : FlutterFlowTheme.of(context).primaryText,
                              FlutterFlowTheme.of(context).onPrimary,
                            ),
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontStyle,
                            lineHeight: 1.2,
                          ),
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  Text(
                    valueOrDefault<String>(
                      widget!.user,
                      'JD',
                    ),
                    style: FlutterFlowTheme.of(context).labelMedium.override(
                          font: GoogleFonts.jetBrainsMono(
                            fontWeight: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                          lineHeight: 1.2,
                        ),
                  ),
                ].divide(SizedBox(width: 4.0)),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    valueOrDefault<String>(
                      widget!.amount,
                      '\$14,500',
                    ),
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                          color: valueOrDefault<Color>(
                            valueOrDefault<bool>(
                              widget!.isMine,
                              true,
                            )
                                ? FlutterFlowTheme.of(context).primary
                                : FlutterFlowTheme.of(context).success,
                            FlutterFlowTheme.of(context).primary,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.bold,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                          lineHeight: 1.3,
                        ),
                  ),
                  Text(
                    valueOrDefault<String>(
                      widget!.time,
                      'Just now',
                    ),
                    style: FlutterFlowTheme.of(context).labelSmall.override(
                          font: GoogleFonts.jetBrainsMono(
                            fontWeight: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                          lineHeight: 1.2,
                        ),
                  ),
                ].divide(SizedBox(width: 4.0)),
              ),
            ].divide(SizedBox(width: 8.0)),
          ),
        ),
      ),
    );
  }
}

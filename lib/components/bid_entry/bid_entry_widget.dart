import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'bid_entry_model.dart';
export 'bid_entry_model.dart';

class BidEntryWidget extends StatefulWidget {
  const BidEntryWidget({
    super.key,
    String? amount,
    String? time,
    String? user,
    bool? isMine,
  })  : this.amount = amount ?? '\$42,500',
        this.time = time ?? '2m ago',
        this.user = user ?? 'User_882',
        this.isMine = isMine ?? false;

  final String amount;
  final String time;
  final String user;
  final bool isMine;

  @override
  State<BidEntryWidget> createState() => _BidEntryWidgetState();
}

class _BidEntryWidgetState extends State<BidEntryWidget> {
  late BidEntryModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BidEntryModel());
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
            false,
          )
              ? FlutterFlowTheme.of(context).primary10
              : FlutterFlowTheme.of(context).secondaryBackground,
          FlutterFlowTheme.of(context).secondaryBackground,
        ),
        borderRadius: BorderRadius.circular(4.0),
        shape: BoxShape.rectangle,
        border: Border.all(
          color: valueOrDefault<Color>(
            valueOrDefault<bool>(
              widget!.isMine,
              false,
            )
                ? FlutterFlowTheme.of(context).primary30
                : FlutterFlowTheme.of(context).alternate,
            FlutterFlowTheme.of(context).alternate,
          ),
          width: valueOrDefault<double>(
            valueOrDefault<bool>(
              widget!.isMine,
              false,
            )
                ? 1.0
                : 1.0,
            1.0,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Container(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: valueOrDefault<Color>(
                    valueOrDefault<bool>(
                      widget!.isMine,
                      false,
                    )
                        ? FlutterFlowTheme.of(context).primary
                        : FlutterFlowTheme.of(context).surfaceVariant,
                    FlutterFlowTheme.of(context).surfaceVariant,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Text(
                  'JD',
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
                            false,
                          )
                              ? FlutterFlowTheme.of(context).onPrimary
                              : FlutterFlowTheme.of(context).primaryText,
                          FlutterFlowTheme.of(context).primaryText,
                        ),
                        fontSize: 12.16,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                        lineHeight: 1.2,
                      ),
                  overflow: TextOverflow.clip,
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget!.user,
                            'User_882',
                          ),
                          style:
                              FlutterFlowTheme.of(context).labelLarge.override(
                                    font: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .fontStyle,
                                    lineHeight: 1.2,
                                  ),
                        ),
                        Text(
                          valueOrDefault<String>(
                            widget!.time,
                            '2m ago',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.jetBrainsMono(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.2,
                              ),
                        ),
                      ],
                    ),
                    Text(
                      valueOrDefault<String>(
                        'Placed a bid for ${widget!.amount}',
                        'Placed a bid for \$42,500',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.spaceGrotesk(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primaryText,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                            lineHeight: 1.5,
                          ),
                    ),
                  ].divide(SizedBox(height: 4.0)),
                ),
              ),
            ].divide(SizedBox(width: 16.0)),
          ),
        ),
      ),
    );
  }
}

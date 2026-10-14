import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'auction_card_model.dart';
export 'auction_card_model.dart';

class AuctionCardWidget extends StatefulWidget {
  const AuctionCardWidget({
    super.key,
    String? currentBid,
    String? imageDesc,
    String? lotNum,
    String? timeLeft,
    String? title,
    bool? isLive,
  })  : this.currentBid = currentBid ?? '\$142,000',
        this.imageDesc = imageDesc ??
            'https://dimg.dreamflow.cloud/v1/image/Vintage%20silver%20porsche%20911',
        this.lotNum = lotNum ?? '42',
        this.timeLeft = timeLeft ?? '02:14:05',
        this.title = title ?? '1967 Porsche 911 S',
        this.isLive = isLive ?? false;

  final String currentBid;
  final String imageDesc;
  final String lotNum;
  final String timeLeft;
  final String title;
  final bool isLive;

  @override
  State<AuctionCardWidget> createState() => _AuctionCardWidgetState();
}

class _AuctionCardWidgetState extends State<AuctionCardWidget> {
  late AuctionCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AuctionCardModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(8.0),
          shape: BoxShape.rectangle,
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 160.0,
              child: Stack(
                alignment: AlignmentDirectional(-1.0, -1.0),
                children: [
                  CachedNetworkImage(
                    fadeInDuration: Duration(milliseconds: 0),
                    fadeOutDuration: Duration(milliseconds: 0),
                    imageUrl: valueOrDefault<String>(
                      widget!.imageDesc,
                      'https://dimg.dreamflow.cloud/v1/image/Vintage%20silver%20porsche%20911',
                    ),
                    fit: BoxFit.cover,
                    alignment: Alignment(0.0, 0.0),
                  ),
                  Align(
                    alignment: AlignmentDirectional(-1.0, -1.0),
                    child: Container(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Container(
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: valueOrDefault<Color>(
                                    valueOrDefault<bool>(
                                      widget!.isLive,
                                      false,
                                    )
                                        ? Color(0x00000000)
                                        : Color(0x00000000),
                                    Color(0x00000000),
                                  ),
                                  borderRadius: BorderRadius.circular(2.0),
                                  shape: BoxShape.rectangle,
                                ),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      8.0, 4.0, 8.0, 4.0),
                                  child: Container(
                                    child: Text(
                                      valueOrDefault<String>(
                                        valueOrDefault<bool>(
                                          widget!.isLive,
                                          false,
                                        )
                                            ? '• LIVE'
                                            : 'TIMED',
                                        'TIMED',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.spaceGrotesk(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .onAccent,
                                            fontSize: 10.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2.0),
                                  shape: BoxShape.rectangle,
                                ),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      8.0, 4.0, 8.0, 4.0),
                                  child: Container(
                                    child: Text(
                                      valueOrDefault<String>(
                                        'LOT ${widget!.lotNum}',
                                        'LOT 42',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.spaceGrotesk(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .onAccent,
                                            fontSize: 10.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ].divide(SizedBox(width: 4.0)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Container(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueOrDefault<String>(
                          widget!.title,
                          '1967 Porsche 911 S',
                        ),
                        maxLines: 1,
                        style: FlutterFlowTheme.of(context)
                            .titleMedium
                            .override(
                              font: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).primaryText,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.bold,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .fontStyle,
                              lineHeight: 1.3,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'CURRENT BID',
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
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
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
                              Text(
                                valueOrDefault<String>(
                                  widget!.currentBid,
                                  '\$142,000',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .titleLarge
                                    .override(
                                      font: GoogleFonts.spaceGrotesk(
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontStyle,
                                      lineHeight: 1.3,
                                    ),
                              ),
                            ].divide(SizedBox(height: 4.0)),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ENDS IN',
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
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
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
                              Text(
                                valueOrDefault<String>(
                                  widget!.timeLeft,
                                  '02:14:05',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.spaceGrotesk(
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: valueOrDefault<Color>(
                                        valueOrDefault<bool>(
                                          widget!.isLive,
                                          false,
                                        )
                                            ? Color(0x00000000)
                                            : FlutterFlowTheme.of(context)
                                                .primaryText,
                                        FlutterFlowTheme.of(context)
                                            .primaryText,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                      lineHeight: 1.5,
                                    ),
                              ),
                            ].divide(SizedBox(height: 4.0)),
                          ),
                        ],
                      ),
                      Container(
                        height: 4.0,
                      ),
                      InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          context.goNamed(LotDetailViewWidget.routeName);
                        },
                        child: wrapWithModel(
                          model: _model.buttonModel,
                          updateCallback: () => safeSetState(() {}),
                          child: ButtonWidget(
                            iconPresent: false,
                            iconEndPresent: false,
                            content: 'Place Bid',
                            variant: 'primary',
                            size: 'small',
                            fullWidth: true,
                            loading: false,
                            disabled: false,
                          ),
                        ),
                      ),
                    ].divide(SizedBox(height: 8.0)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

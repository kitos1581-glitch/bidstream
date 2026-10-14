import '/components/bid_entry2/bid_entry2_widget.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'live_stream_auction_model.dart';
export 'live_stream_auction_model.dart';

class LiveStreamAuctionWidget extends StatefulWidget {
  const LiveStreamAuctionWidget({super.key});

  static String routeName = 'LiveStreamAuction';
  static String routePath = '/liveStreamAuction';

  @override
  State<LiveStreamAuctionWidget> createState() =>
      _LiveStreamAuctionWidgetState();
}

class _LiveStreamAuctionWidgetState extends State<LiveStreamAuctionWidget> {
  late LiveStreamAuctionModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LiveStreamAuctionModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Stack(
          alignment: AlignmentDirectional(-1.0, -1.0),
          children: [
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primaryBackground,
                shape: BoxShape.rectangle,
              ),
              child: Stack(
                alignment: AlignmentDirectional(-1.0, -1.0),
                children: [
                  Opacity(
                    opacity: 0.8,
                    child: CachedNetworkImage(
                      fadeInDuration: Duration(milliseconds: 0),
                      fadeOutDuration: Duration(milliseconds: 0),
                      imageUrl:
                          'https://dimg.dreamflow.cloud/v1/image/Luxury%20watch%20macro%20detail%2C%20high-end%20professional%20lighting',
                      fit: BoxFit.cover,
                      alignment: Alignment(0.0, 0.0),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          FlutterFlowTheme.of(context).background60,
                          FlutterFlowTheme.of(context).primaryBackground
                        ],
                        stops: [0.0, 0.7, 1.0],
                        begin: AlignmentDirectional(0.0, -1.0),
                        end: AlignmentDirectional(0, 1.0),
                      ),
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, -1.0),
              child: Container(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Container(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).error,
                                borderRadius: BorderRadius.circular(2.0),
                                shape: BoxShape.rectangle,
                              ),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    8.0, 4.0, 8.0, 4.0),
                                child: Container(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 8.0,
                                        height: 8.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .onAccent,
                                          borderRadius:
                                              BorderRadius.circular(9999.0),
                                          shape: BoxShape.rectangle,
                                        ),
                                      ),
                                      Text(
                                        'LIVE',
                                        style: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .override(
                                              font: GoogleFonts.jetBrainsMono(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .onAccent,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                              lineHeight: 1.2,
                                            ),
                                      ),
                                    ].divide(SizedBox(width: 4.0)),
                                  ),
                                ),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9999.0),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 8.0,
                                  sigmaY: 8.0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .background40,
                                    borderRadius: BorderRadius.circular(9999.0),
                                    shape: BoxShape.rectangle,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 4.0, 16.0, 4.0),
                                    child: Container(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.visibility_rounded,
                                            color: FlutterFlowTheme.of(context)
                                                .onAccent,
                                            size: 14.0,
                                          ),
                                          Text(
                                            '1,284 viewers',
                                            style: FlutterFlowTheme.of(context)
                                                .labelSmall
                                                .override(
                                                  font:
                                                      GoogleFonts.jetBrainsMono(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelSmall
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelSmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onAccent,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                  lineHeight: 1.2,
                                                ),
                                          ),
                                        ].divide(SizedBox(width: 4.0)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ].divide(SizedBox(height: 8.0)),
                        ),
                        FlutterFlowIconButton(
                          borderRadius: 9999.0,
                          buttonSize: 40.0,
                          fillColor: FlutterFlowTheme.of(context).background40,
                          icon: Icon(
                            Icons.close_rounded,
                            color: FlutterFlowTheme.of(context).onAccent,
                            size: 24.0,
                          ),
                          onPressed: () async {
                            context.goNamed(AuctionDashboardWidget.routeName);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Container(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(8.0),
                          shape: BoxShape.rectangle,
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 100.0,
                              height: 100.0,
                              child: CachedNetworkImage(
                                fadeInDuration: Duration(milliseconds: 0),
                                fadeOutDuration: Duration(milliseconds: 0),
                                imageUrl:
                                    'https://dimg.dreamflow.cloud/v1/image/Rolex%20Submariner%20Date%20126610LN',
                                fit: BoxFit.cover,
                                alignment: Alignment(0.0, 0.0),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Container(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LOT #42',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.jetBrainsMono(
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                                lineHeight: 1.2,
                                              ),
                                        ),
                                        Text(
                                          'Rolex Submariner Date',
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium
                                              .override(
                                                font: GoogleFonts.spaceGrotesk(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                                lineHeight: 1.3,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Current Bid',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts
                                                            .jetBrainsMono(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                        lineHeight: 1.2,
                                                      ),
                                            ),
                                            Text(
                                              '\$14,500',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .titleLarge
                                                  .override(
                                                    font: GoogleFonts
                                                        .spaceGrotesk(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleLarge
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.w900,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleLarge
                                                            .fontStyle,
                                                    lineHeight: 1.3,
                                                  ),
                                            ),
                                          ].divide(SizedBox(width: 8.0)),
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ].divide(SizedBox(width: 0.0)),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 200.0,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        FlutterFlowTheme.of(context).background20
                      ],
                      stops: [0.0, 1.0],
                      begin: AlignmentDirectional(0.0, 1.0),
                      end: AlignmentDirectional(0, -1.0),
                    ),
                    shape: BoxShape.rectangle,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 24.0),
                    child: Container(
                      child: Container(
                        height: 152.0,
                        child: SingleChildScrollView(
                          primary: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    24.0, 0.0, 24.0, 0.0),
                                child: Container(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      wrapWithModel(
                                        model: _model.bidEntryModel1,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BidEntry2Widget(
                                          amount: '\$14,500',
                                          time: 'Just now',
                                          user: 'JD',
                                          isMine: true,
                                        ),
                                      ),
                                      wrapWithModel(
                                        model: _model.bidEntryModel2,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BidEntry2Widget(
                                          amount: '\$14,400',
                                          time: '2m ago',
                                          user: 'AR',
                                          isMine: true,
                                        ),
                                      ),
                                      wrapWithModel(
                                        model: _model.bidEntryModel3,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BidEntry2Widget(
                                          amount: '\$14,250',
                                          time: '4m ago',
                                          user: 'MK',
                                          isMine: true,
                                        ),
                                      ),
                                      wrapWithModel(
                                        model: _model.bidEntryModel4,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BidEntry2Widget(
                                          amount: '\$14,100',
                                          time: '5m ago',
                                          user: 'RL',
                                          isMine: true,
                                        ),
                                      ),
                                      wrapWithModel(
                                        model: _model.bidEntryModel5,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BidEntry2Widget(
                                          amount: '\$14,000',
                                          time: '8m ago',
                                          user: 'TH',
                                          isMine: true,
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      topRight: Radius.circular(8.0),
                    ),
                    shape: BoxShape.rectangle,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 1.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).alternate,
                          shape: BoxShape.rectangle,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Container(
                          child: Column(
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
                                      model: _model.buttonModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ButtonWidget(
                                        iconPresent: false,
                                        iconEndPresent: false,
                                        content: '+\$100',
                                        variant: 'outline',
                                        size: 'small',
                                        fullWidth: false,
                                        loading: false,
                                        disabled: false,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: wrapWithModel(
                                      model: _model.buttonModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ButtonWidget(
                                        iconPresent: false,
                                        iconEndPresent: false,
                                        content: '+\$500',
                                        variant: 'outline',
                                        size: 'small',
                                        fullWidth: false,
                                        loading: false,
                                        disabled: false,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: wrapWithModel(
                                      model: _model.buttonModel3,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ButtonWidget(
                                        iconPresent: false,
                                        iconEndPresent: false,
                                        content: '+\$1,000',
                                        variant: 'outline',
                                        size: 'small',
                                        fullWidth: false,
                                        loading: false,
                                        disabled: false,
                                      ),
                                    ),
                                  ),
                                ].divide(SizedBox(width: 8.0)),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        context.goNamed(
                                            BidConfirmationModalWidget
                                                .routeName);
                                      },
                                      child: wrapWithModel(
                                        model: _model.buttonModel4,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: ButtonWidget(
                                          icon: Icon(
                                            Icons.gavel_rounded,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                          iconPresent: true,
                                          iconEndPresent: false,
                                          content: 'PLACE BID \$14,600',
                                          variant: 'primary',
                                          size: 'large',
                                          fullWidth: false,
                                          loading: false,
                                          disabled: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                  FlutterFlowIconButton(
                                    borderRadius: 4.0,
                                    buttonSize: 44.0,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .surfaceVariant,
                                    icon: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 28.0,
                                    ),
                                    onPressed: () {
                                      print('IconButton pressed ...');
                                    },
                                  ),
                                ].divide(SizedBox(width: 16.0)),
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

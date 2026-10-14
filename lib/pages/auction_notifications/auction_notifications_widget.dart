import '/components/bottom_nav/bottom_nav_widget.dart';
import '/components/bottom_nav_child2/bottom_nav_child2_widget.dart';
import '/components/notification_tile/notification_tile_widget.dart';
import '/components/tab_group/tab_group_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'auction_notifications_model.dart';
export 'auction_notifications_model.dart';

class AuctionNotificationsWidget extends StatefulWidget {
  const AuctionNotificationsWidget({super.key});

  static String routeName = 'AuctionNotifications';
  static String routePath = '/auctionNotifications';

  @override
  State<AuctionNotificationsWidget> createState() =>
      _AuctionNotificationsWidgetState();
}

class _AuctionNotificationsWidgetState
    extends State<AuctionNotificationsWidget> {
  late AuctionNotificationsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AuctionNotificationsModel());
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
        body: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                shape: BoxShape.rectangle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'NOTIFICATIONS',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.cormorant(
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      fontSize: 32.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                      lineHeight: 1.5,
                                    ),
                              ),
                              FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 40.0,
                                fillColor: Colors.transparent,
                                icon: Icon(
                                  Icons.settings_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                                onPressed: () {
                                  print('IconButton pressed ...');
                                },
                              ),
                            ],
                          ),
                          wrapWithModel(
                            model: _model.tabGroupModel,
                            updateCallback: () => safeSetState(() {}),
                            child: TabGroupWidget(
                              label2: 'Bids',
                              label2Present: true,
                              label3: 'Sales',
                              label3Present: true,
                              label4: '',
                              label4Present: false,
                              label5: '',
                              label5Present: false,
                              label1: 'All Activity',
                            ),
                          ),
                        ].divide(SizedBox(height: 16.0)),
                      ),
                    ),
                  ),
                  Container(
                    height: 2.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).onPrimaryContainer,
                          shape: BoxShape.rectangle,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              24.0, 16.0, 24.0, 16.0),
                          child: Container(
                            child: Text(
                              'TODAY',
                              style: FlutterFlowTheme.of(context)
                                  .labelLarge
                                  .override(
                                    font: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .fontStyle,
                                    lineHeight: 1.2,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.notificationTileModel1,
                        updateCallback: () => safeSetState(() {}),
                        child: NotificationTileWidget(
                          body:
                              'A new bid of \$185,500 has been placed. Raise your offer to stay in the lead.',
                          time: '2m ago',
                          title: 'Outbid: 2024 Porsche 911 GT3',
                          isRead: false,
                          type: 'outbid',
                        ),
                      ),
                      wrapWithModel(
                        model: _model.notificationTileModel2,
                        updateCallback: () => safeSetState(() {}),
                        child: NotificationTileWidget(
                          body:
                              'The \'Heritage Watch Collection\' is now live. Join the stream to participate.',
                          time: '15m ago',
                          title: 'Live Stream Starting',
                          isRead: false,
                          type: 'start',
                        ),
                      ),
                      wrapWithModel(
                        model: _model.notificationTileModel3,
                        updateCallback: () => safeSetState(() {}),
                        child: NotificationTileWidget(
                          body:
                              'Your payment for Lot #442 (Vintage Leica M6) has been confirmed. Shipping details sent to email.',
                          time: '2h ago',
                          title: 'Payment Successful',
                          isRead: true,
                          type: 'outbid',
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).onPrimaryContainer,
                          shape: BoxShape.rectangle,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              24.0, 16.0, 24.0, 16.0),
                          child: Container(
                            child: Text(
                              'YESTERDAY',
                              style: FlutterFlowTheme.of(context)
                                  .labelLarge
                                  .override(
                                    font: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .fontStyle,
                                    lineHeight: 1.2,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.notificationTileModel4,
                        updateCallback: () => safeSetState(() {}),
                        child: NotificationTileWidget(
                          body:
                              'Congratulations! You won Lot #109: \'Abstract No. 4\'. Please complete checkout within 24 hours.',
                          time: '1d ago',
                          title: 'Auction Won!',
                          isRead: true,
                          type: 'start',
                        ),
                      ),
                      wrapWithModel(
                        model: _model.notificationTileModel5,
                        updateCallback: () => safeSetState(() {}),
                        child: NotificationTileWidget(
                          body:
                              'Someone just bid \$12,000. Your previous high bid has been surpassed.',
                          time: '1d ago',
                          title: 'Outbid: Rare 1st Ed. Pokemon Charizard',
                          isRead: true,
                          type: 'outbid',
                        ),
                      ),
                      wrapWithModel(
                        model: _model.notificationTileModel6,
                        updateCallback: () => safeSetState(() {}),
                        child: NotificationTileWidget(
                          body:
                              'The \'Modernist Furniture\' catalog starts in 24 hours. View your watchlisted items.',
                          time: '1d ago',
                          title: 'Upcoming Auction Reminder',
                          isRead: true,
                          type: 'outbid',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 1.0),
              child: Container(
                child: wrapWithModel(
                  model: _model.bottomNavModel,
                  updateCallback: () => safeSetState(() {}),
                  child: BottomNavWidget(
                    child: () => BottomNavChild2Widget(),
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

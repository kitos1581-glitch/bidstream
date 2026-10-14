import '/components/bottom_nav/bottom_nav_widget.dart';
import '/components/bottom_nav_child2/bottom_nav_child2_widget.dart';
import '/components/notification_tile/notification_tile_widget.dart';
import '/components/tab_group/tab_group_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'auction_notifications_widget.dart' show AuctionNotificationsWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AuctionNotificationsModel
    extends FlutterFlowModel<AuctionNotificationsWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for TabGroup.
  late TabGroupModel tabGroupModel;
  // Model for NotificationTile.
  late NotificationTileModel notificationTileModel1;
  // Model for NotificationTile.
  late NotificationTileModel notificationTileModel2;
  // Model for NotificationTile.
  late NotificationTileModel notificationTileModel3;
  // Model for NotificationTile.
  late NotificationTileModel notificationTileModel4;
  // Model for NotificationTile.
  late NotificationTileModel notificationTileModel5;
  // Model for NotificationTile.
  late NotificationTileModel notificationTileModel6;
  // Model for BottomNav.
  late BottomNavModel bottomNavModel;

  @override
  void initState(BuildContext context) {
    tabGroupModel = createModel(context, () => TabGroupModel());
    notificationTileModel1 =
        createModel(context, () => NotificationTileModel());
    notificationTileModel2 =
        createModel(context, () => NotificationTileModel());
    notificationTileModel3 =
        createModel(context, () => NotificationTileModel());
    notificationTileModel4 =
        createModel(context, () => NotificationTileModel());
    notificationTileModel5 =
        createModel(context, () => NotificationTileModel());
    notificationTileModel6 =
        createModel(context, () => NotificationTileModel());
    bottomNavModel = createModel(context, () => BottomNavModel());
  }

  @override
  void dispose() {
    tabGroupModel.dispose();
    notificationTileModel1.dispose();
    notificationTileModel2.dispose();
    notificationTileModel3.dispose();
    notificationTileModel4.dispose();
    notificationTileModel5.dispose();
    notificationTileModel6.dispose();
    bottomNavModel.dispose();
  }
}

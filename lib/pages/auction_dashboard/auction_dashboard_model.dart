import '/backend/backend.dart';
import '/components/auction_card/auction_card_widget.dart';
import '/components/bottom_nav/bottom_nav_widget.dart';
import '/components/bottom_nav_child/bottom_nav_child_widget.dart';
import '/components/button/button_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'auction_dashboard_widget.dart' show AuctionDashboardWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AuctionDashboardModel extends FlutterFlowModel<AuctionDashboardWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for TextField.
  late TextFieldModel textFieldModel;
  // Model for Button.
  late ButtonModel buttonModel;
  // Models for AuctionCard.
  late FlutterFlowDynamicModels<AuctionCardModel> auctionCardModels1;
  // Model for BottomNav.
  late BottomNavModel bottomNavModel;

  @override
  void initState(BuildContext context) {
    textFieldModel = createModel(context, () => TextFieldModel());
    buttonModel = createModel(context, () => ButtonModel());
    auctionCardModels1 = FlutterFlowDynamicModels(() => AuctionCardModel());
    bottomNavModel = createModel(context, () => BottomNavModel());
  }

  @override
  void dispose() {
    textFieldModel.dispose();
    buttonModel.dispose();
    auctionCardModels1.dispose();
    bottomNavModel.dispose();
  }
}

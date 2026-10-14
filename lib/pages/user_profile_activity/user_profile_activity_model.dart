import '/components/activity_stat/activity_stat_widget.dart';
import '/components/bid_row/bid_row_widget.dart';
import '/components/button/button_widget.dart';
import '/components/tab_group/tab_group_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'user_profile_activity_widget.dart' show UserProfileActivityWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_palette/material_palette.dart';
import 'package:provider/provider.dart';

class UserProfileActivityModel
    extends FlutterFlowModel<UserProfileActivityWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for ActivityStat.
  late ActivityStatModel activityStatModel1;
  // Model for ActivityStat.
  late ActivityStatModel activityStatModel2;
  // Model for TabGroup.
  late TabGroupModel tabGroupModel;
  // Model for BidRow.
  late BidRowModel bidRowModel1;
  // Model for BidRow.
  late BidRowModel bidRowModel2;
  // Model for BidRow.
  late BidRowModel bidRowModel3;
  // Model for BidRow.
  late BidRowModel bidRowModel4;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;
  // Model for Button.
  late ButtonModel buttonModel3;

  @override
  void initState(BuildContext context) {
    activityStatModel1 = createModel(context, () => ActivityStatModel());
    activityStatModel2 = createModel(context, () => ActivityStatModel());
    tabGroupModel = createModel(context, () => TabGroupModel());
    bidRowModel1 = createModel(context, () => BidRowModel());
    bidRowModel2 = createModel(context, () => BidRowModel());
    bidRowModel3 = createModel(context, () => BidRowModel());
    bidRowModel4 = createModel(context, () => BidRowModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
    buttonModel3 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    activityStatModel1.dispose();
    activityStatModel2.dispose();
    tabGroupModel.dispose();
    bidRowModel1.dispose();
    bidRowModel2.dispose();
    bidRowModel3.dispose();
    bidRowModel4.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
    buttonModel3.dispose();
  }
}

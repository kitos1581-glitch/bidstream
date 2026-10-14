import '/components/bid_entry2/bid_entry2_widget.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'live_stream_auction_widget.dart' show LiveStreamAuctionWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LiveStreamAuctionModel extends FlutterFlowModel<LiveStreamAuctionWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for BidEntry.
  late BidEntry2Model bidEntryModel1;
  // Model for BidEntry.
  late BidEntry2Model bidEntryModel2;
  // Model for BidEntry.
  late BidEntry2Model bidEntryModel3;
  // Model for BidEntry.
  late BidEntry2Model bidEntryModel4;
  // Model for BidEntry.
  late BidEntry2Model bidEntryModel5;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;
  // Model for Button.
  late ButtonModel buttonModel3;
  // Model for Button.
  late ButtonModel buttonModel4;

  @override
  void initState(BuildContext context) {
    bidEntryModel1 = createModel(context, () => BidEntry2Model());
    bidEntryModel2 = createModel(context, () => BidEntry2Model());
    bidEntryModel3 = createModel(context, () => BidEntry2Model());
    bidEntryModel4 = createModel(context, () => BidEntry2Model());
    bidEntryModel5 = createModel(context, () => BidEntry2Model());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
    buttonModel3 = createModel(context, () => ButtonModel());
    buttonModel4 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    bidEntryModel1.dispose();
    bidEntryModel2.dispose();
    bidEntryModel3.dispose();
    bidEntryModel4.dispose();
    bidEntryModel5.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
    buttonModel3.dispose();
    buttonModel4.dispose();
  }
}

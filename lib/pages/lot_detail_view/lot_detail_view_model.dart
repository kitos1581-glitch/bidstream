import '/components/bid_entry/bid_entry_widget.dart';
import '/components/button/button_widget.dart';
import '/components/spec_row/spec_row_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'lot_detail_view_widget.dart' show LotDetailViewWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LotDetailViewModel extends FlutterFlowModel<LotDetailViewWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for SpecRow.
  late SpecRowModel specRowModel1;
  // Model for SpecRow.
  late SpecRowModel specRowModel2;
  // Model for SpecRow.
  late SpecRowModel specRowModel3;
  // Model for SpecRow.
  late SpecRowModel specRowModel4;
  // Model for BidEntry.
  late BidEntryModel bidEntryModel1;
  // Model for BidEntry.
  late BidEntryModel bidEntryModel2;
  // Model for BidEntry.
  late BidEntryModel bidEntryModel3;
  // Model for BidEntry.
  late BidEntryModel bidEntryModel4;
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
    specRowModel1 = createModel(context, () => SpecRowModel());
    specRowModel2 = createModel(context, () => SpecRowModel());
    specRowModel3 = createModel(context, () => SpecRowModel());
    specRowModel4 = createModel(context, () => SpecRowModel());
    bidEntryModel1 = createModel(context, () => BidEntryModel());
    bidEntryModel2 = createModel(context, () => BidEntryModel());
    bidEntryModel3 = createModel(context, () => BidEntryModel());
    bidEntryModel4 = createModel(context, () => BidEntryModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
    buttonModel3 = createModel(context, () => ButtonModel());
    buttonModel4 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    specRowModel1.dispose();
    specRowModel2.dispose();
    specRowModel3.dispose();
    specRowModel4.dispose();
    bidEntryModel1.dispose();
    bidEntryModel2.dispose();
    bidEntryModel3.dispose();
    bidEntryModel4.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
    buttonModel3.dispose();
    buttonModel4.dispose();
  }
}

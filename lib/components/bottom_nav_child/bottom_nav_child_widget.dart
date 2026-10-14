import '/components/nav_item/nav_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'bottom_nav_child_model.dart';
export 'bottom_nav_child_model.dart';

class BottomNavChildWidget extends StatefulWidget {
  const BottomNavChildWidget({super.key});

  @override
  State<BottomNavChildWidget> createState() => _BottomNavChildWidgetState();
}

class _BottomNavChildWidgetState extends State<BottomNavChildWidget> {
  late BottomNavChildModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BottomNavChildModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wrapWithModel(
          model: _model.navItemModel1,
          updateCallback: () => safeSetState(() {}),
          child: NavItemWidget(
            label: 'Catalog',
            icon: Icon(
              Icons.home_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            target: 'AuctionDashboard',
            selected: true,
          ),
        ),
        wrapWithModel(
          model: _model.navItemModel2,
          updateCallback: () => safeSetState(() {}),
          child: NavItemWidget(
            label: 'My Bids',
            icon: Icon(
              Icons.gavel_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            target: 'UserProfileActivity',
            selected: false,
          ),
        ),
        wrapWithModel(
          model: _model.navItemModel3,
          updateCallback: () => safeSetState(() {}),
          child: NavItemWidget(
            label: 'Sell',
            icon: Icon(
              Icons.add_box_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            target: 'CreateLotManagement',
            selected: false,
          ),
        ),
        wrapWithModel(
          model: _model.navItemModel4,
          updateCallback: () => safeSetState(() {}),
          child: NavItemWidget(
            label: 'Alerts',
            icon: Icon(
              Icons.notifications_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            target: 'AuctionNotifications',
            selected: false,
          ),
        ),
      ],
    );
  }
}

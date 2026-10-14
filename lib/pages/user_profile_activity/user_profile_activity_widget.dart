import '/components/activity_stat/activity_stat_widget.dart';
import '/components/bid_row/bid_row_widget.dart';
import '/components/button/button_widget.dart';
import '/components/tab_group/tab_group_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_palette/material_palette.dart';
import 'package:provider/provider.dart';
import 'user_profile_activity_model.dart';
export 'user_profile_activity_model.dart';

class UserProfileActivityWidget extends StatefulWidget {
  const UserProfileActivityWidget({super.key});

  static String routeName = 'UserProfileActivity';
  static String routePath = '/userProfileActivity';

  @override
  State<UserProfileActivityWidget> createState() =>
      _UserProfileActivityWidgetState();
}

class _UserProfileActivityWidgetState extends State<UserProfileActivityWidget> {
  late UserProfileActivityModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserProfileActivityModel());
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
        backgroundColor: FlutterFlowTheme.of(context).onPrimaryContainer,
        body: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: AlignmentDirectional(-1.0, -1.0),
                children: [
                  Container(
                    height: 220.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      shape: BoxShape.rectangle,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return FbmGradientShaderFill(
                          width: constraints.maxWidth.isFinite
                              ? constraints.maxWidth
                              : 200.0,
                          height: constraints.maxHeight.isFinite
                              ? constraints.maxHeight
                              : 200.0,
                          params: ShaderParams(values: {
                            'gradientAngle': 135.0,
                            'gradientScale': 0.89,
                            'gradientOffset': 0.0,
                            'noiseIntensity': 0.32,
                            'ditherStrength': 2.51,
                            'ditherScale': 0.29,
                            'animSpeed': 1.46,
                            'octaves': 6.06,
                            'lacunarity': 2.35,
                            'persistence': 0.5,
                            'noiseScale': 6.36,
                            'colorCount': 7.0,
                            'softness': 0.0,
                            'exposure': 1.0,
                            'contrast': 1.0,
                            'bumpStrength': 0.0,
                            'lightDirX': 0.55,
                            'lightDirY': 0.45,
                            'lightDirZ': 1.0,
                            'lightIntensity': 1.15,
                            'ambient': 0.7,
                            'specular': 0.29,
                            'shininess': 40.76,
                            'metallic': 1.0,
                            'roughness': 1.0,
                            'edgeFade': 1.72,
                            'edgeFadeMode': 0.0,
                            'sharpness': 2.2
                          }, colors: {
                            'color0':
                                FlutterFlowTheme.of(context).surfaceVariant,
                            'color1':
                                FlutterFlowTheme.of(context).primaryBackground,
                            'color2':
                                FlutterFlowTheme.of(context).primaryBackground,
                            'color3': Color(0xFF6224D1),
                            'color4': Color(0xFF8621A6),
                            'color5': Color(0xFF7D1C6D),
                            'color6': Color(0x00808080),
                            'color7': Color(0x00808080),
                            'color8': Color(0x00808080),
                            'color9': Color(0x00808080)
                          }),
                          animationMode: ShaderAnimationMode.continuous,
                          cache: false,
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional(1.0, -1.0),
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 80.0,
                                height: 80.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Text(
                                  'AR',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  style: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.jetBrainsMono(
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        fontSize: 30.4,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                        lineHeight: 1.2,
                                      ),
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Alex Rivera',
                                        style: FlutterFlowTheme.of(context)
                                            .headlineMedium
                                            .override(
                                              font: GoogleFonts.spaceGrotesk(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .onPrimary,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineMedium
                                                      .fontStyle,
                                              lineHeight: 1.2,
                                            ),
                                      ),
                                      Icon(
                                        Icons.verified_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .surfaceVariant,
                                        size: 20.0,
                                      ),
                                    ].divide(SizedBox(width: 4.0)),
                                  ),
                                  Text(
                                    'Pro Bidder • Member since 2023',
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          font: GoogleFonts.spaceGrotesk(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .onPrimary70,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ].divide(SizedBox(height: 4.0)),
                              ),
                            ].divide(SizedBox(width: 16.0)),
                          ),
                        ].divide(SizedBox(height: 24.0)),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primary,
                        borderRadius: BorderRadius.circular(4.0),
                        shape: BoxShape.rectangle,
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          width: 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            24.0, 16.0, 24.0, 16.0),
                        child: Container(
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gpp_good_rounded,
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                size: 24.0,
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Account Verified',
                                      style: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .override(
                                            font: GoogleFonts.jetBrainsMono(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelLarge
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                            lineHeight: 1.2,
                                          ),
                                    ),
                                    Text(
                                      'You have full access to high-value live streams.',
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            font: GoogleFonts.spaceGrotesk(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .background80,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ].divide(SizedBox(height: 4.0)),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                size: 24.0,
                              ),
                            ].divide(SizedBox(width: 16.0)),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 1,
                          child: wrapWithModel(
                            model: _model.activityStatModel1,
                            updateCallback: () => safeSetState(() {}),
                            child: ActivityStatWidget(
                              label: 'Active Bids',
                              tone: FlutterFlowTheme.of(context).surfaceVariant,
                              value: '12',
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: wrapWithModel(
                            model: _model.activityStatModel2,
                            updateCallback: () => safeSetState(() {}),
                            child: ActivityStatWidget(
                              label: 'Lotes Ganados',
                              tone: FlutterFlowTheme.of(context).tertiary,
                              value: '08',
                            ),
                          ),
                        ),
                      ].divide(SizedBox(width: 16.0)),
                    ),
                    wrapWithModel(
                      model: _model.tabGroupModel,
                      updateCallback: () => safeSetState(() {}),
                      child: TabGroupWidget(
                        label2: 'Lotes Ganados',
                        label2Present: true,
                        label3: 'Mis Publicaciones',
                        label3Present: true,
                        label4: '',
                        label4Present: false,
                        label5: '',
                        label5Present: false,
                        label1: 'Pujas Activas',
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        wrapWithModel(
                          model: _model.bidRowModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: BidRowWidget(
                            amount: '\$185,000',
                            status: 'WINNING',
                            statusColor:
                                FlutterFlowTheme.of(context).surfaceVariant,
                            title: '2022 Porsche 911 GT3 RS',
                          ),
                        ),
                        wrapWithModel(
                          model: _model.bidRowModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: BidRowWidget(
                            amount: '\$42,500',
                            status: 'OUTBID',
                            statusColor: FlutterFlowTheme.of(context).tertiary,
                            title: 'Rolex Daytona \'Paul Newman\'',
                          ),
                        ),
                        wrapWithModel(
                          model: _model.bidRowModel3,
                          updateCallback: () => safeSetState(() {}),
                          child: BidRowWidget(
                            amount: '\$12,200',
                            status: 'WINNING',
                            statusColor:
                                FlutterFlowTheme.of(context).surfaceVariant,
                            title: 'Contemporary Art: \'Neon Silence\'',
                          ),
                        ),
                        wrapWithModel(
                          model: _model.bidRowModel4,
                          updateCallback: () => safeSetState(() {}),
                          child: BidRowWidget(
                            amount: '\$3,800',
                            status: 'ENDING SOON',
                            statusColor:
                                FlutterFlowTheme.of(context).primaryBackground,
                            title: 'Vintage Leica M3 Camera Kit',
                          ),
                        ),
                      ].divide(SizedBox(height: 16.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Métodos de Pago',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                    lineHeight: 1.3,
                                  ),
                            ),
                            wrapWithModel(
                              model: _model.buttonModel1,
                              updateCallback: () => safeSetState(() {}),
                              child: ButtonWidget(
                                iconPresent: false,
                                iconEndPresent: false,
                                content: 'Add New',
                                variant: 'ghost',
                                size: 'small',
                                fullWidth: false,
                                loading: false,
                                disabled: false,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(8.0),
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Container(
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48.0,
                                    height: 32.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius: BorderRadius.circular(2.0),
                                      shape: BoxShape.rectangle,
                                    ),
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: SvgPicture.network(
                                      'https://cdn.simpleicons.org/visa/111111.svg',
                                      width: 24.0,
                                      height: 24.0,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Visa Corporate •••• 4242',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.spaceGrotesk(
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                                lineHeight: 1.5,
                                              ),
                                        ),
                                        Text(
                                          'Expires 12/26',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.jetBrainsMono(
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
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                                lineHeight: 1.2,
                                              ),
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color:
                                        FlutterFlowTheme.of(context).onSurface,
                                    size: 20.0,
                                  ),
                                ].divide(SizedBox(width: 16.0)),
                              ),
                            ),
                          ),
                        ),
                      ].divide(SizedBox(height: 16.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context
                                .goNamed(CreateLotManagementWidget.routeName);
                          },
                          child: wrapWithModel(
                            model: _model.buttonModel2,
                            updateCallback: () => safeSetState(() {}),
                            child: ButtonWidget(
                              icon: Icon(
                                Icons.add_box_rounded,
                                color: FlutterFlowTheme.of(context).primaryText,
                                size: 24.0,
                              ),
                              iconPresent: true,
                              iconEndPresent: false,
                              content: 'Create/Manage Lot',
                              variant: 'outline',
                              size: 'medium',
                              fullWidth: true,
                              loading: false,
                              disabled: false,
                            ),
                          ),
                        ),
                        wrapWithModel(
                          model: _model.buttonModel3,
                          updateCallback: () => safeSetState(() {}),
                          child: ButtonWidget(
                            icon: Icon(
                              Icons.history_rounded,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 24.0,
                            ),
                            iconPresent: true,
                            iconEndPresent: false,
                            content: 'View Auction History',
                            variant: 'ghost',
                            size: 'medium',
                            fullWidth: true,
                            loading: false,
                            disabled: false,
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                  ].divide(SizedBox(height: 24.0)),
                ),
              ),
              Container(
                height: 80.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

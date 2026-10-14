import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'notification_tile_model.dart';
export 'notification_tile_model.dart';

class NotificationTileWidget extends StatefulWidget {
  const NotificationTileWidget({
    super.key,
    String? body,
    String? time,
    String? title,
    bool? isRead,
    String? type,
  })  : this.body = body ??
            'A new bid of \$185,500 has been placed. Raise your offer to stay in the lead.',
        this.time = time ?? '2m ago',
        this.title = title ?? 'Outbid: 2024 Porsche 911 GT3',
        this.isRead = isRead ?? false,
        this.type = type ?? 'outbid';

  final String body;
  final String time;
  final String title;
  final bool isRead;
  final String type;

  @override
  State<NotificationTileWidget> createState() => _NotificationTileWidgetState();
}

class _NotificationTileWidgetState extends State<NotificationTileWidget> {
  late NotificationTileModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NotificationTileModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          valueOrDefault<bool>(
            widget!.isRead,
            false,
          )
              ? FlutterFlowTheme.of(context).secondaryBackground
              : FlutterFlowTheme.of(context).surfaceVariant,
          FlutterFlowTheme.of(context).surfaceVariant,
        ),
        shape: BoxShape.rectangle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(24.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: valueOrDefault<Color>(
                        valueOrDefault<String>(
                                  widget!.type,
                                  'outbid',
                                ) ==
                                'start'
                            ? FlutterFlowTheme.of(context).success10
                            : FlutterFlowTheme.of(context).error10,
                        FlutterFlowTheme.of(context).error10,
                      ),
                      borderRadius: BorderRadius.circular(4.0),
                      shape: BoxShape.rectangle,
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Container(
                      width: 24.0,
                      height: 24.0,
                      child: Stack(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        children: [
                          if (valueOrDefault<bool>(
                            valueOrDefault<String>(
                                      widget!.type,
                                      'outbid',
                                    ) ==
                                    'start'
                                ? true
                                : false,
                            false,
                          ))
                            Icon(
                              Icons.play_circle_rounded,
                              color: valueOrDefault<Color>(
                                valueOrDefault<String>(
                                          widget!.type,
                                          'outbid',
                                        ) ==
                                        'start'
                                    ? FlutterFlowTheme.of(context).success
                                    : FlutterFlowTheme.of(context).error,
                                FlutterFlowTheme.of(context).error,
                              ),
                              size: 24.0,
                            ),
                          if (valueOrDefault<bool>(
                            valueOrDefault<String>(
                                      widget!.type,
                                      'outbid',
                                    ) ==
                                    'start'
                                ? false
                                : true,
                            true,
                          ))
                            Icon(
                              Icons.gavel_rounded,
                              color: valueOrDefault<Color>(
                                valueOrDefault<String>(
                                          widget!.type,
                                          'outbid',
                                        ) ==
                                        'start'
                                    ? FlutterFlowTheme.of(context).success
                                    : FlutterFlowTheme.of(context).error,
                                FlutterFlowTheme.of(context).error,
                              ),
                              size: 24.0,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
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
                              valueOrDefault<String>(
                                widget!.title,
                                'Outbid: 2024 Porsche 911 GT3',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                    lineHeight: 1.3,
                                  ),
                            ),
                            Text(
                              valueOrDefault<String>(
                                widget!.time,
                                '2m ago',
                              ),
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
                          ],
                        ),
                        Text(
                          valueOrDefault<String>(
                            widget!.body,
                            'A new bid of \$185,500 has been placed. Raise your offer to stay in the lead.',
                          ),
                          maxLines: 2,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.spaceGrotesk(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                                lineHeight: 1.5,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (valueOrDefault<bool>(
                          valueOrDefault<bool>(
                            widget!.isRead,
                            false,
                          )
                              ? false
                              : true,
                          true,
                        ))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 8.0,
                                height: 8.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).tertiary,
                                  borderRadius: BorderRadius.circular(9999.0),
                                  shape: BoxShape.rectangle,
                                ),
                              ),
                              Text(
                                'New Alert',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.jetBrainsMono(
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).tertiary,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.2,
                                    ),
                              ),
                            ].divide(SizedBox(width: 8.0)),
                          ),
                      ].divide(SizedBox(height: 4.0)),
                    ),
                  ),
                ].divide(SizedBox(width: 16.0)),
              ),
            ),
          ),
          Container(
            height: 1.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).alternate,
              shape: BoxShape.rectangle,
            ),
          ),
        ],
      ),
    );
  }
}

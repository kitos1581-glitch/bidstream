import '/components/image_uploader/image_uploader_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'form_section_child_model.dart';
export 'form_section_child_model.dart';

class FormSectionChildWidget extends StatefulWidget {
  const FormSectionChildWidget({super.key});

  @override
  State<FormSectionChildWidget> createState() => _FormSectionChildWidgetState();
}

class _FormSectionChildWidgetState extends State<FormSectionChildWidget> {
  late FormSectionChildModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormSectionChildModel());
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        wrapWithModel(
          model: _model.imageUploaderModel,
          updateCallback: () => safeSetState(() {}),
          child: ImageUploaderWidget(),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  shape: BoxShape.rectangle,
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                child: CachedNetworkImage(
                  fadeInDuration: Duration(milliseconds: 0),
                  fadeOutDuration: Duration(milliseconds: 0),
                  imageUrl:
                      'https://dimg.dreamflow.cloud/v1/image/vintage%20watch%20close%20up',
                  fit: BoxFit.cover,
                  alignment: Alignment(0.0, 0.0),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  shape: BoxShape.rectangle,
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                child: CachedNetworkImage(
                  fadeInDuration: Duration(milliseconds: 0),
                  fadeOutDuration: Duration(milliseconds: 0),
                  imageUrl:
                      'https://dimg.dreamflow.cloud/v1/image/vintage%20watch%20back%20case',
                  fit: BoxFit.cover,
                  alignment: Alignment(0.0, 0.0),
                ),
              ),
            ),
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(4.0),
                shape: BoxShape.rectangle,
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1.0,
                ),
              ),
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Icon(
                Icons.add_rounded,
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 24.0,
              ),
            ),
          ].divide(SizedBox(width: 8.0)),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }
}

import '/components/image_uploader/image_uploader_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'form_section_child_widget.dart' show FormSectionChildWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FormSectionChildModel extends FlutterFlowModel<FormSectionChildWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for ImageUploader.
  late ImageUploaderModel imageUploaderModel;

  @override
  void initState(BuildContext context) {
    imageUploaderModel = createModel(context, () => ImageUploaderModel());
  }

  @override
  void dispose() {
    imageUploaderModel.dispose();
  }
}

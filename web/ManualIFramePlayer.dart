import 'dart:html' as html;
import 'dart:ui' as ui; // Provides platformViewRegistry on web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class ManualIframePlayer extends StatefulWidget {
  final String videoId;
  const ManualIframePlayer({Key? key, required this.videoId}) : super(key: key);

  @override
  State<ManualIframePlayer> createState() => _ManualIframePlayerState();
}

class _ManualIframePlayerState extends State<ManualIframePlayer> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();

    _viewId = 'youtube-iframe-${widget.videoId}-${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      // The ignore is needed because 'platformViewRegistry' is a web-only API
      // and the Dart analyzer flags it for non-web platforms.
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube.com/embed/${widget.videoId}'
          ..style.border = 'none'
          ..allowFullscreen = true;
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Text('Manual iframe is only supported on Flutter Web.');
    }

    return SizedBox(
      width: 600,
      height: 350,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

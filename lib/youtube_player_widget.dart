import 'dart:html' as html;
import 'dart:ui' as ui; // We'll need this for the platformViewRegistry
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// -------------- Extract YouTube ID ---------------
String? extractYouTubeId(String url) {
  final RegExp regExp = RegExp(
    r'^.*(?:(?:youtu\.be\/|v\/|vi\/|u\/\w\/|embed\/|shorts\/)|(?:(?:watch)?\?v(?:i)?=|\&v(?:i)?=))([^#\&\?]*).*',
    caseSensitive: false,
  );
  final Match? match = regExp.firstMatch(url);
  return match?.group(1);
}

// -------------- ManualIframePlayer ---------------
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
      // The Dart analyzer sees this as undefined for non-web platforms, so we ignore it:
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube.com/embed/${widget.videoId}'
          ..style.border = 'none'
          ..allowFullscreen = true; // allow user to fullscreen if desired
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Text('Manual Iframe is only supported on Flutter Web.');
    }

    return SizedBox(
      width: 600,
      height: 350,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

// -------------- YouTubeVideoPlayer ---------------
class YouTubeVideoPlayer extends StatefulWidget {
  final String url;
  const YouTubeVideoPlayer({Key? key, required this.url}) : super(key: key);

  @override
  State<YouTubeVideoPlayer> createState() => _YouTubeVideoPlayerState();
}

class _YouTubeVideoPlayerState extends State<YouTubeVideoPlayer> {
  String? _extractedVideoId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    try {
      _extractedVideoId = extractYouTubeId(widget.url);
      debugPrint('🔍 Full URL: ${widget.url}');
      debugPrint('🎬 Extracted Video ID: $_extractedVideoId');

      if (_extractedVideoId == null || _extractedVideoId!.isEmpty) {
        throw Exception('Invalid YouTube URL');
      }
    } catch (e) {
      debugPrint('❌ Iframe Player Error: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Text('Error: $_errorMessage');
    }

    if (!kIsWeb) {
      return Text(
        'Manual iframe only works on web. Extracted video ID: $_extractedVideoId',
        style: const TextStyle(color: Colors.red),
      );
    }

    if (_extractedVideoId == null) {
      return const Text('Failed to extract a valid video ID.');
    }

    // Return the manual iframe widget
    return ManualIframePlayer(videoId: _extractedVideoId!);
  }
}

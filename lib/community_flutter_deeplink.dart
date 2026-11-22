import 'dart:async';

import 'package:flutter/services.dart';

/// Text another app shared to this one (Android `ACTION_SEND` with a `text/*` type).
class SharedText {
  const SharedText(this.text, [this.subject]);

  /// `EXTRA_TEXT` (never empty).
  final String text;

  /// `EXTRA_SUBJECT`, when the sender set one.
  final String? subject;

  @override
  bool operator ==(Object other) => other is SharedText && other.text == text && other.subject == subject;

  @override
  int get hashCode => Object.hash(text, subject);

  @override
  String toString() => 'SharedText($text, $subject)';
}

/// A file another app shared to this one (Android `ACTION_SEND` image / PDF, `ACTION_SEND_MULTIPLE`
/// images), copied into the app's cache. A PDF arrives as its first page rendered to a PNG.
class SharedFile {
  const SharedFile({this.path, this.mimeType, this.error});

  /// The cached copy; null when [error] is set.
  final String? path;

  /// The copy's MIME type (`image/png` for a rendered PDF page), when known.
  final String? mimeType;

  /// Why the share could not be read.
  final String? error;

  @override
  bool operator ==(Object other) =>
      other is SharedFile && other.path == path && other.mimeType == mimeType && other.error == error;

  @override
  int get hashCode => Object.hash(path, mimeType, error);

  @override
  String toString() => 'SharedFile($path, $mimeType, $error)';
}

/// Deep links, launching and probing other apps, and content shared to the app.
///
/// Links reach the app through a custom scheme registered by the host app (`myapp://...`),
/// or as an Android App Link / https link.
class CommunityFlutterDeeplink {
  CommunityFlutterDeeplink._();

  static const MethodChannel _channel = MethodChannel('community_flutter_deeplink');
  static const EventChannel _events = EventChannel('community_flutter_deeplink/links');
  static const EventChannel _shares = EventChannel('community_flutter_deeplink/shares');

  /// The link the app was started with (or the latest one received), null when there is none.
  static Future<String?> getLastDeepLink() => _channel.invokeMethod<String>('getLastDeepLink');

  /// Links received while the app is running (a launcher shortcut, another app, a
  /// site open). The launch link is NOT replayed here: read it with [getLastDeepLink].
  static Stream<String> get onDeepLink =>
      _events.receiveBroadcastStream().where((e) => e is String && e.isNotEmpty).cast<String>();

  /// Text shared to the app (Android `ACTION_SEND`, `text/*`, a non-empty `EXTRA_TEXT`, or a selection sent with
  /// `ACTION_PROCESS_TEXT`): the share the
  /// app was started with (delivered once, to the first listener) and every share received while it runs.
  /// The host app declares the `SEND` / `text/plain` intent-filter on its main activity. Nothing on iOS.
  static Stream<SharedText> get onSharedText =>
      _shares.receiveBroadcastStream().map(_sharedText).where((s) => s != null).cast<SharedText>();

  static SharedText? _sharedText(Object? e) {
    if (e is! Map) return null;
    final text = e['text'];
    if (text is! String || text.isEmpty) return null;
    final subject = e['subject'];
    return SharedText(text, subject is String ? subject : null);
  }

  /// The file shared to the app since the last call (one-shot: a second call returns null until
  /// another share arrives). Android only: the host app declares `ShareFileReceiverActivity` with
  /// its `SEND` / `SEND_MULTIPLE` image and PDF intent-filters. Null on iOS, when nothing was shared,
  /// or when the platform call fails.
  static Future<SharedFile?> takeSharedFile() async {
    final Object? e;
    try {
      e = await _channel.invokeMethod<Object?>('takeSharedFile');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
    if (e is! Map) return null;
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    final SharedFile f = SharedFile(path: str(e['path']), mimeType: str(e['mimeType']), error: str(e['error']));
    if (f.path == null && f.error == null) return null;
    return f;
  }

  /// Every file of the latest share (a `SEND_MULTIPLE` of 12 photos gives 12, in the sender's order),
  /// one-shot like [takeSharedFile] - which reads only the first and empties the same slot. Empty on iOS,
  /// when nothing was shared, or when the platform call fails. A file that could not be read keeps its
  /// place with [SharedFile.error] set.
  static Future<List<SharedFile>> takeSharedFiles() async {
    final Object? e;
    try {
      e = await _channel.invokeMethod<Object?>('takeSharedFiles');
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
    if (e is! List) return const [];
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    return [
      for (final m in e)
        if (m is Map && (str(m['path']) != null || str(m['error']) != null))
          SharedFile(path: str(m['path']), mimeType: str(m['mimeType']), error: str(m['error'])),
    ];
  }

  /// Opens [url] in the app that handles it. False when no app does or the launch failed.
  static Future<bool> launchApp(String url) async {
    try {
      return await _channel.invokeMethod<bool>('launchApp', {'url': url}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// True when an installed app can open [url]. Android needs a matching `<queries>` entry and iOS
  /// the scheme in `LSApplicationQueriesSchemes`, both declared by the host app.
  static Future<bool> isAppInstalled(String url) async {
    try {
      return await _channel.invokeMethod<bool>('isAppInstalled', {'url': url}) ?? false;
    } on PlatformException {
      return false;
    }
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_flutter_deeplink/community_flutter_deeplink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('community_flutter_deeplink');
  const events = EventChannel('community_flutter_deeplink/links');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];
  Object? Function(MethodCall call) reply = (_) => null;

  setUp(() {
    calls.clear();
    reply = (_) => null;
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return reply(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(events, null);
  });

  group('getLastDeepLink', () {
    test('sends getLastDeepLink without arguments and returns the link', () async {
      reply = (_) => 'myapp://nfc?tab=tools';
      expect(await CommunityFlutterDeeplink.getLastDeepLink(), 'myapp://nfc?tab=tools');
      expect(calls.single.method, 'getLastDeepLink');
      expect(calls.single.arguments, isNull);
    });

    test('null when there is no link', () async {
      expect(await CommunityFlutterDeeplink.getLastDeepLink(), isNull);
    });

    test('wrong type throws', () async {
      reply = (_) => 42;
      expect(CommunityFlutterDeeplink.getLastDeepLink(), throwsA(isA<TypeError>()));
    });

    test('PlatformException propagates', () async {
      reply = (_) => throw PlatformException(code: 'ERR');
      await expectLater(CommunityFlutterDeeplink.getLastDeepLink(), throwsA(isA<PlatformException>()));
    });
  });

  group('onDeepLink', () {
    test('emits non-empty strings only', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (args, sink) {
            sink.success('myapp://nfc');
            sink.success('');
            sink.success(null);
            sink.success(7);
            sink.success('https://example.com/open');
            sink.endOfStream();
          },
        ),
      );
      expect(await CommunityFlutterDeeplink.onDeepLink.toList(), ['myapp://nfc', 'https://example.com/open']);
    });

    test('listen and cancel reach the native stream handler', () async {
      var listened = 0;
      var cancelled = 0;
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (args, sink) => listened++,
          onCancel: (args) => cancelled++,
        ),
      );
      final sub = CommunityFlutterDeeplink.onDeepLink.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(listened, 1);
      await sub.cancel();
      expect(cancelled, 1);
    });

    test('stream errors are forwarded', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (args, sink) {
            sink.error(code: 'BAD', message: 'oops');
            sink.endOfStream();
          },
        ),
      );
      await expectLater(CommunityFlutterDeeplink.onDeepLink, emitsError(isA<PlatformException>()));
    });
  });

  group('launchApp', () {
    test('sends launchApp with the url and returns true', () async {
      reply = (_) => true;
      expect(await CommunityFlutterDeeplink.launchApp('myapp://nfc'), isTrue);
      expect(calls.single.method, 'launchApp');
      expect(calls.single.arguments, {'url': 'myapp://nfc'});
    });

    test('false from native', () async {
      reply = (_) => false;
      expect(await CommunityFlutterDeeplink.launchApp('x://y'), isFalse);
    });

    test('null result becomes false', () async {
      expect(await CommunityFlutterDeeplink.launchApp('x://y'), isFalse);
    });

    test('PlatformException (APP_NOT_FOUND) becomes false', () async {
      reply = (_) => throw PlatformException(code: 'APP_NOT_FOUND');
      expect(await CommunityFlutterDeeplink.launchApp('x://y'), isFalse);
    });

    test('wrong type throws (only PlatformException is swallowed)', () async {
      reply = (_) => 'yes';
      expect(CommunityFlutterDeeplink.launchApp('x://y'), throwsA(isA<TypeError>()));
    });

    test('MissingPluginException propagates', () async {
      messenger.setMockMethodCallHandler(method, null);
      await expectLater(CommunityFlutterDeeplink.launchApp('x://y'), throwsA(isA<MissingPluginException>()));
    });
  });

  group('isAppInstalled', () {
    test('sends isAppInstalled with the url and returns true', () async {
      reply = (_) => true;
      expect(await CommunityFlutterDeeplink.isAppInstalled('whatsapp://send'), isTrue);
      expect(calls.single.method, 'isAppInstalled');
      expect(calls.single.arguments, {'url': 'whatsapp://send'});
    });

    test('false from native', () async {
      reply = (_) => false;
      expect(await CommunityFlutterDeeplink.isAppInstalled('x://y'), isFalse);
    });

    test('null result becomes false', () async {
      expect(await CommunityFlutterDeeplink.isAppInstalled('x://y'), isFalse);
    });

    test('PlatformException becomes false', () async {
      reply = (_) => throw PlatformException(code: 'INVALID');
      expect(await CommunityFlutterDeeplink.isAppInstalled(''), isFalse);
    });

    test('wrong type throws', () async {
      reply = (_) => 1;
      expect(CommunityFlutterDeeplink.isAppInstalled('x://y'), throwsA(isA<TypeError>()));
    });

    test('MissingPluginException propagates', () async {
      messenger.setMockMethodCallHandler(method, null);
      await expectLater(CommunityFlutterDeeplink.isAppInstalled('x://y'), throwsA(isA<MissingPluginException>()));
    });
  });

  group('onSharedText', () {
    const shares = EventChannel('community_flutter_deeplink/shares');
    tearDown(() => messenger.setMockStreamHandler(shares, null));

    test('emits {text, subject} maps with a non-empty text as SharedText', () async {
      messenger.setMockStreamHandler(
        shares,
        MockStreamHandler.inline(
          onListen: (args, sink) {
            sink.success({'text': 'https://example.com', 'subject': 'A page'});
            sink.success({'text': '', 'subject': 'x'});
            sink.success({'subject': 'no text'});
            sink.success('not a map');
            sink.success({'text': 'hello', 'subject': null});
            sink.success({'text': 'n', 'subject': 7});
            sink.endOfStream();
          },
        ),
      );
      expect(await CommunityFlutterDeeplink.onSharedText.toList(), const [
        SharedText('https://example.com', 'A page'),
        SharedText('hello'),
        SharedText('n'),
      ]);
    });

    test('a native error reaches the listener', () async {
      messenger.setMockStreamHandler(
        shares,
        MockStreamHandler.inline(onListen: (args, sink) => sink.error(code: 'ERR', message: 'boom')),
      );
      await expectLater(CommunityFlutterDeeplink.onSharedText.first, throwsA(isA<PlatformException>()));
    });

    test('SharedText equality and toString', () {
      expect(const SharedText('a', 'b'), const SharedText('a', 'b'));
      expect(const SharedText('a').hashCode, const SharedText('a').hashCode);
      expect(const SharedText('a') == const SharedText('a', 'b'), isFalse);
      expect('${const SharedText('a', 'b')}', 'SharedText(a, b)');
    });
  });

  group('takeSharedFile', () {
    test('sends takeSharedFile and maps the cached file', () async {
      reply = (_) => {'path': '/cache/share_1.png', 'mimeType': 'image/png', 'error': null};
      expect(await CommunityFlutterDeeplink.takeSharedFile(), const SharedFile(path: '/cache/share_1.png', mimeType: 'image/png'));
      expect(calls.single.method, 'takeSharedFile');
      expect(calls.single.arguments, isNull);
    });

    test('an unreadable share carries its error', () async {
      reply = (_) => {'path': null, 'mimeType': null, 'error': 'Unable to read shared PDF'};
      expect(await CommunityFlutterDeeplink.takeSharedFile(), const SharedFile(error: 'Unable to read shared PDF'));
    });

    test('null when nothing was shared, the reply is malformed or the platform fails', () async {
      expect(await CommunityFlutterDeeplink.takeSharedFile(), isNull);
      reply = (_) => 'not a map';
      expect(await CommunityFlutterDeeplink.takeSharedFile(), isNull);
      reply = (_) => {'path': '', 'mimeType': 7, 'error': ''};
      expect(await CommunityFlutterDeeplink.takeSharedFile(), isNull);
      reply = (_) => throw PlatformException(code: 'ERR');
      expect(await CommunityFlutterDeeplink.takeSharedFile(), isNull);
      messenger.setMockMethodCallHandler(method, null);
      expect(await CommunityFlutterDeeplink.takeSharedFile(), isNull);
    });

    test('takeSharedFiles: every file of a SEND_MULTIPLE in order, errors keep their place; empty otherwise', () async {
      reply = (_) => [
            {'path': '/cache/share_1_0.jpg', 'mimeType': 'image/jpeg', 'error': null},
            {'path': null, 'mimeType': null, 'error': 'Could not read the shared file: denied'},
            {'path': '/cache/share_1_2.heic', 'mimeType': 'image/heic', 'error': null},
            {'path': '', 'mimeType': '', 'error': ''},
            'junk',
          ];
      expect(await CommunityFlutterDeeplink.takeSharedFiles(), const [
        SharedFile(path: '/cache/share_1_0.jpg', mimeType: 'image/jpeg'),
        SharedFile(error: 'Could not read the shared file: denied'),
        SharedFile(path: '/cache/share_1_2.heic', mimeType: 'image/heic'),
      ]);
      expect(calls.last.method, 'takeSharedFiles');
      reply = (_) => null;
      expect(await CommunityFlutterDeeplink.takeSharedFiles(), isEmpty);
      reply = (_) => throw PlatformException(code: 'ERR');
      expect(await CommunityFlutterDeeplink.takeSharedFiles(), isEmpty);
      messenger.setMockMethodCallHandler(method, null);
      expect(await CommunityFlutterDeeplink.takeSharedFiles(), isEmpty);
    });

    test('SharedFile equality and toString', () {
      expect(const SharedFile(path: 'a', mimeType: 'b'), const SharedFile(path: 'a', mimeType: 'b'));
      expect(const SharedFile(path: 'a').hashCode, const SharedFile(path: 'a').hashCode);
      expect(const SharedFile(path: 'a') == const SharedFile(error: 'a'), isFalse);
      expect('${const SharedFile(path: 'a', mimeType: 'b')}', 'SharedFile(a, b, null)');
    });
  });
}

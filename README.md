# community_flutter_deeplink

Deep links for Flutter apps: `getLastDeepLink`, `onDeepLink`, `launchApp`, `isAppInstalled`, plus
`onSharedText` (text shared to the app) and `takeSharedFile` / `takeSharedFiles` (images or a PDF shared to the app). Android keeps the link of the activity intent (`onCreate` and `onNewIntent`);
iOS reads `application(_:open:options:)` and the scene's URL contexts.

<!-- support:top:start -->
## ❤️ Support this plugin

I build and maintain this plugin, and [a whole family of free Flutter plugins](https://github.com/EYALIN?tab=repositories&q=community_flutter), in my free time. Every Android and iOS release changes something underneath them (new SDK levels, Swift Package Manager, privacy manifests, OEM quirks), and keeping them working takes hours every month.

**If this plugin saved you from writing the platform code yourself, or it ships in an app that earns money, please sponsor its development.** Even $5 a month makes a real difference. It decides how fast issues get fixed, how quickly the plugin supports each new Android and iOS release, and which features come next. Issues and feature requests from sponsors are looked at first.

[![Sponsor Me](https://img.shields.io/static/v1?label=Sponsor%20Me&style=for-the-badge&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/EYALIN)

Not able to sponsor? A ⭐ on [GitHub](https://github.com/EYALIN) and a 👍 on pub.dev help other developers find it. Thank you!
<!-- support:top:end -->

| | Android | iOS |
|---|---|---|
| Minimum | API 24 | iOS 15 |
| Launch link, link stream | yes | yes (app and scene delegates) |
| `launchApp`, `isAppInstalled` | yes (`<queries>`) | yes (`LSApplicationQueriesSchemes`) |
| Shared text, shared files | yes | — |

## Install

```sh
flutter pub add community_flutter_deeplink
```

## Usage

```dart
import 'package:community_flutter_deeplink/community_flutter_deeplink.dart';

final launch = await CommunityFlutterDeeplink.getLastDeepLink(); // myapp://item/42, or null
final sub = CommunityFlutterDeeplink.onDeepLink.listen((link) => print('opened with $link'));

if (await CommunityFlutterDeeplink.isAppInstalled('otherapp://')) {
  await CommunityFlutterDeeplink.launchApp('otherapp://home');
}

final shared = CommunityFlutterDeeplink.onSharedText.listen((s) => print('shared: ${s.text}'));
```

See [example/lib/main.dart](example/lib/main.dart) for a complete app.

## Setup

The host app declares the schemes it answers to:

* Android: an `<intent-filter>` (VIEW, DEFAULT, BROWSABLE) with `<data android:scheme=... android:host=.../>` on the main
  activity, and `<queries>` entries for the schemes `isAppInstalled` probes.
* iOS: `CFBundleURLTypes` and `LSApplicationQueriesSchemes` in Info.plist.
* Share target (`onSharedText`, Android only): an `<intent-filter>` (SEND, DEFAULT, `<data android:mimeType="text/plain"/>`)
  on the main activity. The launch share is delivered once, to the first listener; later shares arrive through
  `onNewIntent` (the activity needs `launchMode="singleTop"`). The intent is consumed, so an activity re-create does not
  deliver it again.
* File share target (`takeSharedFile`, Android only): declare the plugin's receiver in the app manifest, which keeps the
  share out of apps that do not want it:

  ```xml
  <activity android:name="com.community.flutter.deeplink.ShareFileReceiverActivity"
      android:theme="@android:style/Theme.Translucent.NoTitleBar" android:exported="true"
      android:excludeFromRecents="true" android:noHistory="true">
      <intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="image/*"/></intent-filter>
      <intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="application/pdf"/></intent-filter>
      <intent-filter><action android:name="android.intent.action.SEND_MULTIPLE"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="image/*"/></intent-filter>
  </activity>
  ```

  It copies the file to the cache (a PDF as its first page rendered to a PNG; of several images, the first), keeps it for
  `takeSharedFile` and brings the app forward (a running instance resumes). `takeSharedFile` returns the share once.

## License

MIT — see [LICENSE](LICENSE). Issues and pull requests are welcome at
[github.com/EYALIN/community_flutter_deeplink](https://github.com/EYALIN/community_flutter_deeplink/issues).

<!-- support:bottom:start -->
## Support

If this plugin is useful to you, please [sponsor its development](https://github.com/sponsors/EYALIN). It keeps the plugin maintained for every new Android and iOS release.
<!-- support:bottom:end -->

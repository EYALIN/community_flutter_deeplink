import 'dart:async';

import 'package:community_flutter_deeplink/community_flutter_deeplink.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: DeeplinkDemo()));

class DeeplinkDemo extends StatefulWidget {
  const DeeplinkDemo({super.key});

  @override
  State<DeeplinkDemo> createState() => _DeeplinkDemoState();
}

class _DeeplinkDemoState extends State<DeeplinkDemo> {
  final List<String> _events = [];
  StreamSubscription<String>? _links;
  StreamSubscription<SharedText>? _shares;

  @override
  void initState() {
    super.initState();
    CommunityFlutterDeeplink.getLastDeepLink().then((link) => _add('launch link: $link'));
    _links = CommunityFlutterDeeplink.onDeepLink.listen((link) => _add('link: $link'));
    _shares = CommunityFlutterDeeplink.onSharedText.listen((s) => _add('shared text: ${s.text}'));
  }

  void _add(String event) {
    if (mounted) setState(() => _events.insert(0, event));
  }

  Future<void> _openMaps() async {
    const url = 'geo:0,0?q=coffee';
    final installed = await CommunityFlutterDeeplink.isAppInstalled(url);
    final launched = installed && await CommunityFlutterDeeplink.launchApp(url);
    _add('maps installed: $installed, launched: $launched');
  }

  Future<void> _takeFile() async {
    final file = await CommunityFlutterDeeplink.takeSharedFile();
    _add('shared file: $file');
  }

  @override
  void dispose() {
    _links?.cancel();
    _shares?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deep links')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 8, children: [
              FilledButton(onPressed: _openMaps, child: const Text('Open a maps app')),
              OutlinedButton(onPressed: _takeFile, child: const Text('Take shared file')),
            ]),
          ),
          Expanded(
            child: ListView(children: [for (final e in _events) ListTile(title: Text(e))]),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api_client.dart';
import '../../ui/tokens.dart';
import 'identity_models.dart';

/// Takes the selfie and liveness frames with Smile ID's own camera component. Tests use a fake.
abstract class SelfieCamera {
  /// Null when the customer closes the camera, or it can't start.
  Future<SelfieCapture?> capture(BuildContext context);
}

/// Smile ID's web camera (`smart-camera-web`, the same one the web app uses) in an in-app web
/// view. The images come back to the app, which uploads them straight to Smile ID; they never
/// reach Tabital's servers (founder decision, 2026-10-03).
class SmileWebCamera implements SelfieCamera {
  const SmileWebCamera();

  static const _permissions = MethodChannel('com.tabitalpay/permissions');

  @override
  Future<SelfieCapture?> capture(BuildContext context) async {
    final allowed = await _permissions.invokeMethod<bool>('camera').catchError((_) => false) ?? false;
    if (!context.mounted) return null;
    if (!allowed) {
      throw ApiException('Tabital needs the camera for the selfie. Allow it in your phone settings and try again.');
    }
    return Navigator.of(context)
        .push<SelfieCapture>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _SmileCameraScreen()));
  }
}

const _cameraScript = 'https://cdn.usesmileid.com/js/v12/smart-camera-web.js';

const _cameraPage =
    '''
<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{margin:0;background:#fff;font-family:sans-serif}</style>
</head><body>
<smart-camera-web></smart-camera-web>
<script>
  function send(m) { TabitalCamera.postMessage(JSON.stringify(m)); }
  var s = document.createElement('script');
  s.src = '$_cameraScript';
  s.onerror = function () { send({ error: 'load' }); };
  document.head.appendChild(s);
  window.addEventListener('smart-camera-web.publish', function (e) {
    var images = (e.detail && e.detail.images) || [];
    send({ images: images
      .filter(function (i) { return i.image_type_id === 2 || i.image_type_id === 6; })
      .map(function (i) { return { type: i.image_type_id, image: i.image }; }) });
  });
</script>
</body></html>
''';

class _SmileCameraScreen extends StatefulWidget {
  const _SmileCameraScreen();

  @override
  State<_SmileCameraScreen> createState() => _SmileCameraScreenState();
}

class _SmileCameraScreenState extends State<_SmileCameraScreen> {
  late final WebViewController _web;
  String? _error;

  @override
  void initState() {
    super.initState();
    _web =
        WebViewController(
            onPermissionRequest: (req) {
              // Only the camera, and only for this page
              if (req.types.every((t) => t == WebViewPermissionResourceType.camera)) {
                req.grant();
              } else {
                req.deny();
              }
            },
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel('TabitalCamera', onMessageReceived: (m) => _onMessage(m.message))
          ..setNavigationDelegate(
            NavigationDelegate(
              // Stay on the camera page; nothing here should navigate away
              onNavigationRequest: (req) => req.url.startsWith('https://tabitalpay.com/smile-camera')
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent,
            ),
          )
          // An https base URL makes the page a secure context, which the camera needs
          ..loadHtmlString(_cameraPage, baseUrl: 'https://tabitalpay.com/smile-camera');
  }

  void _onMessage(String raw) {
    Object? m;
    try {
      m = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (m is! Map || !mounted) return;
    if (m['error'] != null) {
      setState(() => _error = "The camera couldn't load. Check your connection and try again.");
      return;
    }
    final images = (m['images'] as List?)?.whereType<Map>().toList() ?? const [];
    final selfie = images.where((i) => i['type'] == 2).map((i) => i['image'].toString()).firstOrNull;
    final liveness = images.where((i) => i['type'] == 6).map((i) => i['image'].toString()).toList();
    if (selfie == null || liveness.isEmpty) {
      setState(() => _error = "We couldn't capture a clear selfie. Please try again.");
      return;
    }
    Navigator.of(context).pop(SelfieCapture(selfie: selfie, liveness: liveness));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(LucideIcons.x), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Take a selfie'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                color: Tp.errorBg,
                padding: const EdgeInsets.all(Tp.s3),
                child: Text(_error!, style: const TextStyle(color: Tp.error)),
              ),
            Expanded(child: WebViewWidget(controller: _web)),
          ],
        ),
      ),
    );
  }
}

/// Sends the capture to Smile ID with the token from `POST /customer/identity/start`.
/// This goes to Smile ID only, never with Tabital's session token.
class SmileUploader {
  SmileUploader({this.client});

  /// Tests pass a fake; otherwise one is made on first use.
  http.Client? client;

  /// Returns Smile ID's job id.
  Future<String> upload(IdentitySession s, SelfieCapture c) async {
    final req = http.MultipartRequest('POST', s.submitUrl)
      ..headers['smileid-token'] = s.token
      ..headers['Accept'] = 'application/json';
    req.files.add(http.MultipartFile.fromBytes('selfie_image', _jpeg(c.selfie), filename: 'selfie.jpg'));
    for (final (i, frame) in c.liveness.indexed) {
      req.files.add(http.MultipartFile.fromBytes('liveness_images', _jpeg(frame), filename: 'liveness-$i.jpg'));
    }
    // The same details the token was minted with
    req.fields.addAll(s.fields);
    req.fields['consent'] = jsonEncode(s.consent);
    req.fields['user_details'] = jsonEncode({
      'given_names': s.fields['given_names'],
      'last_name': s.fields['last_name'],
      'phone_number': s.fields['phone_number'],
    });

    http.Response res;
    try {
      final c = client ??= http.Client();
      res = await http.Response.fromStream(await c.send(req).timeout(const Duration(seconds: 90)));
    } on Exception {
      throw ApiException("We couldn't send your selfie. Check your connection and try again.");
    }
    Object? data;
    try {
      data = jsonDecode(res.body);
    } on FormatException {
      data = null;
    }
    final jobId = data is Map ? data['job_id'] : null;
    if (res.statusCode != 202 || jobId is! String || jobId.isEmpty) {
      final msg = data is Map ? (data['message'] ?? data['error']) : null;
      throw ApiException("We couldn't send your selfie: ${msg is String && msg.isNotEmpty ? msg : 'please try again'}.");
    }
    return jobId;
  }

  static List<int> _jpeg(String base64Image) => base64Decode(base64Image.split(',').last.trim());
}

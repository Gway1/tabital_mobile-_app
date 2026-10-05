import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

/// Opens Terms, the Privacy Policy and Help in the phone's browser. Only https links.
Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.isScheme('https')) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) throw ApiException("Couldn't open $url. Please visit it in your browser.");
}

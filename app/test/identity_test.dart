import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabital_pay/features/identity/identity_models.dart';
import 'package:tabital_pay/features/identity/smile_capture.dart';

import 'fake_api.dart';
import 'test_app.dart';

// Identity check (§9A): Ghana Card + selfie, sent from the phone straight to Smile ID with the
// token from our API. Mirrors the web app's verify-identity flow.
void main() {
  final session = {
    'check_id': 5,
    'token': 'smile-token-1',
    'partner_id': '1234',
    'api_url': 'https://testapi.smileidentity.com',
    'submit_url': 'https://testapi.smileidentity.com/v3/biometric_kyc',
    'fields': {
      'country': 'GH',
      'id_type': 'GHANA_CARD',
      'id_number': 'GHA-123456789-0',
      'given_names': 'Ama',
      'last_name': 'Mensah',
      'phone_number': '0241234567',
    },
    'consent': {'granted': true, 'granted_at': '2026-10-03T10:00:00Z', 'notice_language': 'EN'},
  };
  final capture = SelfieCapture(selfie: 'data:image/jpeg;base64,/9j/AAEC', liveness: ['/9j/AQID', '/9j/AgME']);

  FakeApi api({Map<String, dynamic>? status}) => FakeApi({
    'GET /customer/identity': (200, status ?? identityFixture(kyc: 'pending')),
    'POST /customer/identity/start': (200, session),
    'POST /customer/identity/5/submitted': (200, {'message': 'Thanks.'}),
  });

  testWidgets('a verified customer is told so', (tester) async {
    await pumpApp(tester, api(status: identityFixture()), '/account/identity');
    expect(find.text("You're verified"), findsOneWidget);
  });

  testWidgets('consent comes first; then the selfie goes to Smile ID, never with our session token', (tester) async {
    final f = api();
    http.MultipartRequest? sent;
    final smile = SmileUploader(
      client: MockClient.streaming((req, body) async {
        sent = req as http.MultipartRequest;
        return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({'job_id': 'job_abc1234567'}))), 202);
      }),
    );
    final camera = FakeCamera(capture);
    await pumpApp(tester, f, '/account/identity', camera: camera, smile: smile);

    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('identity-start'))).onPressed, isNull);
    expect(find.text('You have 3 attempts.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('identity-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('identity-start')));
    await tester.pump();
    await tester.pump();

    expect(lastBody(f, '/customer/identity/start'), {'consent': true});
    expect(camera.opened, 1);
    expect(sent!.url.toString(), 'https://testapi.smileidentity.com/v3/biometric_kyc');
    expect(sent!.headers['smileid-token'], 'smile-token-1');
    expect(sent!.headers.containsKey('Authorization'), isFalse);
    expect(sent!.fields['id_number'], 'GHA-123456789-0');
    expect(sent!.files.map((f) => f.field), ['selfie_image', 'liveness_images', 'liveness_images']);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // the waiting spinner never settles
    }
    expect(lastBody(f, '/customer/identity/5/submitted'), {'job_id': 'job_abc1234567'});
    expect(find.textContaining('Checking your identity'), findsOneWidget);

    // Smile ID's result reaches the API; the screen picks it up on the next check
    f.routes['GET /customer/identity'] = (200, identityFixture());
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    await tester.pump();
    expect(find.text("You're verified"), findsOneWidget);
  });

  testWidgets('closing the camera sends nothing to Smile ID', (tester) async {
    final f = api();
    var uploads = 0;
    final smile = SmileUploader(
      client: MockClient((_) async {
        uploads++;
        return http.Response('{}', 202);
      }),
    );
    await pumpApp(tester, f, '/account/identity', camera: FakeCamera(null), smile: smile);
    await tester.tap(find.byKey(const Key('identity-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('identity-start')));
    await tester.pumpAndSettle();
    expect(uploads, 0);
    expect(calls(f, 'POST', '/customer/identity/5/submitted'), 0);
    expect(find.byKey(const Key('identity-start')), findsOneWidget);
  });

  testWidgets("Smile ID refusing the upload shows its message and doesn't report a job", (tester) async {
    final f = api();
    final smile = SmileUploader(client: MockClient((_) async => http.Response(jsonEncode({'message': 'Image too dark'}), 400)));
    await pumpApp(tester, f, '/account/identity', camera: FakeCamera(capture), smile: smile);
    await tester.tap(find.byKey(const Key('identity-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('identity-start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Image too dark'), findsOneWidget);
    expect(calls(f, 'POST', '/customer/identity/5/submitted'), 0);
  });

  testWidgets("a blocked check shows the reason; with no attempts left it can't start", (tester) async {
    await pumpApp(
      tester,
      api(
        status: identityFixture(kyc: 'rejected', check: 'blocked', attemptsLeft: 0),
      ),
      '/account/identity',
    );
    expect(find.textContaining('did not match your Ghana Card photo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('identity-consent')));
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('identity-start'))).onPressed, isNull);
  });
}

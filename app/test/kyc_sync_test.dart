import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabital_pay/core/config.dart';
import 'package:tabital_pay/features/identity/document_picker.dart';
import 'package:tabital_pay/features/identity/identity_models.dart';
import 'package:tabital_pay/features/shop/product_screen.dart';
import 'package:tabital_pay/features/shop/shop_models.dart';

import 'fake_api.dart';
import 'test_app.dart';

/// A document picker that hands back a fixed file.
class FakeDocumentPicker implements DocumentPicker {
  FakeDocumentPicker([this.file]);
  final PickedDocument? file;
  int opened = 0;

  @override
  Future<PickedDocument?> pick(BuildContext context, {required String label}) async {
    opened++;
    return file;
  }
}

// The 2026-10-25 backend sync (docs/backend_sync_2026-10-25.md, U1 and U3–U7).
void main() {
  Map<String, dynamic> doc(String field, String label, String status, {String? reason}) => {
    'field': field,
    'document_type': field,
    'label': label,
    'required': true,
    'status': status,
    'uploaded_at': null,
    'rejection_reason': reason,
    'can_upload': status == 'missing' || status == 'rejected',
  };

  Map<String, dynamic> kyc({
    List<String> detailsMissing = const ['Ghana Card number', 'where you live (city and address)'],
    String front = 'missing',
    String back = 'pending',
    String salary = 'rejected',
    String bank = 'verified',
    Map<String, dynamic> details = const {},
  }) {
    final docs = [
      doc('front_image', 'Ghana Card (Front)', front),
      doc('back_image', 'Ghana Card (Back)', back),
      doc('salary_certificate', 'Salary Certificate', salary, reason: salary == 'rejected' ? 'The photo is blurred' : null),
      doc('bank_statement', '3 Months Bank Statement', bank),
    ];
    return {
      'details': {
        'full_name': 'Ama Mensah',
        'date_of_birth': '1990-01-15',
        'city': null,
        'gps': null,
        'address': null,
        'designation': null,
        'company': null,
        'monthly_salary': null,
        'employment_start_date': null,
        'salary_paid_to_bank': false,
        'national_id': null,
        'momo_number': null,
        'ref_name': null,
        'ref_phone': null,
        'ref_relationship': null,
        ...details,
      },
      'checklist': {
        'kyc_status': 'pending',
        'details_missing': detailsMissing,
        'documents': docs,
        'documents_to_upload': [
          for (final d in docs)
            if (d['can_upload'] == true) d['label'],
        ],
        'documents_in_review': [
          for (final d in docs)
            if (d['status'] == 'pending') d['label'],
        ],
        'complete': false,
      },
    };
  }

  test('U1: the app talks to the live API unless a build says otherwise', () {
    expect(AppConfig.apiBaseUrl, 'https://tabital-backend.onrender.com');
  });

  group('U4: Your details', () {
    testWidgets('shows what is still missing, and saves only what was filled in, in the server\'s format', (tester) async {
      final f = FakeApi({
        'GET /customer/kyc/details': (200, kyc()),
        'PUT /customer/kyc/details': (
          200,
          {
            'message': 'Details saved.',
            ...kyc(detailsMissing: const ['where you live (city and address)']),
          },
        ),
      });
      await pumpApp(tester, f, '/account/identity/details');
      expect(find.textContaining('Still to add: Ghana Card number'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('kyc-national_id')), 'gha 123456789 0');
      await tester.enterText(find.byKey(const Key('kyc-momo_number')), '055 123 4567');
      await tester.ensureVisible(find.byKey(const Key('kyc-save')));
      await tester.tap(find.byKey(const Key('kyc-save')));
      await tester.pumpAndSettle();
      expect(lastBody(f, '/customer/kyc/details'), {
        'national_id': 'GHA-123456789-0',
        'momo_number': '0551234567',
        'salary_paid_to_bank': false,
      });
      expect(find.text('Details saved.'), findsOneWidget);
    });

    testWidgets("the server's {error, field} shows on that field", (tester) async {
      final f = FakeApi({
        'GET /customer/kyc/details': (200, kyc()),
        'PUT /customer/kyc/details': (
          409,
          {'error': 'This Mobile Money number is already linked to another account.', 'field': 'momo_number'},
        ),
      });
      await pumpApp(tester, f, '/account/identity/details');
      await tester.enterText(find.byKey(const Key('kyc-momo_number')), '0551234567');
      await tester.tap(find.byKey(const Key('kyc-save')));
      await tester.pumpAndSettle();
      expect(find.text('This Mobile Money number is already linked to another account.'), findsWidgets);
    });

    testWidgets('a wrong Ghana Card number is caught before sending; empty fields are skipped', (tester) async {
      final f = FakeApi({'GET /customer/kyc/details': (200, kyc())});
      await pumpApp(tester, f, '/account/identity/details');
      await tester.enterText(find.byKey(const Key('kyc-national_id')), 'GHA-123');
      await tester.tap(find.byKey(const Key('kyc-save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter the Ghana Card number as GHA-XXXXXXXXX-X'), findsOneWidget);
      expect(calls(f, 'PUT', '/customer/kyc/details'), 0);
    });
  });

  group('U5: documents', () {
    FakeApi api({(int, Object?)? upload}) => FakeApi({
      'GET /customer/kyc/details': (200, kyc()),
      'POST /customer/documents/upload':
          upload ?? (201, {'message': 'Uploaded: Ghana Card (Front). The team will review it.', 'documents': []}),
    });

    testWidgets("each document's state from the server; upload only where the server allows it", (tester) async {
      await pumpApp(tester, api(), '/account/identity/documents');
      expect(find.textContaining('Still needed: Ghana Card (Front), Salary Certificate'), findsOneWidget);
      expect(find.byKey(const Key('doc-upload-front_image')), findsOneWidget); // missing
      expect(find.byKey(const Key('doc-upload-back_image')), findsNothing); // pending
      expect(find.byKey(const Key('doc-upload-bank_statement')), findsNothing); // verified
      expect(find.text('Waiting for review'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Why: The photo is blurred'), findsOneWidget); // rejected, with the reason
      expect(find.text('Send a new one'), findsOneWidget);
    });

    testWidgets('a picked file goes to the server as that one document, then the list reloads', (tester) async {
      final f = api();
      final picker = FakeDocumentPicker(PickedDocument(name: 'card.jpg', bytes: List.filled(1000, 1)));
      await pumpApp(tester, f, '/account/identity/documents', documents: picker);
      final loads = calls(f, 'GET', '/customer/kyc/details');
      await tester.tap(find.byKey(const Key('doc-upload-front_image')));
      await tester.pumpAndSettle();
      final upload = f.requests.lastWhere((r) => r.url.path == '/customer/documents/upload');
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      expect(upload.body, contains('name="front_image"; filename="card.jpg"'));
      expect(find.text('Uploaded: Ghana Card (Front). The team will review it.'), findsOneWidget);
      expect(calls(f, 'GET', '/customer/kyc/details'), loads + 1);
    });

    testWidgets("the server's refusal shows under that document", (tester) async {
      final f = api(
        upload: (
          409,
          {'error': 'Ghana Card (Front) is waiting for review. You can upload it again only if the team rejects it.'},
        ),
      );
      final picker = FakeDocumentPicker(PickedDocument(name: 'card.png', bytes: List.filled(10, 1)));
      await pumpApp(tester, f, '/account/identity/documents', documents: picker);
      await tester.tap(find.byKey(const Key('doc-upload-front_image')));
      await tester.pumpAndSettle();
      expect(find.textContaining('is waiting for review. You can upload it again'), findsOneWidget);
    });

    testWidgets('a wrong file type or a file over 5 MB is caught before sending', (tester) async {
      final f = api();
      await pumpApp(
        tester,
        f,
        '/account/identity/documents',
        documents: FakeDocumentPicker(PickedDocument(name: 'card.gif', bytes: List.filled(10, 1))),
      );
      await tester.tap(find.byKey(const Key('doc-upload-front_image')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a JPG, PNG, WEBP or PDF file.'), findsOneWidget);
      expect(calls(f, 'POST', '/customer/documents/upload'), 0);
      expect(documentFileError(PickedDocument(name: 'x.pdf', bytes: List.filled(documentMaxBytes + 1, 0))), contains('5 MB'));
      expect(documentFileError(PickedDocument(name: 'x.PDF', bytes: List.filled(10, 0))), isNull);
    });
  });

  group('U3: the selfie check waits for the Ghana Card number', () {
    FakeApi api({List<String> missing = const ['Ghana Card number']}) => FakeApi({
      'GET /customer/kyc/details': (200, kyc(detailsMissing: missing)),
      'GET /customer/identity': (200, identityFixture(kyc: 'pending')),
    });

    testWidgets('without it, the checklist says so and Start stays off', (tester) async {
      final f = api();
      await pumpApp(tester, f, '/account/identity');
      expect(find.byKey(const Key('kyc-checklist')), findsOneWidget);
      expect(find.byKey(const Key('identity-needs-card')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('identity-consent')));
      await tester.tap(find.byKey(const Key('identity-consent')));
      await tester.pump();
      expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('identity-start'))).onPressed, isNull);
      expect(calls(f, 'POST', '/customer/identity/start'), 0);
    });

    testWidgets('with it saved, the selfie check can start', (tester) async {
      await pumpApp(tester, api(missing: const ['where you live (city and address)']), '/account/identity');
      expect(find.byKey(const Key('identity-needs-card')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('identity-consent')));
      await tester.tap(find.byKey(const Key('identity-consent')));
      await tester.pump();
      expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('identity-start'))).onPressed, isNotNull);
    });
  });

  group('U6: pending accounts', () {
    testWidgets("the Shop banner says what's still needed", (tester) async {
      final f = FakeApi({
        'GET /customer/products': (
          200,
          {
            'products': [productFixture()],
            'total': 1,
            'page': 1,
            'total_pages': 1,
          },
        ),
        'GET /customer/identity': (200, identityFixture(kyc: 'pending')),
        'GET /customer/kyc/details': (200, kyc(detailsMissing: const ['Mobile Money number'])),
      });
      await pumpApp(tester, f, '/shop');
      expect(find.textContaining('Still needed: Mobile Money number, Ghana Card (Front), Salary Certificate'), findsOneWidget);
    });

    testWidgets("a refused checkout shows the API's words and offers Verify identity", (tester) async {
      final options = PlanOptions.fromJson(planOptionsFixture());
      final f = FakeApi({
        'GET /customer/payments/config': (200, {'paystack_enabled': true}),
        'POST /customer/purchase': (
          403,
          {'error': 'Verify your identity first: your account is approved once your KYC is checked.'},
        ),
        'GET /customer/profile': (200, {'status': 'pending'}),
        'GET /customer/identity': (200, identityFixture(kyc: 'pending')),
      });
      final router = await pumpApp(
        tester,
        f,
        '/shop/product/11/checkout',
        extra: CheckoutArgs(
          product: Product.fromJson(productFixture()),
          options: options,
          option: options.option(4)!,
          quantity: 1,
        ),
      );
      await tester.enterText(find.byKey(const Key('address')), 'Osu, Oxford Street, Accra');
      await tester.tap(find.byKey(const Key('agree')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(find.text('Verify your identity first: your account is approved once your KYC is checked.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkout-verify')));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/account/identity');
    });

    testWidgets('the Account page shows the account status from the profile', (tester) async {
      await pumpApp(
        tester,
        FakeApi({
          'GET /customer/profile': (200, {'status': 'pending'}),
        }),
        '/account',
      );
      expect(find.text('Waiting for verification'), findsOneWidget);
      expect(find.byKey(const Key('account-status')), findsOneWidget);
    });
  });

  group('U7: products from shops not approved yet', () {
    testWidgets('a product that is no longer available shows that, not an error page', (tester) async {
      final f = FakeApi({
        'GET /customer/products/11': (400, {'error': 'Product is not available'}),
        'POST /customer/plan-options': (400, {'error': 'Product not available'}),
        'GET /customer/identity': (200, identityFixture()),
      });
      await pumpApp(tester, f, '/shop/product/11');
      expect(find.byKey(const Key('product-unavailable')), findsOneWidget);
      expect(find.text('Product is not available'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('an empty shop says partner shops are being added', (tester) async {
      final f = FakeApi({
        'GET /customer/products': (200, {'products': [], 'total': 0, 'page': 1, 'total_pages': 1}),
      });
      await pumpApp(tester, f, '/shop');
      expect(find.byKey(const Key('shop-empty')), findsOneWidget);
      expect(find.text('No products yet'), findsOneWidget);
    });
  });
}

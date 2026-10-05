import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabital_pay/core/api_client.dart';
import 'package:tabital_pay/core/secure_store.dart';
import 'package:tabital_pay/features/auth/auth_controller.dart';
import 'package:tabital_pay/features/plans/customer_repository.dart';

/// A fake Flask API: map "METHOD /path" to (status, body). Records every request.
class FakeApi {
  FakeApi(this.routes);
  final Map<String, (int, Object?)> routes;
  final List<http.Request> requests = [];

  late final session = SessionStore(MemoryStore());
  late final api = ApiClient(
    baseUrl: 'https://api.test',
    session: session,
    client: MockClient((req) async {
      requests.add(req);
      final r = routes['${req.method} ${req.url.path}'];
      if (r == null) return http.Response(jsonEncode({'error': 'Not found'}), 404);
      return http.Response(jsonEncode(r.$2), r.$1, headers: {'content-type': 'application/json'});
    }),
  );
  late final auth = AuthController(api: api, session: session);
  late final customer = CustomerRepository(api);
}

/// CLAUDE.md §5.3: GHS 4,000 phone, Pay in 4, 40% down (GHS 1,600), then 3 × GHS 800.
/// Payment 2 is overdue with the 10% late fee (GHS 80), so GHS 880 is due now.
Map<String, dynamic> referencePlan({String secondStatus = 'overdue', double lateFee = 80}) => {
  'id': 7,
  'plan_id': 'PLN-0007',
  'product_name': 'Samsung Galaxy A55',
  'merchant_name': 'Accra Phones',
  'total_amount': 4000.0,
  'amount_paid': 1600.0,
  'amount_outstanding': 2400.0,
  'status': 'active',
  'payment_schedule': [
    {
      'id': 1,
      'installment_number': 1,
      'due_date': '2026-09-03T00:00:00',
      'amount': 1600.0,
      'late_fee': 0.0,
      'amount_due': 0.0,
      'part_paid': 0.0,
      'status': 'paid',
      'paid_date': '2026-09-03T10:00:00',
    },
    {
      'id': 2,
      'installment_number': 2,
      'due_date': '2026-10-01T00:00:00',
      'amount': 800.0,
      'late_fee': lateFee,
      'amount_due': 800.0 + lateFee,
      'part_paid': 0.0,
      'status': secondStatus,
      'paid_date': '',
    },
    {
      'id': 3,
      'installment_number': 3,
      'due_date': '2026-11-03T00:00:00',
      'amount': 800.0,
      'late_fee': 0.0,
      'amount_due': 800.0,
      'part_paid': 0.0,
      'status': 'pending',
      'paid_date': '',
    },
    {
      'id': 4,
      'installment_number': 4,
      'due_date': '2026-12-03T00:00:00',
      'amount': 800.0,
      'late_fee': 0.0,
      'amount_due': 800.0,
      'part_paid': 0.0,
      'status': 'pending',
      'paid_date': '',
    },
  ],
};

Map<String, dynamic> stats({bool eligible = true}) => {
  'customer_name': 'Ama Mensah',
  'credit': {
    'eligible': eligible,
    'tier': 'medium',
    'credit_limit': 5000.0,
    'available_limit': 2600.0,
    'reasons': eligible ? <String>[] : ['A payment is overdue'],
  },
};

/// The §5.3 phone on every standard plan, as `POST /customer/plan-options` returns it,
/// with a GHS 50 delivery fee paid with Payment 1 only (D3).
Map<String, dynamic> planOptionsFixture({bool eligible = true, double availableLimit = 5000}) {
  Map<String, dynamic> option(int n, double dp, double pct, List<double> rest) => {
    'n_payments': n,
    'label': n == 1 ? 'Pay in full' : 'Pay in $n',
    'due_now': dp + 50,
    'down_payment': dp,
    'down_payment_percentage': pct,
    'delivery_fee': 50.0,
    'installments': rest.length,
    'installment_amount': rest.isEmpty ? 0.0 : rest.first,
    'total_payable': 4050.0,
    'payment_schedule': [
      {
        'installment_number': 1,
        'amount': dp + 50,
        'principal': dp,
        'delivery_fee': 50.0,
        'due_date': '2026-10-03',
        'status': 'due_now',
        'description': 'Down payment',
      },
      for (final (i, a) in rest.indexed)
        {
          'installment_number': i + 2,
          'amount': a,
          'principal': a,
          'delivery_fee': 0.0,
          'due_date': '2026-${(11 + i).toString().padLeft(2, '0')}-03'.replaceFirst('2026-13', '2027-01'),
          'status': 'pending',
          'description': 'Instalment ${i + 1} of ${rest.length}',
        },
    ],
    'available': n == 1 || (eligible && 4000 <= availableLimit),
    'blocked_reason': n == 1
        ? null
        : !eligible
        ? 'A payment is overdue'
        : 4000 > availableLimit
        ? 'This is above your available limit'
        : null,
  };
  return {
    'product_id': 11,
    'quantity': 1,
    'product_price': 4000.0,
    'options': [
      option(1, 4000, 100, []),
      option(2, 2000, 50, [2000]),
      option(3, 2000, 50, [1000, 1000]),
      option(4, 1600, 40, [800, 800, 800]),
    ],
    'credit': {
      'eligible': eligible,
      'tier': 'medium',
      'credit_limit': 5000.0,
      'available_limit': availableLimit,
      'reasons': eligible ? <String>[] : ['A payment is overdue'],
    },
    'key_facts': {
      'late_fee_percentage': 10.0,
      'second_late_fee_percentage': 10.0,
      'second_late_fee_after_days': 31,
      'late_fee_cap_percentage': 25.0,
      'deferment_enabled': true,
      'deferment_fee_percentage': 10.0,
      'deferment_max_per_plan': 1,
      'deferment_months': 1,
      'dispute_resolution_days': 21,
      'terms_url': 'https://tabitalpay.com/elementor-page-3332/',
      'terms_version': '2026-10-03',
      'privacy_url': 'https://tabitalpay.com/privacy-policy/',
    },
  };
}

Map<String, dynamic> productFixture({int stock = 3}) => {
  'id': 11,
  'product_id': 'PRD11',
  'name': 'Samsung Galaxy A55',
  'description': '8 GB RAM, 256 GB',
  'category': 'Phones',
  'brand': 'Samsung',
  'price': 4000.0,
  'stock_quantity': stock,
  'main_image': '',
  'merchant_name': 'Accra Phones',
  'split_preview': {
    'plan': 'Pay in 4',
    'down_payment': 1600.0,
    'installments': 3,
    'installment_amount': 800.0,
    'delivery_fee': 50.0,
  },
};

Map<String, dynamic> identityFixture({String kyc = 'verified', String? check, int attemptsLeft = 3, bool configured = true}) => {
  'configured': configured,
  'required': true,
  'kyc_status': kyc,
  'check': check == null
      ? null
      : {
          'status': check,
          'reasons': check == 'blocked' ? ['Your selfie did not match your Ghana Card photo'] : [],
        },
  'attempts_used': 3 - attemptsLeft,
  'attempts_left': attemptsLeft,
};

/// What Paystack's initialize returns through our API.
Map<String, dynamic> checkoutFixture({String reference = 'TBP-7-2-abc', double amount = 880}) => {
  'reference': reference,
  'authorization_url': 'https://checkout.paystack.com/$reference',
  'access_code': 'ac',
  'amount': amount,
  'currency': 'GHS',
};

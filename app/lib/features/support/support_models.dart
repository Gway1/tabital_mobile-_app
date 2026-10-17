import '../../core/format.dart';

/// The reasons the server accepts for a dispute (`servicing.py` DISPUTE_REASONS), worded as the
/// web app's "Report a problem" form.
const disputeReasons = <(String, String)>[
  ('product_not_received', 'Item not received'),
  ('defective', 'Item is faulty or damaged'),
  ('not_as_described', 'Not as described'),
  ('unauthorized', "I didn't make this purchase"),
  ('other', 'Something else'),
];

/// A reported problem (`GET /customer/disputes`). While it's open the plan is paused: no late
/// fees, reminders or autopay.
class Dispute {
  Dispute({
    required this.id,
    required this.disputeRef,
    required this.reason,
    required this.status,
    required this.planId,
    required this.paused,
    required this.respondBy,
    required this.resolution,
  });

  final int id;
  final String disputeRef;
  final String reason;
  final String status; // open, under_review, escalated, resolved, closed
  final int? planId;
  final bool paused;
  final DateTime? respondBy;
  final String? resolution;

  bool get open => status == 'open' || status == 'under_review' || status == 'escalated';

  String get reasonLabel => disputeReasons.where((r) => r.$1 == reason).map((r) => r.$2).firstOrNull ?? reason;

  factory Dispute.fromJson(Map<String, dynamic> j) => Dispute(
    id: (j['id'] as num?)?.toInt() ?? 0,
    disputeRef: (j['dispute_id'] ?? '').toString(),
    reason: (j['reason'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    planId: (j['plan_id'] as num?)?.toInt(),
    paused: j['paused'] == true,
    respondBy: parseApiDate(j['respond_by']),
    resolution: j['resolution']?.toString(),
  );
}

/// An in-app message (`GET /notifications`): payment reminders and identity updates.
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.link,
    required this.actionText,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final String? link; // a web app path, e.g. /customer/instalments
  final String? actionText;
  final DateTime? createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    message: message,
    type: type,
    read: read ?? this.read,
    link: link,
    actionText: actionText,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: (j['id'] as num?)?.toInt() ?? 0,
    title: (j['title'] ?? '').toString(),
    message: (j['message'] ?? '').toString(),
    type: (j['type'] ?? '').toString(),
    read: j['read'] == true || j['is_read'] == true,
    link: (j['link'] as String?)?.trim().isEmpty ?? true ? null : j['link'] as String,
    actionText: (j['action_text'] as String?)?.trim().isEmpty ?? true ? null : j['action_text'] as String,
    createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
  );
}

/// The app screen for a web app link in a message, or null when the app has no such screen.
String? appRouteForLink(String? link) {
  if (link == null) return null;
  final uri = Uri.tryParse(link);
  if (uri == null) return null;
  final p = uri.path;
  final plan = RegExp(r'^/customer/(?:instalments|payments)/(\d+)').firstMatch(p);
  if (plan != null) return '/plans/${plan.group(1)}';
  final planQuery = uri.queryParameters['planId'];
  if (p.startsWith('/customer/make-payment') && planQuery != null && int.tryParse(planQuery) != null) {
    return '/plans/$planQuery/pay';
  }
  return switch (p) {
    '/customer/instalments' || '/customer/plans' || '/customer/make-payment' => '/plans',
    '/customer/orders' => '/account/orders',
    '/customer/verify-identity' || '/customer/profile' => '/account/identity',
    '/customer/shop' => '/shop',
    '/customer/dashboard' || '/customer' => '/home',
    _ => null,
  };
}

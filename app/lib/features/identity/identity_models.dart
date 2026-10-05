/// `GET /customer/identity`.
class IdentityStatus {
  IdentityStatus({
    required this.configured,
    required this.kycStatus,
    required this.checkStatus,
    required this.checkReasons,
    required this.attemptsLeft,
  });

  final bool configured; // Smile ID switched on
  final String kycStatus; // pending, verified, rejected
  final String? checkStatus; // started, submitted, clear, review, blocked, error
  final List<String> checkReasons;
  final int attemptsLeft;

  bool get verified => kycStatus == 'verified';
  bool get inProgress => checkStatus == 'submitted' || checkStatus == 'review';

  factory IdentityStatus.fromJson(Map<String, dynamic> j) {
    final check = j['check'];
    final c = check is Map ? check.cast<String, dynamic>() : const <String, dynamic>{};
    return IdentityStatus(
      configured: j['configured'] == true,
      kycStatus: (j['kyc_status'] ?? 'pending').toString(),
      checkStatus: c['status']?.toString(),
      checkReasons: ((c['reasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
      attemptsLeft: (j['attempts_left'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `POST /customer/identity/start`: a short-lived Smile ID token bound to the customer's Ghana
/// Card and names. The upload must send exactly these fields.
class IdentitySession {
  IdentitySession({
    required this.checkId,
    required this.token,
    required this.submitUrl,
    required this.fields,
    required this.consent,
  });
  final int checkId;
  final String token;
  final Uri submitUrl;
  final Map<String, String> fields;
  final Map<String, dynamic> consent;

  static IdentitySession? tryParse(Object? j) {
    if (j is! Map) return null;
    final url = Uri.tryParse((j['submit_url'] ?? '').toString());
    final token = j['token'];
    final fields = j['fields'];
    if (url == null || !url.isScheme('https') || token is! String || token.isEmpty || fields is! Map) return null;
    final consent = j['consent'];
    return IdentitySession(
      checkId: (j['check_id'] as num?)?.toInt() ?? 0,
      token: token,
      submitUrl: url,
      fields: fields.map((k, v) => MapEntry(k.toString(), v.toString())),
      consent: consent is Map ? consent.cast<String, dynamic>() : const {},
    );
  }
}

/// What Smile ID's camera captured: one selfie and the liveness frames, as base64 JPEGs.
class SelfieCapture {
  SelfieCapture({required this.selfie, required this.liveness});
  final String selfie;
  final List<String> liveness;
}

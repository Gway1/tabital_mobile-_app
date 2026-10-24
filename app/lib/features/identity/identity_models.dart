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

/// The details asked for at verification (`GET /customer/kyc/details` → `details`), U4. Values as
/// the server stores them; null when not given yet.
class KycDetails {
  KycDetails(this.values);
  final Map<String, Object?> values;

  String text(String key) {
    final v = values[key];
    if (v == null) return '';
    if (v is num) return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return v.toString();
  }

  bool? flag(String key) => values[key] is bool ? values[key] as bool : null;

  factory KycDetails.fromJson(Map<String, dynamic> j) => KycDetails(Map<String, Object?>.from(j));
}

/// One required document and its state, from the server's checklist (U5).
class KycDocument {
  KycDocument({
    required this.field,
    required this.label,
    required this.status,
    required this.rejectionReason,
    required this.canUpload,
  });
  final String field; // front_image, back_image, salary_certificate, bank_statement
  final String label;
  final String status; // missing, pending, verified, rejected
  final String? rejectionReason;
  final bool canUpload;

  factory KycDocument.fromJson(Map<String, dynamic> j) => KycDocument(
    field: (j['field'] ?? '').toString(),
    label: (j['label'] ?? '').toString(),
    status: (j['status'] ?? 'missing').toString(),
    rejectionReason: (j['rejection_reason'] as String?)?.trim().isEmpty ?? true ? null : j['rejection_reason'] as String,
    canUpload: j['can_upload'] == true,
  );
}

/// What's still needed for verification, exactly as the server works it out (U4/U5). The app
/// shows it and never decides it.
class KycChecklist {
  KycChecklist({
    required this.complete,
    required this.kycStatus,
    required this.detailsMissing,
    required this.documents,
    required this.documentsToUpload,
    required this.documentsInReview,
  });

  final bool complete;
  final String kycStatus;
  final List<String> detailsMissing;
  final List<KycDocument> documents;
  final List<String> documentsToUpload;
  final List<String> documentsInReview;

  /// The selfie check needs the Ghana Card number saved first (U3).
  bool get needsGhanaCard => detailsMissing.any((d) => d.toLowerCase().contains('ghana card'));

  static List<String> _strings(Object? v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();

  factory KycChecklist.fromJson(Map<String, dynamic> j) => KycChecklist(
    complete: j['complete'] == true,
    kycStatus: (j['kyc_status'] ?? 'pending').toString(),
    detailsMissing: _strings(j['details_missing']),
    documents: ((j['documents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => KycDocument.fromJson(e.cast<String, dynamic>()))
        .toList(),
    documentsToUpload: _strings(j['documents_to_upload']),
    documentsInReview: _strings(j['documents_in_review']),
  );
}

/// `GET`/`PUT /customer/kyc/details`.
class KycState {
  KycState({required this.details, required this.checklist, this.message});
  final KycDetails details;
  final KycChecklist checklist;
  final String? message;

  factory KycState.fromJson(Map<String, dynamic> j) => KycState(
    details: KycDetails.fromJson(j['details'] is Map ? (j['details'] as Map).cast<String, dynamic>() : const {}),
    checklist: KycChecklist.fromJson(j['checklist'] is Map ? (j['checklist'] as Map).cast<String, dynamic>() : const {}),
    message: j['message']?.toString(),
  );
}

/// A file the customer picked or photographed for a document.
class PickedDocument {
  PickedDocument({required this.name, required this.bytes});
  final String name;
  final List<int> bytes;
}

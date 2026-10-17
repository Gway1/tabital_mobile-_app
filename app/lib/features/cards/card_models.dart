/// A card saved by Paystack after a card payment (`GET /customer/payment-methods`).
class SavedCard {
  SavedCard({
    required this.id,
    required this.cardType,
    required this.bank,
    required this.last4,
    required this.expiry,
    required this.reusable,
    required this.autopay,
    required this.isDefault,
  });

  final int id;
  final String cardType; // e.g. "visa", "mastercard"
  final String bank;
  final String last4;
  final String? expiry; // "12/2027"
  final bool reusable; // Paystack lets us charge it again (needed for autopay)
  final bool autopay;
  final bool isDefault;

  String get name {
    final t = cardType.trim();
    return t.isEmpty ? 'Card' : t[0].toUpperCase() + t.substring(1).toLowerCase();
  }

  factory SavedCard.fromJson(Map<String, dynamic> j) => SavedCard(
    id: (j['id'] as num?)?.toInt() ?? 0,
    cardType: (j['card_type'] ?? '').toString(),
    bank: (j['bank'] ?? '').toString(),
    last4: (j['last4'] ?? '').toString(),
    expiry: (j['expiry'] as String?)?.trim().isEmpty ?? true ? null : j['expiry'] as String,
    reusable: j['reusable'] == true,
    autopay: j['autopay_enabled'] == true,
    isDefault: j['is_default'] == true,
  );
}

/// `GET /account/consents`: what the customer agreed to, and their marketing choice.
class Consents {
  Consents({required this.termsVersion, required this.privacyVersion, required this.acceptedAt, required this.marketing});
  final String? termsVersion;
  final String? privacyVersion;
  final DateTime? acceptedAt;
  final bool marketing;

  factory Consents.fromJson(Map<String, dynamic> j) => Consents(
    termsVersion: (j['terms_version_accepted'] as String?)?.trim().isEmpty ?? true ? null : j['terms_version_accepted'] as String,
    privacyVersion: (j['privacy_version_accepted'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['privacy_version_accepted'] as String,
    acceptedAt: DateTime.tryParse((j['accepted_at'] ?? '').toString()),
    marketing: j['marketing_consent'] == true,
  );
}

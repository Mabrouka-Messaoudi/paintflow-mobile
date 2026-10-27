enum ClientStatus {
  todo('todo', 'لم يبدأ'),
  progress('progress', 'قيد الإنجاز'),
  done('done', 'مكتمل');

  const ClientStatus(this.value, this.label);
  final String value;
  final String label;

  static ClientStatus fromValue(String? v) => ClientStatus.values
      .firstWhere((s) => s.value == v, orElse: () => ClientStatus.todo);
}

/// One row of the `client_summary` view: a client + their project totals.
class ClientSummary {
  const ClientSummary({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.address,
    required this.agreedAmount,
    required this.received,
    required this.remaining,
    required this.purchasesTotal,
    required this.status,
    required this.hasAccount,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? address;
  final double agreedAmount;
  final double received;
  final double remaining;
  final double purchasesTotal;
  final ClientStatus status;
  final bool hasAccount;
  final DateTime createdAt;

  /// Share of the agreed amount already received, between 0 and 1.
  double get progress =>
      agreedAmount <= 0 ? 0 : (received / agreedAmount).clamp(0, 1).toDouble();

  factory ClientSummary.fromMap(Map<String, dynamic> m) => ClientSummary(
        id: m['id'] as String,
        fullName: m['full_name'] as String,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        address: m['address'] as String?,
        agreedAmount: _num(m['agreed_amount']),
        received: _num(m['received']),
        remaining: _num(m['remaining']),
        purchasesTotal: _num(m['purchases_total']),
        status: ClientStatus.fromValue(m['status'] as String?),
        hasAccount: m['user_id'] != null,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.parse(v.toString());
  }
}

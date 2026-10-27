enum PaymentMethod {
  cash('cash', 'نقداً'),
  transfer('transfer', 'تحويل بنكي'),
  postal('postal', 'حوالة بريدية');

  const PaymentMethod(this.value, this.label);
  final String value;
  final String label;

  static PaymentMethod fromValue(String? v) => PaymentMethod.values
      .firstWhere((m) => m.value == v, orElse: () => PaymentMethod.cash);
}

class Payment {
  const Payment({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.method,
    this.note,
    required this.paidAt,
  });

  final String id;
  final String clientId;
  final double amount;
  final PaymentMethod method;
  final String? note;
  final DateTime paidAt;

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        method: PaymentMethod.fromValue(m['method'] as String?),
        note: m['note'] as String?,
        paidAt: DateTime.parse(m['paid_at'] as String),
      );
}

class Purchase {
  const Purchase({
    required this.id,
    required this.clientId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.shopName,
    this.receiptPath,
    this.itemPhotoPath,
    required this.purchasedAt,
  });

  final String id;
  final String clientId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double total;
  final String? shopName;
  final String? receiptPath;
  final String? itemPhotoPath;
  final DateTime purchasedAt;

  factory Purchase.fromMap(Map<String, dynamic> m) => Purchase(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        itemName: m['item_name'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        shopName: m['shop_name'] as String?,
        receiptPath: m['receipt_path'] as String?,
        itemPhotoPath: m['item_photo_path'] as String?,
        purchasedAt: DateTime.parse(m['purchased_at'] as String),
      );
}

class OrderItem {
  final String productId;
  final String article;
  final String qrCode;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.article,
    required this.qrCode,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<dynamic, dynamic> json) {
    return OrderItem(
      productId: json['product_id']?.toString() ?? 'unknown_product',
      article: json['article']?.toString() ?? 'N/A',
      qrCode: json['qr_code']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  // Helper for empty item in case of parsing errors
  factory OrderItem.empty() {
    return OrderItem(productId: '', article: '', qrCode: '', quantity: 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'article': article,
      'qr_code': qrCode,
      'quantity': quantity,
    };
  }
}

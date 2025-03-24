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
}

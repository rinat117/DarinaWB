import 'order_item.dart';

class Order {
  final String id;
  final String pickupPointId;
  final String orderDate;
  final String orderStatus;
  final List<OrderItem> items;
  final int totalPrice;

  Order({
    required this.id,
    required this.pickupPointId,
    required this.orderDate,
    required this.orderStatus,
    required this.items,
    required this.totalPrice,
  });
}

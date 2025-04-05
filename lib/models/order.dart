import 'order_item.dart';

class Order {
  final String id;
  final String pickupPointId;
  final String orderDate;
  final String orderStatus;
  final List<OrderItem> items;
  final int totalPrice;
  final String? bookingSlot; // Added booking slot (nullable string)

  Order({
    required this.id,
    required this.pickupPointId,
    required this.orderDate,
    required this.orderStatus,
    required this.items,
    required this.totalPrice,
    this.bookingSlot, // Added to constructor (optional)
  });

  // It's good practice to have a factory constructor from JSON
  factory Order.fromJson(String id, Map<dynamic, dynamic> json) {
    List<OrderItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List).map((itemData) {
        if (itemData is Map) {
          return OrderItem.fromJson(itemData);
        }
        return OrderItem.empty(); // Return empty or handle error
      }).toList();
    }

    return Order(
      id: id,
      pickupPointId: json['pickup_point_id']?.toString() ?? '',
      orderDate: json['order_date']?.toString() ?? 'N/A',
      orderStatus: json['order_status']?.toString() ?? 'unknown',
      items: parsedItems,
      totalPrice: (json['total_price'] as num?)?.toInt() ?? 0,
      bookingSlot: json['booking_slot'] as String?, // Parse booking slot
    );
  }

  // Optional: toJson method if needed
  Map<String, dynamic> toJson() {
    return {
      'pickup_point_id': pickupPointId,
      'order_date': orderDate,
      'order_status': orderStatus,
      'items': items.map((item) => item.toJson()).toList(),
      'total_price': totalPrice,
      'booking_slot': bookingSlot,
    };
  }
}

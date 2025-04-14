class BookingInfo {
  final String timeSlot; // Время HH:MM
  final String userPhone;
  final String orderId;
  final int timestamp;

  BookingInfo(
      {required this.timeSlot,
      required this.userPhone,
      required this.orderId,
      required this.timestamp});

  factory BookingInfo.fromJson(String timeSlot, Map<dynamic, dynamic> json) {
    return BookingInfo(
      timeSlot: timeSlot,
      userPhone: json['user_phone'] ?? '',
      orderId: json['order_id'] ?? '',
      timestamp: json['timestamp'] ?? 0,
    );
  }
}

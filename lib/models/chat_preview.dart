// lib/models/chat_preview.dart
class ChatPreview {
  final String customerId; // Phone number without '+'
  String customerName; // Can be updated later
  String lastMessage;
  int timestamp;

  ChatPreview({
    required this.customerId,
    required this.customerName,
    required this.lastMessage,
    required this.timestamp,
  });
}

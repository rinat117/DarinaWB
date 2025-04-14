// lib/models/chat_message.dart
class ChatMessage {
  final String key; // Firebase message key
  final String sender;
  final String message;
  final int timestamp;
  final String senderType;

  ChatMessage({
    required this.key,
    required this.sender,
    required this.message,
    required this.timestamp,
    required this.senderType,
  });

  factory ChatMessage.fromJson(String key, Map<dynamic, dynamic> json) {
    return ChatMessage(
      key: key,
      sender: json['sender']?.toString() ?? 'Unknown',
      message: json['message']?.toString() ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      senderType: json['sender_type']?.toString() ?? 'unknown',
    );
  }
}

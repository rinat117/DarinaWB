// lib/models/pickup_point.dart
class PickupPoint {
  final int id; // Или String id, если используешь pickup_point_1
  final String name;
  final String address;
  final String phone; // Можно оставить или использовать phoneFormatted
  final String workingHours;
  final double latitude;
  final double longitude;
  final double ratingValue; // <<<--- Добавили
  final int ratingCount; // <<<--- Добавили
  final List<String> imageUrls; // <<<--- Добавили для фото
  final String phoneFormatted; // <<<--- Добавили форматированный телефон

  PickupPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.workingHours,
    required this.latitude,
    required this.longitude,
    required this.ratingValue,
    required this.ratingCount,
    required this.imageUrls,
    required this.phoneFormatted,
  });

  // Фабричный конструктор для создания из Map (Firebase)
  factory PickupPoint.fromJson(String key, Map<dynamic, dynamic> json) {
    int parsedId = 0;
    try {
      parsedId = int.parse(key.replaceAll('pickup_point_', ''));
    } catch (e) {
      print("Error parsing id from key '$key': $e");
      // Можно присвоить дефолтный id или обработать иначе
    }

    // Функция для безопасного парсинга списка строк
    List<String> _parseStringList(dynamic list) {
      if (list is List) {
        return list
            .map((item) => item?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    return PickupPoint(
      id: parsedId, // Используем распарсенный ID
      name: json['name']?.toString() ?? 'Без названия',
      address: json['address']?.toString() ?? 'Адрес не указан',
      phone: json['phone']?.toString() ?? '',
      workingHours: json['working_hours']?.toString() ?? 'Часы не указаны',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      ratingValue:
          (json['rating_value'] as num?)?.toDouble() ?? 0.0, // Парсим рейтинг
      ratingCount:
          (json['rating_count'] as num?)?.toInt() ?? 0, // Парсим кол-во оценок
      imageUrls: _parseStringList(json['image_urls']), // Парсим фото
      phoneFormatted: json['phone_formatted']?.toString() ??
          '', // Парсим форматированный телефон
    );
  }
}

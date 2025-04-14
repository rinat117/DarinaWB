// lib/models/pickup_point_details.dart
class PickupPointDetails {
  final String id; // Firebase key (e.g., pickup_point_1)
  String name;
  String address;
  String description;
  String email;
  String employeeId;
  List<String> imageUrls;
  double latitude;
  double longitude;
  String phone;
  String phoneFormatted;
  int ratingCount;
  double ratingValue;
  List<String> services;
  String workingHours;

  PickupPointDetails({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.email,
    required this.employeeId,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.phoneFormatted,
    required this.ratingCount,
    required this.ratingValue,
    required this.services,
    required this.workingHours,
  });

  factory PickupPointDetails.fromJson(String id, Map<dynamic, dynamic> json) {
    // Функция для безопасного парсинга списка строк
    List<String> _parseStringList(dynamic list) {
      if (list is List) {
        // Преобразуем каждый элемент в строку, отфильтровывая null
        return list
            .map((item) => item?.toString())
            .whereType<String>()
            .toList();
      }
      return []; // Возвращаем пустой список, если это не список
    }

    return PickupPointDetails(
      id: id,
      name: json['name']?.toString() ?? 'Без названия',
      address: json['address']?.toString().replaceAll('"', '') ??
          'Нет адреса', // Убираем кавычки
      description: json['description']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      imageUrls: _parseStringList(json['image_urls']),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      phone: json['phone']?.toString() ?? '',
      phoneFormatted: json['phone_formatted']?.toString() ?? '',
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      ratingValue: (json['rating_value'] as num?)?.toDouble() ?? 0.0,
      services: _parseStringList(json['services']),
      workingHours: json['working_hours']?.toString() ?? '',
    );
  }

  // Метод для преобразования в Map для обновления в Firebase
  Map<String, dynamic> toUpdateMap() {
    // Включаем только те поля, которые хотим разрешить редактировать сотруднику
    return {
      'name': name,
      'address': address, // Осторожно с редактированием адреса
      'description': description,
      'phone_formatted': phoneFormatted, // Редактируем форматированный телефон
      'working_hours': workingHours,
      'services': services,
      // 'email': email, // Обычно email не меняют так просто
      // 'image_urls': imageUrls, // Редактирование фото - отдельная логика
      // Координаты, ID сотрудника, рейтинг - обычно не редактируются здесь
    };
  }
}

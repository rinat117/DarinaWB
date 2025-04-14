class Employee {
  final String id; // Ключ из Firebase (может быть employee_1 или safe_email)
  final String name;
  final String pickupPointId;
  final String email;
  final String role;

  Employee(
      {required this.id,
      required this.name,
      required this.pickupPointId,
      required this.email,
      required this.role});

  factory Employee.fromJson(String id, Map<dynamic, dynamic> json) {
    return Employee(
      id: id,
      name: json['name'] ?? 'Unknown',
      pickupPointId: json['pickup_point_id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'employee',
    );
  }
}

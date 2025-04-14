import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/employee.dart'; // Модель сотрудника
import '../../models/pickup_point_details.dart'; // Наша новая модель

class EmployeeSettingsTab extends StatefulWidget {
  const EmployeeSettingsTab({Key? key}) : super(key: key);

  @override
  State<EmployeeSettingsTab> createState() => _EmployeeSettingsTabState();
}

class _EmployeeSettingsTabState extends State<EmployeeSettingsTab> {
  bool _isLoading = true;
  bool _isSaving = false;
  Employee? _employee;
  PickupPointDetails? _pickupPointDetails;
  String _pickupPointId = '';

  // Контроллеры для полей
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneFormattedController = TextEditingController();
  final _workingHoursController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _currentServices = [];
  final _newServiceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneFormattedController.dispose();
    _workingHoursController.dispose();
    _descriptionController.dispose();
    _newServiceController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    await _loadEmployeeData(); // Загружаем сотрудника и его ID ПВЗ
    if (_pickupPointId.isNotEmpty) {
      await _loadPickupPointData(_pickupPointId); // Грузим данные ПВЗ
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEmployeeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      print("Error: Employee not logged in or email is null");
      return;
    }
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      final safeEmailKey =
          user.email!.replaceAll('.', '_').replaceAll('@', '_');
      final snapshot = await dbRef.child('users/employees/$safeEmailKey').get();

      if (mounted && snapshot.exists && snapshot.value != null) {
        final employeeData = snapshot.value as Map<dynamic, dynamic>;
        _employee = Employee.fromJson(snapshot.key!, employeeData);
        _pickupPointId = _employee!.pickupPointId; // Сохраняем ID ПВЗ
        print("Employee loaded, PickupPoint ID: $_pickupPointId");
      } else {
        print("Employee data not found for email: ${user.email}");
      }
    } catch (e) {
      print("Error loading employee data: $e");
    }
  }

  Future<void> _loadPickupPointData(String pickupPointId) async {
    if (pickupPointId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await dbRef.child('pickup_points/$pickupPointId').get();
      if (mounted && snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _pickupPointDetails = PickupPointDetails.fromJson(pickupPointId, data);

        // Инициализируем контроллеры
        _nameController.text = _pickupPointDetails!.name;
        _addressController.text = _pickupPointDetails!.address;
        _phoneFormattedController.text = _pickupPointDetails!.phoneFormatted;
        _workingHoursController.text = _pickupPointDetails!.workingHours;
        _descriptionController.text = _pickupPointDetails!.description;
        _currentServices =
            List<String>.from(_pickupPointDetails!.services); // Копируем список
      } else {
        print("Pickup point data not found for ID: $pickupPointId");
      }
    } catch (e) {
      print("Error loading pickup point data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка загрузки данных ПВЗ: $e")));
      }
    }
  }

  // --- Логика сохранения ---
  Future<void> _saveChanges() async {
    if (_pickupPointDetails == null || !mounted) return;
    setState(() => _isSaving = true);

    // Обновляем объект _pickupPointDetails из контроллеров
    _pickupPointDetails!.name = _nameController.text.trim();
    _pickupPointDetails!.address = _addressController.text.trim();
    _pickupPointDetails!.phoneFormatted = _phoneFormattedController.text.trim();
    _pickupPointDetails!.workingHours = _workingHoursController.text.trim();
    _pickupPointDetails!.description = _descriptionController.text.trim();
    _pickupPointDetails!.services = _currentServices; // Обновляем список услуг

    final dbRef = FirebaseDatabase.instance.ref();
    try {
      await dbRef.child('pickup_points/${_pickupPointDetails!.id}').update(
          _pickupPointDetails!.toUpdateMap()); // Обновляем только нужные поля

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Данные пункта выдачи сохранены!')),
        );
        // Можно перезагрузить данные для уверенности, но update должен быть виден
        // await _loadPickupPointData(_pickupPointId);
      }
    } catch (e) {
      print("Error saving pickup point data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения данных: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // --- Добавление услуги ---
  void _addService() {
    final newService = _newServiceController.text.trim();
    if (newService.isNotEmpty && !_currentServices.contains(newService)) {
      setState(() {
        _currentServices.add(newService);
      });
      _newServiceController.clear();
    }
  }

  // --- Удаление услуги ---
  void _removeService(String serviceToRemove) {
    setState(() {
      _currentServices.remove(serviceToRemove);
    });
  }

  // --- Выход ---
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // TODO: Вернуть на LoginScreen
    // Navigator.of(context).pushAndRemoveUntil(...)
    print("Employee signed out");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки ПВЗ'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: _signOut, // Используем функцию выхода
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pickupPointDetails == null
              ? Center(
                  child: Text('Не удалось загрузить данные пункта выдачи.'))
              : ListView(
                  // Используем ListView для скролла
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildTextField(_nameController, 'Название пункта выдачи'),
                    _buildTextField(_addressController, 'Адрес'),
                    _buildTextField(
                        _phoneFormattedController, 'Телефон (форматированный)'),
                    _buildTextField(
                        _workingHoursController, 'Часы работы (текст)'),
                    _buildTextField(_descriptionController, 'Описание',
                        maxLines: 3),

                    const SizedBox(height: 20),
                    Text('Услуги',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    // Поле для добавления услуги
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newServiceController,
                            decoration: InputDecoration(
                              hintText: 'Добавить услугу...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) =>
                                _addService(), // Добавляем по Enter
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: Colors.deepPurple),
                          onPressed: _addService,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Отображение текущих услуг с кнопками удаления
                    Wrap(
                      spacing: 8.0, // Горизонтальный отступ
                      runSpacing: 4.0, // Вертикальный отступ
                      children: _currentServices
                          .map((service) => Chip(
                                label: Text(service),
                                deleteIcon: Icon(Icons.cancel, size: 18),
                                onDeleted: () => _removeService(service),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: 30),
                    // Кнопка сохранения
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save_alt),
                        label: Text('Сохранить изменения'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                        ),
                        onPressed: _isSaving ? null : _saveChanges,
                      ),
                    ),
                    if (_isSaving) // Показываем индикатор во время сохранения
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 40), // Отступ снизу
                  ],
                ),
    );
  }

  // Вспомогательный метод для создания TextField
  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        maxLines: maxLines,
      ),
    );
  }
}

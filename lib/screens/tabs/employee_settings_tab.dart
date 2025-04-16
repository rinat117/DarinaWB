import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/employee.dart'; // Убедись, что путь верный
import '../../models/pickup_point_details.dart'; // Убедись, что путь верный
import '../login_screen.dart'; // <<<--- ДОБАВЛЕН НУЖНЫЙ ИМПОРТ

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
    } else {
      print("Could not load pickup point data because pickupPointId is empty.");
      // Можно показать сообщение об ошибке пользователю
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEmployeeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      print("SettingsTab Error: Employee not logged in or email is null");
      return;
    }
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      // Используем ключ, безопасный для Firebase (адаптируй!)
      final safeEmailKey =
          user.email!.replaceAll('.', '_').replaceAll('@', '_');
      final snapshot = await dbRef.child('users/employees/$safeEmailKey').get();

      if (mounted && snapshot.exists && snapshot.value != null) {
        final employeeData = snapshot.value as Map<dynamic, dynamic>;
        _employee = Employee.fromJson(snapshot.key!, employeeData);
        _pickupPointId = _employee!.pickupPointId; // Сохраняем ID ПВЗ
        print("SettingsTab Employee loaded, PickupPoint ID: $_pickupPointId");
      } else {
        print("SettingsTab Employee data not found for email: ${user.email}");
        _pickupPointId = ''; // Сбрасываем ID, если сотрудника не нашли
      }
    } catch (e) {
      print("SettingsTab Error loading employee data: $e");
      _pickupPointId = ''; // Сбрасываем ID при ошибке
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
        print("SettingsTab Pickup point data not found for ID: $pickupPointId");
        _pickupPointDetails = null; // Сбрасываем детали, если не найдены
      }
    } catch (e) {
      print("SettingsTab Error loading pickup point data: $e");
      _pickupPointDetails = null; // Сбрасываем детали при ошибке
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
      FocusScope.of(context).unfocus(); // Скрыть клавиатуру
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
    setState(() => _isLoading = true); // Показываем индикатор на время выхода
    try {
      await FirebaseAuth.instance.signOut();
      print("Employee signed out");
      // Возвращаемся на экран входа и удаляем все экраны позади
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) =>
                  const LoginScreen()), // <<<--- ТЕПЕРЬ LoginScreen НАЙДЕН
          (Route<dynamic> route) => false, // Удаляем все предыдущие маршруты
        );
      }
    } catch (e) {
      print("Error signing out: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка выхода: $e")),
        );
        setState(() => _isLoading = false); // Убираем индикатор при ошибке
      }
    }
    // Не нужно делать setState(_isLoading = false) здесь, так как мы уходим с экрана
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки ПВЗ'),
        backgroundColor: Colors.deepPurple,
        // Кнопку выхода можно оставить и здесь, ИЛИ ТОЛЬКО ВНИЗУ
        // actions: [
        //   IconButton(
        //      icon: Icon(Icons.logout),
        //      tooltip: 'Выйти',
        //      onPressed: _signOut,
        //   )
        // ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pickupPointDetails == null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Не удалось загрузить данные пункта выдачи. Проверьте ваше подключение или попробуйте войти снова.',
                    textAlign: TextAlign.center,
                  ),
                ))
              : GestureDetector(
                  // Добавляем GestureDetector для скрытия клавиатуры по тапу вне полей
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // --- Основная информация ---
                      Text('Основная информация',
                          style: Theme.of(context).textTheme.titleLarge),
                      _buildTextField(
                          _nameController, 'Название пункта выдачи'),
                      _buildTextField(_addressController, 'Адрес'),
                      _buildTextField(
                          _phoneFormattedController, 'Телефон (для клиента)'),
                      _buildTextField(
                          _workingHoursController, 'Часы работы (текст)'),
                      _buildTextField(
                          _descriptionController, 'Краткое описание',
                          maxLines: 3),
                      const Divider(height: 30),

                      // --- Услуги ---
                      Text('Услуги',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              onSubmitted: (_) => _addService(),
                            ),
                          ),
                          SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 4.0), // Выровнять кнопку по вертикали
                            child: IconButton(
                              icon: Icon(Icons.add_circle,
                                  color: Colors.deepPurple, size: 30),
                              onPressed: _addService,
                              tooltip: 'Добавить услугу',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _currentServices.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Услуги пока не добавлены.',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : Wrap(
                              spacing: 8.0,
                              runSpacing: 0.0, // Уменьшаем вертикальный отступ
                              children: _currentServices
                                  .map((service) => Chip(
                                        label: Text(service),
                                        deleteIcon:
                                            Icon(Icons.cancel, size: 18),
                                        onDeleted: () =>
                                            _removeService(service),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 0), // Уменьшаем padding
                                        labelPadding: EdgeInsets.only(
                                            left: 8), // Отступ слева для текста
                                      ))
                                  .toList(),
                            ),
                      const Divider(height: 30),

                      // --- Кнопка сохранения ---
                      Center(
                        child: ElevatedButton.icon(
                          icon: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.save_alt),
                          label: Text(_isSaving
                              ? 'Сохранение...'
                              : 'Сохранить изменения'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSaving
                                ? Colors.grey
                                : Colors.green, // Цвет кнопки при сохранении
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          onPressed: _isSaving
                              ? null
                              : _saveChanges, // Блокируем кнопку во время сохранения
                        ),
                      ),
                      const SizedBox(height: 40), // Отступ

                      // --- Кнопка Выхода ---
                      Center(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.logout, color: Colors.red),
                          label: Text('Выйти из аккаунта',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side:
                                BorderSide(color: Colors.red.withOpacity(0.5)),
                          ),
                          onPressed: _signOut,
                        ),
                      ),
                      const SizedBox(height: 20), // Нижний отступ
                    ],
                  ),
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
          alignLabelWithHint: true, // Для многострочных полей
        ),
        maxLines: maxLines,
      ),
    );
  }
}

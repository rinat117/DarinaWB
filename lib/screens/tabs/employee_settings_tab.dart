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

  // Цвета
  final Color primaryColor = Color(0xFF7F00FF);
  final Color cardColor = Colors.white;
  final Color backgroundColor = Colors.grey[100]!;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    /* ... очистка контроллеров ... */
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

  // --- Вспомогательная функция для показа SnackBar ошибок ---
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor, // Светлый фон
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: primaryColor, // Фирменный AppBar
        elevation: 1.0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _employee == null || _pickupPointDetails == null // Проверка на null
              ? _buildErrorState() // Показываем состояние ошибки
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    // Используем ListView для скролла
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // --- Блок: Информация о Сотруднике ---
                      _buildInfoCard(
                          icon: Icons.person_pin_circle_outlined,
                          title: 'Сотрудник',
                          children: [
                            _buildInfoRow(
                                'Имя:',
                                _employee!
                                    .name), // Используем ! т.к. проверили на null
                            _buildInfoRow('Email:', _employee!.email),
                          ]),
                      const SizedBox(height: 16),

                      // --- Блок: Управление Пунктом Выдачи ---
                      _buildInfoCard(
                          icon: Icons.storefront_outlined,
                          title: 'Пункт выдачи',
                          children: [
                            _buildTextField(
                                _nameController, 'Название', Icons.title),
                            _buildTextField(_addressController, 'Адрес',
                                Icons.location_on_outlined),
                            _buildTextField(_phoneFormattedController,
                                'Телефон (для клиента)', Icons.phone_outlined),
                            _buildTextField(_workingHoursController,
                                'Часы работы (текст)', Icons.access_time),
                            _buildTextField(_descriptionController,
                                'Краткое описание', Icons.description_outlined,
                                maxLines: 3),
                            const SizedBox(height: 16),
                            // Управление услугами
                            Text('Услуги:',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            _buildServiceManager(), // Выносим управление услугами в отдельный виджет
                            const SizedBox(height: 16),
                            // Кнопка Сохранить ПВЗ
                            Center(
                              child: ElevatedButton.icon(
                                icon: _isSaving
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Icon(Icons.save_alt_outlined, size: 20),
                                label: Text(_isSaving
                                    ? 'Сохранение...'
                                    : 'Сохранить данные ПВЗ'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSaving
                                      ? Colors.grey
                                      : Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _isSaving ? null : _saveChanges,
                              ),
                            ),
                          ]),
                      const SizedBox(height: 16),

                      // --- Блок: Управление Аккаунтом ---
                      _buildInfoCard(
                          icon: Icons.manage_accounts_outlined,
                          title: 'Аккаунт',
                          children: [
                            // Кнопка Выхода
                            Center(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.logout,
                                    color: Colors.red.shade400),
                                label: Text('Выйти из аккаунта',
                                    style:
                                        TextStyle(color: Colors.red.shade400)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Colors.red.withOpacity(0.4)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 24),
                                ),
                                onPressed: _signOut,
                              ),
                            ),
                          ]),
                      const SizedBox(height: 20), // Нижний отступ
                    ],
                  ),
                ),
    );
  }

  // --- Виджет для состояния ошибки ---
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 50),
            SizedBox(height: 16),
            Text(
                'Не удалось загрузить данные сотрудника или пункта выдачи. Проверьте подключение или попробуйте войти снова.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Попробовать снова'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _loadInitialData,
            )
          ],
        ),
      ),
    );
  }

  // --- Виджет для Информационной Карточки/Секции ---
  Widget _buildInfoCard(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Card(
      elevation: 2.0,
      color: cardColor,
      margin: EdgeInsets.zero, // Убираем внешние отступы Card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // Заголовок с иконкой
              children: [
                Icon(icon, color: primaryColor, size: 22),
                const SizedBox(width: 10),
                Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
            const Divider(height: 20, thickness: 0.5), // Разделитель
            ...children, // Вставляем дочерние виджеты
          ],
        ),
      ),
    );
  }

  // --- Виджет для строки Информации (нередактируемой) ---
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14))), // Фиксированная ширина метки
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87))),
        ],
      ),
    );
  }

  // --- Виджет для Поля Ввода ---
  Widget _buildTextField(
      TextEditingController controller, String label, IconData? icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.grey[500], size: 20)
              : null, // Иконка слева
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryColor, width: 1.5)),
          alignLabelWithHint: maxLines > 1,
          contentPadding: EdgeInsets.symmetric(
              vertical: 12, horizontal: 12), // Паддинги внутри поля
        ),
        maxLines: maxLines,
        style: TextStyle(fontSize: 14), // Размер текста в поле
      ),
    );
  }

  // --- Виджет для Управления Услугами ---
  Widget _buildServiceManager() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Поле и кнопка добавления
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newServiceController,
                decoration: InputDecoration(
                  hintText: 'Новая услуга...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true, // Компактное поле
                ),
                style: TextStyle(fontSize: 13),
                onSubmitted: (_) => _addService(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: primaryColor),
              tooltip: 'Добавить услугу',
              visualDensity: VisualDensity.compact,
              onPressed: _addService,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Список текущих услуг в виде Chip
        _currentServices.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Услуги не добавлены.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              )
            : Wrap(
                // Используем Wrap для переноса Chip'ов
                spacing: 6.0, // Горизонтальный отступ
                runSpacing: 0.0, // Вертикальный отступ
                children: _currentServices
                    .map((service) => Chip(
                          label: Text(service, style: TextStyle(fontSize: 12)),
                          deleteIcon: Icon(Icons.cancel_outlined,
                              size: 16), // Иконка удаления
                          onDeleted: () => _removeService(service),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          backgroundColor: Colors.grey[200], // Фон Chip'а
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(6)), // Скругление
                          side: BorderSide.none, // Без рамки
                        ))
                    .toList(),
              ),
      ],
    );
  }
} // Конец класса _EmployeeSettingsTabState

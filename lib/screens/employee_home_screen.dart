import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // <<<--- Добавить импорт
import 'tabs/employee_home_tab.dart';
import 'tabs/employee_chat_tab.dart';
import 'tabs/employee_settings_tab.dart';
// import 'tabs/employee_orders_tab.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _selectedIndex = 0;
  String? _pickupPointId; // <<<--- Добавляем состояние для ID ПВЗ
  bool _isLoadingId = true; // <<<--- Флаг загрузки ID

  late List<Widget> _widgetOptions; // Оставляем late

  @override
  void initState() {
    super.initState();
    _loadEmployeePickupPointId(); // <<<--- Загружаем ID при инициализации
  }

  Future<void> _loadEmployeePickupPointId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      print(
          "EmployeeHomeScreen Error: Cannot load pickupPointId, user not logged in.");
      if (mounted) setState(() => _isLoadingId = false);
      // Возможно, здесь нужен выход или показ ошибки
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref();
    final safeEmailKey = user.email!.replaceAll('.', '_').replaceAll('@', '_');
    print("EmployeeHomeScreen: Loading pickupPointId for key: $safeEmailKey");

    try {
      final snapshot = await dbRef
          .child('users/employees/$safeEmailKey/pickup_point_id')
          .get();
      if (mounted) {
        if (snapshot.exists && snapshot.value != null) {
          setState(() {
            _pickupPointId = snapshot.value as String?;
            _isLoadingId = false;
            _initializeTabs(); // <<<--- Инициализируем вкладки ПОСЛЕ загрузки ID
          });
          print("EmployeeHomeScreen: Loaded pickupPointId: $_pickupPointId");
        } else {
          print(
              "EmployeeHomeScreen Error: pickup_point_id not found for employee $safeEmailKey");
          setState(() => _isLoadingId = false);
          // Обработка случая, когда ID не найден
        }
      }
    } catch (e) {
      print("EmployeeHomeScreen Error loading pickupPointId: $e");
      if (mounted) setState(() => _isLoadingId = false);
    }
  }

  // Инициализация списка вкладок (теперь зависит от _pickupPointId)
  void _initializeTabs() {
    _widgetOptions = <Widget>[
      const EmployeeHomeTab(), // 0: Вкладка "Сегодня"
      const Center(child: Text('Заказы (В разработке)')), // 1: Заглушка Заказы
      // Передаем ID во вкладку чата, если он загружен
      _pickupPointId != null && _pickupPointId!.isNotEmpty
          ? EmployeeChatTab(pickupPointId: _pickupPointId!)
          : const Center(
              child: Text('Ошибка загрузки чата (нет ID ПВЗ)')), // 2: Чат
      const EmployeeSettingsTab(), // 3: Вкладка "Настройки"
    ];
  }

  void _onItemTapped(int index) {
    // Не позволяем переключаться, если ID еще не загружен (для вкладок, которым он нужен)
    if (_isLoadingId && (index == 2)) {
      // Проверяем для чата (индекс 2)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Загрузка данных...")));
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Показываем загрузку, пока ID ПВЗ не загружен
    if (_isLoadingId) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Показываем ошибку, если ID не загрузился
    if (_pickupPointId == null || _pickupPointId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Ошибка")),
        body: Center(
            child: Text(
                "Не удалось загрузить данные сотрудника.\nПожалуйста, попробуйте перезайти.")),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions, // Используем инициализированный список
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            activeIcon: Icon(Icons.today),
            label: 'Сегодня',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Заказы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 8.0,
      ),
    );
  }
}

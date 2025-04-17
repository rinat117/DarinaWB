// lib/screens/employee_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// Импорты вкладок
import 'tabs/employee_home_tab.dart'; // Вкладка "Сегодня"
import 'tabs/employee_chat_tab.dart'; // Вкладка "Чат"
import 'tabs/employee_settings_tab.dart'; // Вкладка "Настройки"

class EmployeeHomeScreen extends StatefulWidget {
  // Этот экран теперь не принимает аргументов,
  // так как ID ПВЗ загружается внутри initState
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _selectedIndex = 0; // Индекс текущей выбранной вкладки
  String? _pickupPointId; // ID пункта выдачи, загружаемый из базы
  bool _isLoadingId = true; // Флаг загрузки ID ПВЗ
  List<Widget> _widgetOptions =
      []; // Список виджетов для каждой вкладки (инициализируется позже)

  // --- Списки для BottomNavigationBar (теперь 3 элемента) ---
  final List<IconData> _icons = [
    Icons.today_outlined, // Иконка "Сегодня"
    Icons.chat_bubble_outline, // Иконка "Чат"
    Icons.settings_outlined, // Иконка "Настройки"
  ];
  final List<IconData> _activeIcons = [
    Icons.today, // Активная иконка "Сегодня"
    Icons.chat_bubble, // Активная иконка "Чат"
    Icons.settings, // Активная иконка "Настройки"
  ];
  final List<String> _labels = [
    'Сегодня',
    'Чат',
    'Настройки',
  ];
  // --- Конец списков для BottomNavigationBar ---

  @override
  void initState() {
    super.initState();
    // Запускаем загрузку ID ПВЗ при инициализации экрана
    _loadEmployeePickupPointId();
  }

  // --- Функция Загрузки ID Пункта Выдачи Сотрудника ---
  Future<void> _loadEmployeePickupPointId() async {
    if (!mounted) return; // Проверка, что виджет еще существует

    final user = FirebaseAuth.instance.currentUser;
    // Проверяем, что пользователь вошел и у него есть email
    if (user == null || user.email == null) {
      print(
          "EmployeeHomeScreen Error: Cannot load pickupPointId, user not logged in or email is null.");
      if (mounted) setState(() => _isLoadingId = false);
      // В реальном приложении здесь может быть выход на экран логина
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref();
    // Создаем безопасный ключ из email для Firebase
    final safeEmailKey = user.email!.replaceAll('.', '_').replaceAll('@', '_');
    print("EmployeeHomeScreen: Loading pickupPointId for key: $safeEmailKey");

    try {
      // Запрашиваем ID ПВЗ из базы данных
      final snapshot = await dbRef
          .child('users/employees/$safeEmailKey/pickup_point_id')
          .get();
      if (mounted) {
        // Проверяем еще раз перед обновлением состояния
        if (snapshot.exists && snapshot.value != null) {
          // Если данные найдены, сохраняем ID и инициализируем вкладки
          setState(() {
            _pickupPointId = snapshot.value as String?;
            _initializeTabs(); // Инициализируем список вкладок
            _isLoadingId = false; // Завершаем загрузку
          });
          print("EmployeeHomeScreen: Loaded pickupPointId: $_pickupPointId");
        } else {
          // Если ID не найден в базе
          print(
              "EmployeeHomeScreen Error: pickup_point_id not found for employee $safeEmailKey");
          setState(() {
            _pickupPointId = null; // Устанавливаем ID в null
            _initializeTabs(); // Инициализируем вкладки (Чат покажет ошибку)
            _isLoadingId = false; // Завершаем загрузку
          });
          // Можно показать SnackBar с ошибкой
          _showErrorSnackBar("Не удалось определить пункт выдачи сотрудника.");
        }
      }
    } catch (e) {
      // Обработка ошибок при запросе к базе данных
      print("EmployeeHomeScreen Error loading pickupPointId: $e");
      if (mounted) {
        setState(() {
          _pickupPointId = null;
          _initializeTabs();
          _isLoadingId = false;
        });
        _showErrorSnackBar("Ошибка загрузки данных сотрудника.");
      }
    }
  }
  // --- Конец Функции Загрузки ID ---

  // --- Функция Инициализации Списка Вкладок ---
  void _initializeTabs() {
    // Проверяем, что ID загружен перед созданием вкладки Чата
    final bool isChatAvailable =
        _pickupPointId != null && _pickupPointId!.isNotEmpty;

    // Создаем список виджетов для вкладок
    _widgetOptions = <Widget>[
      const EmployeeHomeTab(), // 0: Вкладка "Сегодня"
      // 1: Вкладка "Чат" - показываем чат или заглушку/ошибку
      isChatAvailable
          ? EmployeeChatTab(pickupPointId: _pickupPointId!)
          : const Center(child: Text('Ошибка: Чат недоступен (нет ID ПВЗ)')),
      const EmployeeSettingsTab(), // 2: Вкладка "Настройки"
    ];
  }
  // --- Конец Функции Инициализации Вкладок ---

  // --- Функция Обработки Нажатия на Вкладку в BottomNavigationBar ---
  void _onItemTapped(int index) {
    // Проверяем, загружен ли ID, если пользователь пытается открыть Чат (индекс 1)
    if (_isLoadingId && (index == 1)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Загрузка данных...")));
      return; // Не переключаем вкладку, пока ID не загружен
    }

    // Проверяем валидность индекса перед переключением
    if (index >= 0 && index < _widgetOptions.length) {
      setState(() {
        _selectedIndex = index;
      }); // Обновляем выбранный индекс
    } else {
      print("Error: Invalid bottom navigation index tapped: $index");
    }
  }
  // --- Конец Обработки Нажатия ---

  // --- Вспомогательная Функция для SnackBar Ошибок ---
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }
  // --- Конец Вспомогательной Функции ---

  // --- Основной Метод Build ---
  @override
  Widget build(BuildContext context) {
    // Показываем индикатор загрузки, пока ID ПВЗ не загружен
    if (_isLoadingId) {
      return const Scaffold(
        // Можно добавить AppBar с заголовком "Загрузка..."
        body:
            Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }

    // Показываем ошибку, если ID не загрузился или вкладки не инициализировались
    // (Например, если у сотрудника не прописан pickup_point_id в базе)
    if (_widgetOptions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Ошибка Загрузки")),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "Не удалось загрузить основные компоненты приложения.\nПожалуйста, проверьте данные сотрудника или обратитесь к администратору.",
            textAlign: TextAlign.center,
          ),
        )),
      );
    }

    // Основной Scaffold с вкладками
    return Scaffold(
      // Используем IndexedStack для сохранения состояния каждой вкладки
      // при переключении между ними
      body: IndexedStack(
        index: _selectedIndex, // Показываем виджет по выбранному индексу
        children: _widgetOptions, // Список виджетов вкладок
      ),
      // Нижняя панель навигации
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Всегда показывать метки
        // Создаем элементы навигации на основе списков иконок и меток
        items: List.generate(
            _labels.length,
            (index) => BottomNavigationBarItem(
                  icon: Icon(_icons[index]), // Обычная иконка
                  activeIcon: Icon(
                      _activeIcons[index]), // Активная иконка (когда выбрано)
                  label: _labels[index], // Текстовая метка
                )),
        currentIndex: _selectedIndex, // Текущий выбранный элемент
        selectedItemColor: Colors.deepPurple, // Цвет выбранного элемента
        unselectedItemColor: Colors.grey[600], // Цвет невыбранного элемента
        onTap: _onItemTapped, // Функция, вызываемая при нажатии
        showUnselectedLabels: true, // Показывать метки для невыбранных
        backgroundColor: Colors.white, // Фон панели
        elevation: 8.0, // Тень панели
      ),
    );
  }
  // --- Конец Метода Build ---
} // --- Конец Класса _EmployeeHomeScreenState ---

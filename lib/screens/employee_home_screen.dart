import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Импортируем, если понадобится передавать User
// Импорты для вкладок
import 'tabs/employee_home_tab.dart'; // Вкладка "Сегодня"
import 'tabs/employee_chat_tab.dart'; // Вкладка "Чат" (пока может быть заглушкой)
import 'tabs/employee_settings_tab.dart'; // Вкладка "Настройки"
// import 'tabs/employee_orders_tab.dart'; // Закомментировано, пока не создана

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _selectedIndex = 0; // Индекс выбранной вкладки

  // Список виджетов для каждой вкладки BottomNavigationBar
  // Важно: порядок должен соответствовать порядку иконок в BottomNavigationBar
  static final List<Widget> _widgetOptions = <Widget>[
    const EmployeeHomeTab(), // 0: Вкладка "Сегодня"
    const Center(
        child:
            Text('Заказы (В разработке)')), // 1: Заглушка для вкладки "Заказы"
    // TODO: Заменить заглушку на EmployeeChatTab, когда будет готова логика получения pickupPointId для нее
    // EmployeeChatTab(pickupPointId: 'ID_ПУНКТА'), // Пример
    const Center(
        child: Text('Чат (В разработке)')), // 2: Заглушка для вкладки "Чат"
    const EmployeeSettingsTab(), // 3: Вкладка "Настройки"
  ];

  // Обработчик нажатия на элемент BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Обновляем выбранный индекс
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar убран отсюда, так как каждая вкладка теперь имеет свой AppBar
      body: IndexedStack(
        // IndexedStack сохраняет состояние вкладок при переключении
        index: _selectedIndex,
        children: _widgetOptions, // Отображаем виджет выбранной вкладки
      ),
      // Нижний навигационный бар
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Отображать названия всех вкладок
        items: const <BottomNavigationBarItem>[
          // Элемент для вкладки "Сегодня"
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined), // Иконка неактивной вкладки
            activeIcon: Icon(Icons.today), // Иконка активной вкладки
            label: 'Сегодня', // Название вкладки
          ),
          // Элемент для вкладки "Заказы"
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Заказы',
          ),
          // Элемент для вкладки "Чат"
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Чат',
          ),
          // Элемент для вкладки "Настройки"
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
        currentIndex: _selectedIndex, // Индекс текущей активной вкладки
        selectedItemColor:
            Colors.deepPurple, // Цвет иконки и текста активной вкладки
        unselectedItemColor: Colors.grey[600], // Цвет неактивных элементов
        onTap: _onItemTapped, // Функция, вызываемая при нажатии на вкладку
        showUnselectedLabels: true, // Показывать названия неактивных вкладок
        backgroundColor: Colors.white, // Цвет фона бара
        elevation: 8.0, // Тень под баром
      ),
    );
  }
}

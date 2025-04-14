import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tabs/home_tab.dart';
import 'tabs/chat_tab.dart';
import 'tabs/profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  final String pickupPointId;
  final User user;

  const DashboardScreen({
    Key? key,
    required this.pickupPointId,
    required this.user,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeTab(pickupPointId: widget.pickupPointId),
      ChatTab(
          pickupPointId: widget.pickupPointId,
          user: widget.user), // <<<--- ПЕРЕДАЕМ USER
      ProfileTab(user: widget.user, pickupPointId: widget.pickupPointId),
      // Добавь четвертую вкладку, если она нужна для клиента, например "Информация"
      // const Center(child: Text('Информация')),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        // Используем IndexedStack
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Чтобы лейблы не пропадали
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Моё',
          ),
          // Если нужна 4я вкладка для клиента:
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.info_outline),
          //   label: 'Инфо',
          // ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

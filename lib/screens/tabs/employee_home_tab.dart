import 'package:flutter/material.dart';

class EmployeeHomeTab extends StatelessWidget {
  const EmployeeHomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WB Пункт (Сотрудника)'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Center(
        child: Text('Главная страница сотрудника'),
      ),
    );
  }
}

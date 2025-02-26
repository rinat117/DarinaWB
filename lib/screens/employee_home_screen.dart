import 'package:flutter/material.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WB Пункт (Сотрудник)'), // "WB Point (Employee)"
        backgroundColor: Colors.green, // Just to differentiate it
      ),
      body: Center(
        child: Text('Главная страница сотрудника',
            style: TextStyle(fontSize: 20)), // "Employee Home Page"
      ),
    );
  }
}

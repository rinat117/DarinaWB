// lib/screens/pickup_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pickup_point.dart'; // <<<--- Используем ОБНОВЛЕННУЮ модель
import '../widgets/pickup_point_card.dart'; // <<<--- Импортируем ОБНОВЛЕННЫЙ виджет
import 'dashboard_screen.dart';

class PickupSelectionScreen extends StatefulWidget {
  const PickupSelectionScreen({super.key});

  @override
  State<PickupSelectionScreen> createState() => _PickupSelectionScreenState();
}

class _PickupSelectionScreenState extends State<PickupSelectionScreen> {
  List<PickupPoint> _pickupPoints = [];
  bool _isLoading = true;
  String _error = '';

  final Color colorDarkPurple = const Color(0xFF481173);
  final Color colorMidPurple = const Color(0xFF990099);

  @override
  void initState() {
    super.initState();
    _loadPickupPoints();
  }

  Future<void> _loadPickupPoints() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final databaseReference = FirebaseDatabase.instance.ref();
      // Получаем данные из узла 'pickup_points'
      final snapshot = await databaseReference.child('pickup_points').get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<PickupPoint> loadedPoints = [];

        // Используем фабричный конструктор из обновленной модели
        data.forEach((key, value) {
          if (value is Map && key is String) {
            // Убедимся что ключ - строка
            try {
              loadedPoints.add(PickupPoint.fromJson(key, value));
            } catch (e) {
              print(
                  "Error parsing pickup point with key $key: $e. Data: $value");
            }
          } else {
            print("Skipping invalid data format for key $key: $value");
          }
        });

        if (mounted) {
          setState(() {
            // Сортируем по ID или по названию
            loadedPoints.sort(
                (a, b) => a.name.compareTo(b.name)); // Сортировка по имени
            _pickupPoints = loadedPoints;
            _isLoading = false;
          });
        }
      } else {
        print("No pickup points found in the database");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Пункты выдачи не найдены.';
            _pickupPoints = [];
          });
        }
      }
    } catch (e) {
      print("Error loading pickup points: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Произошла ошибка загрузки.';
          _pickupPoints = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors
          .grey[100], // Светло-серый фон для контраста с белыми карточками
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorDarkPurple, colorMidPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Выберите пункт выдачи',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF990099)));
    }
    if (_error.isNotEmpty) {
      // (Виджет ошибки остается без изменений)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 50),
              SizedBox(height: 16),
              Text(_error,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Попробовать снова'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorMidPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadPickupPoints,
              )
            ],
          ),
        ),
      );
    }
    if (_pickupPoints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Доступных пунктов выдачи нет.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
      );
    }

    // Используем ListView.separated для добавления отступов между карточками
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          vertical: 16.0), // Отступы сверху/снизу списка
      itemCount: _pickupPoints.length,
      itemBuilder: (context, index) {
        final pickupPoint = _pickupPoints[index];
        // Используем наш ОБНОВЛЕННЫЙ виджет PickupPointCard
        return PickupPointCard(
          pickupPoint: pickupPoint,
          onTap: () {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    // ID ПВЗ должен быть строкой из ключа Firebase
                    pickupPointId: 'pickup_point_${pickupPoint.id}',
                    user: currentUser,
                  ),
                ),
              );
            } else {
              print(
                  "Error: Current user is null. Cannot navigate to Dashboard.");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Ошибка: Не удалось получить данные пользователя.')),
              );
            }
          },
        );
      },
      separatorBuilder: (context, index) => const SizedBox(
          height: 0), // Убираем стандартный разделитель, т.к. margin в карточке
    );
  }
}

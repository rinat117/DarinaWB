import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../widgets/pickup_point_card.dart'; // Импорт карточки
import 'home_screen.dart';

class PickupPoint {
  final String id;
  final String name;
  final String address;

  PickupPoint({required this.id, required this.name, required this.address});
}

class PickupSelectionScreen extends StatefulWidget {
  const PickupSelectionScreen({super.key});

  @override
  State<PickupSelectionScreen> createState() => _PickupSelectionScreenState();
}

class _PickupSelectionScreenState extends State<PickupSelectionScreen> {
  List<PickupPoint> _pickupPoints = [];
  List<PickupPoint> _filteredPickupPoints = []; // Для поиска
  bool _loading = true;
  String _searchQuery = ''; // Для хранения поискового запроса

  @override
  void initState() {
    super.initState();
    _loadPickupPoints();
  }

  Future<void> _loadPickupPoints() async {
    final databaseReference = FirebaseDatabase.instance.ref();
    final pickupPointsSnapshot =
        await databaseReference.child('pickup_points').get();

    if (pickupPointsSnapshot.exists) {
      final pickupPointsMap =
          pickupPointsSnapshot.value as Map<dynamic, dynamic>;
      final List<PickupPoint> loadedPickupPoints = [];
      pickupPointsMap.forEach((key, value) {
        final pickupPointData = value as Map<dynamic, dynamic>;
        loadedPickupPoints.add(PickupPoint(
          id: key,
          name: pickupPointData['name'] as String,
          address: pickupPointData['address'] as String,
        ));
      });
      setState(() {
        _pickupPoints = loadedPickupPoints;
        _filteredPickupPoints = loadedPickupPoints; // Изначально все пункты
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
      print('No pickup points found');
    }
  }

  void _filterPickupPoints(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredPickupPoints =
            _pickupPoints; // Если запрос пустой - показываем все
      } else {
        _filteredPickupPoints = _pickupPoints
            .where((point) =>
                point.name.toLowerCase().contains(query.toLowerCase()) ||
                point.address.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите пункт выдачи'),
        backgroundColor: Colors.deepPurple, // Цвет AppBar
      ),
      backgroundColor: Colors.grey[100], // Светлый фон экрана
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pickupPoints.isEmpty
              ? const Center(child: Text('Нет доступных пунктов выдачи'))
              : Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 20.0), // Отступы больше
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 16.0), // Отступ под поиском
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Поиск пункта выдачи', // Используем hintText
                            prefixIcon: const Icon(Icons.search,
                                color: Colors
                                    .deepPurple), // Иконка поиска фирменного цвета
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  25.0), // Больше скругление поля поиска
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              // Цвет рамки при фокусе
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: const BorderSide(
                                  color: Colors.deepPurple, width: 2.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 15.0, horizontal: 20.0),
                            filled: true,
                            fillColor: Colors.white, // Белый фон поля поиска
                          ),
                          onChanged: _filterPickupPoints,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty && _filteredPickupPoints.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            'Пункты выдачи не найдены',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Expanded(
                        child: CarouselSlider(
                          options: CarouselOptions(
                            height: 220.0, // Увеличили высоту карусели
                            enlargeCenterPage: true,
                            autoPlay: false,
                            aspectRatio: 16 / 9,
                            enableInfiniteScroll: false,
                            viewportFraction: 0.8,
                            initialPage: 0,
                            scrollDirection: Axis.vertical, // Вертикальный скролл
                          ),
                          items: _filteredPickupPoints.map((pickupPoint) {
                            // Используем _filteredPickupPoints
                            return Builder(
                              builder: (BuildContext context) {
                                return PickupPointCard(
                                  pickupPoint: pickupPoint,
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => HomeScreen(
                                            pickupPointId: pickupPoint.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
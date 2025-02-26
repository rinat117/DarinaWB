import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../widgets/pickup_point_card.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class PickupPoint {
  final String id;
  final String name;
  final String address;

  PickupPoint({required this.id, required this.name, required this.address});
}

class PickupSelectionScreen extends StatefulWidget {
  final UserCredential userCredential; // Add UserCredential
  const PickupSelectionScreen({Key? key, required this.userCredential})
      : super(key: key);

  @override
  State<PickupSelectionScreen> createState() => _PickupSelectionScreenState();
}

class _PickupSelectionScreenState extends State<PickupSelectionScreen> {
  List<PickupPoint> _pickupPoints = [];
  List<PickupPoint> _filteredPickupPoints = [];
  bool _loading = true;
  String _searchQuery = '';

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
        _filteredPickupPoints = loadedPickupPoints;
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
        _filteredPickupPoints = _pickupPoints;
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
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.grey[100],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pickupPoints.isEmpty
              ? const Center(child: Text('Нет доступных пунктов выдачи'))
              : Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Поиск пункта выдачи',
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.deepPurple),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: const BorderSide(
                                  color: Colors.deepPurple, width: 2.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 15.0, horizontal: 20.0),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: _filterPickupPoints,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty &&
                          _filteredPickupPoints.isEmpty)
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
                            height: 220.0,
                            enlargeCenterPage: true,
                            autoPlay: false,
                            aspectRatio: 16 / 9,
                            enableInfiniteScroll: false,
                            viewportFraction: 0.8,
                            initialPage: 0,
                            scrollDirection: Axis.vertical,
                          ),
                          items: _filteredPickupPoints.map((pickupPoint) {
                            return Builder(
                              builder: (BuildContext context) {
                                return PickupPointCard(
                                  pickupPoint: pickupPoint,
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => HomeScreen(
                                            pickupPointId: pickupPoint.id,
                                            userCredential: widget
                                                .userCredential), // Pass userCredential
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

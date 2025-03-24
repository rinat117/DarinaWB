import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pickup_point.dart';
import 'dashboard_screen.dart'; // Импортируем новый экран

class PickupSelectionScreen extends StatefulWidget {
  const PickupSelectionScreen({super.key});

  @override
  State<PickupSelectionScreen> createState() => _PickupSelectionScreenState();
}

class _PickupSelectionScreenState extends State<PickupSelectionScreen> {
  List<PickupPoint> _pickupPoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPickupPoints();
  }

  Future<void> _loadPickupPoints() async {
    try {
      final databaseReference = FirebaseDatabase.instance.ref();
      final snapshot = await databaseReference.child('pickup_points').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<PickupPoint> pickupPoints = [];
        data.forEach((key, value) {
          final idString = key.toString().replaceAll('pickup_point_', '');
          int id;
          try {
            id = int.parse(idString);
          } catch (e) {
            print("Error parsing ID from key $key: $e");
            return;
          }

          pickupPoints.add(PickupPoint(
            id: id,
            name: value['name'],
            address: value['address'],
            phone: value['phone'],
            workingHours: value['working_hours'],
            latitude: (value['latitude'] is String)
                ? double.parse(value['latitude'])
                : value['latitude'].toDouble(),
            longitude: (value['longitude'] is String)
                ? double.parse(value['longitude'])
                : value['longitude'].toDouble(),
          ));
        });
        setState(() {
          _pickupPoints = pickupPoints;
          _isLoading = false;
        });
      } else {
        print("No pickup points found in the database");
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading pickup points: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите пункт выдачи'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pickupPoints.isEmpty
              ? const Center(child: Text('Пункты выдачи не найдены'))
              : ListView.builder(
                  itemCount: _pickupPoints.length,
                  itemBuilder: (context, index) {
                    final pickupPoint = _pickupPoints[index];
                    return Card(
                      child: ListTile(
                        title: Text(pickupPoint.name),
                        subtitle: Text(pickupPoint.address),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DashboardScreen(
                                pickupPointId: 'pickup_point_${pickupPoint.id}',
                                user: FirebaseAuth.instance.currentUser!,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
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
  bool _loading = true;

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
      final List<PickupPoint> pickupPoints = [];
      pickupPointsMap.forEach((key, value) {
        final pickupPointData = value as Map<dynamic, dynamic>;
        pickupPoints.add(PickupPoint(
          id: key,
          name: pickupPointData['name'] as String,
          address: pickupPointData['address'] as String,
        ));
      });
      setState(() {
        _pickupPoints = pickupPoints;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
      print('No pickup points found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите пункт выдачи'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pickupPoints.isEmpty
              ? const Center(child: Text('Нет доступных пунктов выдачи'))
              : ListView.builder(
                  itemCount: _pickupPoints.length,
                  itemBuilder: (context, index) {
                    final pickupPoint = _pickupPoints[index];
                    return Card(
                      child: ListTile(
                        title: Text(pickupPoint.name),
                        subtitle: Text(pickupPoint.address),
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HomeScreen(pickupPointId: pickupPoint.id),
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

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class PickupPoint {
  final int id;
  final String name;
  final String address;
  final String phone;
  final String workingHours;
  final double latitude;
  final double longitude;

  PickupPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.workingHours,
    required this.latitude,
    required this.longitude,
  });
}

class News {
  final int id;
  final String title;
  final String description;

  News({
    required this.id,
    required this.title,
    required this.description,
  });
}

class HomeScreen extends StatefulWidget {
  final String? pickupPointId;
  final UserCredential userCredential; // Add UserCredential
  const HomeScreen({Key? key, this.pickupPointId, required this.userCredential})
      : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PickupPoint? _pickupPoint;
  List<News> _newsList = [];
  String? _pickupPointId;

  @override
  void initState() {
    super.initState();
    _pickupPointId = widget.pickupPointId;
    _loadData();
    // Access user information from widget.userCredential
    print('User ID: ${widget.userCredential.user?.uid}'); // Example
  }

  Future<void> _loadData() async {
    final databaseReference = FirebaseDatabase.instance.ref();

    // Загрузка данных пункта выдачи
    if (_pickupPointId != null) {
      final pickupPointSnapshot =
          await databaseReference.child('pickup_points/$_pickupPointId').get();
      if (pickupPointSnapshot.exists) {
        print('Pickup point data: ${pickupPointSnapshot.value}');
        setState(() {
          _pickupPoint = PickupPoint(
            id: 1,
            name: pickupPointSnapshot.child('name').value as String,
            address: pickupPointSnapshot.child('address').value as String,
            phone: pickupPointSnapshot.child('phone').value as String,
            workingHours:
                pickupPointSnapshot.child('working_hours').value as String,
            latitude: double.parse(
                pickupPointSnapshot.child('latitude').value.toString()),
            longitude: double.parse(
                pickupPointSnapshot.child('longitude').value.toString()),
          );
        });
      } else {
        print('Pickup point not found');
      }
    }

    // Загрузка новостей
    final newsSnapshot = await databaseReference.child('news').get();
    final List<News> newsList = [];
    if (newsSnapshot.exists) {
      print('News data: ${newsSnapshot.value}');
      final newsMap = newsSnapshot.value as Map<dynamic, dynamic>;
      newsMap.forEach((key, value) {
        final newsData = value as Map<dynamic, dynamic>;
        newsList.add(News(
          id: int.parse(key.substring(5)),
          title: newsData['title'] as String,
          description: newsData['description'] as String,
        ));
      });
    } else {
      print('No global news found');
    }

    // Загрузка новостей пункта выдачи
    if (_pickupPointId != null) {
      final pickupPointNewsSnapshot = await databaseReference
          .child('pickup_point_news/$_pickupPointId')
          .get();
      if (pickupPointNewsSnapshot.exists) {
        print('Pickup point news data: ${pickupPointNewsSnapshot.value}');
        final pickupPointNewsMap =
            pickupPointNewsSnapshot.value as Map<dynamic, dynamic>;
        pickupPointNewsMap.forEach((key, value) {
          final newsData = value as Map<dynamic, dynamic>;
          newsList.add(News(
            id: int.parse(key.substring(5)),
            title: newsData['title'] as String,
            description: newsData['description'] as String,
          ));
        });
      } else {
        print('No pickup point news found');
      }
    }

    setState(() {
      _newsList = newsList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WB Пункт'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _pickupPoint == null || _newsList.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: <Widget>[
                  Text(
                    _pickupPoint!.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(_pickupPoint!.address),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(_pickupPoint!.phone),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(_pickupPoint!.workingHours),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 200,
                    child: Placeholder(
                      color: Colors.grey,
                      child: Center(child: Text('Карта')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Новости',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._newsList.map((news) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.new_releases),
                          title: Text(news.title),
                          subtitle: Text(news.description),
                        ),
                      )),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Перейти на экран чата
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.chat),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/pickup_point.dart'; // Исправляем путь
import '../../models/news.dart'; // Исправляем путь

class HomeTab extends StatefulWidget {
  final String pickupPointId;

  const HomeTab({Key? key, required this.pickupPointId}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  PickupPoint? _pickupPoint;
  List<News> _newsList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final databaseReference = FirebaseDatabase.instance.ref();

    if (widget.pickupPointId != null) {
      print("Loading pickup point data for ID: ${widget.pickupPointId}");
      final pickupPointSnapshot = await databaseReference
          .child('pickup_points/${widget.pickupPointId}')
          .get();
      if (pickupPointSnapshot.exists) {
        final data = pickupPointSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _pickupPoint = PickupPoint(
            id: 1,
            name: data['name'] as String,
            address: data['address'] as String,
            phone: data['phone'] as String,
            workingHours: data['working_hours'] as String,
            latitude: (data['latitude'] is String)
                ? double.parse(data['latitude'])
                : data['latitude'].toDouble(),
            longitude: (data['longitude'] is String)
                ? double.parse(data['longitude'])
                : data['longitude'].toDouble(),
          );
        });
      } else {
        print("Pickup point ${widget.pickupPointId} not found");
      }
    }

    print("Loading news...");
    final newsSnapshot = await databaseReference.child('news').get();
    final List<News> newsList = [];
    if (newsSnapshot.exists) {
      final newsMap = newsSnapshot.value as Map<dynamic, dynamic>;
      newsMap.forEach((key, value) {
        final newsData = value as Map<dynamic, dynamic>;
        newsList.add(News(
          id: int.parse(key.toString().substring(5)),
          title: newsData['title'] as String,
          description: newsData['description'] as String,
        ));
      });
    }

    if (widget.pickupPointId != null) {
      print("Loading pickup point news for ID: ${widget.pickupPointId}");
      final pickupPointNewsSnapshot = await databaseReference
          .child('pickup_point_news/${widget.pickupPointId}')
          .get();
      if (pickupPointNewsSnapshot.exists) {
        final pickupPointNewsMap =
            pickupPointNewsSnapshot.value as Map<dynamic, dynamic>;
        pickupPointNewsMap.forEach((key, value) {
          final newsData = value as Map<dynamic, dynamic>;
          newsList.add(News(
            id: int.parse(key.toString().substring(5)),
            title: newsData['title'] as String,
            description: newsData['description'] as String,
          ));
        });
      }
    }

    setState(() {
      _newsList = newsList;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WB Пункт'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _pickupPoint == null
                  ? const Center(child: Text('Пункт выдачи не найден'))
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
                                title: Text(news.title ?? 'Без заголовка'),
                                subtitle:
                                    Text(news.description ?? 'Без описания'),
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

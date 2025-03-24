import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/pickup_point.dart';
import '../models/news.dart';
import '../models/order.dart';
import '../models/order_item.dart';

class HomeScreen extends StatefulWidget {
  final String? pickupPointId;
  final User? user;

  const HomeScreen({Key? key, this.pickupPointId, this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PickupPoint? _pickupPoint;
  List<News> _newsList = [];
  List<Order> _userOrders = [];
  String? _pickupPointId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pickupPointId = widget.pickupPointId;
    print("HomeScreen initialized with pickupPointId: $_pickupPointId");
    print("User: ${widget.user?.phoneNumber}");
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final databaseReference = FirebaseDatabase.instance.ref();

    // Загрузка данных пункта выдачи
    if (_pickupPointId != null) {
      print("Loading pickup point data for ID: $_pickupPointId");
      final pickupPointSnapshot =
          await databaseReference.child('pickup_points/$_pickupPointId').get();
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
        print("Pickup point $_pickupPointId not found");
      }
    }

    // Загрузка новостей
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

    if (_pickupPointId != null) {
      print("Loading pickup point news for ID: $_pickupPointId");
      final pickupPointNewsSnapshot = await databaseReference
          .child('pickup_point_news/$_pickupPointId')
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

    // Загрузка заказов пользователя
    if (widget.user != null) {
      String phoneNumber = widget.user!.phoneNumber?.replaceAll('+', '') ?? '';
      print("Loading orders for user with phone: $phoneNumber");
      final ordersSnapshot = await databaseReference
          .child('users/customers/$phoneNumber/orders')
          .get();
      if (ordersSnapshot.exists) {
        final ordersMap = ordersSnapshot.value as Map<dynamic, dynamic>;
        final List<Order> ordersList = [];
        ordersMap.forEach((key, value) {
          final orderData = value as Map<dynamic, dynamic>;
          final itemsList = (orderData['items'] as List<dynamic>).map((item) {
            final itemData = item as Map<dynamic, dynamic>;
            return OrderItem(
              productId: itemData['product_id'] as String,
              article: itemData['article'] as String,
              qrCode: itemData['qr_code'] as String,
              quantity: itemData['quantity'] as int,
            );
          }).toList();
          ordersList.add(Order(
            id: key,
            pickupPointId: orderData['pickup_point_id'] as String,
            orderDate: orderData['order_date'] as String,
            orderStatus: orderData['order_status'] as String,
            items: itemsList,
            totalPrice: orderData['total_price'] as int,
          ));
        });
        print("Found ${ordersList.length} orders for user $phoneNumber");
        setState(() {
          _userOrders = ordersList
              .where((order) => order.pickupPointId == _pickupPointId)
              .toList();
          print(
              "Filtered orders for pickup point $_pickupPointId: ${_userOrders.length}");
        });
      } else {
        print("No orders found for user $phoneNumber");
      }
    } else {
      print("No user provided to load orders");
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
                                title: Text(news.title),
                                subtitle: Text(news.description),
                              ),
                            )),
                        const SizedBox(height: 16),
                        const Text(
                          'Мои заказы',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_userOrders.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.inbox, color: Colors.grey),
                                  SizedBox(width: 16),
                                  Text(
                                    'В этом пункте пока нет ваших заказов',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._userOrders.map((order) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Заказ от ${order.orderDate}',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Статус: ${order.orderStatus}'),
                                      const SizedBox(height: 8),
                                      ...order.items.map((item) => ListTile(
                                            leading: const Icon(Icons.qr_code),
                                            title: Text(
                                                'Артикул: ${item.article}'),
                                            subtitle: SizedBox(
                                              width: 100,
                                              height: 100,
                                              child: QrImageView(
                                                data: item.qrCode,
                                                version: QrVersions.auto,
                                                size: 100.0,
                                              ),
                                            ),
                                          )),
                                      const SizedBox(height: 8),
                                      Text('Итого: ${order.totalPrice} ₽'),
                                    ],
                                  ),
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

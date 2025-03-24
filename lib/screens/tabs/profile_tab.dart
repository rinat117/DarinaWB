import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/order.dart'; // Исправляем путь
import '../../models/order_item.dart'; // Исправляем путь

class ProfileTab extends StatefulWidget {
  final User user;
  final String pickupPointId;

  const ProfileTab({
    Key? key,
    required this.user,
    required this.pickupPointId,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  List<Order> _userOrders = [];
  bool _isLoading = true;
  String? _username;

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

    String phoneNumber = widget.user.phoneNumber?.replaceAll('+', '') ?? '';
    print("Loading user data for phone: $phoneNumber");
    final userSnapshot =
        await databaseReference.child('users/customers/$phoneNumber').get();
    if (userSnapshot.exists) {
      final userData = userSnapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _username = userData['username'] as String?;
      });
    }

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
            .where((order) => order.pickupPointId == widget.pickupPointId)
            .toList();
        print(
            "Filtered orders for pickup point ${widget.pickupPointId}: ${_userOrders.length}");
      });
    } else {
      print("No orders found for user $phoneNumber");
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Моё'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.deepPurple,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _username ?? 'Клиент',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.user.phoneNumber ?? 'Номер не указан',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 300,
                      child: PageView.builder(
                        itemCount: _userOrders.length,
                        itemBuilder: (context, index) {
                          final order = _userOrders[index];
                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Заказ от ${order.orderDate}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Статус: ${order.orderStatus}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  ...order.items.map((item) => ListTile(
                                        leading: const Icon(Icons.qr_code),
                                        title: Text('Артикул: ${item.article}'),
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
                                  Text(
                                    'Итого: ${order.totalPrice} ₽',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

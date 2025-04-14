import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Импортируем модели (убедись, что пути верные)
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/employee.dart'; // Модель сотрудника
import '../../models/booking_info.dart'; // Модель бронирования

class EmployeeHomeTab extends StatefulWidget {
  const EmployeeHomeTab({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeTab> createState() => _EmployeeHomeTabState();
}

class _EmployeeHomeTabState extends State<EmployeeHomeTab> {
  bool _isLoading = true;
  Employee? _employee;
  String _pickupPointId = '';
  String? _pickupPointAddress; // <<<--- Для хранения адреса
  Map<String, List<Order>> _readyOrdersByCustomer = {};
  List<BookingInfo> _todaysBookings = [];
  Map<String, String> customerUsernames = {}; // <<<--- Объявлено как состояние

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _readyOrdersByCustomer = {};
      _todaysBookings = [];
      customerUsernames = {};
      _pickupPointAddress = null; // <<<--- Сброс адреса
      _employee = null; // Сброс сотрудника
      _pickupPointId = ''; // Сброс ID ПВЗ
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      print("Error: Employee not logged in or email is null");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Сначала загружаем данные сотрудника, чтобы получить pickupPointId
    await _loadEmployeeData(user.email!);
    if (_pickupPointId.isNotEmpty) {
      // Затем параллельно грузим остальное
      try {
        await Future.wait([
          _loadPickupPointDetails(_pickupPointId), // <<<--- Загружаем адрес
          _loadReadyOrders(_pickupPointId),
          _loadTodaysBookings(_pickupPointId),
        ]);
      } catch (e) {
        print("Error during concurrent data loading: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка загрузки данных: $e")),
          );
        }
      }
    } else {
      print("Cannot load details/orders/bookings: pickupPointId is empty");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEmployeeData(String email) async {
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      // Адаптируй этот ключ под твою структуру в Firebase employees
      final safeEmailKey = email.replaceAll('.', '_').replaceAll('@', '_');
      print("Loading employee data for key: $safeEmailKey");
      final snapshot = await dbRef.child('users/employees/$safeEmailKey').get();

      if (mounted && snapshot.exists && snapshot.value != null) {
        final employeeData = snapshot.value as Map<dynamic, dynamic>;
        // Обновляем состояние для немедленного использования
        setState(() {
          _employee = Employee.fromJson(snapshot.key!, employeeData);
          _pickupPointId = _employee!.pickupPointId;
        });
        print(
            "Employee data loaded: ${_employee?.name}, PP ID: $_pickupPointId");
      } else {
        print("Employee data not found for email: $email (key: $safeEmailKey)");
        if (mounted) {
          // Сброс, если не нашли
          setState(() {
            _employee = null;
            _pickupPointId = '';
          });
        }
      }
    } catch (e) {
      print("Error loading employee data: $e");
      if (mounted) {
        setState(() {
          // Сброс при ошибке
          _employee = null;
          _pickupPointId = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки данных сотрудника: $e")),
        );
      }
    }
  }

  // --- Функция для загрузки деталей ПВЗ (включая адрес) ---
  Future<void> _loadPickupPointDetails(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await dbRef.child('pickup_points/$pickupPointId').get();
      if (mounted && snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          // Убираем лишние кавычки из адреса, если они есть
          _pickupPointAddress =
              (data['address'] as String?)?.replaceAll('"', '');
        });
        print("Loaded address: $_pickupPointAddress");
      } else {
        print("Pickup point details not found for $pickupPointId");
        if (mounted)
          setState(() => _pickupPointAddress = null); // Сброс, если не нашли
      }
    } catch (e) {
      print("Error loading pickup point details: $e");
      if (mounted)
        setState(() => _pickupPointAddress = null); // Сброс при ошибке
    }
  }
  // --- Конец функции ---

  Future<void> _loadReadyOrders(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    Map<String, List<Order>> ordersMap = {};
    // Используем переменную состояния customerUsernames

    try {
      final customersSnapshot = await dbRef.child('users/customers').get();
      if (customersSnapshot.exists && customersSnapshot.value != null) {
        final customersData = customersSnapshot.value as Map<dynamic, dynamic>;

        customersData.forEach((phoneKey, customerData) {
          if (customerData is Map) {
            final customerMap = customerData as Map<dynamic, dynamic>;
            customerUsernames[phoneKey] =
                customerMap['username'] ?? phoneKey; // Сохраняем имя

            final ordersData = customerMap['orders'];
            if (ordersData is Map) {
              final orders = ordersData as Map<dynamic, dynamic>;
              orders.forEach((orderKey, orderValue) {
                if (orderValue is Map) {
                  final order = Order.fromJson(orderKey, orderValue);
                  if (order.pickupPointId == pickupPointId &&
                      order.orderStatus == 'ready_for_pickup') {
                    if (!ordersMap.containsKey(phoneKey)) {
                      ordersMap[phoneKey] = [];
                    }
                    ordersMap[phoneKey]!.add(order);
                  }
                }
              });
            }
          }
        });
      }
      // Обновляем состояние после завершения цикла
      if (mounted) {
        setState(() {
          _readyOrdersByCustomer = ordersMap;
        });
        print(
            "Loaded ${_readyOrdersByCustomer.length} customers with ready orders.");
      }
    } catch (e) {
      print("Error loading ready orders: $e");
      if (mounted) {
        setState(() => _readyOrdersByCustomer = {}); // Сброс при ошибке
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки заказов к выдаче: $e")),
        );
      }
    }
  }

  Future<void> _loadTodaysBookings(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<BookingInfo> bookingsList = [];
    print("Loading bookings for date: $todayDate"); // Отладка

    try {
      final snapshot =
          await dbRef.child('bookings/$pickupPointId/$todayDate').get();
      if (snapshot.exists && snapshot.value != null) {
        print(
            "Raw Bookings Snapshot for $todayDate: ${snapshot.value}"); // Отладка
        final bookedSlots = snapshot.value as Map<dynamic, dynamic>;
        bookedSlots.forEach((timeSlot, bookingData) {
          print(
              "Processing booking slot: $timeSlot, data: $bookingData"); // Отладка
          if (bookingData is Map) {
            bookingsList.add(BookingInfo.fromJson(timeSlot, bookingData));
          }
        });
        bookingsList.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      } else {
        print("No bookings found in snapshot for $todayDate"); // Отладка
      }
      if (mounted) {
        setState(() {
          _todaysBookings = bookingsList;
        });
        print("Loaded ${_todaysBookings.length} bookings for today.");
      }
    } catch (e) {
      print("Error loading today's bookings: $e");
      if (mounted) {
        setState(() => _todaysBookings = []); // Сброс при ошибке
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки бронирований: $e")),
        );
      }
    }
  }

  void _showReadyOrderDetailsDialog(
      BuildContext context, String customerPhone, List<Order> orders) {
    // Используем переменную состояния класса для имени
    String customerDisplay = customerUsernames[customerPhone] ?? customerPhone;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Заказы для $customerDisplay'),
          content: Container(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: orders.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Заказ ID: ${order.id}",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    ...order.items.map((item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: GestureDetector(
                            onTap: () =>
                                _showEnlargedQrDialog(context, item.qrCode),
                            child: QrImageView(
                              data: item.qrCode.isNotEmpty
                                  ? item.qrCode
                                  : 'no-qr-code',
                              version: QrVersions.auto,
                              size: 40.0,
                              gapless: false,
                              errorStateBuilder: (cxt, err) => const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Center(
                                      child: Icon(Icons.error_outline,
                                          color: Colors.red))),
                            ),
                          ),
                          title: Text("Арт: ${item.article}"),
                          subtitle: Text("Кол-во: ${item.quantity}"),
                        )),
                  ],
                );
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton.icon(
              icon: Icon(Icons.check_circle_outline),
              label: Text('Отметить как выданные'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                _markOrdersAsDelivered(context, customerPhone, orders);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Закрыть'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markOrdersAsDelivered(BuildContext context,
      String customerPhone, List<Order> ordersToDeliver) async {
    if (!mounted) return;
    print(
        "Marking ${ordersToDeliver.length} orders as delivered for $customerPhone");

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()));

    final dbRef = FirebaseDatabase.instance.ref();
    Map<String, dynamic> updates = {};
    final String newStatus = 'delivered';

    for (var order in ordersToDeliver) {
      final orderStatusPath =
          'users/customers/$customerPhone/orders/${order.id}/order_status';
      updates[orderStatusPath] = newStatus;
      if (order.bookingSlot != null && order.bookingSlot!.isNotEmpty) {
        try {
          final parts = order.bookingSlot!.split(' ');
          final formattedDate = parts[0];
          final formattedTime = parts[1];
          final bookingPath =
              'bookings/$_pickupPointId/$formattedDate/$formattedTime';
          updates[bookingPath] = null;
        } catch (e) {
          print(
              "Error parsing booking slot for deletion: ${order.bookingSlot}");
        }
      }
    }

    try {
      await dbRef.update(updates);
      Navigator.of(context).pop(); // Убираем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Заказы отмечены как выданные!')),
        );
        // Перезагружаем только нужные данные
        await _loadReadyOrders(_pickupPointId);
        await _loadTodaysBookings(_pickupPointId);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Убираем индикатор загрузки при ошибке
      print("Error marking orders as delivered: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления статуса заказов: $e')),
        );
      }
    }
  }

  void _showEnlargedQrDialog(BuildContext context, String qrData) {
    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR-код недоступен')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(10),
          content: SizedBox(
            width: 250,
            height: 250,
            child: Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250.0,
                gapless: false,
                errorStateBuilder: (cxt, err) => const Center(
                  child: Text(
                    'Не удалось отобразить QR-код',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Закрыть'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сегодня'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // Кнопка выхода для сотрудника
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // TODO: Реализовать навигацию на LoginScreen
              // Например: Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => LoginScreen()), (Route<dynamic> route) => false);
              print("User signed out");
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                // Обертка в ListView для скролла
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Приветствие ---
                  Text(
                    'Добрый день, ${_employee?.name ?? 'Сотрудник'}!',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  // --- Отображение Адреса ПВЗ ---
                  if (_pickupPointAddress !=
                      null) // Показываем адрес, если загружен
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Пункт выдачи на $_pickupPointAddress', // Используем загруженный адрес
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey[700]), // Чуть темнее
                      ),
                    ),
                  const SizedBox(height: 24),

                  // --- Секция "Ожидается к выдаче" ---
                  Text(
                    'Ожидается к выдаче (${_readyOrdersByCustomer.values.expand((list) => list).length})', // Считаем общее кол-во заказов
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.deepPurple[700]), // Немного темнее
                  ),
                  const SizedBox(height: 8),
                  _readyOrdersByCustomer.isEmpty
                      ? const Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8))),
                          child: ListTile(
                              leading: Icon(Icons.check_circle_outline,
                                  color: Colors.grey),
                              title: Text('Нет заказов, готовых к выдаче.')))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _readyOrdersByCustomer.length,
                          itemBuilder: (context, index) {
                            final customerPhone =
                                _readyOrdersByCustomer.keys.elementAt(index);
                            final orders =
                                _readyOrdersByCustomer[customerPhone]!;
                            // Используем переменную состояния класса для имени
                            final customerName =
                                customerUsernames[customerPhone] ??
                                    customerPhone;

                            return Card(
                              elevation: 2, // Небольшая тень
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8))),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Icon(Icons.person_outline,
                                      color: Colors.green[800]),
                                ),
                                title: Text(customerName,
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                                subtitle:
                                    Text('Готовых заказов: ${orders.length}'),
                                trailing: Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.grey),
                                onTap: () {
                                  _showReadyOrderDetailsDialog(
                                      context, customerPhone, orders);
                                },
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),

                  // --- Секция "Забронировано на сегодня" ---
                  Text(
                    'Забронировано на сегодня (${_todaysBookings.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.deepPurple[700]),
                  ),
                  const SizedBox(height: 8),
                  _todaysBookings.isEmpty
                      ? const Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8))),
                          child: ListTile(
                              leading: Icon(Icons.calendar_today_outlined,
                                  color: Colors.grey),
                              title: Text('На сегодня нет бронирований.')))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _todaysBookings.length,
                          itemBuilder: (context, index) {
                            final booking = _todaysBookings[index];
                            // Используем переменную состояния класса для имени
                            final customerName =
                                customerUsernames[booking.userPhone] ??
                                    booking.userPhone;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8))),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange[100],
                                  child: Icon(
                                    Icons.watch_later_outlined,
                                    color: Colors.orange[800],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                    '${booking.timeSlot} - $customerName',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text('Заказ ID: ${booking.orderId}'),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20), // Нижний отступ
                ],
              ),
      ),
    );
  }
}

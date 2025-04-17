import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для копирования
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Импорты моделей (убедись, что пути верные)
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/employee.dart';
import '../../models/booking_info.dart';
import '../../widgets/order_status_indicator.dart'; // Импорт индикатора статуса
import '../../widgets/pickup_code_dialog.dart'; // Импорт диалога QR/Кода
import '../login_screen.dart'; // Для выхода

class EmployeeHomeTab extends StatefulWidget {
  const EmployeeHomeTab({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeTab> createState() => _EmployeeHomeTabState();
}

class _EmployeeHomeTabState extends State<EmployeeHomeTab> {
  // --- Состояния ---
  bool _isLoading = true;
  Employee? _employee;
  String _pickupPointId = '';
  String? _pickupPointAddress;
  Map<String, List<Order>> _readyOrdersByCustomer = {};
  List<BookingInfo> _todaysBookings = [];
  Map<String, String> customerUsernames = {};
  List<Order> _allPvzOrders = [];
  List<Order> _filteredOrders = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, String> _orderIdToPhoneMap = {};
  // --- Конец Состояний ---

  // --- Цвета для UI ---
  final Color primaryColor = Color(0xFF7F00FF);
  final Color accentColor = Color(0xFFCB11AB);
  final Color cardBackgroundColor = Colors.white;
  final Color screenBackgroundColor = Colors.grey[100]!;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey[600]!;
  // --- Конец Цветов ---

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _filterOrders(_searchController.text);
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Функции Загрузки Данных ---
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _readyOrdersByCustomer = {};
      _todaysBookings = [];
      customerUsernames = {};
      _pickupPointAddress = null;
      _employee = null;
      _pickupPointId = '';
      _allPvzOrders = [];
      _filteredOrders = [];
      _orderIdToPhoneMap = {};
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      print("Error: Employee not logged in or email is null");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await _loadEmployeeData(user.email!);
    if (_pickupPointId.isNotEmpty) {
      try {
        await Future.wait([
          _loadPickupPointDetails(_pickupPointId),
          _loadReadyOrdersAndUsernames(_pickupPointId),
          _loadTodaysBookings(_pickupPointId),
          _loadAllPvzOrders(_pickupPointId),
        ]);
      } catch (e) {
        print("Error during concurrent data loading: $e");
        _showErrorSnackBar("Ошибка загрузки данных: $e");
      }
    } else {
      print("Cannot load details/orders/bookings: pickupPointId is empty.");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEmployeeData(String email) async {
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      final safeEmailKey = email.replaceAll('.', '_').replaceAll('@', '_');
      final snapshot = await dbRef.child('users/employees/$safeEmailKey').get();
      if (mounted && snapshot.exists && snapshot.value != null) {
        final employeeData = snapshot.value as Map<dynamic, dynamic>;
        _employee = Employee.fromJson(snapshot.key!, employeeData);
        _pickupPointId = _employee!.pickupPointId;
      } else {
        _pickupPointId = '';
      }
    } catch (e) {
      print("Error loading employee data: $e");
      _pickupPointId = '';
      _showErrorSnackBar("Ошибка загрузки данных сотрудника: $e");
    }
  }

  Future<void> _loadPickupPointDetails(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await dbRef.child('pickup_points/$pickupPointId').get();
      if (mounted && snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _pickupPointAddress = (data['address'] as String?)?.replaceAll('"', '');
      } else {
        _pickupPointAddress = null;
      }
    } catch (e) {
      print("Error loading pickup point details: $e");
      _pickupPointAddress = null;
    }
  }

  Future<void> _loadReadyOrdersAndUsernames(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    Map<String, List<Order>> readyOrdersMap = {};
    Map<String, String> usernamesMap = {};
    try {
      final customersSnapshot = await dbRef.child('users/customers').get();
      if (customersSnapshot.exists && customersSnapshot.value != null) {
        final customersData = customersSnapshot.value as Map<dynamic, dynamic>;
        customersData.forEach((phoneKey, customerData) {
          if (phoneKey == null || phoneKey.toString().isEmpty) return;
          final String safePhoneKey = phoneKey.toString();
          if (customerData is Map) {
            usernamesMap[safePhoneKey] =
                customerData['username']?.toString() ?? safePhoneKey;
            final ordersData = customerData['orders'];
            if (ordersData is Map) {
              ordersData.forEach((orderKey, orderValue) {
                if (orderValue is Map) {
                  final order = Order.fromJson(orderKey, orderValue);
                  if (order.pickupPointId == pickupPointId &&
                      order.orderStatus == 'ready_for_pickup') {
                    (readyOrdersMap[safePhoneKey] ??= []).add(order);
                  }
                }
              });
            }
          }
        });
      }
      _readyOrdersByCustomer = readyOrdersMap;
      customerUsernames = usernamesMap;
    } catch (e) {
      print("Error loading ready orders/usernames: $e");
      _readyOrdersByCustomer = {};
      _showErrorSnackBar("Ошибка загрузки заказов к выдаче: $e");
    }
  }

  Future<void> _loadTodaysBookings(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<BookingInfo> bookingsList = [];
    try {
      final snapshot =
          await dbRef.child('bookings/$pickupPointId/$todayDate').get();
      if (snapshot.exists && snapshot.value != null) {
        final bookedSlots = snapshot.value as Map<dynamic, dynamic>;
        bookedSlots.forEach((timeSlot, bookingData) {
          if (bookingData is Map) {
            bookingsList.add(BookingInfo.fromJson(timeSlot, bookingData));
          }
        });
        bookingsList.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      }
      _todaysBookings = bookingsList;
    } catch (e) {
      print("Error loading today's bookings: $e");
      _todaysBookings = [];
      _showErrorSnackBar("Ошибка загрузки бронирований: $e");
    }
  }

  Future<void> _loadAllPvzOrders(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    List<Order> allOrders = [];
    Map<String, String> orderIdToPhone = {};
    try {
      final customersSnapshot = await dbRef.child('users/customers').get();
      if (customersSnapshot.exists && customersSnapshot.value != null) {
        final customersData = customersSnapshot.value as Map<dynamic, dynamic>;
        customersData.forEach((phoneKey, customerData) {
          if (phoneKey == null || phoneKey.toString().isEmpty) return;
          final String safePhoneKey = phoneKey.toString();
          if (customerData is Map) {
            if (!customerUsernames.containsKey(safePhoneKey)) {
              customerUsernames[safePhoneKey] =
                  customerData['username']?.toString() ?? safePhoneKey;
            }
            final ordersData = customerData['orders'];
            if (ordersData is Map) {
              ordersData.forEach((orderKey, orderValue) {
                if (orderValue is Map) {
                  final order = Order.fromJson(orderKey, orderValue);
                  if (order.pickupPointId == pickupPointId) {
                    allOrders.add(order);
                    orderIdToPhone[order.id] = safePhoneKey;
                  }
                }
              });
            }
          }
        });
      }
      allOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      _allPvzOrders = allOrders;
      _orderIdToPhoneMap = orderIdToPhone;
      _filteredOrders = []; // Сброс фильтра
    } catch (e) {
      print("Error loading all orders: $e");
      _allPvzOrders = [];
      _filteredOrders = [];
      _orderIdToPhoneMap = {};
      _showErrorSnackBar("Ошибка загрузки всех заказов: $e");
    }
  }
  // --- Конец Функций Загрузки ---

  // --- Функция Фильтрации/Поиска ---
  void _filterOrders(String query) {
    final lowerCaseQuery = query.trim().toLowerCase();
    if (lowerCaseQuery.isEmpty) {
      setState(() => _filteredOrders = []);
      return;
    }
    final filtered = _allPvzOrders.where((order) {
      if (order.id.toLowerCase().contains(lowerCaseQuery)) return true;
      if (order.items
          .any((item) => item.article.toLowerCase().contains(lowerCaseQuery)))
        return true;
      final customerPhone = _orderIdToPhoneMap[order.id];
      if (customerPhone != null) {
        if (customerPhone.contains(lowerCaseQuery)) return true;
        final customerName =
            customerUsernames[customerPhone]?.toLowerCase() ?? '';
        if (customerName.contains(lowerCaseQuery)) return true;
      }
      return false;
    }).toList();
    setState(() => _filteredOrders = filtered);
  }
  // --- Конец Функции Фильтрации ---

  // --- Диалог Выдачи Готовых Заказов ---
  void _showReadyOrderDetailsDialog(
      BuildContext context, String customerPhone, List<Order> orders) {
    String customerDisplay = customerUsernames[customerPhone] ?? customerPhone;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text('Выдача заказов: $customerDisplay',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[500], size: 22),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(dialogContext).pop(),
              )
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: orders.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 15, color: Colors.grey[700]),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Заказ #${order.id.split('_').last}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15)),
                    SizedBox(height: 6),
                    if (order.items.isEmpty)
                      Text("Нет товаров",
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13))
                    else
                      ...order.items.map((item) => Padding(
                            padding:
                                const EdgeInsets.only(left: 8.0, bottom: 4.0),
                            child: Row(
                              children: [
                                InkWell(
                                    onTap: () => showPickupCodeDialog(
                                        context, item.qrCode, item.article),
                                    child: Icon(Icons.qr_code_2_rounded,
                                        color: Colors.grey[400], size: 20)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text('Код: ${item.article}',
                                        style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 13))),
                                Text('(${item.quantity} шт.)',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 13)),
                              ],
                            ),
                          )),
                  ],
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.check_circle_outline, size: 18),
              label: Text('Выдать (${orders.length} зак.)'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                _markOrdersAsDelivered(context, customerPhone, orders);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
  // --- Конец Диалога Выдачи ---

  // --- Отметка Готовых Заказов как Выданных ---
  Future<void> _markOrdersAsDelivered(BuildContext context,
      String customerPhone, List<Order> ordersToDeliver) async {
    if (!mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()));
    final dbRef = FirebaseDatabase.instance.ref();
    Map<String, dynamic> updates = {};
    final String newStatus = 'delivered';
    for (var order in ordersToDeliver) {
      updates['users/customers/$customerPhone/orders/${order.id}/order_status'] =
          newStatus;
      if (order.bookingSlot != null && order.bookingSlot!.isNotEmpty) {
        try {
          final parts = order.bookingSlot!.split(' ');
          updates['bookings/$_pickupPointId/${parts[0]}/${parts[1]}'] = null;
        } catch (e) {
          print(
              "Error parsing booking slot for deletion: ${order.bookingSlot}");
        }
      }
    }
    try {
      await dbRef.update(updates);
      Navigator.of(context).pop(); // Убираем индикатор
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Заказы отмечены как выданные!'),
            backgroundColor: Colors.green));
        await _loadInitialData(); // Перезагружаем данные
      }
    } catch (e) {
      Navigator.of(context).pop();
      print("Error marking orders as delivered: $e");
      _showErrorSnackBar('Ошибка обновления статуса заказов: $e');
    }
  }
  // --- Конец Функции Отметки ---

  // --- Диалог Деталей Любого Заказа (из поиска) ---
  void _showStyledOrderDetailsDialog(BuildContext context, Order order) {
    final customerPhone = _orderIdToPhoneMap[order.id] ?? 'Не найден';
    final customerDisplay = customerUsernames[customerPhone] ?? customerPhone;
    final List<String> possibleStatuses = [
      'pending',
      'processing',
      'in_transit',
      'ready_for_pickup',
      'delivered'
    ].toSet().toList();
    String? selectedStatus = order.orderStatus;
    final bool canChangeStatus = order.orderStatus != 'delivered';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Заказ #${order.id.split('_').last}',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 22),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  )
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.person_outline,
                        '$customerDisplay ($customerPhone)', context),
                    _buildDetailRow(Icons.calendar_today_outlined,
                        'Дата: ${order.orderDate}', context),
                    const SizedBox(height: 10),
                    OrderStatusIndicator(orderStatus: order.orderStatus),
                    const SizedBox(height: 15),
                    Text('Товары:',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 14)),
                    const SizedBox(height: 5),
                    if (order.items.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Нет товаров',
                              style: TextStyle(color: Colors.grey[500])))
                    else
                      Column(
                        mainAxisSize: MainAxisSize
                            .min, // Чтобы Column не растягивался бесконечно
                        children: List.generate(order.items.length, (index) {
                          final item = order.items[index];
                          // Добавляем разделитель перед каждым элементом, кроме первого
                          final divider = index > 0
                              ? Divider(
                                  height: 10,
                                  color: Colors.grey[700],
                                  thickness: 0.5)
                              : SizedBox.shrink();

                          return Column(
                            // Оборачиваем каждый товар и разделитель (если есть) в Column
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              divider, // Показываем разделитель
                              Padding(
                                // Отступы для каждого товара
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    // Кликабельная иконка QR
                                    InkWell(
                                      onTap: () => showPickupCodeDialog(
                                          context, item.qrCode, item.article),
                                      child: Icon(Icons.qr_code_2_rounded,
                                          color: Colors.grey[400], size: 28),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('Код: ${item.article}',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Кол-во: ${item.quantity}',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    const SizedBox(height: 15),
                    if (canChangeStatus) ...[
                      Text('Изменить статус:',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 14)),
                      const SizedBox(height: 5),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedStatus,
                            isExpanded: true,
                            dropdownColor: Colors.grey[800],
                            icon: Icon(Icons.arrow_drop_down,
                                color: Colors.grey[400]),
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            items: possibleStatuses
                                .map((String v) => DropdownMenuItem<String>(
                                    value: v,
                                    child: Text(_getStatusDisplayName(v))))
                                .toList(),
                            onChanged: (String? n) => n != null
                                ? stfSetState(() => selectedStatus = n)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                            'Статус заказа "${_getStatusDisplayName(order.orderStatus)}" нельзя изменить.',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.grey[400]),
                  child: Text('Отмена'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  onPressed:
                      (canChangeStatus && selectedStatus != order.orderStatus)
                          ? () async {
                              await _updateOrderStatus(order, selectedStatus!);
                              Navigator.of(dialogContext).pop();
                            }
                          : null,
                  child: Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- Конец Диалога Деталей ---

// --- Вспомогательный Виджет для Строки Деталей ---
  Widget _buildDetailRow(IconData icon, String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: Colors.grey[300], fontSize: 14))),
        ],
      ),
    );
  }
  // --- Конец Вспомогательного Виджета ---

// --- Вспомогательная Функция для Имени Статуса ---
  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'В обработке';
      case 'processing':
        return 'Обрабатывается';
      case 'in_transit':
        return 'В пути';
      case 'ready_for_pickup':
        return 'Готов к выдаче';
      case 'delivered':
        return 'Выдан';
      default:
        return status;
    }
  }
  // --- Конец Вспомогательной Функции ---

  // --- Обновление Статуса Заказа ---
  Future<void> _updateOrderStatus(Order order, String newStatus) async {
    final customerPhone = _orderIdToPhoneMap[order.id];
    if (customerPhone == null || customerPhone.isEmpty) {
      _showErrorSnackBar('Ошибка: Не найден клиент для заказа.');
      return;
    }
    final dbRef = FirebaseDatabase.instance.ref();
    final orderStatusPath =
        'users/customers/$customerPhone/orders/${order.id}/order_status';
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()));
    try {
      await dbRef.child(orderStatusPath).set(newStatus);
      Navigator.of(context).pop(); // Убираем индикатор
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Статус заказа обновлен!'),
            backgroundColor: Colors.green));
        await _loadInitialData(); // Перезагружаем все данные
      }
    } catch (e) {
      Navigator.of(context).pop();
      print("Error updating order status: $e");
      _showErrorSnackBar('Ошибка обновления статуса: $e');
    }
  }
  // --- Конец Функции Обновления Статуса ---

  // --- Функция Выхода ---
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      _showErrorSnackBar("Ошибка выхода: $e");
    }
  }
  // --- Конец Функции Выхода ---

  // --- Вспомогательная функция для показа SnackBar ошибок ---
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

// --- ОСНОВНОЙ МЕТОД BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: screenBackgroundColor, // Светлый фон экрана
      appBar: AppBar(
        // AppBar остается простым, т.к. приветствие и адрес будут в контенте
        title: const Text('Сегодня'),
        backgroundColor: Colors.white, // Белый AppBar
        foregroundColor: textColorPrimary, // Цвет текста и иконок на AppBar
        elevation: 1.0, // Небольшая тень
        actions: [
          IconButton(
            icon: Icon(Icons.logout_outlined,
                color: Colors.red[400]), // Иконка выхода
            tooltip: 'Выйти',
            onPressed: _signOut,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData, // Обновление по свайпу
        color: primaryColor, // Цвет индикатора обновления
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : GestureDetector(
                // Скрытие клавиатуры по тапу вне поля
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  // Основной скролл
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // 1. Приветствие и Адрес ПВЗ
                    _buildGreetingSection(),
                    const SizedBox(height: 20),

                    // 2. Поиск Заказа
                    _buildSearchSection(),
                    // Отображение результатов поиска ИЛИ основных секций
                    if (_searchController.text.isNotEmpty)
                      _buildSearchResultsSection() // Показываем результаты если есть запрос
                    else ...[
                      // Иначе показываем брони и готовые
                      const SizedBox(height: 24),
                      // 3. Бронирования на сегодня
                      _buildBookingsSection(),
                      const SizedBox(height: 24),
                      // 4. Готовые к выдаче
                      _buildReadyOrdersSection(),
                    ],
                    const SizedBox(height: 20), // Нижний отступ
                  ],
                ),
              ),
      ),
    );
  }

  // --- Виджет Приветствия ---
  Widget _buildGreetingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Добрый день, ${_employee?.name ?? 'Сотрудник'}!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColorPrimary)),
        if (_pickupPointAddress != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: textColorSecondary),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(_pickupPointAddress!,
                        style: TextStyle(
                            fontSize: 14, color: textColorSecondary))),
              ],
            ),
          ),
      ],
    );
  }
  // --- Конец Виджета Приветствия ---

  // --- Виджет Секции Поиска ---
  Widget _buildSearchSection() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Поиск по ID, коду, телефону, имени...',
        prefixIcon: Icon(Icons.search, color: primaryColor.withOpacity(0.8)),
        filled: true,
        fillColor: cardBackgroundColor,
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.5)),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: textColorSecondary, size: 20),
                onPressed: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                },
              )
            : null,
      ),
    );
  }
  // --- Конец Виджета Поиска ---

  // --- Виджет Отображения Результатов Поиска ---
  Widget _buildSearchResultsSection() {
    if (_isLoading) return SizedBox.shrink();
    if (_filteredOrders.isEmpty)
      return Padding(
        padding: const EdgeInsets.only(top: 30.0),
        child: Center(
            child: Text('Заказы по запросу не найдены.',
                style: TextStyle(color: textColorSecondary))),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text('Результаты поиска (${_filteredOrders.length}):',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColorPrimary)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredOrders.length,
          itemBuilder: (context, index) {
            final order = _filteredOrders[index];
            final customerPhone = _orderIdToPhoneMap[order.id] ?? 'Неизвестно';
            final customerDisplay =
                customerUsernames[customerPhone] ?? customerPhone;
            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                title: Text(
                    "Заказ #${order.id.split('_').last} от ${order.orderDate}",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColorPrimary)),
                subtitle: Text(
                    "$customerDisplay | ${_getStatusDisplayName(order.orderStatus)}",
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            textColorSecondary)), // <<<--- Используем читаемый статус
                trailing:
                    Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: () => _showStyledOrderDetailsDialog(
                    context, order), // <<<--- ИСПРАВЛЕННЫЙ ВЫЗОВ
              ),
            );
          },
        ),
      ],
    );
  }
  // --- Конец Виджета Результатов Поиска ---

  // --- Виджет Секции Бронирований ---
  Widget _buildBookingsSection() {
    _todaysBookings.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
    BookingInfo? nextBooking;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (var booking in _todaysBookings) {
      try {
        final parts = booking.timeSlot.split(':');
        final bookingMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        if (bookingMinutes >= nowMinutes) {
          nextBooking = booking;
          break;
        }
      } catch (e) {
        print("Err parsing booking time: ${booking.timeSlot}");
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Забронировано на сегодня (${_todaysBookings.length})',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorPrimary)),
        const SizedBox(height: 12),
        if (_todaysBookings.isEmpty)
          _buildEmptyStateCard(
              Icons.event_busy_outlined, 'На сегодня нет бронирований.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todaysBookings.length,
            itemBuilder: (context, index) {
              final booking = _todaysBookings[index];
              final customerName =
                  customerUsernames[booking.userPhone] ?? booking.userPhone;
              final isNext = booking == nextBooking;
              return Card(
                elevation: isNext ? 3.0 : 1.5,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: isNext ? accentColor : Colors.transparent,
                        width: isNext ? 1.5 : 0)),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  leading: CircleAvatar(
                      backgroundColor: (isNext ? accentColor : primaryColor)
                          .withOpacity(0.1),
                      child: Icon(Icons.access_time_rounded,
                          color: isNext ? accentColor : primaryColor,
                          size: 24)),
                  title: Text(booking.timeSlot,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isNext ? accentColor : textColorPrimary)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 3),
                      Text(customerName,
                          style:
                              TextStyle(fontSize: 14, color: textColorPrimary)),
                      Text(
                          'Заказ #${booking.orderId.replaceFirst("order_", "")}',
                          style: TextStyle(
                              fontSize: 13, color: textColorSecondary)),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
  // --- Конец Виджета Бронирований --

  // --- Виджет Секции Готовых к Выдаче ---
  Widget _buildReadyOrdersSection() {
    final readyOrdersCount =
        _readyOrdersByCustomer.values.expand((list) => list).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Готовы к выдаче ($readyOrdersCount)',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColorPrimary)),
        const SizedBox(height: 12),
        if (_readyOrdersByCustomer.isEmpty)
          _buildEmptyStateCard(
              Icons.check_circle_outline, 'Нет заказов, готовых к выдаче.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _readyOrdersByCustomer.length,
            itemBuilder: (context, index) {
              final customerPhone =
                  _readyOrdersByCustomer.keys.elementAt(index);
              final orders = _readyOrdersByCustomer[customerPhone]!;
              final customerName =
                  customerUsernames[customerPhone] ?? customerPhone;
              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: Icon(Icons.inventory_2_outlined,
                              color: Colors.green.shade700, size: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customerName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: textColorPrimary)),
                            Text(customerPhone,
                                style: TextStyle(
                                    fontSize: 13, color: textColorSecondary)),
                            Text('Готово заказов: ${orders.length}',
                                style: TextStyle(
                                    fontSize: 13, color: textColorSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showReadyOrderDetailsDialog(
                            context, customerPhone, orders),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: Text('Выдать'),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
  // --- Конец Виджета Готовых к Выдаче ---

  // --- Виджет для Отображения Пустого Состояния ---
  Widget _buildEmptyStateCard(IconData icon, String message) {
    return Card(
      elevation: 0.5,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColorSecondary, size: 24),
            const SizedBox(width: 12),
            Text(message,
                style: TextStyle(color: textColorSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
  // --- Конец Виджета Пустого Состояния ---

// --- Конец Вспомогательных Функций и Класса _EmployeeHomeTabState ---

/* ... Код EmployeeHomeTab и других связанных классов (если они есть) ... */
} // <<<--- Убедись, что эта скобка закрывает класс _EmployeeHomeTabState

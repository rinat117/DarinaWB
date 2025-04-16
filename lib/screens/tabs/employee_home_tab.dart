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
  bool _isLoading = true;
  Employee? _employee;
  String _pickupPointId = '';
  String? _pickupPointAddress;
  Map<String, List<Order>> _readyOrdersByCustomer = {};
  List<BookingInfo> _todaysBookings = [];
  Map<String, String> customerUsernames = {}; // Кэш имен клиентов

  // --- Переменные для поиска ---
  List<Order> _allPvzOrders = []; // Хранит ВСЕ заказы этого ПВЗ
  List<Order> _filteredOrders =
      []; // Хранит отфильтрованные для поиска/отображения
  final TextEditingController _searchController = TextEditingController();
  Map<String, String> _orderIdToPhoneMap =
      {}; // Карта для связи ID заказа с телефоном клиента

  @override
  void initState() {
    super.initState();
    // Добавляем слушатель для поиска
    _searchController.addListener(() {
      _filterOrders(_searchController.text);
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose(); // Очищаем контроллер поиска
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
    // Очищаем поиск при обновлении
    // _searchController.clear(); // Очистка здесь может быть нежелательной при pull-to-refresh

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      print("Error: Employee not logged in or email is null");
      if (mounted) setState(() => _isLoading = false);
      // TODO: Рассмотреть возможность выхода на экран логина
      return;
    }

    await _loadEmployeeData(user.email!); // Сначала грузим данные сотрудника
    if (_pickupPointId.isNotEmpty) {
      try {
        // Грузим все параллельно для ускорения
        await Future.wait([
          _loadPickupPointDetails(_pickupPointId),
          _loadReadyOrdersAndUsernames(
              _pickupPointId), // Грузит готовые + кэширует имена
          _loadTodaysBookings(_pickupPointId),
          _loadAllPvzOrders(_pickupPointId), // Грузит ВСЕ заказы
        ]);
      } catch (e) {
        print("Error during concurrent data loading: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Ошибка загрузки данных: $e")));
        }
      }
    } else {
      print(
          "Cannot load details/orders/bookings: pickupPointId is empty after loading employee data");
      // Возможно, показать сообщение пользователю
    }

    // Завершаем загрузку только после всех операций
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
        // Обновляем состояние без setState, т.к. это часть _loadInitialData
        _employee = Employee.fromJson(snapshot.key!, employeeData);
        _pickupPointId = _employee!.pickupPointId;
        print(
            "Employee data loaded: ${_employee?.name}, PP ID: $_pickupPointId");
      } else {
        print("Employee data not found for email: $email (key: $safeEmailKey)");
        _employee = null;
        _pickupPointId = '';
      }
    } catch (e) {
      print("Error loading employee data: $e");
      _employee = null;
      _pickupPointId = '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка загрузки данных сотрудника: $e")));
      }
    }
  }

  Future<void> _loadPickupPointDetails(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    try {
      final snapshot = await dbRef.child('pickup_points/$pickupPointId').get();
      if (mounted && snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        // Обновляем состояние без setState
        _pickupPointAddress = (data['address'] as String?)?.replaceAll('"', '');
        print("Loaded address: $_pickupPointAddress");
      } else {
        print("Pickup point details not found for $pickupPointId");
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
    Map<String, String> usernamesMap = {}; // Временная карта имен

    try {
      final customersSnapshot = await dbRef.child('users/customers').get();
      if (customersSnapshot.exists && customersSnapshot.value != null) {
        final customersData = customersSnapshot.value as Map<dynamic, dynamic>;

        customersData.forEach((phoneKey, customerData) {
          if (phoneKey == null || phoneKey.toString().isEmpty) return;
          final String safePhoneKey = phoneKey.toString();

          if (customerData is Map) {
            final customerMap = customerData as Map<dynamic, dynamic>;
            // Сохраняем имя во временную карту
            usernamesMap[safePhoneKey] =
                customerMap['username']?.toString() ?? safePhoneKey;

            final ordersData = customerMap['orders'];
            if (ordersData is Map) {
              final orders = ordersData as Map<dynamic, dynamic>;
              orders.forEach((orderKey, orderValue) {
                if (orderValue is Map) {
                  final order = Order.fromJson(orderKey, orderValue);
                  // Фильтруем готовые к выдаче для этого ПВЗ
                  if (order.pickupPointId == pickupPointId &&
                      order.orderStatus == 'ready_for_pickup') {
                    if (!readyOrdersMap.containsKey(safePhoneKey)) {
                      readyOrdersMap[safePhoneKey] = [];
                    }
                    readyOrdersMap[safePhoneKey]!.add(order);
                  }
                }
              });
            }
          }
        });
      }
      // Обновляем состояние (без setState, т.к. часть Future.wait)
      _readyOrdersByCustomer = readyOrdersMap;
      customerUsernames = usernamesMap; // Обновляем кэш имен
      print(
          "Loaded ${_readyOrdersByCustomer.length} customers with ready orders.");
    } catch (e) {
      print("Error loading ready orders/usernames: $e");
      _readyOrdersByCustomer = {}; // Сброс при ошибке
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка загрузки заказов к выдаче: $e")));
      }
    }
  }

  Future<void> _loadTodaysBookings(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<BookingInfo> bookingsList = [];
    print("Loading bookings for date: $todayDate");

    try {
      final snapshot =
          await dbRef.child('bookings/$pickupPointId/$todayDate').get();
      if (snapshot.exists && snapshot.value != null) {
        print("Raw Bookings Snapshot for $todayDate: ${snapshot.value}");
        final bookedSlots = snapshot.value as Map<dynamic, dynamic>;
        bookedSlots.forEach((timeSlot, bookingData) {
          print("Processing booking slot: $timeSlot, data: $bookingData");
          if (bookingData is Map) {
            bookingsList.add(BookingInfo.fromJson(timeSlot, bookingData));
          }
        });
        bookingsList.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      } else {
        print("No bookings found in snapshot for $todayDate");
      }
      // Обновляем состояние (без setState)
      _todaysBookings = bookingsList;
      print("Loaded ${_todaysBookings.length} bookings for today.");
    } catch (e) {
      print("Error loading today's bookings: $e");
      _todaysBookings = []; // Сброс при ошибке
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка загрузки бронирований: $e")));
      }
    }
  }

  Future<void> _loadAllPvzOrders(String pickupPointId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    List<Order> allOrders = [];
    Map<String, String> orderIdToPhone = {}; // Временная карта

    try {
      final customersSnapshot = await dbRef.child('users/customers').get();
      if (customersSnapshot.exists && customersSnapshot.value != null) {
        final customersData = customersSnapshot.value as Map<dynamic, dynamic>;
        customersData.forEach((phoneKey, customerData) {
          if (phoneKey == null || phoneKey.toString().isEmpty) return;
          final String safePhoneKey = phoneKey.toString();

          if (customerData is Map) {
            // Кэшируем имя, если его еще нет (на случай, если клиент не в _readyOrdersByCustomer)
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
                    // Фильтр только по ПВЗ
                    allOrders.add(order);
                    orderIdToPhone[order.id] = safePhoneKey; // Сохраняем связь
                  }
                }
              });
            }
          }
        });
      }
      // Обновляем состояние (без setState)
      allOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate)); // Сортируем
      _allPvzOrders = allOrders;
      _orderIdToPhoneMap = orderIdToPhone; // Сохраняем карту
      _filteredOrders = []; // Сбрасываем фильтр при полной загрузке
      print(
          "Loaded ${_allPvzOrders.length} total orders for PVZ $pickupPointId");
    } catch (e) {
      print("Error loading all orders: $e");
      _allPvzOrders = []; // Сброс при ошибке
      _filteredOrders = [];
      _orderIdToPhoneMap = {};
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка загрузки всех заказов: $e")));
      }
    }
  }

  // --- Функция Фильтрации/Поиска ---
  void _filterOrders(String query) {
    final lowerCaseQuery = query.trim().toLowerCase();

    if (lowerCaseQuery.isEmpty) {
      setState(() =>
          _filteredOrders = []); // Показываем пустой список, если поиск пуст
      return;
    }

    // Фильтруем основной список _allPvzOrders
    final filtered = _allPvzOrders.where((order) {
      // Поиск по ID заказа
      if (order.id.toLowerCase().contains(lowerCaseQuery)) {
        return true;
      }
      // Поиск по Коду товара (бывший артикул)
      if (order.items
          .any((item) => item.article.toLowerCase().contains(lowerCaseQuery))) {
        return true;
      }
      // Поиск по телефону или имени клиента
      final customerPhone =
          _orderIdToPhoneMap[order.id]; // Получаем телефон из карты
      if (customerPhone != null) {
        if (customerPhone.contains(lowerCaseQuery))
          return true; // Поиск по номеру
        final customerName =
            customerUsernames[customerPhone]?.toLowerCase() ?? '';
        if (customerName.contains(lowerCaseQuery))
          return true; // Поиск по имени
      }
      return false;
    }).toList();

    setState(() {
      _filteredOrders = filtered; // Обновляем список для отображения
    });
  }

  // --- Диалог деталей ГОТОВЫХ заказов ---
  void _showReadyOrderDetailsDialog(
      BuildContext context, String customerPhone, List<Order> orders) {
    String customerDisplay = customerUsernames[customerPhone] ?? customerPhone;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Готовые заказы для $customerDisplay'),
          content: Container(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: orders.length,
              separatorBuilder: (context, index) => Divider(height: 15),
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
                          contentPadding: EdgeInsets.symmetric(vertical: 2),
                          leading: GestureDetector(
                            onTap: () => showPickupCodeDialog(
                                context, item.qrCode, item.article),
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
                          title: Text("Код: ${item.article}"),
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

  // --- Отметка ГОТОВЫХ заказов как выданных ---
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
          updates[bookingPath] = null; // Удаляем бронь
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Заказы отмечены как выданные!')));
        // Перезагружаем данные, чтобы списки обновились
        await _loadInitialData(); // Проще перезагрузить всё
      }
    } catch (e) {
      Navigator.of(context).pop();
      print("Error marking orders as delivered: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка обновления статуса заказов: $e')));
      }
    }
  }

  // --- НОВЫЙ Диалог Деталей ЛЮБОГО Заказа ---
  void _showOrderDetailsPopup(BuildContext context, Order order) {
    final customerPhone = _orderIdToPhoneMap[order.id] ?? 'Не найден';
    final customerDisplay = customerUsernames[customerPhone] ?? customerPhone;
    final List<String> possibleStatuses = [
      'pending', 'in_transit',
      'ready_for_pickup', // Можно добавить/убрать ненужные
    ].toSet().toList(); // Убираем дубликаты

    // 2. Получаем текущий статус заказа из объекта order
    String? currentOrderStatusFromOrder = order.orderStatus;

    // 3. Проверяем, есть ли текущий статус заказа в нашем списке допустимых
    if (!possibleStatuses.contains(currentOrderStatusFromOrder)) {
      print(
          "Warning: Order status '$currentOrderStatusFromOrder' from DB is not in the possibleStatuses list for Dropdown. Displaying as unknown.");
      // Если статуса нет в списке, мы не можем его выбрать в Dropdown.
      // Либо добавляем его в possibleStatuses, либо обрабатываем как неизвестный.
      // Установим selectedStatus в null, чтобы Dropdown показал hint.
      currentOrderStatusFromOrder = null;
    }
    // Используем проверенный статус для инициализации Dropdown
    String? selectedStatus = currentOrderStatusFromOrder;
    // --- КОНЕЦ ИСПРАВЛЕНИЯ СТАТУСОВ ---

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(// Нужен для обновления Dropdown
            builder: (BuildContext context, StateSetter setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
              ),
              child: Wrap(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text('Детали заказа ${order.id}',
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          icon: Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  Divider(height: 20),
                  Text('Клиент: $customerDisplay' +
                      (customerPhone != 'Не найден'
                          ? ' ($customerPhone)'
                          : '')),
                  Text('Дата: ${order.orderDate}'),
                  SizedBox(height: 8),
                  OrderStatusIndicator(
                      orderStatus: selectedStatus ?? order.orderStatus),
                  SizedBox(height: 12),
                  Text('Товары:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (order.items.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Нет товаров в заказе.'))
                  else
                    Container(
                      constraints: BoxConstraints(maxHeight: 150),
                      child: ListView(
                        shrinkWrap: true,
                        children: order.items
                            .map((item) => ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 0),
                                  leading: GestureDetector(
                                    onTap: () => showPickupCodeDialog(
                                        context, item.qrCode, item.article),
                                    child: QrImageView(
                                      data: item.qrCode.isNotEmpty
                                          ? item.qrCode
                                          : 'no-qr-code',
                                      version: QrVersions.auto,
                                      size: 40.0,
                                      gapless: false,
                                      errorStateBuilder: (cxt, err) => SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Center(
                                              child: Icon(Icons.error_outline,
                                                  color: Colors.red))),
                                    ),
                                  ),
                                  title: Text("Код: ${item.article}",
                                      style: TextStyle(fontSize: 14)),
                                  subtitle: Text("Кол-во: ${item.quantity}",
                                      style: TextStyle(fontSize: 13)),
                                  trailing: IconButton(
                                    icon: Icon(Icons.copy_outlined,
                                        size: 18, color: Colors.grey),
                                    tooltip: 'Копировать код',
                                    iconSize: 18,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                    onPressed: () {
                                      if (item.article.isNotEmpty &&
                                          item.article != 'N/A') {
                                        Clipboard.setData(ClipboardData(
                                                text: item.article))
                                            .then((_) =>
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Код "${item.article}" скопирован!'),
                                                  duration:
                                                      Duration(seconds: 1),
                                                )));
                                      }
                                    },
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  SizedBox(height: 16),
                  Text('Изменить статус:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value:
                        selectedStatus, // Используем selectedStatus (который может быть null)
                    isExpanded: true,
                    items: possibleStatuses.map((String statusValue) {
                      return DropdownMenuItem<String>(
                        value: statusValue,
                        // TODO: Отображать человекопонятные названия статусов
                        child: Text(statusValue),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          selectedStatus = newValue;
                        });
                      }
                    },
                    // Подсказка, если статус не выбран или некорректен
                    hint: Text(currentOrderStatusFromOrder == null
                        ? "Статус: ${order.orderStatus} (неизвестный)"
                        : "Выберите новый статус"),
                  ),
                  SizedBox(height: 20),
                  Row(
                    // Кнопки
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Отмена'),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        // Кнопка активна, если статус выбран И он отличается от исходного статуса заказа
                        onPressed: (selectedStatus != null &&
                                selectedStatus != order.orderStatus)
                            ? () async {
                                await _updateOrderStatus(order,
                                    selectedStatus!); // Передаем выбранный статус
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text('Сохранить статус'),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          );
        });
      },
    );
  }
  // --- Конец НОВОГО Диалога ---

  // --- ОБНОВЛЕНИЕ: Функция _updateOrderStatus теперь принимает customerPhone ---
  Future<void> _updateOrderStatus(Order order, String newStatus) async {
    // Используем _orderIdToPhoneMap для получения телефона
    final customerPhone = _orderIdToPhoneMap[order.id];
    if (customerPhone == null || customerPhone.isEmpty) {
      print("Error: Could not find customer phone for order ${order.id}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: Не найден клиент для заказа.')));
      }
      return;
    }
    final dbRef = FirebaseDatabase.instance.ref();
    final orderStatusPath =
        'users/customers/$customerPhone/orders/${order.id}/order_status';
    print(
        "Updating status for order ${order.id} at path $orderStatusPath to $newStatus");

    // Показываем индикатор загрузки
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()));

    try {
      await dbRef.child(orderStatusPath).set(newStatus);
      Navigator.of(context).pop(); // Убираем индикатор

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Статус заказа "${order.id}" обновлен на "$newStatus"!')));
        // Перезагружаем все данные, чтобы списки обновились
        await _loadInitialData();
      }
    } catch (e) {
      Navigator.of(context).pop(); // Убираем индикатор при ошибке
      print("Error updating order status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка обновления статуса: $e')));
      }
    }
  }
  // --- Конец функции обновления статуса ---

  // --- Функция Выхода ---
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      print("Employee signed out");
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print("Error signing out: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Ошибка выхода: $e")));
      }
    }
  }

  // --- ОСНОВНОЙ МЕТОД BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сегодня'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: _signOut,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // --- Приветствие и Адрес ПВЗ ---
                    Text(
                      'Добрый день, ${_employee?.name ?? 'Сотрудник'}!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_pickupPointAddress != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Пункт выдачи на $_pickupPointAddress',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // --- Секция "Ожидается к выдаче" ---
                    Text(
                      'Ожидается к выдаче (${_readyOrdersByCustomer.values.expand((list) => list).length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.deepPurple[700]),
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
                            // Список готовых к выдаче
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _readyOrdersByCustomer.length,
                            itemBuilder: (context, index) {
                              final customerPhone =
                                  _readyOrdersByCustomer.keys.elementAt(index);
                              final orders =
                                  _readyOrdersByCustomer[customerPhone]!;
                              final customerName =
                                  customerUsernames[customerPhone] ??
                                      customerPhone;
                              return Card(
                                elevation: 2,
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  subtitle:
                                      Text('Готовых заказов: ${orders.length}'),
                                  trailing: Icon(Icons.arrow_forward_ios,
                                      size: 16, color: Colors.grey),
                                  onTap: () => _showReadyOrderDetailsDialog(
                                      context, customerPhone, orders),
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
                            // Список броней
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _todaysBookings.length,
                            itemBuilder: (context, index) {
                              final booking = _todaysBookings[index];
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  subtitle:
                                      Text('Заказ ID: ${booking.orderId}'),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 24),

                    // --- НОВЫЙ БЛОК: Поиск Заказа ---
                    Text(
                      'Поиск заказа',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.deepPurple[700]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ID заказа, Код товара, Телефон/Имя...',
                        prefixIcon:
                            Icon(Icons.search, color: Colors.deepPurple),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                      // onChanged больше не нужен, используем listener
                    ),
                    const SizedBox(height: 12),

                    // --- Список найденных заказов ---
                    if (_searchController.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                            child: Text('Введите запрос для поиска заказа.',
                                style: TextStyle(color: Colors.grey))),
                      )
                    else if (_filteredOrders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                            child: Text(
                                'Заказы по запросу "${_searchController.text}" не найдены.',
                                style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          final customerPhone =
                              _orderIdToPhoneMap[order.id] ?? 'Неизвестно';
                          final customerDisplay =
                              customerUsernames[customerPhone] ?? customerPhone;

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              title: Text(
                                  "Заказ ${order.id} от ${order.orderDate}",
                                  style: TextStyle(fontSize: 14)),
                              subtitle: Text(
                                  "$customerDisplay | Статус: ${order.orderStatus}",
                                  style: TextStyle(fontSize: 13)),
                              trailing: Icon(Icons.chevron_right, size: 20),
                              onTap: () {
                                _showOrderDetailsPopup(context, order);
                              }, // Вызов НОВОГО диалога
                            ),
                          );
                        },
                      ),
                    // --- Конец Секции Поиска ---
                    const SizedBox(height: 20), // Нижний отступ
                  ],
                ),
              ),
      ),
    );
  }
// <<<--- ЗДЕСЬ КОНЕЦ КЛАССА _EmployeeHomeTabState ---
}

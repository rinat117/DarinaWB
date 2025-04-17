// lib/screens/tabs/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для Clipboard
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Для форматирования дат

// Импорты моделей и виджетов
import '../../models/order.dart';
import '../../models/review.dart';
import '../../widgets/order_status_indicator.dart';
import '../../widgets/pickup_code_dialog.dart';

// Импорты экранов для навигации
import '../booking_screen.dart';
import '../login_screen.dart';
import '../pickup_selection_screen.dart';

class ProfileTab extends StatefulWidget {
  final User user; // Текущий пользователь Firebase
  final String pickupPointId; // ID текущего пункта выдачи

  const ProfileTab({
    Key? key,
    required this.user,
    required this.pickupPointId,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  // --- Состояния Виджета ---
  List<Order> _userOrders = []; // Список заказов пользователя для этого ПВЗ
  bool _isLoading = true; // Флаг общей загрузки данных
  String? _username; // Имя пользователя
  Review? _myReview; // Отзыв пользователя об этом ПВЗ
  double _currentRating = 0; // Рейтинг для формы отзыва
  final TextEditingController _commentController =
      TextEditingController(); // Контроллер комментария
  bool _isSavingReview = false; // Флаг сохранения отзыва
  // --- Конец Состояний ---

  @override
  void initState() {
    super.initState();
    _loadData(); // Загружаем все данные при инициализации
  }

  @override
  void dispose() {
    _commentController.dispose(); // Очищаем контроллер при удалении виджета
    super.dispose();
  }

  // --- Функция Выхода из Аккаунта ---
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      print("User signed out");
      // Переход на экран входа с удалением всех предыдущих экранов
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print("Error signing out: $e");
      _showErrorSnackBar("Ошибка выхода: $e"); // Показываем ошибку
    }
  }
  // --- Конец Функции Выхода ---

  // --- Функция Загрузки Всех Данных ---
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _userOrders = [];
      _username = null;
      _myReview = null;
      _currentRating = 0;
      _commentController.clear();
    });

    final databaseReference = FirebaseDatabase.instance.ref();
    final String phoneNumber =
        widget.user.phoneNumber?.replaceAll('+', '') ?? '';
    if (phoneNumber.isEmpty) {
      print("Error: User phone number is empty.");
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackBar("Не удалось получить номер телефона.");
      return;
    }

    try {
      await Future.wait([
        _loadUsername(databaseReference, phoneNumber),
        _loadOrders(databaseReference, phoneNumber),
        _loadReview(databaseReference, phoneNumber),
      ]);
    } catch (e) {
      print("Error during concurrent data loading: $e");
      _showErrorSnackBar("Ошибка загрузки данных профиля.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- Конец Функции Загрузки ---

  // --- Вспомогательные Функции Загрузки ---
  Future<void> _loadUsername(DatabaseReference dbRef, String phone) async {
    if (phone.isEmpty) return;
    try {
      final userSnapshot = await dbRef.child('users/customers/$phone').get();
      if (mounted && userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _username = userData['username'] as String?;
        });
      } else {
        if (mounted) setState(() => _username = null);
      }
    } catch (e) {
      print("Error loading username: $e");
      if (mounted) setState(() => _username = null);
    }
  }

  Future<void> _loadOrders(DatabaseReference dbRef, String phone) async {
    if (phone.isEmpty) {
      if (mounted) setState(() => _userOrders = []);
      return;
    }
    try {
      final ordersSnapshot =
          await dbRef.child('users/customers/$phone/orders').get();
      final List<Order> loadedOrders = [];
      if (ordersSnapshot.exists && ordersSnapshot.value != null) {
        final ordersMap = ordersSnapshot.value as Map<dynamic, dynamic>;
        ordersMap.forEach((key, value) {
          if (value is Map) {
            loadedOrders.add(Order.fromJson(key, value));
          }
        });
      }
      final filteredOrders = loadedOrders
          .where((order) => order.pickupPointId == widget.pickupPointId)
          .toList();
      filteredOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      if (mounted) {
        setState(() {
          _userOrders = filteredOrders;
        });
        print(
            "Filtered orders for pickup point ${widget.pickupPointId}: ${_userOrders.length}");
      }
    } catch (e) {
      print("Error loading orders: $e");
      if (mounted) {
        setState(() => _userOrders = []);
        _showErrorSnackBar("Ошибка загрузки заказов.");
      }
    }
  }

  Future<void> _loadReview(DatabaseReference dbRef, String phone) async {
    if (phone.isEmpty || widget.pickupPointId.isEmpty) {
      if (mounted) {
        setState(() {
          _myReview = null;
          _currentRating = 0;
          _commentController.text = '';
        });
      }
      return;
    }
    try {
      final reviewSnapshot =
          await dbRef.child('reviews/${widget.pickupPointId}/$phone').get();
      Review? loadedReview;
      double loadedRating = 0;
      String loadedComment = '';
      if (reviewSnapshot.exists && reviewSnapshot.value != null) {
        final reviewData = reviewSnapshot.value as Map<dynamic, dynamic>;
        loadedReview = Review.fromJson(reviewData);
        loadedRating = loadedReview.rating;
        loadedComment = loadedReview.comment;
      }
      if (mounted) {
        setState(() {
          _myReview = loadedReview;
          _currentRating = loadedRating;
          _commentController.text = loadedComment;
        });
      }
    } catch (e) {
      print("Error loading review: $e");
      if (mounted) {
        setState(() {
          _myReview = null;
          _currentRating = 0;
          _commentController.text = '';
        });
        _showErrorSnackBar("Ошибка загрузки отзыва.");
      }
    }
  }
  // --- Конец Вспомогательных Функций Загрузки ---

  // --- Функция Сохранения/Обновления Отзыва ---
  Future<void> _saveOrUpdateReview() async {
    if (_currentRating == 0) {
      _showErrorSnackBar('Пожалуйста, выберите рейтинг (1-5 звезд).');
      return;
    }
    if (!mounted) return;

    final String phoneNumber =
        widget.user.phoneNumber?.replaceAll('+', '') ?? '';
    if (phoneNumber.isEmpty || widget.pickupPointId.isEmpty) return;

    setState(() {
      _isSavingReview = true;
    });

    final newReview = Review(
      rating: _currentRating,
      comment: _commentController.text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      final databaseReference = FirebaseDatabase.instance.ref();
      await databaseReference
          .child('reviews/${widget.pickupPointId}/$phoneNumber')
          .set(newReview.toJson());

      if (mounted) {
        setState(() {
          _myReview = newReview;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Отзыв сохранен!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error saving review: $e");
      _showErrorSnackBar('Ошибка сохранения отзыва: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingReview = false;
        });
      }
    }
  }
  // --- Конец Функции Сохранения Отзыва ---

  // --- Функция Отмены Бронирования (с подтверждением) ---
  Future<void> _confirmAndCancelBooking(
      BuildContext context, Order order) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Отмена бронирования'),
          content: Text(
              'Отменить бронирование на ${DateFormat('d MMM, HH:mm', 'ru').format(DateTime.parse(order.bookingSlot!.replaceFirst(' ', 'T')))}?'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Нет')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Да, отменить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator()));

    final String phoneNumber =
        widget.user.phoneNumber?.replaceAll('+', '') ?? '';
    if (phoneNumber.isEmpty ||
        order.bookingSlot == null ||
        order.bookingSlot!.isEmpty) {
      Navigator.of(context).pop();
      _showErrorSnackBar("Ошибка отмены: нет данных для отмены.");
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref();
    final parts = order.bookingSlot!.split(' ');
    if (parts.length != 2) {
      Navigator.of(context).pop();
      _showErrorSnackBar("Ошибка отмены: неверный формат даты брони.");
      return;
    }
    final formattedDate = parts[0];
    final formattedTime = parts[1];

    final String bookingPath =
        'bookings/${widget.pickupPointId}/$formattedDate/$formattedTime';
    final String orderUpdatePath =
        'users/customers/$phoneNumber/orders/${order.id}/booking_slot';

    try {
      Map<String, dynamic> updates = {
        bookingPath: null,
        orderUpdatePath: "" // Или null
      };
      await dbRef.update(updates);

      Navigator.of(context).pop(); // Убираем индикатор

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Бронирование отменено!'),
              backgroundColor: Colors.green),
        );
        await _loadData();
      }
    } catch (e) {
      Navigator.of(context).pop();
      print("Error cancelling booking: $e");
      _showErrorSnackBar('Ошибка отмены бронирования: $e');
    }
  }
  // --- Конец Функции Отмены Бронирования ---

  // --- Функция перехода на экран выбора ПВЗ ---
  void _navigateToPickupSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PickupSelectionScreen()),
    );
  }
  // --- Конец функции перехода ---

  // --- Вспомогательная функция для показа SnackBar ошибок ---
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3)),
      );
    }
  }
  // --- Конец вспомогательной функции ---

  // --- Основной Метод Build ---
  @override
  Widget build(BuildContext context) {
    const double orderCardHeight = 280.0; // Высота карточки заказа
    final Color primaryColor =
        Theme.of(context).primaryColor; // Основной цвет темы

    // Главный виджет - RefreshIndicator для обновления
    return RefreshIndicator(
      onRefresh: _loadData, // Функция, вызываемая при потягивании
      color: primaryColor, // Цвет индикатора обновления
      child: _isLoading // Показываем индикатор или контент
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 16.0), // Отступы для всего списка
              child: ListView(
                // Основной скролл-контейнер
                children: [
                  // --- Карточка Информации о Пользователе ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0), // Горизонтальные отступы
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 16.0), // Паддинги внутри карточки
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              // Строка с аватаром, именем и телефоном
                              children: [
                                CircleAvatar(
                                  radius: 28, // Чуть меньше аватар
                                  backgroundColor:
                                      primaryColor.withOpacity(0.1),
                                  child: Icon(Icons.person_outline,
                                      size: 30, color: primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _username ?? 'Клиент',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.user.phoneNumber ??
                                            'Номер не указан',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                                height: 8), // Отступ перед кнопкой смены ПВЗ
                            // Кнопка "Сменить ПВЗ"
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _navigateToPickupSelection,
                                icon: Icon(Icons.swap_horiz_rounded,
                                    size: 20,
                                    color: primaryColor.withOpacity(0.9)),
                                label: Text('Сменить ПВЗ',
                                    style: TextStyle(
                                        color: primaryColor.withOpacity(0.9),
                                        fontSize: 13)),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                  // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Можно добавить скругление
                                  // overlayColor: primaryColor.withOpacity(0.1), // Эффект при нажатии
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 24), // Отступ после карточки пользователя

                  // --- Секция Заказов ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Мои заказы в этом пункте',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600), // Стиль заголовка
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Сообщение если нет заказов
                  if (_userOrders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        elevation: 0, // Без тени
                        color: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 32.0, horizontal: 16.0),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined,
                                    color: Colors.grey[500], size: 28),
                                SizedBox(width: 16),
                                Text('Здесь пока нет ваших заказов',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey[700])),
                              ]),
                        ),
                      ),
                    )
                  else
                    // PageView для прокрутки заказов
                    SizedBox(
                      height: orderCardHeight,
                      child: PageView.builder(
                        itemCount: _userOrders.length,
                        controller: PageController(
                            viewportFraction: 0.92), // Немного видно соседние
                        itemBuilder: (context, index) {
                          final order = _userOrders[index];
                          final bool canBook =
                              order.orderStatus == 'ready_for_pickup' &&
                                  (order.bookingSlot == null ||
                                      order.bookingSlot!.isEmpty);
                          final bool hasBooking = order.bookingSlot != null &&
                              order.bookingSlot!.isNotEmpty;

                          // --- Карточка Отдельного Заказа ---
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Card(
                              elevation: 2.5, // Легкая тень
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Статус заказа (индикатор)
                                    OrderStatusIndicator(
                                        orderStatus: order.orderStatus),

                                    const SizedBox(height: 12),

                                    // 2. Основная информация (Дата, Кол-во, Сумма)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Заказ от ${order.orderDate}',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600])),
                                            SizedBox(height: 3),
                                            Text(
                                                'Товаров: ${order.items.length}',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600])),
                                          ],
                                        ),
                                        Text('${order.totalPrice} ₽',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),

                                    const Spacer(), // Занимает пространство, прижимая кнопки вниз

                                    // 3. Отображение брони или кнопка бронирования
                                    if (hasBooking)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Row(children: [
                                          Icon(Icons.event_available_rounded,
                                              color: Colors.green.shade700,
                                              size: 18), // Иконка чуть меньше
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Запись: ${DateFormat('d MMM, HH:mm', 'ru').format(DateTime.parse(order.bookingSlot!.replaceFirst(' ', 'T')))}',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.green.shade800),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                _confirmAndCancelBooking(
                                                    context, order),
                                            style: TextButton.styleFrom(
                                                foregroundColor:
                                                    Colors.red.shade400,
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size(30, 30),
                                                visualDensity:
                                                    VisualDensity.compact),
                                            child: Text('Отмена',
                                                style: TextStyle(fontSize: 12)),
                                          ),
                                        ]),
                                      )
                                    else if (canBook)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18),
                                          label: Text('Забронировать время'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.orange.shade700,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                          onPressed: () async {
                                            final result =
                                                await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BookingScreen(
                                                  pickupPointId:
                                                      widget.pickupPointId,
                                                  orderId: order.id,
                                                  userPhoneNumber: widget
                                                          .user.phoneNumber
                                                          ?.replaceAll(
                                                              '+', '') ??
                                                      '',
                                                ),
                                              ),
                                            );
                                            if (result == true && mounted) {
                                              _loadData();
                                            }
                                          },
                                        ),
                                      ),

                                    // Кнопка "Код получения"
                                    SizedBox(
                                        height: hasBooking || canBook ? 8 : 0),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: Icon(Icons.qr_code_2_rounded,
                                            size: 20, color: primaryColor),
                                        label: Text('Код получения',
                                            style: TextStyle(
                                                color: primaryColor,
                                                fontWeight: FontWeight.w500)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: primaryColor
                                                  .withOpacity(0.4)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          padding: EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                        onPressed: () {
                                          if (order.items.isNotEmpty) {
                                            final firstItem = order.items.first;
                                            showPickupCodeDialog(
                                                context,
                                                firstItem.qrCode,
                                                firstItem.article);
                                          } else {
                                            _showErrorSnackBar(
                                                'В заказе нет товаров.');
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          // --- Конец Карточки Заказа ---
                        },
                      ),
                    ),
                  // --- Конец Секции Заказов ---

                  // --- Секция Отзыва ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 0),
                    child: Text(
                      'Мой отзыв о пункте',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Звезды рейтинга
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                  5,
                                  (index) => IconButton(
                                        icon: Icon(
                                          index < _currentRating
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          color: Colors.amber,
                                          size: 35,
                                        ),
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 2),
                                        constraints: BoxConstraints(),
                                        onPressed: () => setState(
                                            () => _currentRating = index + 1.0),
                                      )),
                            ),
                            SizedBox(height: 16),
                            // Поле комментария
                            TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Ваш комментарий (необязательно)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: primaryColor)),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 12.0),
                              ),
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            SizedBox(height: 16),
                            // Кнопка сохранения/обновления
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: _isSavingReview
                                    ? null
                                    : _saveOrUpdateReview,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                child: _isSavingReview
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white)))
                                    : Text(_myReview == null
                                        ? 'Оставить отзыв'
                                        : 'Обновить отзыв'),
                              ),
                            ),
                            // Время последнего обновления отзыва
                            if (_myReview != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Обновлено: ${DateFormat('d MMM yyyy, HH:mm', 'ru').format(DateTime.fromMillisecondsSinceEpoch(_myReview!.timestamp))}',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // --- Конец Секции Отзыва ---

                  // --- Кнопка Выхода ---
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.logout, color: Colors.red.shade400),
                      label: Text('Выйти из аккаунта',
                          style: TextStyle(color: Colors.red.shade400)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _signOut,
                    ),
                  ),
                  // --- Конец Кнопки Выхода ---

                  const SizedBox(height: 20), // Нижний отступ
                ],
              ),
            ),
    );
  }
}

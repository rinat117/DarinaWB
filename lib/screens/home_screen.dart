// lib/screens/home_screen.dart

import 'dart:async'; // Убедись, что он есть
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Оставляем
import '../models/pickup_point.dart';
import '../models/news.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../../widgets/pickup_code_dialog.dart';

class HomeScreen extends StatefulWidget {
  final String? pickupPointId; // ID должен быть строкой 'pickup_point_X'
  final User? user;

  const HomeScreen({Key? key, this.pickupPointId, this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PickupPoint? _pickupPoint;
  List<News> _newsList = [];
  List<Order> _userOrders = [];
  // pickupPointId теперь берется из widget.pickupPointId
  bool _isLoading = true;

  // --- (initState остается) ---
  @override
  void initState() {
    super.initState();
    // pickupPointId = widget.pickupPointId; // Эта строка больше не нужна
    print("HomeScreen initialized with pickupPointId: ${widget.pickupPointId}");
    print("User: ${widget.user?.phoneNumber}");
    _loadData();
  }

  Future<void> _loadData() async {
    // ... (начало функции _loadData без изменений) ...
    setState(() {
      _isLoading = true;
      _pickupPoint = null; // Сбрасываем перед загрузкой
      _newsList = [];
      _userOrders = [];
    });

    final databaseReference = FirebaseDatabase.instance.ref();

    // Загрузка данных пункта выдачи
    if (widget.pickupPointId != null && widget.pickupPointId!.isNotEmpty) {
      // Используем ID из виджета
      print("Loading pickup point data for ID: ${widget.pickupPointId}");
      try {
        // Добавим try-catch для безопасности
        final pickupPointSnapshot = await databaseReference
            .child(
                'pickup_points/${widget.pickupPointId}') // Используем ID из виджета
            .get();

        if (mounted &&
            pickupPointSnapshot.exists &&
            pickupPointSnapshot.value != null) {
          final data = pickupPointSnapshot.value as Map<dynamic, dynamic>;

          // --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
          // Парсим ID из строки ключа
          int parsedId = 0;
          try {
            parsedId = int.parse(
                widget.pickupPointId!.replaceAll('pickup_point_', ''));
          } catch (e) {
            print(
                "Error parsing id from widget.pickupPointId '${widget.pickupPointId}': $e");
          }

          // Вспомогательная функция для парсинга списка строк (как в модели)
          List<String> _parseStringList(dynamic list) {
            if (list is List) {
              return list
                  .map((item) => item?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
            return [];
          }

          setState(() {
            _pickupPoint = PickupPoint(
              id: parsedId, // Используем распарсенный ID
              name: data['name']?.toString() ?? 'Без названия',
              address: data['address']?.toString() ?? 'Адрес не указан',
              phone: data['phone']?.toString() ?? '',
              workingHours:
                  data['working_hours']?.toString() ?? 'Часы не указаны',
              latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
              // --- ДОБАВЛЕНЫ НЕДОСТАЮЩИЕ ПОЛЯ ---
              ratingValue: (data['rating_value'] as num?)?.toDouble() ?? 0.0,
              ratingCount: (data['rating_count'] as num?)?.toInt() ?? 0,
              imageUrls:
                  _parseStringList(data['image_urls']), // Используем хелпер
              phoneFormatted: data['phone_formatted']?.toString() ?? '',
              // --- КОНЕЦ ДОБАВЛЕННЫХ ПОЛЕЙ ---
            );
            print("PickupPoint loaded successfully: ${_pickupPoint?.name}");
          });
          // --- КОНЕЦ ИСПРАВЛЕНИЯ ---
        } else {
          print("Pickup point ${widget.pickupPointId} not found");
          if (mounted)
            setState(() => _pickupPoint = null); // Обнуляем если не найден
        }
      } catch (e) {
        print("Error loading pickup point data in HomeScreen: $e");
        if (mounted) setState(() => _pickupPoint = null); // Обнуляем при ошибке
      }
    } else {
      print("Error: pickupPointId is null or empty in HomeScreen.");
      if (mounted) setState(() => _pickupPoint = null);
    }

    // --- (Загрузка новостей и заказов остается БЕЗ ИЗМЕНЕНИЙ) ---
    // ... (код загрузки новостей) ...
    // ... (код загрузки заказов) ...

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- (build метод остается БЕЗ ИЗМЕНЕНИЙ, он уже использует _pickupPoint?) ---
  @override
  Widget build(BuildContext context) {
    // Добавим проверку isLoading в начало build метода
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('WB Пункт'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }

    // Основной Scaffold возвращается, если загрузка завершена
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _pickupPoint?.name ?? 'WB Пункт'), // Используем имя из _pickupPoint
        backgroundColor: Colors.deepPurple,
      ),
      body: _pickupPoint == null
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 40),
                  SizedBox(height: 10),
                  Text(
                    'Пункт выдачи (${widget.pickupPointId ?? 'ID не указан'}) не найден или не удалось загрузить данные.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    // Кнопка перезагрузки
                    icon: Icon(Icons.refresh),
                    label: Text('Попробовать снова'),
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple),
                  )
                ],
              ),
            ))
          : RefreshIndicator(
              // Добавляем возможность обновить потянув вниз
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  // --- Используем данные из _pickupPoint ---
                  Text(
                    _pickupPoint!
                        .name, // Теперь можно использовать ! т.к. проверили на null
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_pickupPoint!.address)), // Используем !
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      // Показываем форматированный номер, если есть, иначе обычный
                      Text(_pickupPoint!.phoneFormatted.isNotEmpty
                          ? _pickupPoint!.phoneFormatted
                          : _pickupPoint!.phone),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined,
                          color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Text(_pickupPoint!.workingHours), // Используем !
                    ],
                  ),
                  // --- Конец использования данных из _pickupPoint ---

                  const SizedBox(height: 16),
                  const SizedBox(
                    // Карта (заглушка)
                    height: 200,
                    child: Placeholder(
                      color: Colors.grey,
                      child: Center(child: Text('Карта')),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Новости (остается без изменений) ---
                  const Text(
                    'Новости',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_newsList.isEmpty)
                    const Text('Нет новостей для отображения.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ..._newsList.map((news) => Card(
                          // Используем ... для добавления списка виджетов
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.new_releases_outlined),
                            title: Text(news.title),
                            subtitle: Text(news.description),
                          ),
                        )),

                  const SizedBox(height: 16),
                  // --- Заказы (остается без изменений) ---
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
                            Icon(Icons.inbox_outlined, color: Colors.grey),
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
                    ..._userOrders.map((order) => Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                // Используем builder для товаров внутри заказа
                                ListView.builder(
                                    shrinkWrap:
                                        true, // Важно для вложенных списков
                                    physics:
                                        NeverScrollableScrollPhysics(), // Отключаем скролл вложенного списка
                                    itemCount: order.items.length,
                                    itemBuilder: (context, itemIndex) {
                                      final item = order.items[itemIndex];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 0),
                                        leading: GestureDetector(
                                          // Оборачиваем QR в GestureDetector
                                          onTap: () {
                                            // Показываем диалог при тапе
                                            // Убедимся, что qrCode не пустой перед показом
                                            if (item.qrCode.isNotEmpty) {
                                              // Используем функцию из pickup_code_dialog.dart
                                              showPickupCodeDialog(context,
                                                  item.qrCode, item.article);
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'QR-код для этого товара недоступен.')),
                                              );
                                            }
                                          },
                                          child: SizedBox(
                                            // Задаем размер контейнера для QR
                                            width: 50,
                                            height: 50,
                                            child: QrImageView(
                                              data: item.qrCode.isNotEmpty
                                                  ? item.qrCode
                                                  : "no-qr-code", // Обработка пустого QR
                                              version: QrVersions.auto,
                                              size: 50.0, // Размер QR
                                              gapless:
                                                  false, // Пробелы между модулями
                                              errorStateBuilder: (cxt, err) {
                                                // Обработка ошибок генерации QR
                                                return Center(
                                                    child: Icon(
                                                        Icons.error_outline,
                                                        color: Colors.red,
                                                        size: 20));
                                              },
                                            ),
                                          ),
                                        ),
                                        title: Text('Артикул: ${item.article}'),
                                        subtitle:
                                            Text('Кол-во: ${item.quantity}'),
                                      );
                                    }),
                                const SizedBox(height: 8),
                                Align(
                                  // Выравниваем итог по правому краю
                                  alignment: Alignment.centerRight,
                                  child: Text('Итого: ${order.totalPrice} ₽',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
      // Убираем FloatingActionButton отсюда, так как он в DashboardScreen
      // floatingActionButton: FloatingActionButton(...)
    );
  }
}

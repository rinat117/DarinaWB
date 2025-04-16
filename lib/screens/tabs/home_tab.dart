import 'dart:async'; // <<<--- Добавить импорт
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// Импорты моделей - убедись, что пути верные
import '../../models/pickup_point_details.dart'; // <<<--- Используем детальную модель
import '../../models/news.dart';

class HomeTab extends StatefulWidget {
  final String pickupPointId;

  const HomeTab({Key? key, required this.pickupPointId}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  PickupPointDetails? _pickupPointDetails; // <<<--- Используем детальную модель
  List<News> _newsList = [];
  bool _isLoading = true;
  StreamSubscription? _pickupPointSubscription; // <<<--- Подписка на ПВЗ
  StreamSubscription? _newsSubscription; // <<<--- Подписка на новости
  StreamSubscription? _pointNewsSubscription; // <<<--- Подписка на новости ПВЗ

  @override
  void initState() {
    super.initState();
    _startListeners();
  }

  @override
  void dispose() {
    // Отменяем все подписки при удалении виджета
    _pickupPointSubscription?.cancel();
    _newsSubscription?.cancel();
    _pointNewsSubscription?.cancel();
    super.dispose();
  }

  void _startListeners() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final databaseReference = FirebaseDatabase.instance.ref();

    // --- Слушатель для данных ПВЗ ---
    _pickupPointSubscription = databaseReference
        .child('pickup_points/${widget.pickupPointId}')
        .onValue // Используем onValue для получения обновлений
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          // Используем fromJson из детальной модели
          _pickupPointDetails =
              PickupPointDetails.fromJson(widget.pickupPointId, data);
        });
      } else {
        print("Pickup point ${widget.pickupPointId} not found or removed.");
        setState(() => _pickupPointDetails = null); // Сбрасываем, если удалили
      }
      // Убираем isLoading только после первой загрузки или если ПВЗ нет
      if (_isLoading) setState(() => _isLoading = false);
    }, onError: (error) {
      print("Error listening to pickup point data: $error");
      if (mounted) setState(() => _isLoading = false);
      // Показать ошибку пользователю
    });

    // --- Слушатель для общих новостей ---
    _newsSubscription = databaseReference.child('news').onValue.listen((event) {
      _updateNewsList(); // Вызываем общую функцию обновления новостей
    }, onError: (error) => print("Error listening to global news: $error"));

    // --- Слушатель для новостей ПВЗ ---
    _pointNewsSubscription = databaseReference
        .child('pickup_point_news/${widget.pickupPointId}')
        .onValue
        .listen((event) {
      _updateNewsList(); // Вызываем общую функцию обновления новостей
    },
            onError: (error) =>
                print("Error listening to pickup point news: $error"));
  }

  // --- Функция для обновления списка новостей (общих и ПВЗ) ---
  Future<void> _updateNewsList() async {
    if (!mounted) return;
    final databaseReference = FirebaseDatabase.instance.ref();
    final List<News> combinedNewsList = [];

    try {
      // Загрузка общих новостей
      final newsSnapshot = await databaseReference.child('news').get();
      if (newsSnapshot.exists && newsSnapshot.value != null) {
        final newsMap = newsSnapshot.value as Map<dynamic, dynamic>;
        newsMap.forEach((key, value) {
          if (value is Map) {
            // Используем модель News (если она у тебя есть)
            // combinedNewsList.add(News.fromJson(key, value));
            // Пока простой парсинг:
            combinedNewsList.add(News(
              id: 0, // ID из ключа может быть не числом, упрощаем
              title: value['title']?.toString() ?? 'Без заголовка',
              description: value['description']?.toString() ?? '',
              // imageUrl: value['image_url']?.toString(), // Если есть картинка
              // date: value['date']?.toString(), // Если есть дата
            ));
          }
        });
      }

      // Загрузка новостей ПВЗ
      final pointNewsSnapshot = await databaseReference
          .child('pickup_point_news/${widget.pickupPointId}')
          .get();
      if (pointNewsSnapshot.exists && pointNewsSnapshot.value != null) {
        final pointNewsMap = pointNewsSnapshot.value as Map<dynamic, dynamic>;
        pointNewsMap.forEach((key, value) {
          if (value is Map) {
            combinedNewsList.add(News(
              id: 0,
              title: value['title']?.toString() ?? 'Без заголовка',
              description: value['description']?.toString() ?? '',
            ));
          }
        });
      }

      // TODO: Добавить сортировку новостей по дате, если она есть

      if (mounted) {
        setState(() {
          _newsList = combinedNewsList;
        });
      }
    } catch (e) {
      print("Error updating news list: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pickupPointDetails?.name ??
            'Пункт выдачи'), // Используем имя из деталей
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pickupPointDetails == null
              ? const Center(
                  child: Text('Не удалось загрузить данные пункта выдачи.'))
              : RefreshIndicator(
                  // Добавляем RefreshIndicator и сюда
                  onRefresh: () async {
                    _startListeners();
                  }, // Перезапускаем слушатели
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: <Widget>[
                      // Используем данные из _pickupPointDetails
                      Text(
                        _pickupPointDetails!.name, // Теперь не будет null
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
                          Expanded(child: Text(_pickupPointDetails!.address)),
                        ],
                      ), // Expanded для адреса
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(_pickupPointDetails!.phoneFormatted.isNotEmpty
                              ? _pickupPointDetails!.phoneFormatted
                              : _pickupPointDetails!.phone),
                        ],
                      ), // Показываем форматированный телефон
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(_pickupPointDetails!.workingHours),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Отображение Описания
                      if (_pickupPointDetails!.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_pickupPointDetails!.description,
                              style: TextStyle(color: Colors.grey[700])),
                        ),
                      // Отображение Услуг
                      if (_pickupPointDetails!.services.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Услуги:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _pickupPointDetails!.services
                              .map((service) => Chip(
                                    label: Text(service),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                  ))
                              .toList(),
                        )
                      ],
                      const SizedBox(height: 16),
                      // Карта (пока заглушка)
                      SizedBox(
                        height: 200,
                        child: Placeholder(
                          color: Colors.grey,
                          child: Center(child: Text('Карта')),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Новости
                      const Text(
                        'Новости',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ), // Чуть меньше заголовок
                      const SizedBox(height: 8),
                      if (_newsList.isEmpty)
                        const Text('Нет новостей для отображения.',
                            style: TextStyle(color: Colors.grey))
                      else
                        ListView.builder(
                          // Используем builder для новостей
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _newsList.length,
                          itemBuilder: (context, index) {
                            final news = _newsList[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              elevation: 1,
                              child: ListTile(
                                // leading: news.imageUrl != null ? Image.network(news.imageUrl!, width: 50, height: 50, fit: BoxFit.cover) : Icon(Icons.new_releases_outlined), // Если есть картинка
                                leading: Icon(Icons.new_releases_outlined),
                                title: Text(news.title),
                                subtitle: Text(news.description),
                                // trailing: news.date != null ? Text(news.date!, style: TextStyle(fontSize: 12, color: Colors.grey)) : null, // Если есть дата
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
      // --- УБИРАЕМ КНОПКУ ЧАТА ОТСЮДА ---
      // floatingActionButton: FloatingActionButton(...)
      // ---
    );
  }
}

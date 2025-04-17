// lib/screens/tabs/home_tab.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart'; // <<<--- Импорт карусели
// Импорты моделей остаются
import '../../models/pickup_point_details.dart';
import '../../models/news.dart';

class HomeTab extends StatefulWidget {
  final String pickupPointId;
  const HomeTab({Key? key, required this.pickupPointId}) : super(key: key);
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  PickupPointDetails? _pickupPointDetails;
  List<News> _newsList = [];
  bool _isLoading = true;
  StreamSubscription? _pickupPointSubscription;
  StreamSubscription? _newsSubscription;
  StreamSubscription? _pointNewsSubscription;
  int _currentCarouselIndex = 0; // <<<--- Индекс для карусели

  // --- Цвета для дизайна ---
  final Color primaryColor = const Color(0xFF7F00FF);
  final Color accentColor = const Color(0xFFCB11AB);
  final Color lightGrey = Colors.grey[200]!;
  final Color mediumGrey = Colors.grey[600]!;
  final Color darkGrey = Colors.grey[800]!;

  @override
  void initState() {
    super.initState();
    _startListeners();
  }

  @override
  void dispose() {
    _pickupPointSubscription?.cancel();
    _newsSubscription?.cancel();
    _pointNewsSubscription?.cancel();
    super.dispose();
  }

  // --- (_startListeners и _updateNewsList остаются БЕЗ ИЗМЕНЕНИЙ) ---
  void _startListeners() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final databaseReference = FirebaseDatabase.instance.ref();

    _pickupPointSubscription = databaseReference
        .child('pickup_points/${widget.pickupPointId}')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _pickupPointDetails =
              PickupPointDetails.fromJson(widget.pickupPointId, data);
          // Сбрасываем индекс карусели при обновлении данных
          if (_pickupPointDetails != null &&
              _pickupPointDetails!.imageUrls.length <= _currentCarouselIndex) {
            _currentCarouselIndex = 0;
          }
        });
      } else {
        print("Pickup point ${widget.pickupPointId} not found or removed.");
        setState(() => _pickupPointDetails = null);
      }
      if (_isLoading) setState(() => _isLoading = false);
    }, onError: (error) {
      print("Error listening to pickup point data: $error");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки данных ПВЗ: $error")),
        );
      }
    });

    _newsSubscription = databaseReference.child('news').onValue.listen((event) {
      _updateNewsList();
    }, onError: (error) => print("Error listening to global news: $error"));

    _pointNewsSubscription = databaseReference
        .child('pickup_point_news/${widget.pickupPointId}')
        .onValue
        .listen((event) {
      _updateNewsList();
    },
            onError: (error) =>
                print("Error listening to pickup point news: $error"));
  }

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
            combinedNewsList.add(News(
              id: 0,
              title: value['title']?.toString() ?? 'Без заголовка',
              description: value['description']?.toString() ?? '',
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

      if (mounted) {
        setState(() {
          _newsList = combinedNewsList;
        });
      }
    } catch (e) {
      print("Error updating news list: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки новостей: $e")),
        );
      }
    }
  }
  // --- Конец неизменных функций ---

  // --- Функция для звонка (остается без изменений) ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      print('Error launching phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось совершить звонок.')),
        );
      }
    }
  }

  // --- Функция открытия карты (теперь не нужна) ---
  // void _openMap() { ... } // <<<--- УДАЛИТЬ ЭТУ ФУНКЦИЮ

  // --- Вспомогательные виджеты (остаются без изменений) ---
  Widget _buildRatingStars(double rating) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    for (int i = 0; i < 5; i++) {
      IconData iconData;
      Color color = Colors.amber;

      if (i < fullStars)
        iconData = Icons.star_rounded;
      else if (i == fullStars && hasHalfStar)
        iconData = Icons.star_half_rounded;
      else {
        iconData = Icons.star_border_rounded;
        color = Colors.grey[350]!;
      }
      stars.add(Icon(iconData, color: color, size: 20));
    }
    if (_pickupPointDetails != null && _pickupPointDetails!.ratingCount > 0) {
      stars.add(const SizedBox(width: 6));
      stars.add(Text(
        '(${_pickupPointDetails!.ratingCount})',
        style: TextStyle(fontSize: 13, color: mediumGrey),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryColor.withOpacity(0.8)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style:
                      TextStyle(fontSize: 14, color: darkGrey, height: 1.3))),
        ],
      ),
    );
  }
  // --- Конец вспомогательных виджетов ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF990099)));
    }
    if (_pickupPointDetails == null) {
      return Center(/* ... (код ошибки без изменений) ... */);
    }

    final List<String> images =
        _pickupPointDetails!.imageUrls; // Получаем список фото

    return RefreshIndicator(
      onRefresh: () async {
        _startListeners();
      },
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            0, 16, 0, 16), // Убираем гориз. отступы, добавляем сверху/снизу
        children: <Widget>[
          // --- Карточка Информации о ПВЗ ---
          // Добавляем внешние отступы для карточки
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Фото ПВЗ (остается как есть)
                  if (_pickupPointDetails!.imageUrls.isNotEmpty)
                    Image.network(
                      _pickupPointDetails!.imageUrls.first,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child; // Возвращаем загруженное изображение
                        } else {
                          // <<<--- Добавляем явный else
                          // Возвращаем индикатор загрузки
                          return Container(
                              height: 160,
                              color: lightGrey,
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null)));
                        }
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // Возвращаем заглушку при ошибке
                        return Container(
                            height: 160,
                            color: lightGrey,
                            child: Icon(Icons.error_outline,
                                color: mediumGrey)); // Достаточно одного return
                      },
                    )
                  else
                    Container(/* ... (заглушка фото) ... */),

                  // Основная информация (остается как есть)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_pickupPointDetails!.name,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: darkGrey)),
                        const SizedBox(height: 8),
                        if (_pickupPointDetails!.ratingValue > 0) ...[
                          _buildRatingStars(_pickupPointDetails!.ratingValue),
                          const SizedBox(height: 12),
                        ],
                        _buildInfoRow(Icons.location_on_outlined,
                            _pickupPointDetails!.address),
                        _buildInfoRow(Icons.access_time_outlined,
                            _pickupPointDetails!.workingHours),
                        if (_pickupPointDetails!.phoneFormatted.isNotEmpty ||
                            _pickupPointDetails!.phone.isNotEmpty)
                          _buildInfoRow(
                              Icons.phone_outlined,
                              _pickupPointDetails!.phoneFormatted.isNotEmpty
                                  ? _pickupPointDetails!.phoneFormatted
                                  : _pickupPointDetails!.phone),
                        if (_pickupPointDetails!.description.isNotEmpty) ...[
                          /*...*/
                        ],
                        if (_pickupPointDetails!.services.isNotEmpty) ...[
                          /*...*/
                        ],
                      ],
                    ),
                  ),
                  // Кнопка "Позвонить" (кнопку "На карте" УДАЛЯЕМ)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      // Кнопка на всю ширину
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.call_outlined,
                            size: 18, color: primaryColor),
                        label: Text('Позвонить',
                            style: TextStyle(color: primaryColor)),
                        onPressed: (_pickupPointDetails!.phone.isNotEmpty ||
                                _pickupPointDetails!.phoneFormatted.isNotEmpty)
                            ? () => _makePhoneCall(
                                _pickupPointDetails!.phoneFormatted.isNotEmpty
                                    ? _pickupPointDetails!.phoneFormatted
                                    : _pickupPointDetails!.phone)
                            : null,
                        style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: primaryColor.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(
                                vertical: 12) // Паддинг кнопки
                            ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          // --- Конец Карточки Информации ---

          // --- НОВАЯ Карусель Фотографий ---
          if (images.isNotEmpty) ...[
            // Показываем карусель только если есть фото
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0), // Отступы для заголовка
              child: Text(
                'Фотографии пункта',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: darkGrey),
              ),
            ),
            const SizedBox(height: 12),
            CarouselSlider.builder(
              itemCount: images.length,
              itemBuilder: (context, index, realIdx) {
                final url = images[index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 5.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: 1000.0, // Ширина для карусели
                      // Индикатор загрузки для каждого фото в карусели
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                            color: lightGrey,
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)));
                      },
                      // Обработка ошибок для каждого фото в карусели
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                            color: lightGrey,
                            child: Icon(Icons.broken_image_outlined,
                                color: mediumGrey));
                      },
                    ),
                  ),
                );
              },
              options: CarouselOptions(
                height: 200.0, // Высота карусели
                autoPlay: images.length > 1, // Автопрокрутка если больше 1 фото
                enlargeCenterPage: true, // Увеличивать центральное фото
                aspectRatio: 16 / 9,
                autoPlayCurve: Curves.fastOutSlowIn,
                enableInfiniteScroll:
                    images.length > 1, // Бесконечная прокрутка
                autoPlayAnimationDuration: Duration(milliseconds: 800),
                viewportFraction: 0.8, // Сколько видно соседних фото
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentCarouselIndex = index; // Обновляем индекс для точек
                  });
                },
              ),
            ),
            // Индикаторы-точки
            if (images.length > 1) // Показываем точки если фото больше одного
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: images.asMap().entries.map((entry) {
                  return GestureDetector(
                    onTap: () {
                      /* TODO: Можно добавить переход по тапу на точку */
                    },
                    child: Container(
                      width: 8.0,
                      height: 8.0,
                      margin:
                          EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : primaryColor)
                            .withOpacity(_currentCarouselIndex == entry.key
                                ? 0.9
                                : 0.3), // Яркая активная точка
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20), // Отступ после карусели
          ],
          // --- Конец Карусели ---

          // --- Заголовок Новостей (добавляем отступ слева/справа) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Новости пункта выдачи',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: darkGrey),
            ),
          ),
          const SizedBox(height: 12),

          // --- Список Новостей (добавляем отступ слева/справа для карточек) ---
          if (_newsList.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Text('Нет актуальных новостей.',
                  style: TextStyle(color: mediumGrey)),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0), // Отступы для списка новостей
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _newsList.length,
              itemBuilder: (context, index) {
                final news = _newsList[index];
                return Card(
                  /* ... (стили карточки новостей без изменений) ... */
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(Icons.campaign_outlined, color: accentColor),
                    title: Text(news.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: darkGrey)),
                    subtitle: Text(news.description,
                        style: TextStyle(fontSize: 13, color: mediumGrey)),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                );
              },
            ),
          const SizedBox(height: 20), // Нижний отступ
        ],
      ),
    );
  }
}

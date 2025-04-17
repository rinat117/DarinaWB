// lib/widgets/pickup_point_card.dart
import 'package:flutter/material.dart';
import '../models/pickup_point.dart';

class PickupPointCard extends StatelessWidget {
  final PickupPoint pickupPoint;
  final VoidCallback onTap;

  const PickupPointCard({
    Key? key,
    required this.pickupPoint,
    required this.onTap,
  }) : super(key: key);

  // Функция для генерации виджета звезд рейтинга
  Widget _buildRatingStars(double rating) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    for (int i = 0; i < 5; i++) {
      IconData iconData;
      Color color = Colors.amber; // Цвет звезд

      if (i < fullStars) {
        iconData = Icons.star_rounded; // Полная звезда
      } else if (i == fullStars && hasHalfStar) {
        iconData = Icons.star_half_rounded; // Половина звезды
      } else {
        iconData = Icons.star_border_rounded; // Пустая звезда
        color = Colors.grey[350]!; // Цвет пустых звезд
      }
      stars.add(Icon(iconData, color: color, size: 18)); // Размер звезд
    }
    // Добавляем количество отзывов, если оно есть
    if (pickupPoint.ratingCount > 0) {
      stars.add(const SizedBox(width: 6));
      stars.add(Text(
        '(${pickupPoint.ratingCount})',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ));
    }

    return Row(children: stars);
  }

  @override
  Widget build(BuildContext context) {
    // Определяем цвета
    final Color primaryColor = Color(0xFF7F00FF); // Основной фиолетовый WB
    final Color accentColor = Color(0xFFCB11AB); // Розовый акцент WB
    final Color textColor = Colors.grey[800]!;
    final Color lightTextColor = Colors.grey[600]!;

    return InkWell(
      // Используем InkWell для эффекта при нажатии
      onTap: onTap,
      borderRadius: BorderRadius.circular(16), // Скругление для эффекта
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15), // Мягкая тень
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              // Тонкая обводка для выделения
              color: Colors.grey[200]!,
              width: 1.0,
            )),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание по верху
          children: [
            // Иконка (можно заменить на фото в будущем)
            // Если есть фото, показываем его, иначе иконку
            if (pickupPoint.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  // Загружаем первое фото
                  pickupPoint.imageUrls.first,
                  width: 55, // Размер фото
                  height: 55,
                  fit: BoxFit.cover,
                  // Обработка ошибок загрузки фото
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.storefront_outlined,
                        color: primaryColor.withOpacity(0.6), size: 30),
                  ),
                  // Индикатор загрузки фото
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      )),
                    );
                  },
                ),
              )
            else // Если фото нет, показываем иконку
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  // Градиент для иконки
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      accentColor.withOpacity(0.1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(8), // Скругление фона иконки
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: primaryColor,
                  size: 30,
                ),
              ),

            const SizedBox(width: 16),
            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название
                  Text(
                    pickupPoint.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Рейтинг
                  if (pickupPoint.ratingValue > 0) ...[
                    _buildRatingStars(pickupPoint.ratingValue),
                    const SizedBox(height: 6),
                  ],

                  // Адрес
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: lightTextColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          pickupPoint.address,
                          style: TextStyle(fontSize: 13, color: lightTextColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Часы работы
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 16, color: lightTextColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          pickupPoint.workingHours,
                          style: TextStyle(fontSize: 13, color: lightTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Иконка "далее"
            // Icon(
            //   Icons.arrow_forward_ios_rounded,
            //   size: 16,
            //   color: Colors.grey[400],
            // ),
          ],
        ),
      ),
    );
  }
}

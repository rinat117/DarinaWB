// lib/widgets/order_status_indicator.dart
import 'package:flutter/material.dart';

// Перечисление возможных этапов заказа
enum OrderStage { warehouse, inTransit, ready, delivered, unknown }

class OrderStatusIndicator extends StatelessWidget {
  final String
      orderStatus; // Статус заказа в виде строки (например, 'ready_for_pickup')

  const OrderStatusIndicator({Key? key, required this.orderStatus})
      : super(key: key);

  // Функция для преобразования строкового статуса в этап OrderStage
  OrderStage _getStage(String status) {
    // Приводим статус к нижнему регистру для надежного сравнения
    status = status.toLowerCase();
    if (status == 'pending' ||
        status == 'processing' ||
        status == 'на складе' ||
        status == 'ожидается отправка') {
      return OrderStage.warehouse;
    } else if (status == 'in_transit' || status == 'в пути') {
      return OrderStage.inTransit;
    } else if (status == 'ready_for_pickup' || status == 'готов к выдаче') {
      return OrderStage.ready;
    } else if (status == 'delivered' ||
        status == 'доставлен' ||
        status == 'выдан') {
      // Добавлены синонимы для "доставлен"
      return OrderStage.delivered;
    }
    // Если статус не распознан, выводим предупреждение и возвращаем unknown
    print("OrderStatusIndicator: Unknown order status received: '$status'");
    return OrderStage.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _getStage(orderStatus);
    final bool isDelivered = currentStage ==
        OrderStage.delivered; // Флаг для определения, доставлен ли заказ

    // --- Цвета и Размеры для Виджета ---
    final Color activeColor =
        Colors.deepPurple.shade400; // Основной активный цвет (чуть светлее)
    final Color readyColor =
        Colors.orange.shade700; // Цвет для статуса "готов к выдаче"
    final Color deliveredColor =
        Colors.green.shade600; // Цвет для статуса "доставлен/получен"
    final Color inactiveColor =
        Colors.grey.shade300; // Цвет неактивных элементов
    final Color textInactiveColor =
        Colors.grey.shade500; // Цвет текста неактивных элементов
    final double iconSize = 26.0; // Размер иконок внутри кругов
    final double circleSize = 40.0; // Диаметр кругов этапов
    final double lineWidth = 2.0; // Толщина линий-соединителей
    // --- Конец Цветов и Размеров ---

    // Определяем, какие этапы и линии активны
    bool stage1Active = currentStage !=
        OrderStage.unknown; // Активен всегда, кроме неизвестного статуса
    bool stage2Active = currentStage == OrderStage.inTransit ||
        currentStage == OrderStage.ready ||
        isDelivered;
    bool stage3Active = currentStage == OrderStage.ready || isDelivered;
    bool stage4Active = isDelivered; // Активен только когда доставлен

    return Padding(
      // Отступы вокруг всего индикатора
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Row(
        // Используем Row для расположения элементов в линию
        mainAxisAlignment:
            MainAxisAlignment.center, // Центрируем по горизонтали
        crossAxisAlignment:
            CrossAxisAlignment.start, // Выравниваем круги и текст по верху
        children: <Widget>[
          // --- ЭТАП 1: На складе ---
          _buildStageCircle(
            icon: Icons.warehouse_outlined, // Иконка склада
            label: 'На складе', // Текст под иконкой
            isActive: stage1Active, // Активен ли этап?
            isCurrent: currentStage == OrderStage.warehouse &&
                !isDelivered, // Является ли текущим? (но не если уже доставлен)
            activeColor: activeColor, // Цвет активного состояния
            inactiveColor: inactiveColor, // Цвет неактивного состояния
            textInactiveColor: textInactiveColor,
            iconSize: iconSize,
            circleSize: circleSize,
          ),
          // Линия-соединитель 1 -> 2
          _buildConnector(
            isActive: stage2Active, // Активна, если активен 2-й этап
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            lineWidth: lineWidth,
          ),
          // --- ЭТАП 2: В пути ---
          _buildStageCircle(
            icon: Icons.local_shipping_outlined, // Иконка грузовика
            label: 'В пути',
            isActive: stage2Active,
            isCurrent: currentStage == OrderStage.inTransit && !isDelivered,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            textInactiveColor: textInactiveColor,
            iconSize: iconSize,
            circleSize: circleSize,
          ),
          // Линия-соединитель 2 -> 3
          _buildConnector(
            isActive: stage3Active, // Активна, если активен 3-й этап
            // Цвет линии зависит от того, доставлен заказ или только готов к выдаче
            activeColor: isDelivered ? deliveredColor : readyColor,
            inactiveColor: inactiveColor,
            lineWidth: lineWidth,
          ),
          // --- ЭТАП 3: В пункте ---
          _buildStageCircle(
            icon: Icons.storefront_outlined, // Иконка пункта выдачи
            label: 'В пункте',
            isActive: stage3Active,
            isCurrent: currentStage == OrderStage.ready &&
                !isDelivered, // Текущий, только если готов к выдаче (не доставлен)
            activeColor: isDelivered
                ? deliveredColor
                : readyColor, // Цвет зависит от конечного статуса
            inactiveColor: inactiveColor,
            textInactiveColor: textInactiveColor,
            iconSize: iconSize,
            circleSize: circleSize,
          ),
          // Линия-соединитель 3 -> 4
          _buildConnector(
            isActive: stage4Active, // Активна, только если доставлен
            activeColor: deliveredColor, // Цвет линии - зеленый
            inactiveColor: inactiveColor,
            lineWidth: lineWidth,
          ),
          // --- ЭТАП 4: Получен ---
          _buildStageCircle(
            icon: Icons.check_circle_outline_rounded, // Иконка галочки
            label: 'Получен',
            isActive: stage4Active, // Активен, только если доставлен
            isCurrent: isDelivered, // Является текущим, если доставлен
            activeColor: deliveredColor, // Зеленый цвет
            inactiveColor: inactiveColor,
            textInactiveColor: textInactiveColor,
            iconSize: iconSize,
            circleSize: circleSize,
          ),
        ],
      ),
    );
  }

  // --- Вспомогательный виджет для отрисовки круга этапа ---
  Widget _buildStageCircle({
    required IconData icon,
    required String label,
    required bool isActive, // Пройден ли этот этап или текущий
    required bool isCurrent, // Является ли этот этап текущим активным
    required Color activeColor,
    required Color inactiveColor,
    required Color textInactiveColor,
    required double iconSize,
    required double circleSize,
  }) {
    // Определяем цвета и стили на основе активности и текущего состояния
    final Color circleBorderColor = isActive ? activeColor : inactiveColor;
    final Color iconColor = isActive ? activeColor : inactiveColor;
    // Цвет текста: активный для текущего, темнее для пройденных, серый для неактивных
    final Color textColor = isActive
        ? (isCurrent ? activeColor : Colors.grey[800]!)
        : textInactiveColor;
    // Толщина рамки: толще для текущего, стандартная для пройденных, тоньше для неактивных
    final double borderThickness = isActive ? (isCurrent ? 2.5 : 1.5) : 1.0;
    // Фон круга: немного цвета для текущего, прозрачный для остальных (кроме неактивных)
    final Color backgroundColor = isActive
        ? (isCurrent ? activeColor.withOpacity(0.12) : Colors.transparent)
        : inactiveColor.withOpacity(0.05); // Легкий фон для неактивных
    // Стиль текста: жирный для текущего
    final FontWeight fontWeight =
        isCurrent ? FontWeight.bold : FontWeight.normal;

    return Column(
      mainAxisSize: MainAxisSize.min, // Занимать минимум места
      children: [
        // Анимированный круг
        AnimatedContainer(
          duration: const Duration(milliseconds: 300), // Плавная анимация
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
              color: backgroundColor, // Фон
              shape: BoxShape.circle, // Форма круга
              border: Border.all(
                  color: circleBorderColor, width: borderThickness), // Рамка
              // Тень только для текущего активного этапа
              boxShadow: [
                if (isActive && isCurrent)
                  BoxShadow(
                    color: activeColor.withOpacity(0.3), // Цвет тени
                    blurRadius: 6, // Размытие тени
                    offset: Offset(0, 2), // Смещение тени
                  )
              ]),
          // Иконка внутри круга
          child: Center(child: Icon(icon, color: iconColor, size: iconSize)),
        ),
        const SizedBox(height: 6), // Отступ между кругом и текстом
        // Текстовая подпись под кругом
        SizedBox(
          width: 60, // Ширина для текста (чтобы помещалось)
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11, // Размер шрифта
              fontWeight: fontWeight, // Жирность шрифта
              color: textColor, // Цвет текста
            ),
            textAlign: TextAlign.center, // Выравнивание по центру
            maxLines: 1, // Максимум одна строка
            overflow: TextOverflow.ellipsis, // Обрезать если не влезает
          ),
        ),
      ],
    );
  }

  // --- Вспомогательный виджет для отрисовки линии-соединителя ---
  Widget _buildConnector({
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required double lineWidth,
  }) {
    // Expanded занимает все доступное место между кругами
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), // Плавная анимация
        height: lineWidth, // Толщина линии
        // Отступы слева/справа от линии, чтобы она не прилипала к кругам
        margin: const EdgeInsets.symmetric(horizontal: 1.0),
        decoration: BoxDecoration(
          // Цвет линии зависит от активности следующего этапа
          color: isActive ? activeColor : inactiveColor,
          // Скругление краев линии
          borderRadius: BorderRadius.circular(lineWidth / 2),
        ),
      ),
    );
  }
}

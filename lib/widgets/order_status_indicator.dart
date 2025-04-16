import 'package:flutter/material.dart';

enum OrderStage { warehouse, inTransit, ready, delivered, unknown }

class OrderStatusIndicator extends StatelessWidget {
  final String orderStatus;

  const OrderStatusIndicator({Key? key, required this.orderStatus})
      : super(key: key);

  OrderStage _getStage(String status) {
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
    } else if (status == 'delivered' || status == 'доставлен') {
      return OrderStage.delivered;
    }
    print("Unknown order status received: $status");
    return OrderStage.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _getStage(orderStatus);
    final Color activeColor = Colors.deepPurple;
    final Color readyColor = Colors.amber[700]!;
    final Color deliveredColor = Colors.green;
    final Color inactiveColor = Colors.grey[300]!;
    final Color textInactiveColor = Colors.grey[600]!;
    final double iconSize = 32.0;
    final double circleSize = 46.0;
    final double lineWidth = 3.0;

    bool stage1Active = currentStage != OrderStage.unknown;
    bool stage2Active = currentStage == OrderStage.inTransit ||
        currentStage == OrderStage.ready ||
        currentStage == OrderStage.delivered;
    bool stage3Active = currentStage == OrderStage.ready ||
        currentStage == OrderStage.delivered;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Stage 1
          _buildStageCircle(
            icon: Icons.warehouse_outlined,
            label: 'На складе',
            isActive: stage1Active,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            textInactiveColor: textInactiveColor,
            iconSize: iconSize,
            circleSize: circleSize,
          ),
          _buildConnector(
              isActive: stage2Active,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              lineWidth: lineWidth),
          // Stage 2
          _buildStageCircle(
            icon: Icons.local_shipping_outlined,
            label: 'В пути',
            isActive: stage2Active,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            textInactiveColor: textInactiveColor,
            iconSize: iconSize,
            circleSize: circleSize,
          ),
          _buildConnector(
              isActive: stage3Active,
              activeColor: readyColor,
              inactiveColor: inactiveColor,
              lineWidth: lineWidth),
          // Stage 3
          _buildStageCircle(
            icon: stage3Active && currentStage == OrderStage.delivered
                ? Icons.check_circle_rounded
                : Icons.storefront_outlined,
            label: stage3Active && currentStage == OrderStage.delivered
                ? 'Доставлен'
                : 'Готов к выдаче',
            isActive: stage3Active,
            activeColor: stage3Active && currentStage == OrderStage.delivered
                ? deliveredColor
                : readyColor,
            inactiveColor: inactiveColor,
            textInactiveColor: textInactiveColor,
            iconSize: iconSize,
            circleSize: circleSize,
          ),
        ],
      ),
    );
  }

  Widget _buildStageCircle({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required Color textInactiveColor,
    required double iconSize,
    required double circleSize,
  }) {
    final Color color = isActive ? activeColor : inactiveColor;
    final Color textColor = isActive ? activeColor : textInactiveColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: isActive
                ? color.withOpacity(0.11)
                : inactiveColor.withOpacity(0.13),
            shape: BoxShape.circle,
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
            ],
            border: Border.all(
              color: color,
              width: isActive ? 2.5 : 1.0,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
              color: textColor,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector({
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required double lineWidth,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        height: lineWidth,
        margin: const EdgeInsets.symmetric(horizontal: 6.0),
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(2.0),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.18),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}

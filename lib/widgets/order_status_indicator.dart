import 'package:flutter/material.dart';

enum OrderStage { warehouse, inTransit, ready, delivered, unknown }

class OrderStatusIndicator extends StatelessWidget {
  final String orderStatus;

  const OrderStatusIndicator({Key? key, required this.orderStatus})
      : super(key: key);

  OrderStage _getStage(String status) {
    status = status.toLowerCase();
    // Added more potential status strings from the database
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
    print("Unknown order status received: $status"); // Log unknown statuses
    return OrderStage.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _getStage(orderStatus);
    final Color activeColor = Colors.deepPurple;
    final Color inactiveColor = Colors.grey[300]!;
    final double iconSize = 24.0;
    final double lineWidth = 2.0; // <<<--- Variable declared here

    // Determine activity based on stage progression
    bool stage1Active = currentStage != OrderStage.unknown;
    bool stage2Active = currentStage == OrderStage.inTransit ||
        currentStage == OrderStage.ready ||
        currentStage == OrderStage.delivered;
    bool stage3Active = currentStage == OrderStage.ready ||
        currentStage == OrderStage.delivered;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the indicator
        children: <Widget>[
          // Stage 1: Warehouse
          _buildStage(
            icon: Icons.warehouse_outlined,
            label: 'На складе',
            isActive: stage1Active,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            iconSize: iconSize,
          ),
          // Connector 1-2
          Expanded(
            child: Container(
              height: lineWidth, // Use the declared variable
              margin: EdgeInsets.symmetric(horizontal: 4.0), // Add some margin
              color: stage2Active ? activeColor : inactiveColor,
            ),
          ),
          // Stage 2: In Transit
          _buildStage(
            icon: Icons.local_shipping_outlined,
            label: 'В пути',
            isActive: stage2Active,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            iconSize: iconSize,
          ),
          // Connector 2-3
          Expanded(
            child: Container(
              height: lineWidth, // Use the declared variable
              margin: EdgeInsets.symmetric(horizontal: 4.0), // Add some margin
              color: stage3Active ? activeColor : inactiveColor,
            ),
          ),
          // Stage 3: Ready for Pickup / Delivered
          _buildStage(
            icon: stage3Active && currentStage == OrderStage.delivered
                ? Icons.check_circle // Filled check for delivered
                : Icons.storefront_outlined, // Storefront for ready
            label: stage3Active && currentStage == OrderStage.delivered
                ? 'Доставлен'
                : 'Готов к выдаче',
            isActive: stage3Active,
            activeColor: stage3Active && currentStage == OrderStage.delivered
                ? Colors.green
                : activeColor, // Green for delivered
            inactiveColor: inactiveColor,
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }

  Widget _buildStage({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required double iconSize,
  }) {
    final Color color = isActive ? activeColor : inactiveColor;
    return Column(
      mainAxisSize: MainAxisSize.min, // Ensure column takes minimum space
      children: [
        Icon(
          icon,
          color: color,
          size: iconSize,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1, // Prevent label wrapping
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

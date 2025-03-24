import 'package:flutter/material.dart';
import '../models/pickup_point.dart'; // Импортируем модель PickupPoint

class PickupPointCard extends StatelessWidget {
  final PickupPoint pickupPoint;
  final VoidCallback onTap;

  const PickupPointCard({
    super.key,
    required this.pickupPoint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(pickupPoint.name),
        subtitle: Text(pickupPoint.address),
        onTap: onTap,
      ),
    );
  }
}

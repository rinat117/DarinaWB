import 'package:flutter/material.dart';
import '../screens/pickup_selection_screen.dart'; // Убедись, что путь к PickupPoint верный

class PickupPointCard extends StatelessWidget {
  final PickupPoint pickupPoint;
  final VoidCallback onTap;

  const PickupPointCard({
    Key? key,
    required this.pickupPoint,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0)), // Больше скругление
        color: Colors.white, // Белый цвет карточки
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                pickupPoint.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple, // Фирменный цвет
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.location_on,
                      color: Colors.grey[600], size: 18), // Цвет иконки
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickupPoint.address,
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[700]), // Цвет адреса
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Можно добавить что-то еще, например, иконку Wildberries или статус "Открыто/Закрыто"
            ],
          ),
        ),
      ),
    );
  }
}
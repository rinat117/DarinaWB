// lib/widgets/pickup_code_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Функция теперь просто void и принимает context
void showPickupCodeDialog(
    BuildContext context, String qrData, String pickupCode) {
  if (qrData.isEmpty && pickupCode.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('QR-код и код получения недоступны')),
    );
    return;
  }

  // Используем showDialog вместо showModalBottomSheet
  showDialog(
    context: context,
    barrierDismissible: true, // Можно закрыть тапом вне диалога
    builder: (BuildContext dialogContext) {
      // Переименовываем context чтобы не путать
      return AlertDialog(
        backgroundColor: Colors.grey[900], // Темный фон диалога
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0), // Сильное скругление
        ),
        contentPadding: EdgeInsets.zero, // Убираем стандартные отступы контента
        insetPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24), // Отступы самого диалога от краев экрана
        content: Container(
          // Обертка для контента
          padding: const EdgeInsets.all(24.0),
          width:
              MediaQuery.of(dialogContext).size.width * 0.85, // Ширина диалога
          constraints: BoxConstraints(maxWidth: 350), // Макс. ширина
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // Занимать минимум места по вертикали
            children: [
              // --- QR Code с белой подложкой ---
              Container(
                padding: EdgeInsets.all(10), // Отступ вокруг QR
                decoration: BoxDecoration(
                  color: Colors.white, // Белая подложка
                  borderRadius:
                      BorderRadius.circular(16.0), // Скругление подложки
                ),
                child: QrImageView(
                  data: qrData.isNotEmpty
                      ? qrData
                      : 'no-data', // Заглушка если нет данных
                  version: QrVersions.auto,
                  size: 180.0, // Размер QR
                  gapless: false,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square, // Квадратные "глаза"
                    color: Colors.black,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    color: Colors.black,
                    dataModuleShape:
                        QrDataModuleShape.square, // Квадратные модули
                  ),
                  errorStateBuilder: (cxt, err) {
                    print("Error generating QR: $err");
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Ошибка\nотображения\nQR-кода',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.red.shade300, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // --- Код получения и кнопка Копировать ---
              Text(
                'Код получения:',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    // Чтобы текст кода переносился если длинный
                    child: Text(
                      pickupCode.isNotEmpty
                          ? pickupCode
                          : '---', // Показываем прочерки если нет кода
                      style: TextStyle(
                        fontSize: 28, // Крупный шрифт для кода
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2, // Разрядка букв/цифр
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (pickupCode
                      .isNotEmpty) // Показываем кнопку только если есть код
                    IconButton(
                      icon: Icon(Icons.content_copy_rounded,
                          color: Colors.grey[400], size: 20),
                      tooltip: 'Скопировать код',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: pickupCode))
                            .then((_) {
                          // Navigator.of(dialogContext).pop(); // Можно закрыть диалог после копирования
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Код "$pickupCode" скопирован!'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors
                                  .green.shade800, // Зеленый фон для успеха
                            ),
                          );
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Информационный текст ---
              Text(
                'Покажите QR-код или назовите код сотруднику пункта выдачи для получения заказа.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[400], height: 1.4),
              ),
              const SizedBox(height: 24),

              // --- Кнопка Закрыть ---
              SizedBox(
                width: double.infinity, // Кнопка на всю ширину
                child: TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor:
                          Colors.white.withOpacity(0.1), // Полупрозрачный фон
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text(
                    'Закрыть',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Закрываем диалог
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

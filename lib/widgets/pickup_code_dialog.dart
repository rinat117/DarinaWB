import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

void showPickupCodeDialog(
    BuildContext context, String qrData, String pickupCode) {
  if (qrData.isEmpty && pickupCode.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('QR-код и код получения недоступны')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF181D29), Color(0xFF232943)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: Offset(0, -6),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- "Ручка" ---
              Container(
                width: 48,
                height: 5,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // --- QR Code ---
              if (qrData.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey[200]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 180,
                    gapless: false,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Colors.indigo,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      color: Colors.indigo[900],
                      dataModuleShape: QrDataModuleShape.circle,
                    ),
                    errorStateBuilder: (cxt, err) => Center(
                        child: Text('Ошибка QR',
                            style: TextStyle(color: Colors.red))),
                  ),
                )
              else
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.indigo[700]!.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      'QR-код\nнедоступен',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // --- Заголовок ---
              Text(
                'Покажите QR-код, чтобы получить заказ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              // --- Альтернативный способ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: Colors.indigo[200]),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Или назовите телефон и код ',
                      style: TextStyle(fontSize: 15, color: Colors.grey[300]),
                    ),
                  ),
                  if (pickupCode.isNotEmpty)
                    Text(
                      pickupCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[200],
                        letterSpacing: 2,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Обновляются ежедневно в 00:00',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Text(
                'Если заказ в постамате, код для него будет в уведомлениях или доставках',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 32),

              // --- Кнопка "Скопировать код" ---
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.blue[100],
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      // foregroundColor: Colors.white, // если нужно
                    ),
                    icon: Icon(Icons.copy_rounded, color: Colors.white),
                    label: Text(
                      'Скопировать код',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                    onPressed: pickupCode.isNotEmpty
                        ? () {
                            Clipboard.setData(ClipboardData(text: pickupCode))
                                .then((_) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Код "$pickupCode" скопирован!'),
                                    duration: Duration(seconds: 1)),
                              );
                            });
                          }
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // --- Кнопка "Закрыть" ---
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                label: Text(
                  'Закрыть',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

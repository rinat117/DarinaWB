import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Для форматирования даты/времени

class BookingScreen extends StatefulWidget {
  final String pickupPointId;
  final String orderId;
  final String userPhoneNumber; // Номер телефона для сохранения брони

  const BookingScreen({
    Key? key,
    required this.pickupPointId,
    required this.orderId,
    required this.userPhoneNumber,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTimeSlot; // Выбранный слот (TimeOfDay для простоты)
  List<TimeOfDay> _availableSlots =
      []; // Список доступных слотов для выбранной даты
  bool _isLoadingSlots = false;
  Map<String, dynamic> _bookedSlots = {}; // Загруженные забронированные слоты

  // TODO: Получить часы работы из pickup_points/{pickupPointId}/working_hours
  // Примерные часы работы для начала:
  final TimeOfDay _startTime = TimeOfDay(hour: 10, minute: 0);
  final TimeOfDay _endTime = TimeOfDay(hour: 21, minute: 0);
  final int _slotDurationMinutes = 15; // Длительность слота

  @override
  void initState() {
    super.initState();
    // Загружаем слоты для начальной даты (сегодня)
    _loadBookedSlotsForDate(_selectedDate);
  }

  // --- Загрузка уже забронированных слотов для выбранной даты ---
  Future<void> _loadBookedSlotsForDate(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _isLoadingSlots = true;
      _availableSlots = []; // Очищаем доступные слоты при смене даты
      _selectedTimeSlot = null; // Сбрасываем выбранный слот
      _bookedSlots = {};
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final dbRef = FirebaseDatabase.instance.ref();

    try {
      final snapshot = await dbRef
          .child('bookings/${widget.pickupPointId}/$formattedDate')
          .get();
      if (mounted && snapshot.exists) {
        setState(() {
          _bookedSlots = snapshot.value as Map<String, dynamic>;
        });
      } else {
        setState(() {
          _bookedSlots = {}; // Убедимся, что пусто, если нет данных
        });
      }
      _generateAvailableSlots(); // Генерируем доступные слоты после загрузки занятых
    } catch (e) {
      print("Error loading booked slots: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки слотов: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  // --- Генерация доступных слотов на основе рабочих часов и занятых слотов ---
  void _generateAvailableSlots() {
    List<TimeOfDay> slots = [];
    DateTime now = DateTime.now();
    DateTime currentSlotTime = DateTime(
      _selectedDate.year,
      _selectedDate.year,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final DateTime endTime = DateTime(
      _selectedDate.year,
      _selectedDate.year,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    while (currentSlotTime.isBefore(endTime)) {
      final timeOfDay = TimeOfDay.fromDateTime(currentSlotTime);
      final formattedTimeSlot =
          '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';

      // Проверяем, не занят ли слот и не в прошлом ли он (для сегодняшней даты)
      bool isBooked = _bookedSlots.containsKey(formattedTimeSlot);
      bool isPast =
          _selectedDate.isSameDate(now) && currentSlotTime.isBefore(now);

      if (!isBooked && !isPast) {
        slots.add(timeOfDay);
      }

      currentSlotTime =
          currentSlotTime.add(Duration(minutes: _slotDurationMinutes));
    }
    setState(() {
      _availableSlots = slots;
    });
  }

  // --- Выбор даты ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(), // Нельзя выбрать прошлые даты
      lastDate: DateTime.now()
          .add(Duration(days: 7)), // Ограничим выбор неделей вперед
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadBookedSlotsForDate(
          _selectedDate); // Перезагружаем слоты для новой даты
    }
  }

  // --- Сохранение бронирования ---
  Future<void> _confirmBooking() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, выберите временной слот.')),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLoadingSlots = true;
    }); // Используем тот же индикатор

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final formattedTime =
        '${_selectedTimeSlot!.hour.toString().padLeft(2, '0')}:${_selectedTimeSlot!.minute.toString().padLeft(2, '0')}';
    final dbRef = FirebaseDatabase.instance.ref();
    final bookingPath =
        'bookings/${widget.pickupPointId}/$formattedDate/$formattedTime';
    final orderUpdatePath =
        'users/customers/${widget.userPhoneNumber}/orders/${widget.orderId}/booking_slot';

    try {
      // Используем транзакцию для атомарности (если нужно, но для начала можно set)
      await dbRef.child(bookingPath).set({
        'user_phone': widget.userPhoneNumber,
        'order_id': widget.orderId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Обновляем заказ информацией о брони
      await dbRef.child(orderUpdatePath).set('$formattedDate $formattedTime');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Время успешно забронировано!')),
        );
        Navigator.of(context).pop(true); // Возвращаем true для индикации успеха
      }
    } catch (e) {
      print("Error saving booking: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка бронирования: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Бронирование времени'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Выбор даты ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Дата: ${DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate)}', // Формат даты на русском
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today, color: Colors.deepPurple),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
            Divider(height: 20),

            // --- Выбор времени ---
            Text(
              'Доступные слоты:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 10),
            _isLoadingSlots
                ? Center(child: CircularProgressIndicator())
                : _availableSlots.isEmpty
                    ? Center(child: Text('Нет доступных слотов на эту дату.'))
                    : Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, // 3 слота в ряд
                            childAspectRatio: 2.5, // Соотношение сторон кнопок
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _availableSlots.length,
                          itemBuilder: (context, index) {
                            final slot = _availableSlots[index];
                            final formattedSlot =
                                '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                            final bool isSelected = _selectedTimeSlot == slot;

                            return ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTimeSlot = slot;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey[200],
                                foregroundColor: isSelected
                                    ? Colors.white
                                    : Colors.black, // Text color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(formattedSlot),
                            );
                          },
                        ),
                      ),
            SizedBox(height: 20),
            // --- Кнопка подтверждения ---
            if (!_isLoadingSlots &&
                _availableSlots
                    .isNotEmpty) // Показываем кнопку только если есть слоты и не грузится
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('Подтвердить бронирование'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  onPressed: _selectedTimeSlot == null
                      ? null
                      : _confirmBooking, // Кнопка активна только если выбран слот
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Вспомогательное расширение для сравнения дат без учета времени
extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

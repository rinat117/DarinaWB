import 'dart:async'; // Импорт для StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/chat_preview.dart'; // Убедись, что путь верный
import '../employee_chat_screen.dart'; // Убедись, что путь верный

class EmployeeChatTab extends StatefulWidget {
  final String pickupPointId;

  const EmployeeChatTab({Key? key, required this.pickupPointId})
      : super(key: key);

  @override
  State<EmployeeChatTab> createState() => _EmployeeChatTabState();
}

class _EmployeeChatTabState extends State<EmployeeChatTab> {
  List<ChatPreview> _chatPreviews = [];
  Map<String, String> _customerUsernames = {}; // Храним имена здесь
  bool _isLoading = true;
  StreamSubscription? _chatListSubscription;
  Map<String, StreamSubscription?> _lastMessageSubscriptions =
      {}; // Подписки на последние сообщения

  @override
  void initState() {
    super.initState();
    // Проверяем pickupPointId перед запуском прослушивания
    if (widget.pickupPointId.isNotEmpty) {
      _listenForChatList();
    } else {
      print(
          "Error: Pickup Point ID is empty in EmployeeChatTab. Cannot initialize listener.");
      // Устанавливаем isLoading в false, чтобы показать сообщение об ошибке или пустом состоянии
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _chatListSubscription?.cancel(); // Отменяем основную подписку
    _lastMessageSubscriptions
        .forEach((key, sub) => sub?.cancel()); // Отменяем подписки на сообщения
    super.dispose();
  }

  // Слушаем список чатов (клиентов, написавших в этот ПВЗ)
  void _listenForChatList() {
    if (!mounted) return;
    setState(() => _isLoading = true); // Начинаем загрузку

    final dbRef =
        FirebaseDatabase.instance.ref('chats/${widget.pickupPointId}');

    _chatListSubscription = dbRef.onValue.listen((event) async {
      // Делаем async для await Future.wait
      if (!mounted) return;

      Map<String, ChatPreview> previewsMap =
          {}; // Временная карта для сборки превью
      // Отменяем старые подписки на последние сообщения перед созданием новых
      _lastMessageSubscriptions.forEach((key, sub) => sub?.cancel());
      _lastMessageSubscriptions.clear();

      List<Future> usernameFutures = []; // <<<--- ОБЪЯВЛЯЕМ СПИСОК ЗДЕСЬ

      if (event.snapshot.exists && event.snapshot.value != null) {
        final chatMap = event.snapshot.value as Map<dynamic, dynamic>;

        chatMap.forEach((customerPhoneKeyDynamic, messages) {
          // Проверка и преобразование ключа (номера телефона)
          if (customerPhoneKeyDynamic == null ||
              customerPhoneKeyDynamic.toString().isEmpty) {
            print(
                "Warning: Skipping invalid customer phone key: $customerPhoneKeyDynamic");
            return;
          }
          final String customerPhoneKey = customerPhoneKeyDynamic.toString();

          if (messages is Map && messages.isNotEmpty) {
            // Проверяем, что есть сообщения
            // Создаем превью с номером телефона по умолчанию
            previewsMap[customerPhoneKey] = ChatPreview(
              customerId: customerPhoneKey,
              customerName: customerPhoneKey, // Имя обновится позже
              lastMessage: "Загрузка...", // Начальное сообщение
              timestamp: 0, // Начальное время
            );
            // Если имени клиента еще нет в кэше, запускаем его загрузку
            if (!_customerUsernames.containsKey(customerPhoneKey)) {
              usernameFutures.add(_fetchCustomerUsername(customerPhoneKey));
            } else {
              // Если имя есть, сразу подставляем
              previewsMap[customerPhoneKey]!.customerName =
                  _customerUsernames[customerPhoneKey]!;
            }
            // Запускаем прослушивание последнего сообщения для этого чата
            _listenToLastMessage(customerPhoneKey, previewsMap);
          } else {
            print(
                "Warning: Invalid or empty messages format for key $customerPhoneKey: $messages");
          }
        });

        // Ждем завершения загрузки всех имен (если были запущены)
        if (usernameFutures.isNotEmpty) {
          await Future.wait(usernameFutures);
          // Обновляем имена в карте превью после завершения загрузки
          previewsMap.forEach((key, preview) {
            preview.customerName =
                _customerUsernames[key] ?? key; // Используем имя или номер
          });
        }
      }

      // Обновляем и сортируем список для отображения
      if (mounted) {
        _updatePreviewList(previewsMap); // Обновляем состояние списка
        // Устанавливаем isLoading в false после всех операций
        setState(() => _isLoading = false);
      }
    }, onError: (error) {
      print("Error listening to chat list: $error");
      if (mounted) {
        setState(() {
          _isLoading = false; // Завершаем загрузку при ошибке
          _chatPreviews = []; // Очищаем список при ошибке
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки списка чатов: $error")),
        );
      }
    });
  }

  // Загрузка имени клиента по номеру телефона
  Future<void> _fetchCustomerUsername(String phoneKey) async {
    if (phoneKey.isEmpty || !mounted) return;
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/customers/$phoneKey/username')
          .get();
      if (mounted) {
        // Проверяем еще раз перед обновлением состояния
        if (snapshot.exists &&
            snapshot.value != null &&
            snapshot.value is String) {
          _customerUsernames[phoneKey] = snapshot.value as String;
        } else {
          _customerUsernames[phoneKey] =
              phoneKey; // Используем номер, если имя не найдено
        }
      }
    } catch (e) {
      print("Error fetching username for $phoneKey: $e");
      if (mounted)
        _customerUsernames[phoneKey] = phoneKey; // Используем номер при ошибке
    }
    // Не вызываем setState здесь, имя обновится при обновлении превью
  }

  // Прослушивание последнего сообщения в конкретном чате
  void _listenToLastMessage(
      String customerPhoneKey, Map<String, ChatPreview> previewsMap) {
    if (customerPhoneKey.isEmpty || !mounted) return;
    final lastMessageRef = FirebaseDatabase.instance
        .ref('chats/${widget.pickupPointId}/$customerPhoneKey')
        .orderByChild('timestamp')
        .limitToLast(1);

    // Отменяем предыдущую подписку для этого чата, если она была
    _lastMessageSubscriptions[customerPhoneKey]?.cancel();

    _lastMessageSubscriptions[customerPhoneKey] =
        lastMessageRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final messageMap = event.snapshot.value as Map<dynamic, dynamic>;
        if (messageMap.isEmpty) return;

        final messageKey = messageMap.keys.first;
        final messageData = messageMap[messageKey];

        if (messageData is Map) {
          final messageText = messageData['message']?.toString() ?? '';
          final messageTimestamp =
              (messageData['timestamp'] as num?)?.toInt() ?? 0;

          final preview = previewsMap[customerPhoneKey];
          if (preview != null) {
            // Обновляем данные превью
            preview.lastMessage = messageText;
            preview.timestamp = messageTimestamp;
            preview.customerName = _customerUsernames[customerPhoneKey] ??
                customerPhoneKey; // Обновляем имя на всякий случай
            _updatePreviewList(
                previewsMap); // Обновляем и сортируем весь список
          }
        } else {
          print(
              "Warning: Invalid messageData format for key $messageKey in chat $customerPhoneKey: $messageData");
        }
      }
    }, onError: (error) {
      print("Error listening to last message for $customerPhoneKey: $error");
      // Можно добавить обработку ошибки для конкретного чата
    });
  }

  // Обновляет список превью в состоянии и сортирует его
  void _updatePreviewList(Map<String, ChatPreview> previewsMap) {
    if (!mounted) return;
    final sortedList = previewsMap.values.toList();
    // Сортировка по времени последнего сообщения (новые вверху)
    sortedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _chatPreviews = sortedList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты с клиентами'),
        backgroundColor: Colors.deepPurple,
        // Можно добавить кнопку выхода и сюда, если нужно
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Обновить список',
            onPressed: _listenForChatList, // Просто перезапускаем слушатель
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatPreviews.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Нет активных чатов. Клиенты появятся здесь после того, как напишут вам.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ))
              : ListView.builder(
                  itemCount: _chatPreviews.length,
                  itemBuilder: (context, index) {
                    final preview = _chatPreviews[index];
                    // Безопасное получение значений для отображения
                    final customerNameText = preview
                        .customerName; // Уже содержит номер, если имя не найдено
                    final lastMessageText = preview.lastMessage;
                    final timeText = preview.timestamp > 0
                        ? DateFormat('HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                preview.timestamp))
                        : '';

                    return Card(
                      elevation: 1, // Меньше тени
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple
                              .withOpacity(0.1), // Прозрачнее фон
                          child: Icon(Icons.person_outline,
                              color: Colors.deepPurple), // Аутлайн иконка
                        ),
                        title: Text(customerNameText,
                            style: TextStyle(
                                fontWeight: FontWeight.w600)), // Жирнее имя
                        subtitle: Text(
                          lastMessageText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          timeText,
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12), // Чуть темнее время
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EmployeeChatScreen(
                                pickupPointId: widget.pickupPointId,
                                customerPhoneNumber:
                                    preview.customerId, // Передаем чистый номер
                                customerName:
                                    customerNameText, // Передаем отображаемое имя
                              ),
                            ),
                          ).then((_) {
                            // Опционально: обновить список после возвращения из чата
                            // _listenForChatList(); // или просто обновить последнее сообщение
                          });
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

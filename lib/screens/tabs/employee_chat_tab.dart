// lib/screens/tabs/employee_chat_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Для времени
import '../../models/chat_preview.dart'; // Модель превь
import '../employee_chat_screen.dart';

class EmployeeChatTab extends StatefulWidget {
  final String pickupPointId;
  const EmployeeChatTab({Key? key, required this.pickupPointId})
      : super(key: key);
  @override
  State<EmployeeChatTab> createState() => _EmployeeChatTabState();
}

class _EmployeeChatTabState extends State<EmployeeChatTab> {
  // Используем новую модель для хранения всей информации о чате клиента
  Map<String, CustomerChatInfo> _customerChats = {};
  bool _isLoading = true;
  StreamSubscription? _chatListSubscription;
  Map<String, StreamSubscription?> _detailsSubscriptions =
      {}; // Подписки на детали (статус, имя, последнее сообщение)

  // Цвета
  final Color primaryColor = Color(0xFF7F00FF);
  final Color waitingColor = Colors.orange.shade600;
  final Color employeeColor = Colors.green.shade600;
  final Color botColor = Colors.grey.shade500;

  @override
  void initState() {
    super.initState();
    if (widget.pickupPointId.isNotEmpty) {
      _listenForChatList();
    } else {
      if (mounted) setState(() => _isLoading = false);
      print("Error: Pickup Point ID is empty in EmployeeChatTab.");
    }
  }

  @override
  void dispose() {
    _chatListSubscription?.cancel();
    _detailsSubscriptions.forEach((_, sub) => sub?.cancel());
    _detailsSubscriptions.clear();
    super.dispose();
  }

  // Слушаем список клиентов, которые писали в этот ПВЗ
  void _listenForChatList() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final dbRef =
        FirebaseDatabase.instance.ref('chats/${widget.pickupPointId}');

    _chatListSubscription = dbRef.onValue.listen((event) {
      if (!mounted) return;

      final Set<String> currentPhoneKeys = {}; // Сохраняем ключи из snapshot
      if (event.snapshot.exists && event.snapshot.value != null) {
        final chatMap = event.snapshot.value as Map<dynamic, dynamic>;
        chatMap.forEach((key, _) {
          if (key != null) currentPhoneKeys.add(key.toString());
        });
      }

      // Удаляем подписки и данные для чатов, которых больше нет
      final removedKeys =
          _customerChats.keys.toSet().difference(currentPhoneKeys);
      for (var key in removedKeys) {
        _detailsSubscriptions[key]?.cancel();
        _detailsSubscriptions.remove(key);
        _customerChats.remove(key);
      }

      // Добавляем новые чаты и запускаем/обновляем подписки на детали
      for (var phoneKey in currentPhoneKeys) {
        if (!_customerChats.containsKey(phoneKey)) {
          // Если чат новый
          _customerChats[phoneKey] =
              CustomerChatInfo(customerId: phoneKey); // Создаем объект
          _listenToChatDetails(phoneKey); // Запускаем слушатель деталей
        }
        // Если чат уже есть, слушатель деталей уже работает и обновит данные
      }

      // Первичная установка isLoading = false после обработки списка
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
      _sortAndRefreshList(); // Сортируем и обновляем UI
    }, onError: (error) {
      print("Error listening to chat list: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _customerChats.clear();
        });
        // Показать ошибку пользователю
      }
    });
  }

  // Слушаем детали конкретного чата (имя, статус, последнее сообщение)
  void _listenToChatDetails(String phoneKey) {
    if (!mounted) return;

    // Отменяем старую подписку, если она была
    _detailsSubscriptions[phoneKey]?.cancel();

    List<Stream<DatabaseEvent>> streams = [];

    // 1. Имя пользователя
    streams.add(FirebaseDatabase.instance
        .ref('users/customers/$phoneKey/username')
        .onValue);
    // 2. Статус чата
    streams.add(FirebaseDatabase.instance
        .ref('users/customers/$phoneKey/chat_status')
        .onValue);
    // 3. Последнее сообщение
    streams.add(FirebaseDatabase.instance
        .ref('chats/${widget.pickupPointId}/$phoneKey')
        .orderByChild('timestamp')
        .limitToLast(1)
        .onValue);

    // Объединяем потоки. Используем StreamGroup или combineLatest (требует rxdart)
    // Простой вариант - подписка на каждый отдельно:
    _detailsSubscriptions[phoneKey] = Stream.fromFutures([
      // "Объединяем" через Future.wait на первый эвент
      streams[0].first, streams[1].first, streams[2].first
    ]).listen((_) {
      // После первого события от каждого потока, запускаем постоянные слушатели
      _startPermanentListeners(phoneKey, streams);
    }, onError: (e) {
      print("Error combining streams for $phoneKey: $e");
    });
  }

  // Запуск постоянных слушателей после первого события
  void _startPermanentListeners(
      String phoneKey, List<Stream<DatabaseEvent>> streams) {
    if (!mounted || !_customerChats.containsKey(phoneKey)) return;

    // Слушаем имя
    final nameSub = streams[0].listen((event) {
      if (mounted && _customerChats.containsKey(phoneKey)) {
        _customerChats[phoneKey]!.customerName =
            (event.snapshot.value as String?) ?? phoneKey;
        _sortAndRefreshList();
      }
    });
    // Слушаем статус
    final statusSub = streams[1].listen((event) {
      if (mounted && _customerChats.containsKey(phoneKey)) {
        _customerChats[phoneKey]!.status =
            (event.snapshot.value as String?) ?? 'bot';
        _sortAndRefreshList();
      }
    });
    // Слушаем последнее сообщение
    final msgSub = streams[2].listen((event) {
      if (mounted && _customerChats.containsKey(phoneKey)) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final map = event.snapshot.value as Map<dynamic, dynamic>;
          final msgData = map.values.first;
          if (msgData is Map) {
            _customerChats[phoneKey]!.lastMessage =
                msgData['message']?.toString() ?? '';
            _customerChats[phoneKey]!.timestamp =
                (msgData['timestamp'] as num?)?.toInt() ?? 0;
          }
        } else {
          _customerChats[phoneKey]!.lastMessage = '';
          _customerChats[phoneKey]!.timestamp = 0;
        }
        _sortAndRefreshList();
      }
    });
    // Сохраняем подписки, чтобы можно было их отменить
    _detailsSubscriptions[phoneKey] =
        _CombinedStreamSubscription([nameSub, statusSub, msgSub]);
  }

  // Сортировка и обновление UI
  void _sortAndRefreshList() {
    if (!mounted) return;
    final chatList = _customerChats.values.toList();

    // Правила сортировки:
    // 1. 'waiting' всегда наверху
    // 2. 'employee' следующие
    // 3. 'bot' внизу
    // Внутри каждой группы - по времени последнего сообщения (новые выше)
    chatList.sort((a, b) {
      int statusCompare =
          _getStatusPriority(a.status).compareTo(_getStatusPriority(b.status));
      if (statusCompare != 0) {
        return statusCompare; // Сортируем по статусу
      }
      // Если статусы одинаковые, сортируем по времени
      return b.timestamp.compareTo(a.timestamp);
    });

    setState(() {
      // Обновляем список в состоянии (можно создать новый список, если требуется)
      // _customerChats уже обновлен по ключам, просто обновляем UI
    });
  }

  // Приоритет статусов для сортировки (меньше = выше)
  int _getStatusPriority(String status) {
    switch (status) {
      case 'waiting':
        return 1;
      case 'employee':
        return 2;
      case 'bot':
        return 3;
      default:
        return 4;
    }
  }

  // Цвет статуса
  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return waitingColor;
      case 'employee':
        return employeeColor;
      case 'bot':
        return botColor;
      default:
        return Colors.grey;
    }
  }

  // Иконка статуса
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waiting':
        return Icons.priority_high_rounded; // Восклицательный знак
      case 'employee':
        return Icons.headset_mic_outlined; // Наушники
      case 'bot':
        return Icons.adb_rounded; // Андроид-бот
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatList = _customerChats.values.toList();
    // Сортируем перед построением списка (на случай если setState не успел)
    chatList.sort((a, b) {
      int statusCompare =
          _getStatusPriority(a.status).compareTo(_getStatusPriority(b.status));
      if (statusCompare != 0) return statusCompare;
      return b.timestamp.compareTo(a.timestamp);
    });

    return Scaffold(
      backgroundColor: Colors.grey[100], // Светлый фон
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7F00FF)))
          : chatList.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Text(
                    'Нет активных чатов.\nКлиенты появятся здесь, когда напишут.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ))
              : ListView.builder(
                  padding:
                      EdgeInsets.symmetric(vertical: 8.0), // Отступы списка
                  itemCount: chatList.length,
                  itemBuilder: (context, index) {
                    final chatInfo = chatList[index];
                    final statusColor = _getStatusColor(chatInfo.status);
                    final statusIcon = _getStatusIcon(chatInfo.status);
                    final bool needsAttention = chatInfo.status == 'waiting';

                    return Card(
                      elevation: needsAttention ? 3 : 1.5, // Выделяем ожидающие
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      color: needsAttention
                          ? Colors.orange.shade50
                          : Colors.white, // Фон для ожидающих
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(statusIcon, color: statusColor, size: 22),
                        ),
                        title: Text(chatInfo.customerName,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        subtitle: Text(chatInfo.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                        trailing: chatInfo.timestamp > 0
                            ? Text(
                                DateFormat('HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                        chatInfo.timestamp)),
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              )
                            : null, // Не показываем время, если его нет
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EmployeeChatScreen(
                                pickupPointId: widget.pickupPointId,
                                customerPhoneNumber: chatInfo.customerId,
                                customerName: chatInfo.customerName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// --- Вспомогательный класс для отписки от группы StreamSubscription ---
class _CombinedStreamSubscription implements StreamSubscription<dynamic> {
  final List<StreamSubscription<dynamic>> _subscriptions;
  _CombinedStreamSubscription(this._subscriptions);

  @override
  Future<void> cancel() async {
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
  }

  @override
  bool get isPaused => _subscriptions.any((s) => s.isPaused);
  @override
  void pause([Future<void>? resumeSignal]) {
    for (var sub in _subscriptions) {
      sub.pause(resumeSignal);
    }
  }

  @override
  void resume() {
    for (var sub in _subscriptions) {
      sub.resume();
    }
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) =>
      throw UnimplementedError(); // Не используется
  @override
  void onData(void Function(dynamic data)? handleData) =>
      throw UnimplementedError(); // Не используется
  @override
  void onDone(void Function()? handleDone) =>
      throw UnimplementedError(); // Не используется
  @override
  void onError(Function? handleError) =>
      throw UnimplementedError(); // Не используется
}

// --- НОВАЯ Модель для хранения информации о чате клиента ---
// lib/models/customer_chat_info.dart (можно вынести в отдельный файл)
class CustomerChatInfo {
  final String customerId; // Номер телефона без '+'
  String customerName;
  String lastMessage;
  int timestamp;
  String status; // 'bot', 'waiting', 'employee'

  CustomerChatInfo({
    required this.customerId,
    this.customerName = '', // Инициализируем пустым
    this.lastMessage = '',
    this.timestamp = 0,
    this.status = 'bot', // Статус по умолчанию
  }) {
    // Если имя пустое, используем ID (номер телефона) как временное имя
    if (customerName.isEmpty) {
      customerName = customerId;
    }
  }
}

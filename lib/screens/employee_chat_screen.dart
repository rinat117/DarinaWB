import 'dart:async'; // Импорт для StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart'; // Убедись, что путь верный
import '../../models/order.dart'; // Для показа заказов
import '../../models/order_item.dart'; // Для показа заказов

class EmployeeChatScreen extends StatefulWidget {
  final String pickupPointId;
  final String customerPhoneNumber; // Номер телефона *без* '+'
  final String customerName; // Имя или номер для отображения

  const EmployeeChatScreen({
    Key? key,
    required this.pickupPointId,
    required this.customerPhoneNumber,
    required this.customerName,
  }) : super(key: key);

  @override
  State<EmployeeChatScreen> createState() => _EmployeeChatScreenState();
}

class _EmployeeChatScreenState extends State<EmployeeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  StreamSubscription? _messagesSubscription;
  User? _currentUser; // Сотрудник

  DatabaseReference? _chatRef; // Ссылка на ветку чата
  DatabaseReference? _statusRef; // <<<--- Ссылка на статус чата клиента
  String _currentChatStatus =
      'bot'; // <<<--- Текущий статус чата (для логики кнопки Завершить)
  StreamSubscription? _statusSubscription; // <<<--- Слушатель статуса
  bool _isChatRefInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _initializeChatRefAndListen();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _statusSubscription?.cancel(); // <<<--- Отменяем подписку на статус
    super.dispose();
  }

  void _initializeChatRefAndListen() {
    if (_currentUser == null) {
      print("Error: Employee user not found in ChatScreen.");
      setState(() => _isLoading = false);
      return;
    }
    if (widget.pickupPointId.isEmpty || widget.customerPhoneNumber.isEmpty) {
      print("Error: pickupPointId or customerPhoneNumber is empty.");
      setState(() => _isLoading = false);
      return;
    }
    try {
      _chatRef = FirebaseDatabase.instance
          .ref('chats/${widget.pickupPointId}/${widget.customerPhoneNumber}');
      _statusRef = FirebaseDatabase.instance.ref(
          'users/customers/${widget.customerPhoneNumber}/chat_status'); // <<<--- Инициализируем ссылку на статус
      _isChatRefInitialized = true;
      _listenToMessages();
      _listenToChatStatus(); // <<<--- Начинаем слушать статус
    } catch (e) {
      print("Error initializing chat ref in EmployeeChatScreen: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // <<<--- НОВЫЙ СЛУШАТЕЛЬ СТАТУСА ---
  void _listenToChatStatus() {
    if (!_isChatRefInitialized || _statusRef == null) return;
    _statusSubscription = _statusRef!.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        setState(() {
          _currentChatStatus = event.snapshot.value as String? ?? 'bot';
        });
        print("EmployeeChatScreen: Chat status updated: $_currentChatStatus");
      } else {
        setState(() {
          _currentChatStatus = 'bot';
        });
      }
    }, onError: (error) {
      print("Error listening to chat status in EmployeeChatScreen: $error");
      if (mounted) setState(() => _currentChatStatus = 'bot');
    });
  }
  // <<<--- КОНЕЦ СЛУШАТЕЛЯ СТАТУСА ---

  void _listenToMessages() {
    if (!_isChatRefInitialized || _chatRef == null) return;
    setState(() => _isLoading = true);
    _messagesSubscription =
        _chatRef!.orderByChild('timestamp').onValue.listen((event) {
      if (!mounted) return;
      final List<ChatMessage> loadedMessages = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final messagesMap = event.snapshot.value as Map<dynamic, dynamic>;
        messagesMap.forEach((key, value) {
          if (value is Map) {
            try {
              loadedMessages.add(ChatMessage.fromJson(key, value));
            } catch (e) {
              print("Error parsing message with key $key: $e");
            }
          }
        });
      }
      setState(() {
        _messages = loadedMessages;
        _isLoading = false;
      });
      _scrollToBottom();
    }, onError: (error) {
      print("Error listening to messages: $error");
      if (mounted) {
        setState(() => _isLoading = false); /* ... SnackBar ... */
      }
    });
  }

  Future<void> _sendMessage() async {
    if (!_isChatRefInitialized || _chatRef == null) {
      /* ... */ return;
    }
    if (_messageController.text.trim().isEmpty || _currentUser?.email == null)
      return;

    final message = {
      'sender': _currentUser!.email,
      'sender_type': 'employee',
      'message': _messageController.text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await _chatRef!.push().set(message);

      // <<<--- ОБНОВЛЕНИЕ СТАТУСА ПРИ ОТВЕТЕ СОТРУДНИКА ---
      // Если статус был 'bot' или 'waiting', меняем на 'employee'
      if (_currentChatStatus == 'bot' || _currentChatStatus == 'waiting') {
        await _statusRef?.set('employee'); // Используем безопасный вызов
        print("Chat status set to 'employee' by employee response.");
        // Статус обновится через слушатель _listenToChatStatus
      }
      // <<<--- КОНЕЦ ОБНОВЛЕНИЯ СТАТУСА ---

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {/* ... SnackBar ... */}
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Диалог для показа заказов клиента ---
  Future<void> _showCustomerOrdersDialog() async {
    if (!mounted) return;
    // Показываем индикатор загрузки, пока грузим заказы
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    final dbRef = FirebaseDatabase.instance.ref();
    List<Order> customerOrders = [];
    try {
      final ordersSnapshot = await dbRef
          .child('users/customers/${widget.customerPhoneNumber}/orders')
          .get();
      if (ordersSnapshot.exists && ordersSnapshot.value != null) {
        final ordersMap = ordersSnapshot.value as Map<dynamic, dynamic>;
        ordersMap.forEach((key, value) {
          if (value is Map) {
            final order = Order.fromJson(key, value);
            // Показываем заказы только для ТЕКУЩЕГО ПВЗ
            if (order.pickupPointId == widget.pickupPointId) {
              customerOrders.add(order);
            }
          }
        });
        // Сортируем по дате (новейшие сначала)
        customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      }
    } catch (e) {
      print("Error fetching orders for dialog: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки заказов клиента: $e")),
        );
      }
    } finally {
      Navigator.of(context).pop(); // Убираем индикатор загрузки
    }

    // Показываем диалог с заказами (или сообщение, если их нет)
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Заказы ${widget.customerName}"),
        content: Container(
          width: double.maxFinite,
          child: customerOrders.isEmpty
              ? Text("У клиента нет заказов в этом пункте выдачи.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: customerOrders.length,
                  itemBuilder: (context, index) {
                    final order = customerOrders[index];
                    return ListTile(
                      title: Text("Заказ от ${order.orderDate}"),
                      subtitle: Text(
                          "Статус: ${order.orderStatus}\nТоваров: ${order.items.length}"),
                      isThreeLine: true,
                      dense: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Закрыть"),
          ),
        ],
      ),
    );
  }
  // --- Конец диалога заказов ---

  // --- Функция подтверждения и завершения чата сотрудником ---
  Future<void> _confirmAndEndChat(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        /* ... Диалог подтверждения ... */
        return AlertDialog(
          title: Text('Завершить диалог?'),
          content: Text('Клиент снова будет общаться с ботом. Вы уверены?'),
          actions: <Widget>[
            TextButton(
              child: Text('Отмена'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Да, завершить'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange[900]),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return; // Выход если не подтвердили

    if (!mounted) return;
    print("Ending chat session with customer: ${widget.customerPhoneNumber}");

    // Показываем индикатор
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()));

    // Ссылка на статус клиента (уже инициализирована в initState)
    // final statusRef = FirebaseDatabase.instance.ref('users/customers/${widget.customerPhoneNumber}/chat_status');
    // Ссылка на чат (уже инициализирована)
    // final chatRef = FirebaseDatabase.instance.ref('chats/${widget.pickupPointId}/${widget.customerPhoneNumber}');

    // Системное сообщение
    final systemMessage = {
      'sender': 'system',
      'sender_type': 'system',
      'message':
          'Сотрудник завершил консультацию. Если у вас остались вопросы, бот постарается помочь.',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      // Используем ссылки, инициализированные в initState
      if (_statusRef != null) {
        await _statusRef!.set('bot'); // Меняем статус на 'bot'
      } else {
        throw Exception("Status reference is null");
      }

      if (_chatRef != null) {
        await _chatRef!.push().set(systemMessage); // Отправляем сообщение
      } else {
        throw Exception("Chat reference is null");
      }

      Navigator.of(context).pop(); // Убираем индикатор загрузки

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Диалог завершен. Клиент передан боту.')),
        );
        // Можно закрыть этот экран после завершения
        // Navigator.of(context).pop();
      }
    } catch (e) {
      Navigator.of(context).pop(); // Убираем индикатор при ошибке
      print("Error ending chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка завершения диалога: $e')),
        );
      }
    }
  }
  // --- Конец функции завершения чата ---

  @override
  Widget build(BuildContext context) {
    if (!_isChatRefInitialized) {
      // Проверка инициализации
      return Scaffold(
        appBar: AppBar(title: Text(widget.customerName)),
        body: Center(child: Text("Ошибка инициализации чата.")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.list_alt),
            tooltip: 'Посмотреть заказы клиента',
            onPressed: _showCustomerOrdersDialog,
          ),
          // --- КНОПКА ЗАВЕРШЕНИЯ ДИАЛОГА ---
          // Показываем кнопку, только если диалог ведет сотрудник
          if (_currentChatStatus == 'employee')
            IconButton(
              icon: Icon(Icons.done_all),
              tooltip: 'Завершить диалог (передать боту)',
              onPressed: () =>
                  _confirmAndEndChat(context), // Вызываем функцию подтверждения
            ),
          // --- КОНЕЦ КНОПКИ ЗАВЕРШЕНИЯ ---
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text("Нет сообщений."))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(8.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderType == 'employee';
                          return _buildMessageBubble(message, isMe);
                        },
                      ),
          ),
          // Поле ввода
          Container(
            decoration:
                BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [
              BoxShadow(
                offset: Offset(0, -1),
                blurRadius: 4,
                color: Colors.black.withOpacity(0.1),
              )
            ]),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
                .copyWith(
                    bottom: MediaQuery.of(context).padding.bottom / 2 + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Введите ответ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Виджет для "пузыря" сообщения
  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    // ... (Код _buildMessageBubble остается без изменений, как в предыдущем ответе) ...
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleAlignment =
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    Color bubbleColor;
    Color textColor;
    switch (message.senderType) {
      case 'customer':
        bubbleColor = Colors.grey[300]!;
        textColor = Colors.black87;
        break;
      case 'employee':
        bubbleColor = Colors.deepPurple[400]!;
        textColor = Colors.white;
        break; // Сотрудник теперь справа
      case 'bot':
        bubbleColor = Colors.blueGrey[100]!;
        textColor = Colors.black87;
        break;
      case 'system':
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          alignment: Alignment.center,
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontSize: 12),
          ),
        );
      default:
        bubbleColor = Colors.grey[300]!;
        textColor = Colors.black87;
    }
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: isMe ? Radius.circular(16) : Radius.circular(0),
      bottomRight: isMe ? Radius.circular(0) : Radius.circular(16),
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: bubbleAlignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
              ),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              child: Text(
                message.message,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            ),
          ),
          SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Text(
              DateFormat('HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(message.timestamp)),
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

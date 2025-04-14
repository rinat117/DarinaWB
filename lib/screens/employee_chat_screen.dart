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
      _isChatRefInitialized = true;
      _listenToMessages();
    } catch (e) {
      print("Error initializing chat ref in EmployeeChatScreen: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToMessages() {
    if (!_isChatRefInitialized || _chatRef == null) return;

    setState(() => _isLoading = true);
    _messagesSubscription =
        _chatRef!.orderByChild('timestamp').onValue.listen((event) {
      // Используем ! после проверки
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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки чата: $error")),
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (!_isChatRefInitialized || _chatRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка чата. Не удалось отправить.")));
      return;
    }
    if (_messageController.text.trim().isEmpty || _currentUser?.email == null)
      return;

    final message = {
      'sender': _currentUser!.email, // Сотрудник отправляет со своим email
      'sender_type': 'employee', // Тип отправителя
      'message': _messageController.text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await _chatRef!.push().set(message); // Используем ! после проверки
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка отправки сообщения: $e")));
      }
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

  @override
  Widget build(BuildContext context) {
    if (!_isChatRefInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.customerName)),
        body: Center(child: Text("Ошибка инициализации чата.")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName), // Имя или номер клиента
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.list_alt), // Иконка заказов
            tooltip: 'Посмотреть заказы клиента',
            onPressed: _showCustomerOrdersDialog, // Вызов диалога
          ),
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
                          // Сообщения сотрудника (sender_type == 'employee') справа
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

  // Виджет для "пузыря" сообщения (такой же, как в chat_tab)
  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleAlignment =
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final color = isMe ? Colors.deepPurple[400] : Colors.grey[300];
    final textColor = isMe ? Colors.white : Colors.black87;
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
                color: color,
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

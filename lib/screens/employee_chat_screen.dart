import 'dart:async'; // Импорт для StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart'; // Убедись, что путь верный
import '../../models/order.dart'; // Для показа заказов
import '../../models/order_item.dart'; // Для показа заказов
import '../../widgets/order_status_indicator.dart'; // <<<--- ДОБАВИТЬ ЭТОТ ИМПОРТ
import '../../widgets/pickup_code_dialog.dart'; // <<<--- ДОБАВИТЬ ЭТОТ ИМПОРТ

class EmployeeChatScreen extends StatefulWidget {
  final String pickupPointId;
  final String customerPhoneNumber; // Номер телефона *без* '+'
  final String customerName;

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
  User? _currentUser;

  DatabaseReference? _chatRef;
  DatabaseReference? _statusRef;
  String _currentChatStatus = 'bot';
  StreamSubscription? _statusSubscription;
  bool _isChatRefInitialized = false;

  // --- Цвета для дизайна ---
  final Color primaryColor = const Color(0xFF7F00FF);
  final Color accentColor = const Color(0xFFCB11AB);
  final Color customerBubbleColor = Colors.grey.shade200; // Для клиента
  final Color botBubbleColor = Colors.blueGrey[50]!; // Для бота
  final Color systemTextColor = Colors.grey[600]!;
  final Color inputBackgroundColor = Colors.white;
  final Color backgroundColor = Colors.grey[50]!;

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

  // --- ОБНОВЛЕННЫЙ Диалог для показа заказов клиента ---
  Future<void> _showCustomerOrdersDialog() async {
    if (!mounted) return;
    // Показываем стандартный индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final dbRef = FirebaseDatabase.instance.ref();
    List<Order> customerOrders = [];
    String errorMessage = ''; // Для отображения ошибки в диалоге

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
      errorMessage = "Ошибка загрузки заказов клиента: $e";
    } finally {
      Navigator.of(context).pop(); // Убираем индикатор загрузки
    }

    // Показываем новый стилизованный диалог
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Темный фон
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          titlePadding:
              const EdgeInsets.fromLTRB(20, 20, 10, 10), // Отступы заголовка
          contentPadding: const EdgeInsets.fromLTRB(
              0, 0, 0, 10), // Отступы контента (убраны боковые)
          actionsPadding:
              const EdgeInsets.fromLTRB(20, 0, 20, 15), // Отступы кнопок
          // Заголовок с именем клиента и крестиком
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Заказы ${widget.customerName}',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[500], size: 22),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(dialogContext).pop(),
              )
            ],
          ),
          // Основной контент диалога
          content: Container(
            width: double.maxFinite, // Занять доступную ширину
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height *
                    0.6), // Ограничение высоты
            child: (errorMessage.isNotEmpty) // Если была ошибка загрузки
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(errorMessage,
                            style: TextStyle(color: Colors.red[300]))))
                : (customerOrders.isEmpty) // Если заказов нет
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(30.0),
                            child: Text("У клиента нет заказов в этом ПВЗ.",
                                style: TextStyle(color: Colors.grey[400]))))
                    // Если заказы есть - показываем список
                    : ListView.builder(
                        shrinkWrap:
                            true, // Важно для ListView внутри AlertDialog
                        padding: EdgeInsets.symmetric(
                            horizontal: 20), // Боковые отступы для списка
                        itemCount: customerOrders.length,
                        itemBuilder: (context, index) {
                          final order = customerOrders[index];
                          // --- Карточка Отдельного Заказа ---
                          return Card(
                            color: Colors.grey[850], // Цвет карточки заказа
                            margin: EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ID и Дата
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Заказ #${order.id.split('_').last}",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 14)),
                                      Text(order.orderDate,
                                          style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12)),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  // Статус заказа
                                  OrderStatusIndicator(
                                      orderStatus: order.orderStatus),
                                  SizedBox(height: 10),
                                  // Товары (если есть)
                                  if (order.items.isNotEmpty) ...[
                                    Text("Товары:",
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13)),
                                    SizedBox(height: 4),
                                    // Используем Column для товаров внутри карточки
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: order.items
                                          .map((item) => InkWell(
                                                // Делаем строку кликабельной
                                                onTap: () => showPickupCodeDialog(
                                                    context,
                                                    item.qrCode,
                                                    item.article), // Показываем диалог QR/кода
                                                borderRadius: BorderRadius.circular(
                                                    6), // Скругление для области нажатия
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 5.0),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .qr_code_scanner_rounded,
                                                          color:
                                                              Colors.grey[500],
                                                          size:
                                                              18), // Иконка QR
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                          child: Text(
                                                              'Код: ${item.article}',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      300],
                                                                  fontSize:
                                                                      13))),
                                                      Text(
                                                          '( ${item.quantity} шт. )',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[500],
                                                              fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                              ))
                                          .toList(), // Преобразуем map в список виджетов
                                    ),
                                  ] else
                                    Text("Нет товаров в заказе",
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                          // --- Конец Карточки Заказа ---
                        },
                      ),
          ),
          // Кнопки действий диалога
          actions: <Widget>[
            TextButton(
              child: Text("Закрыть", style: TextStyle(color: Colors.grey[400])),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
  // --- Конец ОБНОВЛЕННОГО Диалога ---

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
      return Scaffold(
          appBar: AppBar(title: Text(widget.customerName)),
          body: Center(child: Text("Ошибка инициализации чата.")));
    }
    return Scaffold(
      backgroundColor: backgroundColor, // Светлый фон
      appBar: AppBar(
        // Стилизация AppBar
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1.0,
        title: Column(
          // Имя и номер телефона
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.customerName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('+${widget.customerPhoneNumber}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey[600])), // Добавляем + обратно для отображения
          ],
        ),
        actions: [
          // Кнопка просмотра заказов
          IconButton(
            icon: Icon(Icons.list_alt_outlined,
                color: primaryColor), // Иконка заказов
            tooltip: 'Посмотреть заказы клиента',
            onPressed: _showCustomerOrdersDialog,
          ),
          // Кнопка завершения диалога (если активен сотрудник)
          if (_currentChatStatus == 'employee')
            IconButton(
              icon: Icon(Icons.done_all_rounded,
                  color: Colors.green.shade700), // Иконка завершения
              tooltip: 'Завершить диалог (передать боту)',
              onPressed: () => _confirmAndEndChat(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // --- Список сообщений ---
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _messages.isEmpty
                    ? Center(
                        child: Text("Нет сообщений.",
                            style: TextStyle(color: Colors.grey[600])))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 10.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          // ВАЖНО: isMe теперь true, если отправитель - сотрудник
                          final bool isMe = message.senderType == 'employee';
                          return _buildMessageBubble(
                              message, isMe); // Используем обновленный виджет
                        },
                      ),
          ),

          // --- Поле ввода (стиль как у клиента) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
                .copyWith(
                    bottom: MediaQuery.of(context).padding.bottom / 2 + 8),
            decoration: BoxDecoration(
              color: inputBackgroundColor,
              boxShadow: [
                BoxShadow(
                    offset: Offset(0, -2),
                    blurRadius: 6,
                    color: Colors.black.withOpacity(0.05))
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Введите ответ...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: primaryColor, width: 1.5)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                InkWell(
                  onTap: _messageController.text.trim().isEmpty
                      ? null
                      : _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: _messageController.text.trim().isEmpty
                          ? null
                          : LinearGradient(
                              colors: [accentColor, primaryColor],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight),
                      color: _messageController.text.trim().isEmpty
                          ? Colors.grey[300]
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.send_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ОБНОВЛЕННЫЙ Виджет для пузыря сообщения (стиль инвертирован) ---
  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final Alignment bubbleAlignment =
        isMe ? Alignment.centerRight : Alignment.centerLeft;
    final Color bubbleColor;
    final Color textColor;
    final BorderRadius borderRadius;
    final Gradient? bubbleGradient;

    switch (message.senderType) {
      // --- СТИЛИ ПОМЕНЯЛИСЬ МЕСТАМИ ---
      case 'employee': // СОТРУДНИК (isMe = true) - теперь градиент
        bubbleColor = Colors.white;
        textColor = Colors.white;
        bubbleGradient = LinearGradient(
            colors: [
              accentColor.withOpacity(0.9),
              primaryColor
            ], // Можно сделать градиент чуть другим
            begin: Alignment.bottomLeft,
            end: Alignment.topRight);
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(20), bottomLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(4), // Хвостик справа
        );
        break;
      case 'customer': // КЛИЕНТ (isMe = false) - теперь светлый
        bubbleColor = customerBubbleColor; // Используем цвет клиента
        textColor = Colors.black87;
        bubbleGradient = null;
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(20), // Хвостик слева
          topRight: Radius.circular(20), bottomRight: Radius.circular(20),
        );
        break;
      // --- ОСТАЛЬНЫЕ СТАТУСЫ КАК БЫЛИ ---
      case 'bot':
        bubbleColor = botBubbleColor;
        textColor = Colors.black87;
        bubbleGradient = null;
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        );
        break;
      case 'system':
        return Container(
          padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
          alignment: Alignment.center,
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: systemTextColor,
                fontStyle: FontStyle.italic,
                fontSize: 12),
          ),
        );
      default:
        bubbleColor = Colors.grey[300]!;
        textColor = Colors.black87;
        bubbleGradient = null;
        borderRadius = BorderRadius.circular(20);
    }

    // --- Структура пузыря остается такой же ---
    return Align(
      alignment: bubbleAlignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
            color: bubbleGradient == null ? bubbleColor : null,
            gradient: bubbleGradient,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(1, 1))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.message,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.3)),
            SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat('HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(message.timestamp)),
                style: TextStyle(
                    color: isMe ? Colors.white70 : systemTextColor,
                    fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Вспомогательный класс _CombinedStreamSubscription и модель CustomerChatInfo ---
// (Их код нужно либо скопировать сюда, либо вынести в отдельные файлы и импортировать)
// --- НАЧАЛО КОДА ИЗ EmployeeChatTab ---
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
  Future<E> asFuture<E>([E? futureValue]) => throw UnimplementedError();
  @override
  void onData(void Function(dynamic data)? handleData) =>
      throw UnimplementedError();
  @override
  void onDone(void Function()? handleDone) => throw UnimplementedError();
  @override
  void onError(Function? handleError) => throw UnimplementedError();
}

class CustomerChatInfo {
  final String customerId;
  String customerName;
  String lastMessage;
  int timestamp;
  String status;

  CustomerChatInfo({
    required this.customerId,
    this.customerName = '',
    this.lastMessage = '',
    this.timestamp = 0,
    this.status = 'bot',
  }) {
    if (customerName.isEmpty) {
      customerName = customerId;
    }
  }
}
// --- КОНЕЦ КОДА ИЗ EmployeeChatTab ---

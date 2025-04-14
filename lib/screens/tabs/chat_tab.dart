import 'dart:async'; // Импорт для StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Для форматирования времени
import '../../models/chat_message.dart'; // Убедись, что путь верный

class ChatTab extends StatefulWidget {
  final String pickupPointId;
  final User user; // Текущий пользователь (клиент)

  const ChatTab({
    Key? key,
    required this.pickupPointId,
    required this.user,
  }) : super(key: key);

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  StreamSubscription? _messagesSubscription; // Подписка на сообщения

  DatabaseReference? _chatRef; // Ссылка на ветку чата (может быть null)
  bool _isChatRefInitialized = false; // Флаг для проверки

  @override
  void initState() {
    super.initState();
    _initializeChatRefAndListen(); // Инициализация и запуск слушателя
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel(); // Отменяем подписку при удалении виджета
    super.dispose();
  }

  // Инициализация ссылки на чат и запуск прослушивания
  void _initializeChatRefAndListen() {
    String? userPhone = widget.user.phoneNumber?.replaceAll('+', '');
    if (userPhone != null &&
        userPhone.isNotEmpty &&
        widget.pickupPointId.isNotEmpty) {
      try {
        _chatRef = FirebaseDatabase.instance
            .ref('chats/${widget.pickupPointId}/$userPhone');
        _isChatRefInitialized = true;
        _listenToMessages(); // Начинаем слушать сообщения
      } catch (e) {
        print("Error initializing chat reference: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      print(
          "Error: Cannot initialize chat. User phone or pickupPointId is invalid.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Прослушивание сообщений
  void _listenToMessages() {
    if (!_isChatRefInitialized || _chatRef == null) return; // Двойная проверка

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
            // Добавляем проверку типа перед созданием объекта
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
      _scrollToBottom(); // Прокрутка вниз после обновления
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

  // Отправка сообщения
  Future<void> _sendMessage() async {
    if (!_isChatRefInitialized || _chatRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка чата. Не удалось отправить.")));
      return;
    }
    if (_messageController.text.trim().isEmpty) return;

    final user = widget.user;
    String? senderId =
        user.phoneNumber; // Клиент отправляет со своим номером телефона

    if (senderId == null || senderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Не удалось отправить сообщение: номер телефона не найден.")));
      return;
    }

    final message = {
      'sender':
          senderId, // Можно оставить '+' или убрать - главное консистентность
      'sender_type': 'customer', // Тип отправителя
      'message': _messageController.text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await _chatRef!.push().set(message); // Используем ! после проверки
      _messageController.clear();
      _scrollToBottom(); // Прокрутка после отправки
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка отправки сообщения: $e")));
      }
    }
  }

  // Прокрутка к последнему сообщению
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

  @override
  Widget build(BuildContext context) {
    // Показываем ошибку, если чат не инициализирован
    if (!_isChatRefInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Чат'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
            child: Text(
                "Не удалось загрузить чат.\nПроверьте свой номер телефона.",
                textAlign: TextAlign.center)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чат с пунктом выдачи'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text("Нет сообщений. Начните диалог!"))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(8.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          // Клиентские сообщения (sender_type == 'customer') справа
                          final isMe = message.senderType == 'customer';
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
                    bottom: MediaQuery.of(context).padding.bottom / 2 +
                        8), // Учет нижнего отступа системы
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Введите сообщение...',
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

  // Виджет для отображения "пузыря" сообщения
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
      margin: const EdgeInsets.symmetric(
          vertical: 4.0), // Убрали горизонтальный отступ для выравнивания
      child: Row(
        // Используем Row для выравнивания
        mainAxisAlignment: bubbleAlignment,
        crossAxisAlignment: CrossAxisAlignment.end, // Выравниваем время по низу
        children: [
          Flexible(
            // Чтобы контейнер не занимал всю ширину
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: borderRadius,
              ),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width *
                      0.75), // Ограничение ширины
              child: Text(
                message.message,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            ),
          ),
          SizedBox(width: 6), // Отступ между сообщением и временем
          Padding(
            padding: const EdgeInsets.only(
                bottom: 2.0), // Небольшой отступ времени снизу
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

import 'dart:async';
import 'dart:convert'; // Для jsonEncode/jsonDecode
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Импорт http
import 'package:intl/intl.dart';
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
  bool _isLoadingMessages = true; // Загрузка сообщений
  bool _isLoadingStatus = true; // Загрузка статуса
  bool _isBotProcessing = false; // Индикатор работы бота
  String _currentChatStatus = 'bot'; // Текущий статус чата
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _statusSubscription; // Слушатель статуса

  DatabaseReference? _chatRef;
  DatabaseReference? _statusRef;
  bool _isChatRefInitialized = false;

  // --- ВАЖНО: ЗАМЕНИ НА СВОЙ КЛЮЧ И URL! ---
  // Вставь свой реальный ключ OpenRouter вместо "sk-or-v1-..."
  final String _openRouterApiKey =
      "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"; // <<<--- ТВОЙ API КЛЮЧ ЗДЕСЬ! (ПОМНИ О БЕЗОПАСНОСТИ!)
  final String _yourSiteUrl =
      "app://com.example.myapp"; // <<<--- Замени на URL/Идентификатор твоего приложения
  final String _yourSiteName = "Darina WB Helper"; // <<<--- Замени на название
  // ---

  @override
  void initState() {
    super.initState();
    _initializeChatRefAndListen();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _initializeChatRefAndListen() {
    String? userPhone = widget.user.phoneNumber?.replaceAll('+', '');
    if (userPhone != null &&
        userPhone.isNotEmpty &&
        widget.pickupPointId.isNotEmpty) {
      try {
        _chatRef = FirebaseDatabase.instance
            .ref('chats/${widget.pickupPointId}/$userPhone');
        _statusRef = FirebaseDatabase.instance
            .ref('users/customers/$userPhone/chat_status');
        _isChatRefInitialized = true;
        _listenToMessages();
        _listenToChatStatus(); // Начинаем слушать статус
      } catch (e) {
        print("Error initializing chat reference: $e");
        if (mounted)
          setState(() {
            _isLoadingMessages = false;
            _isLoadingStatus = false;
          });
      }
    } else {
      print(
          "Error: Cannot initialize chat. User phone or pickupPointId is invalid.");
      if (mounted)
        setState(() {
          _isLoadingMessages = false;
          _isLoadingStatus = false;
        });
    }
  }

  void _listenToChatStatus() {
    if (!_isChatRefInitialized || _statusRef == null) return;
    if (mounted) setState(() => _isLoadingStatus = true);

    _statusSubscription = _statusRef!.onValue.listen((event) {
      if (!mounted) return;
      String status = 'bot'; // Статус по умолчанию
      if (event.snapshot.exists &&
          event.snapshot.value != null &&
          event.snapshot.value is String) {
        status = event.snapshot.value as String;
      } else {
        // Если статус не найден в базе, устанавливаем 'bot' по умолчанию
        _statusRef?.set('bot');
      }
      setState(() {
        _currentChatStatus = status;
        _isLoadingStatus = false; // Статус загружен
      });
      print("Chat status updated: $_currentChatStatus");
    }, onError: (error) {
      print("Error listening to chat status: $error");
      if (mounted)
        setState(() {
          _currentChatStatus = 'bot';
          _isLoadingStatus = false;
        }); // Статус по умолчанию при ошибке
    });
  }

  void _listenToMessages() {
    if (!_isChatRefInitialized || _chatRef == null) return;
    if (mounted) setState(() => _isLoadingMessages = true);

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
        _isLoadingMessages = false; // Сообщения загружены
      });
      _scrollToBottom();
    }, onError: (error) {
      print("Error listening to messages: $error");
      if (mounted) {
        setState(() => _isLoadingMessages = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка загрузки чата: $error")));
      }
    });
  }

  Future<void> _sendMessage() async {
    if (!_isChatRefInitialized || _chatRef == null) {
      /* ... ошибка ... */ return;
    }
    final userMessageText = _messageController.text.trim();
    if (userMessageText.isEmpty) return;

    final user = widget.user;
    String? senderId = user.phoneNumber;
    if (senderId == null || senderId.isEmpty) {
      /* ... ошибка ... */ return;
    }
    // Получаем чистый номер телефона для чтения статуса
    String userPhoneClean = senderId.replaceAll('+', '');

    final userMessagePayload = {
      'sender': senderId,
      'sender_type': 'customer',
      'message': userMessageText,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _messageController.clear(); // Очищаем поле ввода сразу

    try {
      // 1. Сохраняем сообщение пользователя
      DatabaseReference newMessageRef =
          _chatRef!.push(); // Получаем ссылку на новое сообщение
      await newMessageRef.set(userMessagePayload);
      _scrollToBottom(); // Прокручиваем сразу после добавления нашего сообщения

      // 2. Проверяем статус чата (используем актуальное значение из state)
      print("Checking status before bot call: $_currentChatStatus");
      if (_currentChatStatus == 'bot') {
        // 3. Вызываем псевдо-бота
        setState(() => _isBotProcessing = true);
        await _getAndSaveBotResponse(userMessageText);
        // Убираем индикатор бота после его ответа (или ошибки)
        if (mounted) setState(() => _isBotProcessing = false);
      }
    } catch (e) {
      print("Error sending message or triggering bot: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Ошибка отправки: $e")));
        setState(
            () => _isBotProcessing = false); // Убираем индикатор при ошибке
      }
    }
  }

  Future<void> _getAndSaveBotResponse(String userMessage) async {
    // Проверка ключа (лучше вынести в переменные окружения, но для демо...)
    if (_openRouterApiKey.startsWith("sk-or-v1-...") ||
        _openRouterApiKey.isEmpty) {
      print("OpenRouter API Key is missing or invalid!");
      await _saveBotMessage(
          "Извините, я сейчас не доступен (API Key не настроен)."); // Используем await
      return;
    }

    final String url = "https://openrouter.ai/api/v1/chat/completions";
    final String systemPrompt =
        "Ты — чат-бот пункта выдачи заказов Wildberries. Отвечай ТОЛЬКО на вопросы, связанные с заказами, доставкой, работой пункта выдачи, возвратами и компанией Wildberries. Будь вежливым и кратким. На любые другие темы отвечай: 'Простите, я могу помочь только с вопросами по Wildberries и работе пункта выдачи.'. Не упоминай, что ты ИИ или чат-бот.";

    print("Sending to OpenRouter: $userMessage");

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_openRouterApiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': _yourSiteUrl,
              'X-Title': _yourSiteName,
            },
            body: jsonEncode({
              "model":
                  "deepseek/deepseek-chat-v3-0324:free", // Используем бесплатную модель
              "messages": [
                {"role": "system", "content": systemPrompt},
                {"role": "user", "content": userMessage}
              ]
            }),
          )
          .timeout(const Duration(seconds: 30)); // Таймаут 30 секунд

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody =
            jsonDecode(utf8.decode(response.bodyBytes)); // Декодируем UTF-8
        if (responseBody['choices'] != null &&
            responseBody['choices'].isNotEmpty) {
          final botMessage =
              responseBody['choices'][0]['message']['content']?.trim();
          if (botMessage != null && botMessage.isNotEmpty) {
            print("Bot response received: $botMessage");
            await _saveBotMessage(botMessage); // Ждем сохранения
          } else {
            print("Bot response was empty.");
            await _saveBotMessage("..."); // Ответ-заглушка
          }
        } else {
          print("Invalid response structure from OpenRouter: ${response.body}");
          await _saveBotMessage("Не удалось получить ответ.");
        }
      } else {
        print(
            "Error calling OpenRouter API: ${response.statusCode} ${response.body}");
        await _saveBotMessage(
            "Извините, помощник временно недоступен (${response.statusCode}).");
      }
    } catch (e) {
      print("Exception calling OpenRouter API: $e");
      if (mounted) {
        await _saveBotMessage("Извините, не удалось связаться с помощником.");
      }
    }
  }

  Future<void> _saveBotMessage(String messageText) async {
    if (!_isChatRefInitialized || _chatRef == null) return;

    final botMessagePayload = {
      'sender': 'bot',
      'sender_type': 'bot',
      'message': messageText,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await _chatRef!.push().set(botMessagePayload);
      _scrollToBottom();
    } catch (e) {
      print("Error saving bot message: $e");
    }
  }

  // --- Функция для запроса помощи сотрудника ---
  Future<void> _requestEmployeeHelp() async {
    if (!_isChatRefInitialized || _statusRef == null) return;

    final userPhone = widget.user.phoneNumber?.replaceAll('+', '') ?? '';
    // <<<--- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
    // Вместо несуществующей _username, берем номер телефона из widget.user
    final customerDisplay = widget.user.phoneNumber ??
        'Клиент'; // Берем полный номер или просто "Клиент"
    // <<<--- КОНЕЦ ИСПРАВЛЕНИЯ ---

    final systemMessage = {
      'sender': 'system',
      'sender_type': 'system',
      // Теперь используем customerDisplay, который точно определен
      'message': '$customerDisplay запросил помощь сотрудника.',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Остальная логика функции остается без изменений
    try {
      await _statusRef!.set('waiting');
      await _chatRef!.push().set(systemMessage);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Запрос отправлен. Сотрудник скоро подключится.')),
        );
      }
    } catch (e) {
      print("Error requesting employee help: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Не удалось запросить помощь: $e")));
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

  @override
  Widget build(BuildContext context) {
    bool stillLoading =
        _isLoadingMessages || _isLoadingStatus; // Общий флаг загрузки

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
          // --- Индикатор статуса чата и кнопка вызова сотрудника ---
          // Показываем только если статус уже загружен
          if (!_isLoadingStatus) ...[
            if (_currentChatStatus != 'bot')
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _currentChatStatus == 'waiting'
                    ? Colors.orange[100]
                    : Colors.green[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentChatStatus == 'waiting'
                          ? Icons.support_agent_outlined
                          : Icons.check_circle_outline,
                      size: 18,
                      color: _currentChatStatus == 'waiting'
                          ? Colors.orange[800]
                          : Colors.green[800],
                    ),
                    SizedBox(width: 8),
                    Text(
                      _currentChatStatus == 'waiting'
                          ? 'Ожидание сотрудника...'
                          : 'Вам отвечает сотрудник',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _currentChatStatus == 'waiting'
                            ? Colors.orange[800]
                            : Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
            if (_currentChatStatus == 'bot')
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 0.0), // Убрали верт отступ
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact, // Компактнее кнопка
                  ),
                  icon: Icon(Icons.support_agent, size: 20),
                  label: Text('Связаться с сотрудником'),
                  onPressed: _requestEmployeeHelp,
                ),
              ),
            Divider(height: 1), // Разделитель
          ],
          // --- Конец индикатора/кнопки ---

          Expanded(
            child: stillLoading // Используем общий флаг
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text("Нет сообщений. Начните диалог!"))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(8.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderType == 'customer';
                          return _buildMessageBubble(message, isMe);
                        },
                      ),
          ),
          // --- Индикатор "Бот думает..." ---
          if (_isBotProcessing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      height: 15,
                      width: 15,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text("Бот печатает...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          // --- Конец индикатора ---

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
                    minLines: 1, maxLines: 5,
                    enabled:
                        !_isBotProcessing, // Блокируем ввод, пока бот думает
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  // Блокируем отправку, пока бот думает
                  onPressed: _isBotProcessing ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleAlignment =
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    Color bubbleColor;
    Color textColor;
    // Определяем цвета в зависимости от типа отправителя
    switch (message.senderType) {
      case 'customer':
        bubbleColor = Colors.deepPurple[400]!;
        textColor = Colors.white;
        break;
      case 'employee':
        bubbleColor = Colors.green[300]!;
        textColor = Colors.black87;
        break;
      case 'bot':
        bubbleColor = Colors.blueGrey[100]!;
        textColor = Colors.black87;
        break;
      case 'system':
        // Системные сообщения отображаем по центру
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
      default: // Неизвестный тип
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
          // Сообщение
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
          // Время
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

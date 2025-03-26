import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmployeeChatTab extends StatefulWidget {
  final String pickupPointId;

  const EmployeeChatTab({Key? key, required this.pickupPointId})
      : super(key: key);

  @override
  State<EmployeeChatTab> createState() => _EmployeeChatTabState();
}

class _EmployeeChatTabState extends State<EmployeeChatTab> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  final databaseReference = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    databaseReference
        .child('chats/${widget.pickupPointId}')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final messagesMap = event.snapshot.value as Map<dynamic, dynamic>;
        final messagesList = <Map<String, dynamic>>[];
        messagesMap.forEach((key, value) {
          messagesList.add({
            'sender': value['sender'],
            'message': value['message'],
            'timestamp': value['timestamp'],
          });
        });
        messagesList.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        setState(() {
          _messages = messagesList;
        });
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final message = {
      'sender': user.email,
      'message': _messageController.text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    databaseReference
        .child('chats/${widget.pickupPointId}')
        .push()
        .set(message);

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чат'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['sender'] ==
                    FirebaseAuth.instance.currentUser?.email;
                return ListTile(
                  title: Text(
                    message['sender'] ?? 'Аноним',
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      color: isMe ? Colors.deepPurple : Colors.black,
                    ),
                  ),
                  subtitle: Text(message['message']),
                  trailing: Text(
                    DateTime.fromMillisecondsSinceEpoch(message['timestamp'])
                        .toString()
                        .substring(11, 16),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
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
}

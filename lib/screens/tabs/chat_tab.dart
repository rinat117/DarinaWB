import 'package:flutter/material.dart';

class ChatTab extends StatelessWidget {
  const ChatTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чат'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Center(
        child: Text('Чат пока не реализован'),
      ),
    );
  }
}

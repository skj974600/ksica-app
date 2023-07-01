import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:ksica/query/message.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../provider/auth.dart';
import '../query/chatroom.dart';

class ChatScreen extends StatefulWidget {
  final int? chatroomId;
  const ChatScreen({this.chatroomId, super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  late WebSocketChannel _channel;

  void _addMessage(Map<String, dynamic> message) {
    _messages.add(message);

    Timer(const Duration(milliseconds: 300), () {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(channel, message) {
    channel.sink.add(message);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget MessageInputBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50.0,
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Enter your message',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              _sendMessage(_channel, _messageController.text);
              _messageController.clear();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('WebSocket Example'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<Auth>(
              builder: (context, auth, child) {
                if (widget.chatroomId == null) {
                  return FutureBuilder(
                    future: fetchChatroom(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {}
                    },
                  );
                } else {
                  return FutureBuilder(
                    future: fetchMessages(1),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        List<Map<String, dynamic>> messages =
                            snapshot.data?.toList() ?? [];
                        _messages.addAll(messages);
                      }

                      _channel = IOWebSocketChannel.connect(
                        Uri.parse(
                            'ws://141.164.51.245:8000/message/ws/1?token=${auth.token}'),
                      );
                      Map<String, dynamic> token =
                          JwtDecoder.decode(auth.token);

                      return StreamBuilder(
                        stream: _channel.stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            Map<String, dynamic> message =
                                json.decode(snapshot.data);
                            _addMessage(message);
                          }
                          return _MessageBoxes(
                            scrollController: _scrollController,
                            messages: _messages,
                            userId: token["id"],
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
          MessageInputBox(),
        ],
      ),
    );
  }
}

class _MessageBoxes extends StatefulWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final int userId;
  const _MessageBoxes(
      {required this.scrollController,
      required this.messages,
      required this.userId});

  @override
  State<_MessageBoxes> createState() => _MessageBoxesState();
}

class _MessageBoxesState extends State<_MessageBoxes> {
  void _scrollToBottom() {
    if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _MessageBox(
      Map<String, dynamic> message, AlignmentGeometry alignment) {
    DateTime timestamp = DateTime.parse(message["timestamp"]);
    int difference = DateTime.now().difference(timestamp).inDays;
    DateFormat dateFormat = DateFormat('HH:mm');
    if (difference >= 1) {
      dateFormat = DateFormat('yy.MM.dd HH:mm');
    }
    return Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            dateFormat.format(timestamp),
            style: const TextStyle(fontSize: 10),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(7.0, 4.0, 7.0, 4.0),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              message["content"],
              overflow: TextOverflow.visible,
              softWrap: true,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: ListView.builder(
        shrinkWrap: true,
        controller: widget.scrollController,
        itemCount: widget.messages.length,
        itemBuilder: (BuildContext context, int index) {
          Map<String, dynamic> message = widget.messages[index];
          AlignmentGeometry alignment = Alignment.centerLeft;
          if (message["userId"] == widget.userId) {
            alignment = Alignment.centerRight;
          }
          return _MessageBox(message, alignment);
        },
      ),
    );
  }
}

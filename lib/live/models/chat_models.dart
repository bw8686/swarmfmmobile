import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  final String name;
  final String nameColor;
  final String message;

  const ChatMessage({
    required this.name,
    required this.nameColor,
    required this.message,
  });
}

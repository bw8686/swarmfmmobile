import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  final String? name;
  final String nameColor;
  final String message;
  final int id;
  final bool isStruckThrough;

  const ChatMessage({
    this.name,
    required this.nameColor,
    required this.message,
    required this.id,
    this.isStruckThrough = false,
  });

  ChatMessage copyWith({
    String? name,
    String? nameColor,
    String? message,
    int? id,
    bool? isStruckThrough,
  }) {
    return ChatMessage(
      name: name ?? this.name,
      nameColor: nameColor ?? this.nameColor,
      message: message ?? this.message,
      id: id ?? this.id,
      isStruckThrough: isStruckThrough ?? this.isStruckThrough,
    );
  }
}

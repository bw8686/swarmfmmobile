// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarmfmmobile/live/components/fpwebsockets.dart';
import 'package:flutter/material.dart';
import 'package:swarmfmmobile/features/emotes/emote_provider.dart';

import 'package:swarmfmmobile/live/models/chat_models.dart';

final webSocketEventHandlerProvider = Provider<WebSocketEventHandler>((ref) {
  return WebSocketEventHandler(ref);
});

final chatProvider = StateNotifierProvider<ChatManager, List<ChatMessage>>((
  ref,
) {
  return ChatManager(ref);
});

final chatbroken = StateProvider<bool>((ref) => false);
final errorProvider = StateNotifierProvider<ErrorNotifier, ErrorState>((ref) {
  return ErrorNotifier();
});

class ErrorState {
  final bool hasError;
  final String errorMessage;

  ErrorState({this.hasError = false, this.errorMessage = ''});
}

class ErrorNotifier extends StateNotifier<ErrorState> {
  ErrorNotifier() : super(ErrorState());

  void setError(String message) {
    state = ErrorState(hasError: true, errorMessage: message);
  }
}

class Emote {
  final String name;
  final String url;

  Emote({required this.name, required this.url});

  factory Emote.fromJson(Map<String, dynamic> json) {
    return Emote(name: json['code'], url: json['image']);
  }
}

class EmoteResult {
  final bool isValid;
  final Emote? emote;

  EmoteResult(this.isValid, this.emote);
}

class ChatManager extends StateNotifier<List<ChatMessage>> {
  ChatManager(this.ref) : super([]);
  final dynamic ref;

  void addMessage(ChatMessage message) {
    final newState = [...state, message];
    state = newState.length > 175
        ? newState.sublist(newState.length - 175)
        : newState;
  }

  void reset() async {
    state = [];
  }

  void chatDisconnect() {
    state = [];
    ref.read(webSocketEventHandlerProvider).chatDisconnect();
  }

  void sendMessage(String message) {
    if (message.isNotEmpty) {
      fpWebsockets.sendChatMessage(message);
    }
  }
}

final emotepickerProvider =
    StateNotifierProvider<EmotePickerManager, Map<String, List<dynamic>>>((
      ref,
    ) {
      return EmotePickerManager(ref);
    });

class EmotePickerManager extends StateNotifier<Map<String, List<dynamic>>> {
  EmotePickerManager(this.ref) : super({});
  final dynamic ref;

  void updateEmotes(Map<String, dynamic> emotes) {
    final twitchEmotes = (emotes['emotes'] as List).map<Emote>((e) {
      return Emote.fromJson(e as Map<String, dynamic>);
    }).toList();
    state = {...state, 'Twitch': twitchEmotes};
  }

  Future<void> addSevenTVEmotes() async {
    final sevenTVEmotes = await ref.read(sevenTVEmotesProvider.future);
    final currentEmotes = Map<String, List<dynamic>>.from(state);

    currentEmotes['7TV'] = sevenTVEmotes;

    state = currentEmotes;
  }

  void reset() {
    state = {};
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionManager, Map<String, dynamic>>((ref) {
      return ConnectionManager(ref);
    });

class ConnectionManager extends StateNotifier<Map<String, dynamic>> {
  ConnectionManager(this.ref) : super({});
  final dynamic ref;

  void updateConnectionState(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (data['color'] == 'success') {
        Future.delayed(const Duration(seconds: 7), () {
          ref.read(connectionProvider.notifier).reset();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state = data;
    });
  }

  void reset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state = {};
    });
  }
}

class WebSocketEventHandler {
  final Ref ref;
  WebSocketEventHandler(this.ref);
  TextEditingController? controller;
  BuildContext? context;

  void sendMessage(
    String username,
    String message,
    String id, {
    bool isModerator = false,
    bool isCreator = true,
  }) {
    if (message.isNotEmpty) {
      fpWebsockets.sendChatMessage(message);
    }
  }

  void reset() {
    ref.read(emotepickerProvider.notifier).reset();
    ref.read(emotepickerProvider.notifier).addSevenTVEmotes();
    ref.read(chatProvider.notifier).reset();
  }

  void messagesHandler(Map<String, dynamic> data) async {
    try {
      if (data['type'] == 'new_message') {
        final msg = data['message'];
        final message = ChatMessage(
          name: msg['name'],
          nameColor: msg['name_color'],
          message: msg['message'],
        );
        ref.read(chatProvider.notifier).addMessage(message);
      } else if (data['type'] == 'message_history') {
        final msgs = data['messages'];
        for (final msg in msgs) {
          final message = ChatMessage(
            name: msg['name'],
            nameColor: msg['name_color'],
            message: msg['message'],
          );
          ref.read(chatProvider.notifier).addMessage(message);
        }
      } else if (data['type'] == 'user_timed_out') {
        ref.read(emotepickerProvider.notifier).updateEmotes(data['data']);
      } else if (data['type'] == 'user_banned') {
        ref.read(emotepickerProvider.notifier).updateEmotes(data['data']);
      } else if (data['type'] == 'message_deleted') {
        ref.read(emotepickerProvider.notifier).updateEmotes(data['data']);
      } else if (data['type'] == 'user_leave') {
        ref.read(emotepickerProvider.notifier).updateEmotes(data['data']);
      } else if (data['type'] == 'user_joined') {
        ref.read(emotepickerProvider.notifier).updateEmotes(data['data']);
      }
    } catch (e) {
      print('Error in messagesHandler: $e');
    }
  }

  void connectionHandler(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectionProvider.notifier).updateConnectionState(data);
    });
  }
}

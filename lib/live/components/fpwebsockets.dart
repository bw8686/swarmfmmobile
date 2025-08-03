import 'dart:async';
import 'dart:convert';

import 'package:web_socket_client/web_socket_client.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

final FPWebsockets fpWebsockets = GetIt.I<FPWebsockets>();

class FPWebsockets {
  late final WebSocket io;
  String userAgent;
  PackageInfo? packageInfo;
  StreamSubscription? listen;

  @override
  FPWebsockets({required this.userAgent}) {
    io = WebSocket(
      Uri.parse('wss://player.sw.arm.fm/chat'),
      headers: {'User-Agent': userAgent, 'Origin': 'https://player.sw.arm.fm'},
    );
  }

  registerListener(Function(Map<String, dynamic>) messagesHandler) {
    if (listen != null) {
      listen!.cancel();
      listen = null;
    }
    listen = io.messages.listen((message) {
      print(message);
      messagesHandler(jsonDecode(message));
    });
  }

  sendChatMessage(String message) async {
    if (message.isNotEmpty) {
      io.send(jsonEncode({"type": "send_message", "message": message}));
    }
  }

  historyRequest() async {
    bool connected = false;
    final stream = io.connection.listen((state) {
      if (state.toString() == "Instance of 'Connected'") {
        connected = true;
        io.send(jsonEncode({"type": "history_request"}));
      }
    });
    while (!connected) {
      await Future.delayed(const Duration(seconds: 1));
    }
    stream.cancel();
  }

  authorise(String session) async {
    bool connected = false;
    final stream = io.connection.listen((state) {
      if (state.toString() == "Instance of 'Connected'") {
        connected = true;
        final body = jsonEncode({"type": "authenticate", "session": session});
        io.send(body);
      }
    });
    while (!connected) {
      await Future.delayed(const Duration(seconds: 1));
    }
    stream.cancel();
  }

  Future<List<dynamic>> getChatUserList() async {
    late List<dynamic> users;
    bool recieved = false;
    final listen = io.messages.listen((message) {
      final decoded = jsonDecode(message);
      if (decoded['type'] == 'user_list') {
        users = decoded['users'];
        recieved = true;
      }
    });
    io.send(jsonEncode({"type": "user_list"}));
    while (!recieved) {
      await Future.delayed(const Duration(seconds: 1));
    }
    listen.cancel();
    return users;
  }
}

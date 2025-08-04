import 'dart:async';
import 'dart:convert';

import 'package:swarmfmmobile/settings.dart';
import 'package:web_socket_client/web_socket_client.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

final FPWebsockets fpWebsockets = GetIt.I<FPWebsockets>();

class FPWebsockets {
  late final WebSocket io;
  String userAgent;
  PackageInfo? packageInfo;
  StreamSubscription? listen;
  StreamSubscription? listen2;
  bool authsent = false;

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
    if (listen2 != null) {
      listen2!.cancel();
      listen2 = null;
    }
    listen = io.messages.listen((message) {
      messagesHandler(jsonDecode(message));
    });
    listen2 = io.connection.listen((state) async {
      if (state.toString() == "Instance of 'Connected'") {
        if (authsent) {
          authorise(await settings.getKey('session'));
        }
      }
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

  Future<String> authorise(String session) async {
    bool connected = false;
    StreamSubscription? msgstream;
    String name = '';
    bool nameset = false;
    final stream = io.connection.listen((state) {
      if (state.toString() == "Instance of 'Connected'") {
        connected = true;
        msgstream = io.messages.listen((message) {
          final decoded = jsonDecode(message);
          if (decoded['type'] == 'user_join') {
            msgstream!.cancel();
            name = decoded['name'];
            nameset = true;
          }
        });
        final body = jsonEncode({"type": "authenticate", "session": session});
        io.send(body);
        authsent = true;
      }
    });
    while (!connected) {
      await Future.delayed(const Duration(seconds: 1));
    }
    int namesetattempts = 0;
    while (!nameset && namesetattempts < 10) {
      await Future.delayed(const Duration(seconds: 1));
      namesetattempts++;
    }
    stream.cancel();
    msgstream!.cancel();
    return name;
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

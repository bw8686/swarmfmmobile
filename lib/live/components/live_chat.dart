// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:swarmfmmobile/settings.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:swarmfmmobile/live/components/chat_utils.dart';
import 'package:swarmfmmobile/live/components/emote_picker.dart';
import 'package:swarmfmmobile/live/components/fpwebsockets.dart';
import 'package:swarmfmmobile/live/controllers/live_chat_provider.dart';
import 'package:swarmfmmobile/live/components/chat_message_view.dart';
import 'package:uuid/uuid.dart';

class LiveChat extends ConsumerStatefulWidget {
  const LiveChat({super.key});

  @override
  ConsumerState<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends ConsumerState<LiveChat> {
  final TextEditingController controller = TextEditingController();
  final _scrollController = ScrollController();
  String? trueliveid;
  bool isChatterListOpen = false;
  bool isSettingsOpen = false;
  bool showEmotePicker = false;
  List<dynamic> chatterlist = [];
  int longpress = 0;
  bool authed = false;
  bool loading = true;
  String name = '';
  bool banned = false;
  bool timedout = false;
  int timeoutTime = 0;
  Timer? _timeoutTimer;

  final CookieManager _cookieManager = CookieManager.instance();

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent) {
        ref.read(chatbroken.notifier).state = true;
      } else {
        ref.read(chatbroken.notifier).state = false;
      }
    });
  }

  Future<void> _loadInitialStatus() async {
    final isBanned = await settings.getBool('banned');
    if (isBanned && mounted) {
      setState(() {
        banned = true;
      });
    }

    final timeoutString = await settings.getKey('timeout_until');
    if (timeoutString.isNotEmpty) {
      final timeoutUntil = DateTime.tryParse(timeoutString);
      if (timeoutUntil != null && timeoutUntil.isAfter(DateTime.now())) {
        if (mounted) {
          ref.read(timeoutProvider.notifier).timeout(timeoutUntil);
        }
      }
    }
  }

  Future<void> _init() async {
    await _loadInitialStatus();
    ref.read(webSocketEventHandlerProvider).controller = controller;
    ref.read(webSocketEventHandlerProvider).context = context;
    await fpWebsockets.registerListener(
      ref.read(webSocketEventHandlerProvider).messagesHandler,
    );
    final messages = ref.read(chatProvider);
    if (messages.isEmpty) {
      fpWebsockets.historyRequest();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final users = await fpWebsockets.getChatUserList();
      if (mounted) {
        setState(() {
          chatterlist = users;
        });
      }
    });
    final session = await settings.getKey('session');
    final authedcheck = session.isNotEmpty;
    if (authedcheck) {
      name = await fpWebsockets.authorise(session);
    }
    ref.read(webSocketEventHandlerProvider).name = name;
    setState(() {
      authed = authedcheck;
      loading = false;
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final messages = ref.watch(chatProvider);
    final errorState = ref.watch(errorProvider);

    ref.listen<bool>(banProvider, (previous, next) {
      if (next == true) {
        if (mounted) {
          setState(() {
            banned = true;
          });
        }
      }
    });

    ref.listen<Timeout>(timeoutProvider, (previous, next) {
      final now = DateTime.now();
      if (next.timeoutTime.isAfter(now)) {
        if (mounted) {
          setState(() {
            timedout = true;
            timeoutTime = next.timeoutTime.difference(now).inSeconds;
          });
          _timeoutTimer?.cancel();
          _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              setState(() {
                if (timeoutTime > 0) {
                  timeoutTime--;
                } else {
                  timedout = false;
                  settings.removeKey('timeout_until');
                  timer.cancel();
                }
              });
            } else {
              timer.cancel();
            }
          });
        }
      }
    });

    ref.listen<bool>(banProvider, (previous, next) {
      if (next == true) {
        if (mounted) {
          setState(() {
            banned = true;
          });
        }
      }
    });

    ref.listen<Timeout>(timeoutProvider, (previous, next) {
      final now = DateTime.now();
      if (next.timeoutTime.isAfter(now)) {
        if (mounted) {
          setState(() {
            timedout = true;
            timeoutTime = next.timeoutTime.difference(now).inSeconds;
          });
          _timeoutTimer?.cancel();
          _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              setState(() {
                if (timeoutTime > 0) {
                  timeoutTime--;
                } else {
                  timedout = false;
                  settings.removeKey('timeout_until');
                  timer.cancel();
                }
              });
            } else {
              timer.cancel();
            }
          });
        }
      }
    });
    ref.listen(chatProvider, (previous, next) {
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ref.watch(chatbroken) == false) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });
    return loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Scaffold(
              appBar: AppBar(
                elevation: 0,
                toolbarHeight: 40,
                backgroundColor: colorScheme.surfaceContainer,
                surfaceTintColor: colorScheme.surfaceContainer,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () async {
                      if (isSettingsOpen) {
                        setState(() {
                          isSettingsOpen = false;
                        });
                      }
                      final users = await fpWebsockets.getChatUserList();
                      setState(() {
                        chatterlist = users;
                      });
                      if (chatterlist.isEmpty) {
                        ref
                            .read(errorProvider.notifier)
                            .setError(chatterlist.toString());
                        setState(() {
                          isChatterListOpen = !isChatterListOpen;
                        });
                      } else {
                        if (isChatterListOpen) {
                          setState(() {
                            isChatterListOpen = false;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (ref.watch(chatbroken) == false) {
                              _scrollController.jumpTo(
                                _scrollController.position.maxScrollExtent,
                              );
                            }
                          });
                        } else {
                          setState(() {
                            isChatterListOpen = true;
                          });
                        }
                      }
                    },
                    icon: isChatterListOpen
                        ? Icon(
                            Icons.chat,
                            color: theme.textTheme.titleLarge?.color,
                          )
                        : Icon(
                            Icons.list,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                  ),
                  IconButton(
                    onLongPress: () async {
                      longpress = longpress + 1;
                      if (longpress == 2) {
                        settings.setBool('secretsettings', true);
                      }
                      if (longpress == 4) {
                        settings.setBool('secretsettings', false);
                        longpress = 0;
                      }
                    },
                    onPressed: () async {
                      if (isChatterListOpen) {
                        setState(() {
                          isChatterListOpen = false;
                        });
                      }
                      if (isSettingsOpen) {
                        setState(() {
                          isSettingsOpen = false;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (ref.watch(chatbroken) == false) {
                            _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            );
                          }
                        });
                      } else {
                        setState(() {
                          isSettingsOpen = true;
                        });
                      }
                    },
                    icon: isSettingsOpen
                        ? Icon(
                            Icons.chat,
                            color: theme.textTheme.titleLarge?.color,
                          )
                        : Icon(
                            Icons.settings,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                  ),
                ],
                title: Text(
                  isChatterListOpen
                      ? "Viewer List"
                      : isSettingsOpen
                      ? "Settings"
                      : "Live Chat",
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ),
              body: errorState.hasError
                  ? Center(child: Text(errorState.errorMessage))
                  : isChatterListOpen
                  ? Column(
                      children: [Expanded(child: chatterList(chatterlist))],
                    )
                  : isSettingsOpen
                  ? Column(children: [Expanded(child: SettingsScreen())])
                  : Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          if (controller.text.isNotEmpty) {
                            fpWebsockets.sendChatMessage(controller.text);
                            controller.clear();
                          }
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              Flexible(
                                child: Stack(
                                  children: [
                                    if (ref
                                        .watch(connectionProvider)
                                        .isNotEmpty)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 7.5,
                                        child: Center(
                                          child: Badge(
                                            backgroundColor:
                                                ref.watch(
                                                      connectionProvider,
                                                    )['color'] ==
                                                    'success'
                                                ? colorScheme.secondaryContainer
                                                : ref.watch(
                                                        connectionProvider,
                                                      )['color'] ==
                                                      'warning'
                                                ? colorScheme.tertiaryContainer
                                                : colorScheme.errorContainer,
                                            label: Text(
                                              ref.watch(
                                                    connectionProvider,
                                                  )['message'] ??
                                                  'Disconnected',
                                              style: TextStyle(
                                                color:
                                                    ref.watch(
                                                          connectionProvider,
                                                        )['color'] ==
                                                        'success'
                                                    ? colorScheme
                                                          .onSecondaryContainer
                                                    : ref.watch(
                                                            connectionProvider,
                                                          )['color'] ==
                                                          'warning'
                                                    ? colorScheme
                                                          .onTertiaryContainer
                                                    : colorScheme
                                                          .onErrorContainer,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 3.5,
                                              horizontal: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ListView.builder(
                                      controller: _scrollController,
                                      itemCount: messages.length,
                                      itemBuilder: (context, index) {
                                        final msg = messages[index];
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ChatMessageView(message: msg),
                                            Divider(
                                              indent: 2,
                                              endIndent: 2,
                                              height: 2,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (authed)
                                Column(
                                  children: [
                                    Container(
                                      height: 35,
                                      color: colorScheme.surfaceContainer,
                                      padding: EdgeInsets.only(top: 6),
                                      child: ListTile(
                                        minVerticalPadding: 0,
                                        minTileHeight: 1,
                                        dense: true,
                                        title: Text(
                                          "Emotes",
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            showEmotePicker = !showEmotePicker;
                                          });
                                        },
                                        trailing: IconButton(
                                          iconSize: 15,
                                          icon: Icon(
                                            showEmotePicker
                                                ? Icons.arrow_drop_down
                                                : Icons.arrow_drop_up,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              showEmotePicker =
                                                  !showEmotePicker;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      height: showEmotePicker ? 150 : 0,
                                      color: colorScheme.surfaceContainer,
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          return EmotePicker(
                                            onEmoteSelected: (emote) {
                                              controller.text += '$emote ';
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              if (authed)
                                Row(
                                  children: [
                                    Flexible(
                                      child: banned
                                          ? Center(
                                              child: Text('You are banned'),
                                            )
                                          : timedout
                                          ? Center(
                                              child: Text(
                                                'You are timed out for $timeoutTime seconds',
                                              ),
                                            )
                                          : TextField(
                                              maxLength: 500,
                                              maxLengthEnforcement:
                                                  MaxLengthEnforcement.enforced,
                                              minLines: 1,
                                              maxLines: 2,
                                              controller: controller,
                                              onSubmitted: (String value) {
                                                fpWebsockets.sendChatMessage(
                                                  controller.text,
                                                );
                                                controller.clear();
                                              },
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.all(
                                                  4,
                                                ),
                                                border: InputBorder.none,
                                                counterText:
                                                    '', // i love flutter
                                                hintText: "Enter your message",
                                              ),
                                            ),
                                    ),
                                    if (!banned && !timedout)
                                      IconButton(
                                        icon: Icon(Icons.send),
                                        onPressed: () {
                                          fpWebsockets.sendChatMessage(
                                            controller.text,
                                          );
                                          controller.clear();
                                        },
                                      ),
                                  ],
                                ),
                              if (!authed)
                                Container(
                                  width: double.infinity,
                                  color: colorScheme.surfaceContainer,
                                  padding: EdgeInsets.all(8),
                                  child: Center(
                                    child: TextButton(
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(
                                          Colors.deepPurple,
                                        ),
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final cookieManager =
                                            CookieManager.instance();
                                        final uuid = Uuid().v4();
                                        await cookieManager.deleteAllCookies();
                                        await cookieManager.setCookie(
                                          url: WebUri(
                                            'https://player.sw.arm.fm/',
                                          ),
                                          name: 'swarm_fm_player_session',
                                          value: uuid,
                                        );
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            content: SizedBox(
                                              width:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.8,
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.7,
                                              child: SingleChildScrollView(
                                                child: SizedBox(
                                                  height:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.height *
                                                      1.5,
                                                  child: InAppWebView(
                                                    initialUrlRequest: URLRequest(
                                                      url: WebUri(
                                                        'https://id.twitch.tv/oauth2/authorize?client_id=ijg6o5dv2nq9j6g4tcm6mx3p25twbz&redirect_uri=https://player.sw.arm.fm/twitch_auth&response_type=code&scope=',
                                                      ),
                                                    ),
                                                    onLoadStop: (controller, url) async {
                                                      if (url.toString() ==
                                                          'https://player.sw.arm.fm/') {
                                                        final cookies =
                                                            await _cookieManager
                                                                .getCookies(
                                                                  url: WebUri(
                                                                    'https://player.sw.arm.fm',
                                                                  ),
                                                                );
                                                        final sessionCookie =
                                                            cookies.firstWhere(
                                                              (cookie) =>
                                                                  cookie.name ==
                                                                  'swarm_fm_player_session',
                                                              orElse: () =>
                                                                  Cookie(
                                                                    name: '',
                                                                  ),
                                                            );

                                                        if (sessionCookie
                                                            .name
                                                            .isNotEmpty) {
                                                          final sessionValue =
                                                              sessionCookie
                                                                  .value;

                                                          settings.setKey(
                                                            'session',
                                                            sessionValue,
                                                          );

                                                          fpWebsockets
                                                              .authorise(
                                                                sessionValue,
                                                              );

                                                          setState(() {
                                                            authed = true;
                                                          });

                                                          if (mounted) {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          }
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                child: Text("Cancel"),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: SizedBox(
                                        height: 35,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            FaIcon(
                                              FontAwesomeIcons.twitch,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              "Login with Twitch",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Positioned(
                            top: 20,
                            right: 20,
                            child: AnimatedOpacity(
                              duration: Duration(milliseconds: 300),
                              opacity: ref.watch(chatbroken) ? 1.0 : 0.0,
                              child: FloatingActionButton(
                                onPressed: () async {
                                  await _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  ref.read(chatbroken.notifier).state =
                                      false; // Reset chatbroken state
                                  //this is just in case (insurance policy)
                                  Future.delayed(
                                    Duration(milliseconds: 10),
                                    () {
                                      _scrollController.jumpTo(
                                        _scrollController
                                            .position
                                            .maxScrollExtent,
                                      );
                                    },
                                  );
                                },
                                backgroundColor: colorScheme.primary,
                                child: Icon(Icons.arrow_downward),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
  }
}

Widget chatterList(List<dynamic> chatterdata) {
  // Convert to Set to remove duplicates, then back to List
  final uniqueChatters = chatterdata.toSet().toList();

  // Sort the list case-insensitively
  uniqueChatters.sort(
    (a, b) => a.toString().toLowerCase().compareTo(b.toString().toLowerCase()),
  );
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(top: 10, left: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${uniqueChatters.length} chatters present",
            textAlign: TextAlign.left,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Column(
              children: List.generate(uniqueChatters.length, (index) {
                final username = uniqueChatters[index].toString();
                final colorHex = getColorForUsername(username);
                final color = Color(
                  int.parse('0xFF$colorHex'.replaceAll('#', '')),
                );

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 0,
                  minTileHeight: 0,
                  dense: true,
                  title: Text(
                    username,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? sizeOption;
  bool showUsernameColors = true; // Default true
  bool playSoundWhenMentioned = false; // Default false
  bool highlightMentions = true; // Default true
  bool adminview = false; // Default false
  bool timestampMessages = false; // Default false
  bool ll = false; // Default false
  bool _isPlayerInitialized = false;
  bool secretSettings = false;
  bool _isLoading = true;
  String username = '';
  final AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _isPlayerInitialized = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bool usernamecolors = await settings.getBool(
      'show_username_colors',
      defaultValue: true,
    );
    final bool soundMentions = await settings.getBool(
      'play_sound_when_mentioned',
      defaultValue: false,
    );
    final bool lightMentions = await settings.getBool(
      'highlight_mentions',
      defaultValue: true,
    );
    final bool adminView = await settings.getBool(
      'adminview',
      defaultValue: false,
    );
    final bool timestampOnMessages = await settings.getBool(
      'timestamp_messages',
      defaultValue: false,
    );
    final bool llresult = await settings.getBool(
      'll',
      defaultValue: Platform.isIOS ? true : false,
    );
    final bool secretSettingsEnabled = await settings.getBool(
      'secretsettings',
      defaultValue: false,
    );

    final String usernameKey = await settings.getKey('username');

    if (mounted) {
      setState(() {
        showUsernameColors = usernamecolors;
        playSoundWhenMentioned = soundMentions;
        highlightMentions = lightMentions;
        adminview = adminView;
        timestampMessages = timestampOnMessages;
        ll = llresult;
        secretSettings = secretSettingsEnabled;
        username = usernameKey;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_isPlayerInitialized) {
      _isPlayerInitialized = false;
    }
    super.dispose();
    player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: playSoundWhenMentioned,
                onChanged: (value) async {
                  setState(() {
                    playSoundWhenMentioned = value;
                  });
                  settings.setBool('play_sound_when_mentioned', value);
                  if (value) {
                    final player = AudioPlayer();
                    await player.play(AssetSource('livechat/pop.wav'));
                    Future.delayed(const Duration(seconds: 5), () {
                      player.dispose();
                    });
                  }
                },
                title: Text('Play sound when mentioned'),
              ),
              SwitchListTile(
                value: highlightMentions,
                onChanged: (value) async {
                  setState(() {
                    highlightMentions = value;
                  });
                  settings.setBool('highlight_mentions', value);
                },
                title: Text('Highlight @myname mentions'),
              ),
              SwitchListTile(
                value: timestampMessages,
                onChanged: (value) async {
                  setState(() {
                    timestampMessages = value;
                  });
                  settings.setBool('timestamp_messages', value);
                },
                title: Text('Timestamp on messages'),
              ),
              SwitchListTile(
                value: ll,
                onChanged: (value) async {
                  setState(() {
                    timestampMessages = value;
                  });
                  settings.setBool('ll', value);
                },
                title: Text('Low Latency HLS (Buggy)'),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text('Chat Message Size', style: textTheme.titleMedium),
              ),
              SizedBox(height: 5),
              Center(
                child: FutureBuilder(
                  future: settings.getDynamic(
                    'chat_message_size',
                    defaultValue: 1,
                  ),
                  builder: (context, snapshot) {
                    return ToggleButtons(
                      direction: Axis.horizontal,
                      onPressed: (int index) {
                        setState(() {
                          sizeOption = index;
                        });
                        settings.setDynamic('chat_message_size', index);
                      },
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      constraints: BoxConstraints(
                        minHeight: 40.0,
                        minWidth: constraints.maxWidth / 3 - 12,
                      ),
                      isSelected: [
                        sizeOption != null
                            ? sizeOption == 0
                            : snapshot.data == 0,
                        sizeOption != null
                            ? sizeOption == 1
                            : snapshot.data == 1,
                        sizeOption != null
                            ? sizeOption == 2
                            : snapshot.data == 2,
                      ],
                      children: const [
                        Text('Small'),
                        Text('Medium'),
                        Text('Large'),
                      ],
                    );
                  },
                ),
              ),
              if (secretSettings) SizedBox(height: 16),
              if (secretSettings)
                SwitchListTile(
                  value: adminview,
                  onChanged: (value) {
                    setState(() {
                      adminview = value;
                    });
                    settings.setBool('adminview', value);
                  },
                  title: Text('Admin View'),
                ),
            ],
          );
        },
      ),
    );
  }
}

import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swarmfmmobile/live/components/fpwebsockets.dart';
import 'package:swarmfmmobile/live/components/live_chat.dart';
import 'package:swarmfmmobile/settings.dart';

GetIt getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  final userAgent =
      'SwarmFMMobile/${packageInfo.version} (${packageInfo.buildNumber})';

  getIt.registerSingleton<Settings>(Settings());

  getIt.registerSingleton<FPWebsockets>(FPWebsockets(userAgent: userAgent));

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const SafeArea(child: MyHomePage()),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final BetterPlayerController _betterPlayerController;
  bool _isInitialized = false;
  double _chatWidth = 350.0;
  bool _isResizing = false;
  final double _minChatWidth = 200.0;
  final double _maxChatWidth = 500.0;

  final GlobalKey _betterPlayerKey = GlobalKey();

  // Handle mouse hover and drag for resizing
  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isResizing) return;

    setState(() {
      _chatWidth = (_chatWidth - details.delta.dx).clamp(
        _minChatWidth,
        _maxChatWidth,
      );
    });
  }

  void _onPanStart(DragStartDetails details) {
    _isResizing = true;
  }

  void _onPanEnd(DragEndDetails details) {
    _isResizing = false;
  }

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final configuration = BetterPlayerConfiguration(
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableSubtitles: false,
        enableAudioTracks: false,
        enablePlaybackSpeed: false,
      ),
      autoPlay: true,
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      handleLifecycle: false,
      allowedScreenSleep: false,
    );

    final ll = await settings.getBool(
      'll',
      defaultValue: Platform.isIOS ? true : false,
    );

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      'https://customer-x1r232qaorg7edh8.cloudflarestream.com/3a05b1a1049e0f24ef1cd7b51733ff09/manifest/video.m3u8${ll ? '?protocol=llhls' : ''}',
      liveStream: true,
      videoFormat: BetterPlayerVideoFormat.hls,
      videoExtension: 'm3u8',
    );

    _betterPlayerController = BetterPlayerController(
      configuration,
      betterPlayerDataSource: dataSource,
    );

    _betterPlayerController.setBetterPlayerGlobalKey(_betterPlayerKey);

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          if (availableWidth < 600) {
            return Column(
              children: [
                // Video Player
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 400),
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: BetterPlayer(
                        key: _betterPlayerKey,
                        controller: _betterPlayerController,
                      ),
                    ),
                  ),
                ),
                // Chat takes remaining space
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: const LiveChat(),
                  ),
                ),
              ],
            );
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Player - takes remaining width minus chat width
                Expanded(
                  flex: 3,
                  child: Container(
                    height: double.infinity,
                    color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: BetterPlayer(
                          key: _betterPlayerKey,
                          controller: _betterPlayerController,
                        ),
                      ),
                    ),
                  ),
                ),
                // Resizable divider between video and chat
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: _onPanUpdate,
                    onHorizontalDragStart: _onPanStart,
                    onHorizontalDragEnd: _onPanEnd,
                    child: Container(
                      width: 3,
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: 3,
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                // Chat panel
                Container(
                  width: _chatWidth,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: const LiveChat(),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

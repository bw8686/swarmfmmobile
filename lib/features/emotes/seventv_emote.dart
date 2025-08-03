import 'package:flutter/foundation.dart';

@immutable
class SevenTVEmote {
  final String id;
  final String name;
  final int flags;
  final bool animated;
  final String url;
  final int height;
  final int width;

  bool get zeroWidth => flags != 0;

  const SevenTVEmote({
    required this.id,
    required this.name,
    required this.flags,
    required this.animated,
    required this.url,
    required this.height,
    required this.width,
  });

  factory SevenTVEmote.fromJson(
    Map<String, dynamic> json,
    List<dynamic> files,
  ) {
    final isZeroWidth = (json['data']['flags']) != 0;
    print(
      '[Debug Emote] Parsing emote: ${json['name']}, flags: ${json['data']['flags']}, isZeroWidth: $isZeroWidth',
    );
    return SevenTVEmote(
      id: json['id'],
      name: json['name'],
      animated: json['data']['animated'],
      flags: json['data']['flags'],
      url: 'https://cdn.7tv.app/emote/${json['id']}',
      width: files[0]['width'],
      height: files[0]['height'],
    );
  }
}

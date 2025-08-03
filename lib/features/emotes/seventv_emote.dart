import 'package:flutter/foundation.dart';

@immutable
class SevenTVEmote {
  final String id;
  final String name;
  final bool zeroWidth;
  final bool animated;
  final String url;
  final int height;
  final int width;

  const SevenTVEmote({
    required this.id,
    required this.name,
    required this.zeroWidth,
    required this.animated,
    required this.url,
    required this.height,
    required this.width,
  });

  factory SevenTVEmote.fromJson(
    Map<String, dynamic> json,
    List<dynamic> files,
  ) {
    return SevenTVEmote(
      id: json['id'],
      name: json['name'],
      animated: json['data']['animated'],
      zeroWidth: (json['data']['flags'] & 1) == 1,
      url: 'https://cdn.7tv.app/emote/${json['id']}',
      width: files[0]['width'],
      height: files[0]['height'],
    );
  }
}

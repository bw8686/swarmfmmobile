import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarmfmmobile/features/emotes/emote_service.dart';
import 'package:swarmfmmobile/features/emotes/seventv_emote.dart';
import 'dart:convert';

final emoteServiceProvider = Provider((ref) => EmoteService());

final sevenTVEmotesProvider = FutureProvider<List<SevenTVEmote>>((ref) async {
  final emoteService = ref.watch(emoteServiceProvider);
  final prefs = await SharedPreferences.getInstance();

  final cachedEmotes = prefs.getString('seventv_emotes');
  final cacheTimestamp = prefs.getInt('seventv_emotes_timestamp');
  final now = DateTime.now().millisecondsSinceEpoch;

  if (cachedEmotes != null && cacheTimestamp != null) {
    if (now - cacheTimestamp < 86400000) {
      // 24 hours
      final List<dynamic> decodedEmotes = jsonDecode(cachedEmotes);
      return decodedEmotes.map((emoteJson) {
        final files = emoteJson['data']['host']['files'] as List<dynamic>;
        return SevenTVEmote.fromJson(emoteJson, files);
      }).toList();
    }
  }

  const emoteSetIds = [
    "01GN2QZDS0000BKRM8E4JJD3NV", // vedal
    "01JKCEZS0D4MGWVNGKQWBTWSYT", // swarmfm whisper
    "01JKCF444J7HTNKE4TEQ0DBP1F", // swarmfm emotes
    "01K1H87ZZVE92Y3Z37H3ES6BK8", // dafox
    "01HKQT8EWR000ESSWF3625XCS4", // global
  ];

  final allEmotes = <String, SevenTVEmote>{};

  for (final emoteSetId in emoteSetIds.reversed) {
    final emotes = await emoteService.getSevenTVEmoteSet(emoteSetId);
    for (final emote in emotes) {
      allEmotes[emote.name] = emote;
    }
  }

  final emoteList = allEmotes.values.toList();

  await prefs.setString(
    'seventv_emotes',
    jsonEncode(
      emoteList
          .map(
            (value) => {
              'id': value.id,
              'name': value.name,
              'data': {
                'animated': value.animated,
                'flags': value.zeroWidth ? 1 : 0,
                'host': {
                  'files': [
                    {'width': value.width, 'height': value.height},
                  ],
                },
              },
            },
          )
          .toList(),
    ),
  );
  await prefs.setInt('seventv_emotes_timestamp', now);

  return emoteList;
});

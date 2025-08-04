import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarmfmmobile/features/emotes/emote_service.dart';
import 'package:swarmfmmobile/features/emotes/seventv_emote.dart';

final emoteServiceProvider = Provider((ref) => EmoteService());

final emotepickerProvider = FutureProvider<Map<String, List<SevenTVEmote>>>((
  ref,
) async {
  final emoteService = ref.watch(emoteServiceProvider);

  const emoteSets = {
    'vedal': "01GN2QZDS0000BKRM8E4JJD3NV",
    'swarmfm whisper': "01JKCEZS0D4MGWVNGKQWBTWSYT",
    'swarmfm emotes': "01JKCF444J7HTNKE4TEQ0DBP1F",
    'dafox': "01K1H87ZZVE92Y3Z37H3ES6BK8",
    'global': "01HKQT8EWR000ESSWF3625XCS4",
  };

  final allEmotes = <String, List<SevenTVEmote>>{};

  for (final entry in emoteSets.entries) {
    final channelName = entry.key;
    final emoteSetId = entry.value;
    try {
      final emotes = await emoteService.getSevenTVEmoteSet(emoteSetId);
      allEmotes[channelName] = emotes;
    } catch (e) {
      allEmotes[channelName] = []; // Add empty list on failure
    }
  }

  return allEmotes;
});

// This provider gives a flat list of all emotes for chat message rendering.
final sevenTVEmotesProvider = FutureProvider<List<SevenTVEmote>>((ref) async {
  final emoteMap = await ref.watch(emotepickerProvider.future);
  // Flatten the map values into a single list of emotes.
  return emoteMap.values.expand((emotes) => emotes).toList();
});

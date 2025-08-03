import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarmfmmobile/features/emotes/emote_provider.dart';
import 'package:swarmfmmobile/features/emotes/seventv_emote.dart';

class EmotePicker extends ConsumerWidget {
  final Function(String) onEmoteSelected;

  const EmotePicker({super.key, required this.onEmoteSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emotesAsyncValue = ref.watch(sevenTVEmotesProvider);

    return emotesAsyncValue.when(
      data: (emotes) {
        // The provider returns a List<SevenTVEmote>, not a Map.
        final List<SevenTVEmote> emoteList = emotes;
        return Container(
          height: 100,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 40,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
            ),
            itemCount: emoteList.length,
            itemBuilder: (context, index) {
              final SevenTVEmote emote = emoteList[index];
              return GestureDetector(
                onTap: () => onEmoteSelected(emote.name),
                child: Tooltip(
                  message: emote.name,
                  child: Padding(
                    padding: const EdgeInsets.all(0.5),
                    child: Image.network('${emote.url}/1x.webp'),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const Center(child: Text('Failed to load emotes')),
    );
  }
}

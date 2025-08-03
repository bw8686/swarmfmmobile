import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swarmfmmobile/features/emotes/emote_provider.dart';
import 'package:swarmfmmobile/features/emotes/seventv_emote.dart';
import 'package:swarmfmmobile/live/models/chat_models.dart';

class ChatMessageView extends ConsumerWidget {
  final ChatMessage message;

  const ChatMessageView({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emotesAsyncValue = ref.watch(sevenTVEmotesProvider);

    return emotesAsyncValue.when(
      data: (emotes) => _buildMessageWithEmotes(context, emotes),
      loading: () =>
          _buildMessageWithEmotes(context, []), // Show plain text while loading
      error: (err, stack) =>
          _buildMessageWithEmotes(context, []), // Show plain text on error
    );
  }

  Widget _buildMessageWithEmotes(
    BuildContext context,
    List<SevenTVEmote> emoteList,
  ) {
    final emotes = {for (var e in emoteList) e.name: e};
    final List<InlineSpan> spans = [];
    final words = message.message.split(' ');

    for (final word in words) {
      if (emotes.containsKey(word)) {
        final emote = emotes[word]!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Image.network(
                '${emote.url}/1x.webp', // Using webp format as a default
                height: 24,
                width: 24,
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: '$word '));
      }
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '${message.name}: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _parseColor(message.nameColor),
            ),
          ),
          ...spans,
        ],
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.white;
    }
  }
}

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
    final List<InlineSpan> textSpans = [];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final emote = emotes[word];

      if (emote != null && !emote.zeroWidth) {
        // This is a base emote, check for subsequent zero-width emotes.
        final List<SevenTVEmote> zeroWidthEmotes = [];
        int j = i + 1;
        while (j < words.length) {
          final nextWord = words[j];
          final nextEmote = emotes[nextWord];
          if (nextEmote != null && nextEmote.zeroWidth) {
            zeroWidthEmotes.add(nextEmote);
            j++;
          } else {
            break;
          }
        }

        final allEmotes = [emote, ...zeroWidthEmotes];

        // Calculate the maximum width needed for proper stacking
        const double emoteHeight = 28.0;
        final double maxWidth = allEmotes
            .map((e) => (e.width / e.height) * emoteHeight)
            .reduce((a, b) => a > b ? a : b);

        final List<Widget> stackChildren = [];

        // Add base emote first (bottom of stack)
        stackChildren.add(
          SizedBox(
            width: maxWidth,
            height: emoteHeight,
            child: Image.network(
              '${emote.url}/2x.webp',
              height: emoteHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to 1x version if 2x fails
                return Image.network(
                  '${emote.url}/1x.webp',
                  height: emoteHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Final fallback - show emote name as text
                    return Container(
                      width: maxWidth,
                      height: emoteHeight,
                      alignment: Alignment.center,
                      child: Text(
                        emote.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );

        // Add zero-width emotes on top
        for (final zeroWidthEmote in zeroWidthEmotes) {
          stackChildren.add(
            SizedBox(
              width: maxWidth,
              height: emoteHeight,
              child: Image.network(
                '${zeroWidthEmote.url}/2x.webp',
                height: emoteHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to 1x version if 2x fails
                  return Image.network(
                    '${zeroWidthEmote.url}/1x.webp',
                    height: emoteHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Final fallback - show emote name as text
                      return SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          );
        }

        textSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Stack(alignment: Alignment.center, children: stackChildren),
          ),
        );

        i = j - 1; // Move index past the consumed zero-width emotes
      } else if (emote != null && emote.zeroWidth) {
        // Standalone zero-width emote, render as text.
        textSpans.add(TextSpan(text: '$word '));
      } else {
        // Regular word
        textSpans.add(TextSpan(text: '$word '));
      }
    }

    spans.addAll(textSpans);

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

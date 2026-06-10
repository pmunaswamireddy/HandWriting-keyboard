import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../../core/services/sticker_service.dart';
import '../../../core/theme/keyboard_themes.dart';

class MediaPanel extends ConsumerStatefulWidget {
  final Function(String) onEmojiTap;
  final KeyboardThemeData kbTheme;

  const MediaPanel({
    super.key,
    required this.onEmojiTap,
    required this.kbTheme,
  });

  @override
  ConsumerState<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends ConsumerState<MediaPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<String> _stickers = [];
  bool _isLoadingStickers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrendingStickers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrendingStickers() async {
    setState(() => _isLoadingStickers = true);
    final service = ref.read(stickerServiceProvider);
    final stickers = await service.getTrendingStickers();
    if (mounted) {
      setState(() {
        _stickers = stickers;
        _isLoadingStickers = false;
      });
    }
  }

  Future<void> _searchStickers(String query) async {
    setState(() => _isLoadingStickers = true);
    final service = ref.read(stickerServiceProvider);
    final stickers = await service.searchStickers(query);
    if (mounted) {
      setState(() {
        _stickers = stickers;
        _isLoadingStickers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.kbTheme.backgroundColor,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              indicatorColor: widget.kbTheme.accentColor,
              labelColor: widget.kbTheme.accentColor,
              unselectedLabelColor: widget.kbTheme.textColor.withOpacity(0.5),
              tabs: const [
                Tab(icon: Icon(Icons.emoji_emotions_outlined), text: 'Emoji'),
                Tab(icon: Icon(Icons.gif_box_outlined), text: 'Stickers'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmojiPicker(),
                _buildStickerPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    const emojis = [
      '😀','😂','🥰','😎','😭','🥺','🤔','😤','🤯','🥳',
      '👍','👎','👏','🙌','🤝','🙏','💪','👌','✌️','🔥',
      '❤️','💔','💯','✨','🎉','🎂','🎁','🎈','🌟','💫',
      '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯',
      '🍎','🍊','🍋','🍌','🍉','🍇','🍓','🍈','🍒','🍑',
      '🚗','🚕','🚙','🚌','🚎','🏎️','🚓','🚑','🚒','🚐',
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => widget.onEmojiTap(emojis[index]),
          child: Center(
            child: Text(
              emojis[index],
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            onSubmitted: _searchStickers,
            style: GoogleFonts.outfit(color: widget.kbTheme.textColor),
            decoration: InputDecoration(
              hintText: 'Search Giphy Stickers...',
              hintStyle: TextStyle(color: widget.kbTheme.textColor.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: widget.kbTheme.textColor.withOpacity(0.5)),
              filled: true,
              fillColor: widget.kbTheme.keyColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingStickers
              ? Center(child: CircularProgressIndicator(color: widget.kbTheme.accentColor))
              : _stickers.isEmpty
                  ? Center(
                      child: Text(
                        'No stickers found',
                        style: TextStyle(color: widget.kbTheme.textColor.withOpacity(0.5)),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _stickers.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // In a real keyboard IME, this would insert an ImageSpan or commit Content.
                            // For now, we'll just insert a placeholder text or show a snackbar.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sticker selected: ${_stickers[index]}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _stickers[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: widget.kbTheme.keyColor,
                                  child: Center(
                                    child: Icon(Icons.image, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

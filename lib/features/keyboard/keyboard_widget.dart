import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/keyboard_themes.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/glyph_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/models/glyph_map.dart';
import 'widgets/glyph_key.dart';
import 'voice/voice_indicator_widget.dart';
import 'media/media_panel.dart';
import '../../core/services/gemini_service.dart';

/// The main keyboard widget — rendered as a system IME on Android.
/// On Windows this is the floating overlay keyboard.
class HandwritingKeyboardWidget extends ConsumerStatefulWidget {
  final Function(String) onTextInput;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;
  final String currentText;
  final Function(String, int)? onSuggestionTap;

  const HandwritingKeyboardWidget({
    super.key,
    required this.onTextInput,
    required this.onBackspace,
    required this.onEnter,
    this.currentText = '',
    this.onSuggestionTap,
  });

  @override
  ConsumerState<HandwritingKeyboardWidget> createState() =>
      _HandwritingKeyboardWidgetState();
}

class _HandwritingKeyboardWidgetState
    extends ConsumerState<HandwritingKeyboardWidget> {
  bool _isShifted = false;
  bool _isCapsLock = false;
  bool _showSymbols = false;
  bool _showEmoji = false;
  bool _isVoiceActive = false;
  String _voiceText = '';

  // Swipe gesture tracking
  Offset? _swipeStart;
  List<String> _swipePath = [];
  bool _isSwiping = false;

  // Speech
  final SpeechToText _speech = SpeechToText();

  static const List<List<String>> _qwertyRows = [
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'],
    ['z','x','c','v','b','n','m'],
  ];

  static const List<List<String>> _symbolRows = [
    ['1','2','3','4','5','6','7','8','9','0'],
    ['!','@','#','\$','%','^','&','*','(',')',],
    ['-','_','=','+','[',']','{','}','|','\\'],
    [';',':','\'','"',',','.','<','>','/','?'],
  ];

  String _lastWord(String text) {
    final RegExp wordRegex = RegExp(r"[a-zA-Z0-9\']+$");
    final match = wordRegex.firstMatch(text);
    return match != null ? match.group(0) ?? '' : '';
  }

  String _applyShift(String char) {
    if (_isShifted || _isCapsLock) return char.toUpperCase();
    return char;
  }

  void _onKeyTap(String char) {
    HapticFeedback.selectionClick();
    widget.onTextInput(_applyShift(char));
    if (_isShifted && !_isCapsLock) {
      setState(() => _isShifted = false);
    }
  }

  void _onShiftTap() {
    setState(() {
      if (_isCapsLock) {
        _isCapsLock = false;
        _isShifted = false;
      } else if (_isShifted) {
        _isCapsLock = true;
      } else {
        _isShifted = true;
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleVoice() async {
    print('Voice typing toggled: active=$_isVoiceActive');
    if (_isVoiceActive) {
      await _speech.stop();
      setState(() => _isVoiceActive = false);
    } else {
      try {
        final available = await _speech.initialize(
          onStatus: (status) => print('Speech status: $status'),
          onError: (error) => print('Speech error: ${error.errorMsg}'),
        );
        print('Speech initialize available: $available');
        if (available) {
          setState(() {
            _isVoiceActive = true;
            _voiceText = '';
          });
          await _speech.listen(
            onResult: (result) {
              print('Speech result: ${result.recognizedWords}');
              setState(() => _voiceText = result.recognizedWords);
              if (result.finalResult) {
                widget.onTextInput('${result.recognizedWords} ');
                setState(() {
                  _isVoiceActive = false;
                  _voiceText = '';
                });
              }
            },
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 2),
          );
        } else {
          print('Speech not available, permissions maybe denied.');
        }
      } catch (e) {
        print('Exception initializing speech: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);
    final glyphMapAsync = activeProfile != null
        ? ref.watch(glyphMapProvider(activeProfile.id))
        : null;
    final showAsciiHint = ref.watch(showAsciiHintProvider);
    final glyphMap = glyphMapAsync?.valueOrNull;
    final kbTheme = ref.watch(keyboardThemeProvider);
    final kbHeightScale = ref.watch(keyboardHeightProvider);

    return Container(
      height: 300 * kbHeightScale,
      decoration: BoxDecoration(
        color: kbTheme.backgroundColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Voice transcription pill ──
          if (_isVoiceActive)
            VoiceIndicatorWidget(
              transcription: _voiceText,
              onStop: _toggleVoice,
            ),

          // ── Suggestion bar ──
          _SuggestionBar(
            kbTheme: kbTheme,
            currentText: widget.currentText,
            onSuggestionTap: (suggestion) {
              if (widget.onSuggestionTap != null) {
                final last = _lastWord(widget.currentText);
                widget.onSuggestionTap!(suggestion, last.length);
              } else {
                widget.onTextInput(suggestion);
              }
            },
          ),

          // ── Keyboard rows ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _showEmoji
                  ? MediaPanel(onEmojiTap: widget.onTextInput, kbTheme: kbTheme)
                  : _showSymbols
                      ? _buildSymbolRows(kbTheme)
                      : _buildQwertyRows(glyphMap, showAsciiHint, kbTheme),
            ),
          ),

          // ── Bottom toolbar ──
          _BottomToolbar(
            kbTheme: kbTheme,
            isShifted: _isShifted,
            isCapsLock: _isCapsLock,
            showSymbols: _showSymbols,
            showEmoji: _showEmoji,
            isVoiceActive: _isVoiceActive,
            activeProfile: activeProfile,
            onShift: _onShiftTap,
            onBackspace: () {
              HapticFeedback.selectionClick();
              widget.onBackspace();
            },
            onEnter: () {
              HapticFeedback.selectionClick();
              widget.onEnter();
            },
            onSpace: () => widget.onTextInput(' '),
            onToggleSymbols: () =>
                setState(() => _showSymbols = !_showSymbols),
            onToggleEmoji: () => setState(() => _showEmoji = !_showEmoji),
            onVoice: _toggleVoice,
          ),
          // System nav space
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildQwertyRows(GlyphMap? glyphMap, bool showAsciiHint, KeyboardThemeData kbTheme) {
    return Column(
      children: [
        // Row 1: QWERTY (10 keys, flex: 2 each, total 20)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _qwertyRows[0].map((char) {
                final displayChar = _applyShift(char);
                return Expanded(
                  flex: 2,
                  child: GlyphKey(
                    kbTheme: kbTheme,
                    character: displayChar,
                    glyphSvgPath: glyphMap?.glyphFor(displayChar),
                    showAsciiHint: showAsciiHint,
                    onTap: () => _onKeyTap(char),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Row 2: ASDFGHJKL (Spacer(1) + 9 keys + Spacer(1), total 1 + 18 + 1 = 20)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 1),
                ..._qwertyRows[1].map((char) {
                  final displayChar = _applyShift(char);
                  return Expanded(
                    flex: 2,
                    child: GlyphKey(
                      kbTheme: kbTheme,
                      character: displayChar,
                      glyphSvgPath: glyphMap?.glyphFor(displayChar),
                      showAsciiHint: showAsciiHint,
                      onTap: () => _onKeyTap(char),
                    ),
                  );
                }),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),

        // Row 3: Shift(3) + ZXCVBNM(14) + Backspace(3), total 3 + 14 + 3 = 20)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToolKey(
                  kbTheme: kbTheme,
                  icon: _isCapsLock
                      ? Icons.keyboard_capslock_rounded
                      : _isShifted
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_upward_outlined,
                  color: (_isShifted || _isCapsLock) ? kbTheme.accentColor : null,
                  onTap: _onShiftTap,
                  flex: 3,
                ),
                ..._qwertyRows[2].map((char) {
                  final displayChar = _applyShift(char);
                  return Expanded(
                    flex: 2,
                    child: GlyphKey(
                      kbTheme: kbTheme,
                      character: displayChar,
                      glyphSvgPath: glyphMap?.glyphFor(displayChar),
                      showAsciiHint: showAsciiHint,
                      onTap: () => _onKeyTap(char),
                    ),
                  );
                }).toList(),
                _BackspaceKey(
                  kbTheme: kbTheme,
                  onBackspace: widget.onBackspace,
                  flex: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolRows(KeyboardThemeData kbTheme) {
    return Column(
      children: _symbolRows.map((row) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((char) {
                return Expanded(
                  flex: 2,
                  child: GlyphKey(
                    kbTheme: kbTheme,
                    character: char,
                    glyphSvgPath: null,
                    showAsciiHint: true,
                    onTap: () => widget.onTextInput(char),
                    isSymbol: true,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Suggestion Bar ─────────────────────────────────────────────

class _SuggestionBar extends ConsumerStatefulWidget {
  final KeyboardThemeData kbTheme;
  final String currentText;
  final Function(String) onSuggestionTap;

  const _SuggestionBar({required this.kbTheme, required this.currentText, required this.onSuggestionTap});

  @override
  ConsumerState<_SuggestionBar> createState() => _SuggestionBarState();
}

class _SuggestionBarState extends ConsumerState<_SuggestionBar> {
  Timer? _debounce;
  List<String> _suggestions = ['the', 'and', 'is'];
  bool _isLoading = false;

  @override
  void didUpdateWidget(_SuggestionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentText != oldWidget.currentText) {
      _onTextChanged();
    }
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions();
    });
  }

  Future<void> _fetchSuggestions() async {
    if (widget.currentText.trim().isEmpty) {
      if (mounted) setState(() => _suggestions = ['the', 'and', 'is']);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    final gemini = ref.read(geminiServiceProvider);
    final words = await gemini.getKeyboardSuggestions(widget.currentText);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (words.isNotEmpty) _suggestions = words;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: widget.kbTheme.keyColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => widget.onSuggestionTap('${_suggestions[index]} '),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: widget.kbTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _suggestions[index],
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: _isLoading ? widget.kbTheme.textColor.withOpacity(0.5) : widget.kbTheme.textColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Bottom Toolbar ─────────────────────────────────────────────

class _BottomToolbar extends StatelessWidget {
  final KeyboardThemeData kbTheme;
  final bool isShifted;
  final bool isCapsLock;
  final bool showSymbols;
  final bool showEmoji;
  final bool isVoiceActive;
  final dynamic activeProfile;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;
  final VoidCallback onSpace;
  final VoidCallback onToggleSymbols;
  final VoidCallback onToggleEmoji;
  final VoidCallback onVoice;

  const _BottomToolbar({
    required this.kbTheme,
    required this.isShifted,
    required this.isCapsLock,
    required this.showSymbols,
    required this.showEmoji,
    required this.isVoiceActive,
    required this.activeProfile,
    required this.onShift,
    required this.onBackspace,
    required this.onEnter,
    required this.onSpace,
    required this.onToggleSymbols,
    required this.onToggleEmoji,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Symbols toggle (123 / ABC)
            _TextToolKey(
              kbTheme: kbTheme,
              label: showSymbols ? 'ABC' : '123',
              onTap: onToggleSymbols,
              flex: 2,
            ),
            
            // Voice mic key
            _ToolKey(
              kbTheme: kbTheme,
              icon: Icons.mic_rounded,
              color: isVoiceActive ? kbTheme.accentColor : null,
              onTap: onVoice,
              flex: 2,
            ),
            
            // Space bar
            Expanded(
              flex: showSymbols ? 6 : 8,
              child: GestureDetector(
                onTap: onSpace,
                child: Container(
                  height: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: kbTheme.keyColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      activeProfile != null ? activeProfile.name : 'space',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: kbTheme.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            
            // Emoji key
            _ToolKey(
              kbTheme: kbTheme,
              icon: Icons.emoji_emotions_outlined,
              color: showEmoji ? kbTheme.accentColor : null,
              onTap: onToggleEmoji,
              flex: 2,
            ),
            
            // Enter key
            _ToolKey(
              kbTheme: kbTheme,
              icon: Icons.keyboard_return_rounded,
              onTap: onEnter,
              flex: 2,
            ),
            
            // Backspace key (only in symbol mode)
            if (showSymbols)
              _BackspaceKey(
                kbTheme: kbTheme,
                onBackspace: onBackspace,
                flex: 2,
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolKey extends StatelessWidget {
  final KeyboardThemeData kbTheme;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final int flex;

  const _ToolKey({
    required this.kbTheme,
    required this.icon,
    required this.onTap,
    this.color,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
          decoration: BoxDecoration(
            color: kbTheme.keyColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color ?? kbTheme.textColor, size: 18),
        ),
      ),
    );
  }
}

class _TextToolKey extends StatelessWidget {
  final KeyboardThemeData kbTheme;
  final String label;
  final VoidCallback onTap;
  final int flex;

  const _TextToolKey({required this.kbTheme, required this.label, required this.onTap, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
          decoration: BoxDecoration(
            color: kbTheme.keyColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kbTheme.textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _EmojiPanel removed in favor of MediaPanel

class _BackspaceKey extends StatefulWidget {
  final KeyboardThemeData kbTheme;
  final VoidCallback onBackspace;
  final int flex;

  const _BackspaceKey({
    required this.kbTheme,
    required this.onBackspace,
    this.flex = 3,
  });

  @override
  State<_BackspaceKey> createState() => _BackspaceKeyState();
}

class _BackspaceKeyState extends State<_BackspaceKey> {
  Timer? _timer;

  void _startRepeating() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      _timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
        HapticFeedback.lightImpact();
        widget.onBackspace();
      });
    });
  }

  void _stopRepeating() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: widget.flex,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          widget.onBackspace();
          _startRepeating();
        },
        onTapUp: (_) => _stopRepeating(),
        onTapCancel: () => _stopRepeating(),
        child: Container(
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
          decoration: BoxDecoration(
            color: widget.kbTheme.keyColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.backspace_outlined, color: widget.kbTheme.textColor, size: 18),
        ),
      ),
    );
  }
}

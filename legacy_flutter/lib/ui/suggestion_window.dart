import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/ime_controller.dart';
import '../services/win32_caret.dart';
import '../services/window_helper.dart';

class SuggestionView extends StatefulWidget {
  const SuggestionView({Key? key}) : super(key: key);

  @override
  State<SuggestionView> createState() => _SuggestionViewState();
}

class _SuggestionViewState extends State<SuggestionView> {
  final ImeController ime = ImeController();
  CaretPosition? _lockedMousePosition;
  Size? _lastSize;
  Offset? _lastPosition;

  @override
  void initState() {
    super.initState();
    ime.addListener(_onImeChange);
    // Initial position trigger if buffer is already populated
    _updatePosition();
  }

  @override
  void dispose() {
    ime.removeListener(_onImeChange);
    super.dispose();
  }

  void _onImeChange() {
    if (mounted) {
      setState(() {});
      _updatePosition();
    }
  }

  void _updatePosition() async {
    if (ime.buffer.isEmpty && ime.notificationText.isEmpty) {
      _lockedMousePosition = null;
      return;
    }

    // Resize window to fit content, with a generous safety margin
    final int suggCount = ime.suggestions.length;
    final double itemHeight = ime.fontSize.toDouble() + 16;
    final double bufferBarHeight = ime.fontSize.toDouble() + 20;
    final double totalHeight = (ime.buffer.isNotEmpty)
        ? (bufferBarHeight + 10 + (suggCount > 0 ? suggCount * itemHeight : 24) + 40) // +40 safety
        : 60; // notification card height
    final double clampedHeight = totalHeight.clamp(40, 300);
    final newSize = Size(300, clampedHeight);
    if (_lastSize != newSize) {
      await windowManager.setSize(newSize);
      _lastSize = newSize;
    }

    final caret = Win32Caret.getCaretScreenPos();
    if (caret != null) {
      // 1. Lock position for mouse fallback to avoid following mouse around
      if (caret.isMouseFallback) {
        if (_lockedMousePosition != null) {
          // Re-use locked mouse position
          final dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;
          final newPos = Offset(_lockedMousePosition!.x / dpr, (_lockedMousePosition!.bottom / dpr) + 4);
          if (_lastPosition != newPos) {
            await windowManager.setPosition(newPos);
            _lastPosition = newPos;
          }
          return;
        } else {
          _lockedMousePosition = caret;
        }
      } else {
        _lockedMousePosition = null; // Clear if we get real caret
      }

      final dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;
      final targetLogicalX = caret.x / dpr;
      final targetLogicalY = (caret.bottom / dpr) + 4;
      
      final newPos = Offset(targetLogicalX, targetLogicalY);
      if (_lastPosition != newPos) {
        await windowManager.setPosition(newPos);
        _lastPosition = newPos;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ime.buffer.isEmpty && ime.notificationText.isEmpty) return const SizedBox.shrink();

    // Render Floating Language / Active Status Notification Card
    if (ime.buffer.isEmpty && ime.notificationText.isNotEmpty) {
      final isEnabled = ime.notificationText != "Disabled";
      final accentColor = isEnabled ? const Color(0xFF00ff88) : const Color(0xFFff3b30);
      return Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111113).withOpacity(ime.suggestionOpacity),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.language : Icons.block,
                color: accentColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                ime.notificationText.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ime.fontSize.toDouble() + 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: ime.enableGlassmorphism ? 15.0 : 0.0,
              sigmaY: ime.enableGlassmorphism ? 15.0 : 0.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: ime.bgColor.withOpacity(ime.enableGlassmorphism ? 0.4 : ime.suggestionOpacity),
                border: Border.all(color: const Color(0xFF2c2c36)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a24),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ime.buffer,
                style: TextStyle(
                  color: ime.highlightColor, // Dynamic highlight color
                  fontSize: (ime.fontSize - 2).clamp(8, 24).toDouble(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (ime.suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ...List.generate(
                ime.suggestions.length,
                (index) => _CandidateRow(
                  index: index,
                  word: ime.suggestions[index],
                  isHighlighted: index == ime.highlightedIndex,
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final int index;
  final String word;
  final bool isHighlighted;

  const _CandidateRow({
    required this.index,
    required this.word,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF20202a) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHighlighted)
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: ImeController().highlightColor,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(width: 3),
          const SizedBox(width: 8),
          Text(
            '${index + 1}.',
            style: TextStyle(
              color: isHighlighted ? ImeController().highlightColor : const Color(0xFF6c6c7c),
              fontWeight: FontWeight.bold,
              fontSize: ImeController().fontSize.toDouble(),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            word,
            style: TextStyle(
              color: ImeController().textColor,
              fontSize: ImeController().fontSize.toDouble(),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

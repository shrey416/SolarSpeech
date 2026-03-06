import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/suggestion.dart';
import '../providers/suggestion_providers.dart';
import '../services/behavior_tracker.dart';
import '../../assistant/ai_assistant_dialog.dart';
import '../../assistant/chatbot_dialog.dart';
import 'report_dialog.dart';

/// A compact AI help button in the bottom-right that expands into a panel
/// showing contextual suggestions + a voice assistant trigger.
class AiHelpButton extends ConsumerStatefulWidget {
  const AiHelpButton({super.key});

  @override
  ConsumerState<AiHelpButton> createState() => _AiHelpButtonState();
}

class _AiHelpButtonState extends ConsumerState<AiHelpButton>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(suggestionsProvider);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 600;
    final panelWidth = isCompact ? width - 32 : 380.0;

    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expanded panel
          SizeTransition(
            sizeFactor: _scaleAnim,
            axisAlignment: 1.0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: panelWidth,
                margin: const EdgeInsets.only(bottom: 12),
                constraints: const BoxConstraints(maxHeight: 420),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const Divider(
                        height: 1, color: Colors.white12, thickness: 1),
                    // Suggestions list (scrollable)
                    suggestionsAsync.when(
                      data: (suggestions) => suggestions.isEmpty
                          ? _buildEmpty()
                          : _buildSuggestionsList(suggestions),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white54),
                          ),
                        ),
                      ),
                      error: (_, __) => _buildEmpty(),
                    ),
                    const Divider(
                        height: 1, color: Colors.white12, thickness: 1),
                    _buildChatbotRow(),
                    const Divider(
                        height: 1, color: Colors.white10, thickness: 1),
                    _buildVoiceRow(),
                  ],
                ),
              ),
            ),
          ),
          // FAB button
          _buildFab(suggestionsAsync),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'AI Suggestions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 18),
            onPressed: _toggle,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white24, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No suggestions for this page right now.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(List<AiSuggestion> suggestions) {
    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white10, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          return _SuggestionTile(
            suggestion: s,
            onTap: () => _handleTap(context, s),
          );
        },
      ),
    );
  }

  Widget _buildChatbotRow() {
    return InkWell(
      onTap: () {
        _toggle();
        showDialog(
          context: context,
          builder: (context) => const ChatbotDialog(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF10B981), size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat Assistant',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text('Ask questions, compare data',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRow() {
    return InkWell(
      onTap: () {
        _toggle();
        showDialog(
          context: context,
          builder: (context) => const AiAssistantDialog(),
        );
      },
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mic, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice Assistant',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text('Tap to speak a command',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(AsyncValue<List<AiSuggestion>> suggestionsAsync) {
    final count = suggestionsAsync.whenOrNull(data: (s) => s.length) ?? 0;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _expanded
                ? [const Color(0xFF475569), const Color(0xFF334155)]
                : [AppColors.primary, const Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_expanded ? Colors.grey : AppColors.primary)
                  .withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _expanded ? Icons.close : Icons.auto_awesome,
                key: ValueKey(_expanded),
                color: Colors.white,
                size: 24,
              ),
            ),
            // Badge showing suggestion count
            if (!_expanded && count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.alert,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, AiSuggestion suggestion) {
    final ctx = ref.read(screenContextProvider);
    if (ctx != null) {
      BehaviorTracker.recordClick(ctx.route, suggestion.id);
    }

    _toggle(); // close panel after action

    if (suggestion.type == SuggestionType.report) {
      showDialog(
        context: context,
        builder: (_) => ReportDialog(metadata: suggestion.metadata),
      );
    } else if (suggestion.route != null) {
      context.go(suggestion.route!);
    }
  }
}

class _SuggestionTile extends StatelessWidget {
  final AiSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _typeColor(suggestion.type).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(suggestion.icon,
                  color: _typeColor(suggestion.type), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion.message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                suggestion.type == SuggestionType.report
                    ? Icons.edit_note
                    : Icons.arrow_forward_ios,
                color: Colors.white24,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(SuggestionType type) {
    switch (type) {
      case SuggestionType.navigation:
        return Colors.lightBlueAccent;
      case SuggestionType.anomaly:
        return Colors.orangeAccent;
      case SuggestionType.report:
        return Colors.redAccent;
      case SuggestionType.insight:
        return Colors.greenAccent;
      case SuggestionType.comparison:
        return Colors.purpleAccent;
    }
  }
}

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
    final crowdAsync = ref.watch(crowdSuggestionsProvider);
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
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
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
                        height: 1, color: AppColors.border, thickness: 1),
                    // AI Suggestions list
                    suggestionsAsync.when(
                      data: (suggestions) => suggestions.isEmpty
                          ? const SizedBox.shrink()
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
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    // Crowd suggestions section
                    crowdAsync.when(
                      data: (crowd) =>
                          crowd.isEmpty ? const SizedBox.shrink() : _buildCrowdSection(crowd),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    // Empty state only if both are empty
                    Builder(builder: (context) {
                      final aiEmpty = suggestionsAsync
                              .whenOrNull(data: (s) => s.isEmpty) ??
                          true;
                      final crowdEmpty = crowdAsync
                              .whenOrNull(data: (s) => s.isEmpty) ??
                          true;
                      if (aiEmpty && crowdEmpty) return _buildEmpty();
                      return const SizedBox.shrink();
                    }),
                    const Divider(
                        height: 1, color: AppColors.border, thickness: 1),
                    _buildChatbotRow(),
                    const Divider(
                        height: 1, color: AppColors.border, thickness: 1),
                    _buildVoiceRow(),
                  ],
                ),
              ),
            ),
          ),
          // FAB button
          _buildFab(suggestionsAsync, crowdAsync),
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
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'AI Suggestions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
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
          Icon(Icons.check_circle_outline, color: AppColors.textSecondary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No suggestions for this page right now.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(List<AiSuggestion> suggestions) {
    return Flexible(
      flex: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                SizedBox(width: 6),
                Text(
                  'AI SUGGESTIONS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.border,
                  indent: 16,
                  endIndent: 16),
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return _SuggestionTile(
                  suggestion: s,
                  onTap: () => _handleTap(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrowdSection(List<AiSuggestion> crowdSuggestions) {
    return Flexible(
      flex: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.border, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.people, color: AppColors.active, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'MOST USERS GO HERE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: crowdSuggestions.length,
              itemBuilder: (context, index) {
                final s = crowdSuggestions[index];
                final pct = s.metadata['crowd_percentage'] as int? ?? 0;
                return InkWell(
                  onTap: () => _handleTap(context, s),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Percentage ring
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  value: pct > 0 ? pct / 100 : 0.15,
                                  strokeWidth: 3,
                                  backgroundColor: AppColors.border,
                                  color: AppColors.active,
                                ),
                              ),
                              Text(
                                pct > 0 ? '$pct%' : '~',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.active,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.message,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios,
                            color: AppColors.active, size: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
                color: AppColors.active.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.active, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat Assistant',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text('Ask questions, compare data',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
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
                color: AppColors.primaryLight,
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
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text('Tap to speak a command',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(AsyncValue<List<AiSuggestion>> suggestionsAsync,
      AsyncValue<List<AiSuggestion>> crowdAsync) {
    final aiCount =
        suggestionsAsync.whenOrNull(data: (s) => s.length) ?? 0;
    final crowdCount =
        crowdAsync.whenOrNull(data: (s) => s.length) ?? 0;
    final count = aiCount + crowdCount;

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
                color: _typeColor(suggestion.type).withValues(alpha: 0.1),
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
                  color: AppColors.textPrimary,
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
                color: AppColors.textSecondary,
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
        return AppColors.primary;
      case SuggestionType.anomaly:
        return AppColors.warning;
      case SuggestionType.report:
        return AppColors.alert;
      case SuggestionType.insight:
        return AppColors.active;
      case SuggestionType.comparison:
        return AppColors.chartPurple;
      case SuggestionType.trending:
        return AppColors.active;
    }
  }
}

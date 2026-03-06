import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/suggestion.dart';
import '../providers/suggestion_providers.dart';
import '../services/behavior_tracker.dart';
import 'report_dialog.dart';

class SuggestionBar extends ConsumerStatefulWidget {
  const SuggestionBar({super.key});

  @override
  ConsumerState<SuggestionBar> createState() => _SuggestionBarState();
}

class _SuggestionBarState extends ConsumerState<SuggestionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnimation;
  int _currentIndex = 0;
  final PageController _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(suggestionBarVisibleProvider);
    final suggestionsAsync = ref.watch(suggestionsProvider);

    return suggestionsAsync.when(
      data: (suggestions) {
        if (suggestions.isEmpty || !visible) {
          _animCtrl.reverse();
          return const SizedBox.shrink();
        }
        _animCtrl.forward();
        return SlideTransition(
          position: _slideAnimation,
          child: _buildBar(context, suggestions),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBar(BuildContext context, List<AiSuggestion> suggestions) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 600;

    return Container(
      margin: EdgeInsets.only(
        left: isCompact ? 8 : 16,
        right: isCompact ? 8 : 16,
        bottom: isCompact ? 72 : 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Suggestion',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // Page indicator
                if (suggestions.length > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      suggestions.length,
                      (i) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentIndex
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: () {
                    final ctx = ref.read(screenContextProvider);
                    if (ctx != null && suggestions.isNotEmpty) {
                      BehaviorTracker.recordDismiss(
                          ctx.route, suggestions[_currentIndex].id);
                    }
                    ref.read(suggestionBarVisibleProvider.notifier).hide();
                  },
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          // Suggestion cards (swipeable)
          SizedBox(
            height: isCompact ? 80 : 72,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: suggestions.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return _SuggestionCard(
                  suggestion: s,
                  onTap: () => _handleTap(context, s),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, AiSuggestion suggestion) {
    final ctx = ref.read(screenContextProvider);
    if (ctx != null) {
      BehaviorTracker.recordClick(ctx.route, suggestion.id);
    }

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

class _SuggestionCard extends StatelessWidget {
  final AiSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionCard({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _typeColor(suggestion.type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(suggestion.icon, color: _typeColor(suggestion.type), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                suggestion.type == SuggestionType.report
                    ? Icons.edit_note
                    : Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
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

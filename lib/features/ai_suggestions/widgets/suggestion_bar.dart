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
  bool _showingCrowd = false;

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
    final crowdAsync = ref.watch(crowdSuggestionsProvider);

    return suggestionsAsync.when(
      data: (suggestions) {
        final crowdSuggestions =
            crowdAsync.whenOrNull(data: (c) => c) ?? [];
        if (suggestions.isEmpty && crowdSuggestions.isEmpty || !visible) {
          _animCtrl.reverse();
          return const SizedBox.shrink();
        }
        _animCtrl.forward();
        return SlideTransition(
          position: _slideAnimation,
          child: _buildBar(context, suggestions, crowdSuggestions),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBar(BuildContext context, List<AiSuggestion> suggestions,
      List<AiSuggestion> crowdSuggestions) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 600;
    final activeList = _showingCrowd ? crowdSuggestions : suggestions;
    final hasBothSections =
        suggestions.isNotEmpty && crowdSuggestions.isNotEmpty;

    // Reset page index when switching sections
    if (_currentIndex >= activeList.length) {
      _currentIndex = 0;
    }

    return Container(
      margin: EdgeInsets.only(
        left: isCompact ? 8 : 16,
        right: isCompact ? 8 : 16,
        bottom: isCompact ? 72 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (_showingCrowd
                    ? AppColors.active
                    : AppColors.primary)
                .withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: (_showingCrowd ? AppColors.active : AppColors.primary)
                .withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section toggle tabs
          if (hasBothSections)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  _buildTabChip(
                    label: 'AI Suggestion',
                    icon: Icons.auto_awesome,
                    isActive: !_showingCrowd,
                    color: AppColors.primary,
                    onTap: () => _switchSection(false),
                  ),
                  const SizedBox(width: 6),
                  _buildTabChip(
                    label: 'Most Users',
                    icon: Icons.people,
                    isActive: _showingCrowd,
                    color: AppColors.active,
                    onTap: () => _switchSection(true),
                    badge: crowdSuggestions.isNotEmpty
                        ? crowdSuggestions.length.toString()
                        : null,
                  ),
                  const Spacer(),
                  // Page indicator
                  if (activeList.length > 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        activeList.length,
                        (i) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _currentIndex
                                ? (_showingCrowd
                                    ? AppColors.active
                                    : AppColors.primary)
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 18),
                    onPressed: () {
                      final ctx = ref.read(screenContextProvider);
                      if (ctx != null && activeList.isNotEmpty) {
                        BehaviorTracker.recordDismiss(
                            ctx.route, activeList[_currentIndex].id);
                      }
                      ref
                          .read(suggestionBarVisibleProvider.notifier)
                          .hide();
                    },
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          // Single section header (when only one section exists)
          if (!hasBothSections)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (crowdSuggestions.isNotEmpty
                              ? AppColors.active
                              : AppColors.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                        crowdSuggestions.isNotEmpty
                            ? Icons.people
                            : Icons.auto_awesome,
                        color: crowdSuggestions.isNotEmpty
                            ? AppColors.active
                            : AppColors.primary,
                        size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    crowdSuggestions.isNotEmpty
                        ? 'Most Users Go Here'
                        : 'AI Suggestion',
                    style: TextStyle(
                      color: crowdSuggestions.isNotEmpty
                          ? AppColors.active
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (activeList.length > 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        activeList.length,
                        (i) => Container(
                          width: 6,
                          height: 6,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _currentIndex
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 18),
                    onPressed: () {
                      ref
                          .read(suggestionBarVisibleProvider.notifier)
                          .hide();
                    },
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          // Suggestion cards (swipeable)
          SizedBox(
            height: isCompact ? 80 : 72,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: activeList.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final s = activeList[index];
                return _SuggestionCard(
                  suggestion: s,
                  onTap: () => _handleTap(context, s),
                  isCrowd: _showingCrowd || crowdSuggestions.contains(s),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? color : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _switchSection(bool toCrowd) {
    if (_showingCrowd == toCrowd) return;
    setState(() {
      _showingCrowd = toCrowd;
      _currentIndex = 0;
    });
    if (_pageCtrl.hasClients) {
      _pageCtrl.jumpToPage(0);
    }
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
  final bool isCrowd;

  const _SuggestionCard({
    required this.suggestion,
    required this.onTap,
    this.isCrowd = false,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = suggestion.metadata['crowd_percentage'] as int?;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            // Icon with optional percentage ring
            if (isCrowd && percentage != null && percentage > 0)
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: CircularProgressIndicator(
                        value: percentage / 100,
                        strokeWidth: 3,
                        backgroundColor: AppColors.border,
                        color: AppColors.active,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.active,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _typeColor(suggestion.type).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(suggestion.icon,
                    color: _typeColor(suggestion.type), size: 22),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion.message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
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
                color: (isCrowd ? AppColors.active : AppColors.primary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                suggestion.type == SuggestionType.report
                    ? Icons.edit_note
                    : Icons.arrow_forward_ios,
                color: isCrowd ? AppColors.active : AppColors.primary,
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

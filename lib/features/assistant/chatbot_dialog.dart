import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import 'chatbot_service.dart';
import 'llm_navigation_service.dart';

class ChatbotDialog extends StatefulWidget {
  const ChatbotDialog({super.key});

  @override
  State<ChatbotDialog> createState() => _ChatbotDialogState();
}

class _ChatbotDialogState extends State<ChatbotDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  int _listenSession = 0; // session counter to isolate voice sessions
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // Welcome message
    _messages.add(ChatMessage(
      text: "Hi! I'm your Solar Dashboard Assistant. Ask me anything about your plants, inverters, sensors, energy data — or say **help** to see all I can do!",
      isUser: false,
    ));
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening && mounted) {
            final text = _textController.text;
            setState(() => _isListening = false);
            _pulseCtrl.stop();
            _pulseCtrl.reset();
            if (text.isNotEmpty) {
              _sendMessage(text);
            }
          }
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isListening = false);
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      },
    );
  }

  void _listen() {
    if (_isProcessing) return;
    if (!_isListening) {
      if (!_speechAvailable) return;
      // Cancel any prior session to avoid stale callbacks
      _speech.cancel();
      _listenSession++;
      final currentSession = _listenSession;
      setState(() {
        _isListening = true;
        _textController.clear();
      });
      _pulseCtrl.repeat(reverse: true);
      _speech.listen(
        onResult: (val) {
          // Ignore results from a stale/prior session
          if (!mounted || currentSession != _listenSession) return;
          setState(() => _textController.text = val.recognizedWords);
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } else {
      _speech.stop();
      setState(() => _isListening = false);
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      if (_textController.text.isNotEmpty) {
        _sendMessage(_textController.text);
      }
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;

    final userMsg = ChatMessage(text: text.trim(), isUser: true);
    setState(() {
      _messages.add(userMsg);
      _isProcessing = true;
      _textController.clear();
    });
    _scrollToBottom();

    // Resolve navigation route
    final route = await LlmNavigationService.getRouteFromText(text);
    final isDataQ = _isDataQuestion(text);

    if (isDataQ) {
      // Answer with data from chatbot
      final response = await ChatbotService.processMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(response);
        _isProcessing = false;
      });
      _scrollToBottom();
    } else if (route != null && _isNavigationCommand(text)) {
      // Navigate
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: "Navigating for you!",
          isUser: false,
        ));
        _isProcessing = false;
      });
      _scrollToBottom();
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go(route);
      return;
    } else {
      // Fallback chatbot response
      final response = await ChatbotService.processMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(response);
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  bool _isDataQuestion(String text) {
    final t = text.toLowerCase();
    return t.contains('?') || t.contains('what ') || t.contains('how much') ||
        t.contains('how many') || t.contains('percentage') ||
        t.contains('percent') || t.contains('compare') ||
        t.contains('tell me') || t.contains('which ') ||
        t.contains('average') || t.contains('ratio') ||
        t.contains('highest') || t.contains('lowest') ||
        t.contains('best') || t.contains('worst') ||
        t.contains('top ') || t.contains('bottom ') ||
        t.contains('how is') || t.contains('count') ||
        t.contains('summary') || t.contains('status') ||
        t.contains('help') || t.contains('contribution') ||
        t.contains('trend') || t.contains('historical') ||
        t.contains('last ') || t.contains('past ') ||
        t.contains('yesterday') || t.contains('this week') ||
        t.contains('this month') || t.contains('last week') ||
        t.contains('last month') || t.contains('improving') ||
        t.contains('declining') || t.contains('energy') ||
        t.contains('power') || t.contains('generation') ||
        t.contains('sensor') || t.contains('temperature') ||
        t.contains('versus') || t.contains(' vs ') ||
        (t.contains('alert') && (t.contains('inverter') || t.contains('mfm') ||
            t.contains('temp') || t.contains('sensor') || t.contains('plant') ||
            t.contains('device')));
  }

  bool _isNavigationCommand(String text) {
    final t = text.toLowerCase();
    // Explicit navigation words
    if (t.contains('go to') || t.contains('navigate') || t.contains('open') ||
        t.contains('show me') || t.contains('take me') ||
        t.contains('switch to') || t.contains('visit')) {
      return true;
    }
    // Device + chart/graph intent
    if ((t.contains('graph') || t.contains('chart')) &&
        RegExp(r'\b(inverter|plant|mfm|temp|sensor|slms)\b',
                caseSensitive: false)
            .hasMatch(t)) {
      return true;
    }
    // Bare tab name
    if (RegExp(r'^\s*(dashboard|alerts?|my\s*plants?|exports?)\s*$',
            caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    // Alert + show/open + device
    if ((t.contains('show') || t.contains('open') || t.contains('go')) &&
        RegExp(r'\b(alert|alarm|warning|fault)\b', caseSensitive: false).hasMatch(t) &&
        RegExp(r'\b(inverter|mfm|temp|sensor|plant|site)\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // Device + number without data-question context
    if (!_isDataQuestion(text) &&
        RegExp(r'\b(inverter|mfm|temp|slms)\s+\w',
                caseSensitive: false)
            .hasMatch(t) &&
        RegExp(r'\d').hasMatch(t)) {
      return true;
    }
    return false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 600;
    final dialogWidth = isCompact ? screenSize.width - 32 : 480.0;
    final dialogHeight = isCompact ? screenSize.height * 0.75 : 600.0;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: _buildMessagesList()),
            if (_isProcessing) _buildTypingIndicator(),
            const Divider(height: 1, color: AppColors.border),
            _buildQuickActions(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Solar Assistant',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('Ask anything about your solar data',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _MessageBubble(message: msg);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 14),
          ),
          const SizedBox(width: 8),
          const _TypingDots(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _quickChip('Active alerts'),
          _quickChip('Compare inverters'),
          _quickChip('Energy today'),
          _quickChip('Last 5 days trend'),
          _quickChip('System status'),
          _quickChip('Compare plants'),
          _quickChip('Top inverters'),
          _quickChip('Percentage breakdown'),
          _quickChip('Historical data'),
          _quickChip('Sensor readings'),
          _quickChip('Help'),
        ],
      ),
    );
  }

  Widget _quickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label,
            style: const TextStyle(color: AppColors.primary, fontSize: 11)),
        backgroundColor: AppColors.primaryLighter,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Row(
        children: [
          // Mic button
          ScaleTransition(
            scale: _isListening ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
            child: GestureDetector(
              onTap: _listen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? AppColors.alert
                      : AppColors.primaryLighter,
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.white : AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _isListening ? 'Listening...' : 'Ask something...',
                hintStyle: TextStyle(
                    color: _isListening ? AppColors.alert.withValues(alpha: 0.7) : AppColors.textSecondary,
                    fontSize: 14),
                filled: true,
                fillColor: AppColors.primaryLighter,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              onSubmitted: _sendMessage,
              enabled: !_isProcessing,
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: Container(
              height: 40,
              width: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: AppColors.primary, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : AppColors.primaryLighter,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: _buildRichText(message.text, isUser),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildRichText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary;
    final boldColor = isUser ? Colors.white : AppColors.textPrimary;
    final dimColor = isUser ? Colors.white.withValues(alpha: 0.6) : AppColors.textSecondary;

    // Split by lines to handle --- separators and line-level structures
    final lines = text.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      // Horizontal rule
      if (line.trim() == '---') {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(
            color: isUser ? Colors.white24 : AppColors.border,
            height: 1,
          ),
        ));
        continue;
      }

      // Parse inline bold (**text**)
      final spans = <InlineSpan>[];
      final parts = line.split('**');
      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 1) {
          spans.add(TextSpan(
            text: parts[i],
            style: TextStyle(
              color: boldColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ));
        } else {
          // Dim indented data lines for bot responses
          final isIndented = !isUser && parts[i].startsWith('  ');
          spans.add(TextSpan(
            text: parts[i],
            style: TextStyle(
              color: isIndented ? dimColor : baseColor,
              fontSize: isIndented ? 12 : 13,
              height: 1.4,
            ),
          ));
        }
      }
      children.add(RichText(text: TextSpan(children: spans)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_ctrl.value + delay) % 1.0;
            final opacity = (1 - (t - 0.5).abs() * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

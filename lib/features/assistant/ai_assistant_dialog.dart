import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import 'llm_navigation_service.dart';

class AiAssistantDialog extends StatefulWidget {
  const AiAssistantDialog({super.key});

  @override
  State<AiAssistantDialog> createState() => _AiAssistantDialogState();
}

class _AiAssistantDialogState extends State<AiAssistantDialog> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _textController.text = val.recognizedWords;
          });
          if (val.hasConfidenceRating && val.confidence > 0 && _speech.isNotListening) {
            _processCommand(_textController.text);
          }
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _processCommand(_textController.text);
    }
  }

  void _processCommand(String text) async {
    if (text.isEmpty) return;
    setState(() => _isProcessing = true);
    
    final route = await LlmNavigationService.getRouteFromText(text);
    
    setState(() => _isProcessing = false);
    
    if (route != null && mounted) {
      context.pop(); // Close dialog
      context.go(route); // Navigate
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigating to $text...')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sorry, I didn't understand that.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:[
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 48),
            const SizedBox(height: 16),
            const Text("AI Assistant", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text("Say 'Show me inverter 3' or type below.", style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center,),
            const SizedBox(height: 24),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Type your command...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: () => _processCommand(_textController.text),
                ),
              ),
              onSubmitted: _processCommand,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _listen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 80, width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? AppColors.alert : AppColors.primary,
                  boxShadow:[
                    if (_isListening) BoxShadow(color: AppColors.alert.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                  ]
                ),
                child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 36),
              ),
            )
          ],
        ),
      ),
    );
  }
}
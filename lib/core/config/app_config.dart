import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const bool useSyntheticData = false;

  // ── Assistant Mode ──
  // true  = Rule-based entity resolution + LLM response formatting
  //         (falls back to rule-based on LLM API error)
  // false = Sole rule-based mode (no LLM calls for chat responses)
  static const bool useLlmAssisted = true;

  // ── OpenRouter LLM Configuration ──
  // API key loaded from .env file
  static String get openRouterApiKey =>
      dotenv.env['OPENROUTER_API_KEY'] ?? '';

  // Model to use — fast model for responsive chatbot
  static const String llmModel = 'qwen/qwen3-vl-30b-a3b-thinking';
}
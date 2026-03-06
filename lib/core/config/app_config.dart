class AppConfig {
  // Toggle this to false when Supabase is ready
  static const bool useSyntheticData = true; 
  
  // LLM API Key (OpenAI/Gemini/Custom) - Store securely in .env in production
  static const String llmApiKey = "YOUR_LLM_API_KEY"; 
}
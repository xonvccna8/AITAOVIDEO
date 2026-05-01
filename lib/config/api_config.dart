// API Configuration
// Pass secrets with --dart-define in Flutter or .env.local for the Vite server.

class APIConfig {
  // AIVideoAuto / Gommo video API configuration
  static const String aiVideoAccessToken = String.fromEnvironment(
    'AI_VIDEO_ACCESS_TOKEN',
  );

  static const String aiVideoBaseUrl = String.fromEnvironment(
    'AI_VIDEO_BASE_URL',
    defaultValue: 'https://api.gommo.net/ai',
  );
  static const String aiVideoDomain = String.fromEnvironment(
    'AI_VIDEO_DOMAIN',
    defaultValue: 'aivideoauto.com',
  );
  static const String aiVideoProjectId = String.fromEnvironment(
    'AI_VIDEO_PROJECT_ID',
    defaultValue: 'default',
  );
  static const String aiVideoModel = String.fromEnvironment(
    'AI_VIDEO_MODEL',
    defaultValue: 'grok_video_heavy',
  );
  static const String aiVideoResolution = String.fromEnvironment(
    'AI_VIDEO_RESOLUTION',
    defaultValue: '720p',
  );

  // OpenAI API Configuration
  static const String openAIKey = String.fromEnvironment('OPENAI_API_KEY');

  // Gemini API Configuration
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
}

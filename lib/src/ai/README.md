# AI Assistance Implementation

This directory contains the AI-powered bookmark assistance feature for Pinboard Wizard, which automatically generates titles, descriptions, and tags for bookmarks using OpenAI's API and optional web scraping with Jina AI.

## Overview

The AI assistance feature helps users create better bookmarks by:
- Fetching web page content (with optional Jina AI scraping)
- Analyzing the content with OpenAI's GPT models
- Generating structured metadata: title, description, and tags
- Providing editable suggestions to the user

## Architecture

```
ai/
├── README.md                    # This file
├── ai_settings.dart            # Main settings models and configuration
├── ai_settings_service.dart    # Settings management and secure storage
├── openai/                     # OpenAI integration
│   ├── openai_service.dart     # OpenAI API client and analysis
│   └── models/
│       └── bookmark_suggestions.dart  # AI response models
└── web_scraping/               # Web content extraction
    ├── jina_service.dart       # Jina AI scraping service
    └── models/
        └── scraped_content.dart    # Web content models
```

## Features Implemented

### Settings Management (`ai_settings.dart`, `ai_settings_service.dart`)
- **Master Toggle**: Enable/disable AI assistance
- **Secure API Key Storage**: OpenAI and Jina API keys stored with Flutter Secure Storage
- **Configurable Limits**:
  - Description max length (50-300 characters)
  - Max number of tags (1-10)
- **Real-time Updates**: Settings saved immediately when changed

### OpenAI Integration (`openai/`)
- **GPT-3.5-turbo Integration**: Using openai_dart package
- **Structured Prompts**: Clear instructions for consistent JSON responses
- **Error Handling**: Robust error handling with custom exceptions
- **JSON Parsing**: Reliable extraction of structured data from AI responses

### Web Scraping (`web_scraping/`)
- **Jina AI Integration**: Optional service for clean markdown extraction
- **Fallback Support**: Works without API key (with rate limits)
- **Content Processing**: HTML to clean text conversion
- **Metadata Extraction**: Title, description, images, and other metadata

### Models
- **AiSettings**: Main configuration container with nested settings
- **OpenAiSettings**: OpenAI-specific configuration (API key, limits)
- **WebScrapingSettings**: Jina AI configuration
- **BookmarkSuggestions**: AI-generated suggestions with confidence scores
- **ScrapedContent**: Web page content with metadata

## Usage Flow

1. **User enters URL** in bookmark dialog
2. **Magic Button clicked** → triggers AI analysis
3. **Web Scraping** (optional): Jina AI extracts clean content
4. **Content Analysis**: OpenAI analyzes the content and generates:
   - Clear, descriptive title (max 80 chars)
   - Brief description (user-configurable length)
   - Relevant tags (user-configurable count)
5. **User Review**: Editable suggestions presented in modal
6. **Auto-fill**: Accepted suggestions populate bookmark form

## Settings UI Integration

Added to Settings Page (`lib/src/pages/settings_page.dart`):
- AI assistance toggle with explanation
- OpenAI API key field (secure, password-style)
- Jina API key field (optional, with explanation)
- Description length configuration
- Max tags configuration
- Clear all AI settings button

## Configuration Details

### OpenAI Settings
- **API Key**: Required, stored securely
- **Model**: GPT-3.5-turbo (cost-effective)
- **Max Tokens**: 300 (controlled costs)
- **Temperature**: 0.3 (focused, consistent responses)
- **Description Length**: 50-300 characters (user configurable)
- **Max Tags**: 1-10 tags (user configurable)

### Jina AI Settings
- **API Key**: Optional (free tier available)
- **Endpoint**: `https://r.jina.ai/[URL]`
- **Content**: Clean markdown extraction
- **Fallbacks**: Works without key with rate limits

## Error Handling

- **Network Errors**: Graceful degradation, user-friendly messages
- **API Errors**: Specific error types (quota, auth, parsing)
- **Validation**: Input validation for all settings
- **Fallbacks**: Manual bookmark creation always available

## Security Considerations

- **API Key Storage**: Flutter Secure Storage for all sensitive data
- **No Logging**: API keys never logged or exposed
- **User Consent**: Clear explanations of data sent to external services
- **Optional Features**: All AI features can be disabled

## Service Locator Integration

Registered in `service_locator.dart`:
```dart
..registerLazySingleton<AiSettingsService>(() => AiSettingsService());
```

## Dependencies Added

```yaml
dependencies:
  openai_dart: ^0.5.5  # OpenAI API integration
```

## Future Enhancements

- **Caching**: Store AI responses to avoid duplicate API calls
- **Batch Processing**: Analyze multiple URLs at once
- **Custom Prompts**: User-customizable AI instructions
- **Usage Tracking**: Monitor API usage and costs
- **Alternative Providers**: Support for other AI services

## Testing

The implementation includes proper error handling and fallbacks to ensure the core bookmark functionality works even if AI features fail. All AI features are optional and can be disabled.

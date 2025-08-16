# Ollama Integration for Maybe Finance App

## Summary

Replaced OpenAI with Ollama for AI-powered features in the Maybe finance app. This enables users to run AI features locally without relying on external API services.

## Changes Made

### 1. Dependencies

- **Removed**: `ruby-openai` gem
- **Added**: `ruby_llm` gem (v1.6.2)

### 2. New Provider Implementation

Created `Provider::Ollama` class that implements the same interface as `Provider::Openai`:

**Files Created:**

- `app/models/provider/ollama.rb` - Main Ollama provider
- `app/models/provider/ollama/auto_categorizer.rb` - Transaction categorization
- `app/models/provider/ollama/auto_merchant_detector.rb` - Merchant detection
- `app/models/provider/ollama/chat_config.rb` - Chat configuration
- `app/models/provider/ollama/chat_parser.rb` - Response parsing
- `app/models/provider/ollama/chat_stream_parser.rb` - Streaming support

### 3. Registry Updates

- Updated `Provider::Registry` to use `:ollama` instead of `:openai`
- Modified LLM provider resolution in all components

### 4. Application Updates

Updated references throughout the app:

- `app/models/rule/registry/transaction_resource.rb`
- `app/models/family/auto_categorizer.rb`
- `app/models/family/auto_merchant_detector.rb`

### 5. Test Updates

- Updated test mocks to use `:ollama` provider
- Created `test/models/provider/ollama_test.rb` with comprehensive test coverage
- Fixed existing test references

### 6. Configuration

- Updated environment variable configuration to use `OLLAMA_URL` and `OLLAMA_MODEL`
- Modified Docker compose configuration
- Updated documentation

### 7. Documentation

- Created comprehensive Ollama setup guide at `docs/hosting/ollama.md`
- Updated environment configuration files

## Supported Features

The Ollama integration supports all the same features as the OpenAI integration:

1. **Transaction Auto-categorization**: Automatically categorize transactions based on transaction details and user-defined categories
2. **Merchant Detection**: Detect and normalize merchant names and URLs from transaction data
3. **Chat Functionality**: Interactive chat with streaming support
4. **Function Calling**: Support for function calls in chat contexts (basic implementation)

## Supported Models

The following Ollama models are pre-configured:

- `llama3.2` (recommended default)
- `llama3.1`
- `llama3`
- `llama2`
- `mistral`
- `gemma2`
- `codellama`
- `qwen2.5`
- `phi3`
- `deepseek-coder`
- `yi`
- `neural-chat`

## Configuration

### Environment Variables

```bash
# Required
OLLAMA_URL=http://localhost:11434/v1
OLLAMA_MODEL=llama3.2
```

### Docker Compose

```yaml
environment:
  OLLAMA_URL: ${OLLAMA_URL:-http://localhost:11434/v1}
  OLLAMA_MODEL: ${OLLAMA_MODEL:-llama3.2}
```

## Setup Instructions

1. **Install Ollama**

   ```bash
   # macOS
   brew install ollama

   # Or download from https://ollama.ai/
   ```

2. **Start Ollama service**

   ```bash
   ollama serve
   ```

3. **Download a model**

   ```bash
   ollama pull llama3.2
   ```

4. **Configure environment**
   Add to `.env.local`:

   ```bash
   OLLAMA_URL=http://localhost:11434/v1
   OLLAMA_MODEL=llama3.2
   ```

5. **Test the integration**
   ```bash
   bin/test_ollama
   ```

## Testing

Run the comprehensive test suite:

```bash
# Test Ollama provider specifically
bundle exec rails test test/models/provider/ollama_test.rb

# Test auto-categorization
bundle exec rails test test/models/family/auto_categorizer_test.rb

# Test merchant detection
bundle exec rails test test/models/family/auto_merchant_detector_test.rb

# Test overall integration
bin/test_ollama
```

## Migration from OpenAI

The migration maintains full backward compatibility:

- All existing functionality works identically
- Same API interfaces and method signatures
- No changes needed to application code outside the provider layer
- Environment variables changed from `OPENAI_*` to `OLLAMA_*`

## Performance Considerations

- **Local Processing**: No network latency or external API limits
- **Model Size**: Larger models provide better accuracy but require more resources
- **Hardware**: GPU acceleration significantly improves performance
- **Memory**: Ensure sufficient RAM for the chosen model (8GB+ recommended)

## Benefits of Ollama Integration

1. **Privacy**: All data processing happens locally
2. **Cost**: No API usage fees
3. **Reliability**: No dependency on external services
4. **Customization**: Full control over model selection and parameters
5. **Speed**: Local processing can be faster than API calls
6. **Offline**: Works without internet connectivity

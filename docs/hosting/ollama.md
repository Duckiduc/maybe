# Setting up Ollama for AI Features

Maybe can use Ollama as an alternative to OpenAI for AI-powered features like:
- Transaction auto-categorization
- Merchant detection
- Chat functionality

## Prerequisites

1. Install Ollama from [ollama.ai](https://ollama.ai/)
2. Download a compatible model (we recommend `llama3.2`)

## Setup Steps

### 1. Install and Start Ollama

```bash
# macOS
brew install ollama

# Or download from https://ollama.ai/

# Start Ollama service
ollama serve
```

### 2. Download a Model

```bash
# Download Llama 3.2 (recommended)
ollama pull llama3.2

# Or try other models:
ollama pull llama3.1
ollama pull mistral
ollama pull gemma2
```

### 3. Configure Environment Variables

Add these to your `.env.local` file:

```bash
# Ollama Configuration
OLLAMA_URL=http://localhost:11434/v1
OLLAMA_MODEL=llama3.2
```

Note: The URL should include `/v1` at the end for compatibility with RubyLLM.

### 4. Test the Setup

You can test that Ollama is working by running:

```bash
curl http://localhost:11434/api/tags
```

This should return a list of your installed models.

## Model Recommendations

- **llama3.2**: Best balance of speed and quality (recommended)
- **llama3.1**: Higher quality but slower
- **mistral**: Fast and good for coding tasks
- **gemma2**: Good alternative, developed by Google

## Performance Notes

- Larger models provide better results but require more computational resources
- For production use, consider models optimized for your hardware
- GPU acceleration significantly improves performance if available

## Troubleshooting

### Ollama not responding
- Ensure Ollama service is running: `ollama serve`
- Check if the port 11434 is available
- Verify firewall settings if running on a different machine

### Model not found errors
- Make sure you've downloaded the model: `ollama pull llama3.2`
- Check available models: `ollama list`

### Slow responses
- Consider using a smaller model like `gemma2:2b`
- Ensure you have sufficient RAM (8GB+ recommended)
- Enable GPU acceleration if available

## Using Different Models

To use a different model, update your environment variable:

```bash
OLLAMA_MODEL=mistral
```

The supported models are defined in `app/models/provider/ollama.rb` in the `MODELS` constant.

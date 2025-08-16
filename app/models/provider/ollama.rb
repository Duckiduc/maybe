class Provider::Ollama < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Ollama::Error
  Error = Class.new(Provider::Error)

  # Popular Ollama models - you can customize this list based on your needs
  MODELS = %w[llama3.2 llama3.1 llama3 llama2 mistral gemma2 codellama qwen2.5 phi3 deepseek-coder yi neural-chat].freeze

  # Model aliases for backward compatibility
  MODEL_ALIASES = {
    "gpt-4.1" => "llama3.2",  # Map OpenAI model to Ollama equivalent
    "gpt-4" => "llama3.2",
    "gpt-3.5-turbo" => "llama3.2"
  }.freeze

  def initialize(base_url: nil, model: nil)
    @base_url = base_url || "http://localhost:11434/v1"
    @default_model = model || "llama3.2"

    # Configure RubyLLM for Ollama if needed
    begin
      require "ruby_llm"
      RubyLLM.configure do |config|
        config.ollama_api_base = @base_url
      end
    rescue LoadError
      raise Error, "ruby_llm gem is required for Ollama integration"
    end
  end

  def supports_model?(model)
    # Check if it's a direct alias first
    return true if MODEL_ALIASES.key?(model)

    # Strip version tags (e.g., "llama3.2:3b" -> "llama3.2")
    base_model = model.split(":").first
    MODELS.include?(base_model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        self,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        self,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      # Resolve model alias (e.g., "gpt-4.1" -> "llama3.2")
      model_to_use = resolve_model(model)

      # Create chat config from parameters
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      # Create a chat instance with Ollama using the provider:model format
      chat = RubyLLM.chat(model: model_to_use, provider: :ollama)

      # Build the complete prompt with instructions and context
      full_prompt = build_chat_prompt(prompt, instructions, chat_config)

      if streamer.present?
        # Handle streaming
        collected_content = ""

        response = chat.ask(full_prompt) do |chunk|
          if chunk.respond_to?(:content) && chunk.content.present?
            collected_content += chunk.content
            parsed_chunk = ChatStreamParser.new(chunk).parsed
            streamer.call(parsed_chunk) if parsed_chunk
          end
        end

        # Return the complete response for streaming
        ChatResponse.new(
          id: SecureRandom.uuid,
          model: model_to_use,
          messages: [ ChatMessage.new(id: SecureRandom.uuid, output_text: collected_content) ],
          function_requests: []
        )
      else
        # Handle non-streaming
        response = chat.ask(full_prompt)

        parsed_response = ChatParser.new(response).parsed

        # Emit events for non-streaming responses to match expected interface
        if streamer.present?
          # First emit the text content
          if parsed_response.messages.any? && parsed_response.messages.first.output_text.present?
            output_text_chunk = Provider::LlmConcept::ChatStreamChunk.new(
              type: "output_text",
              data: parsed_response.messages.first.output_text
            )
            streamer.call(output_text_chunk)
          end

          # Then emit the complete response
          response_chunk = Provider::LlmConcept::ChatStreamChunk.new(
            type: "response",
            data: parsed_response
          )
          streamer.call(response_chunk)
        end

        parsed_response
      end
    end
  end

  # Internal method for auto-categorization and merchant detection
  def generate_completion(prompt, model: nil)
    model_to_use = resolve_model(model || @default_model)
    chat = RubyLLM.chat(model: model_to_use, provider: :ollama)
    response = chat.ask(prompt)
    response.content || response.to_s
  end

  private
    attr_reader :base_url, :default_model

    def resolve_model(model)
      # Return the aliased model if it exists, otherwise return the original model
      MODEL_ALIASES[model] || model
    end

    def build_chat_prompt(prompt, instructions, chat_config)
      parts = []

      if instructions.present?
        parts << "Instructions: #{instructions}"
      end

      built_input = chat_config.build_input(prompt)
      parts << built_input

      parts.join("\n\n")
    end
end

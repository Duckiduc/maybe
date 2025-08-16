class Provider::Ollama::ChatParser
  Error = Class.new(StandardError)

  def initialize(response)
    @response = response
  end

  def parsed
    ChatResponse.new(
      id: SecureRandom.uuid,
      model: @response.respond_to?(:model) ? @response.model : "ollama",
      messages: [message],
      function_requests: []
    )
  end

  private
    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def message
      content = if @response.respond_to?(:content)
        @response.content
      elsif @response.is_a?(String)
        @response
      else
        @response.to_s
      end

      ChatMessage.new(
        id: SecureRandom.uuid,
        output_text: content
      )
    end
end

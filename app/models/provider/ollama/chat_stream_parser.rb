class Provider::Ollama::ChatStreamParser
  def initialize(chunk)
    @chunk = chunk
  end

  def parsed
    if @chunk.respond_to?(:content) && @chunk.content.present?
      ChatStreamChunk.new(
        type: "output_text",
        data: @chunk.content
      )
    elsif @chunk.respond_to?(:done) && @chunk.done
      ChatStreamChunk.new(
        type: "response",
        data: ChatResponse.new(
          id: SecureRandom.uuid,
          model: "ollama",
          messages: [ChatMessage.new(id: SecureRandom.uuid, output_text: "")],
          function_requests: []
        )
      )
    else
      nil
    end
  end

  private
    ChatStreamChunk = Provider::LlmConcept::ChatStreamChunk
    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
end

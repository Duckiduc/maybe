class Provider::Ollama::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  def tools
    # Ollama/Ruby_LLM may have different tool format
    # For now, return empty as we'll handle functions differently
    []
  end

  def build_input(prompt)
    if function_results.any?
      # Include function results in the prompt context
      results_context = function_results.map do |fn_result|
        "Function #{fn_result[:name]} (call_id: #{fn_result[:call_id]}) returned: #{fn_result[:output]}"
      end.join("\n")
      
      "#{prompt}\n\nPrevious function call results:\n#{results_context}"
    else
      prompt
    end
  end

  private
    attr_reader :functions, :function_results
end

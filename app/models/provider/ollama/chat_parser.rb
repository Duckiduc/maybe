class Provider::Ollama::ChatParser
  Error = Class.new(StandardError)

  def initialize(response)
    @response = response
  end

  def parsed
    content = extract_content(@response)
    function_requests, cleaned_content = extract_function_calls(content)

    ChatResponse.new(
      id: SecureRandom.uuid,
      model: @response.respond_to?(:model) ? @response.model : "ollama",
      messages: [ ChatMessage.new(id: SecureRandom.uuid, output_text: cleaned_content || content) ],
      function_requests: function_requests
    )
  end

  private
    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def extract_content(response)
      content = if response.respond_to?(:content)
        response.content
      elsif response.is_a?(String)
        response
      else
        response.to_s
      end

      if content.is_a?(String)
        # Strip HTML tags that might interfere with function call parsing
        content = content.gsub(/<[^>]+>/, "")
        # Normalize whitespace and remove extra line breaks
        content = content.gsub(/\s+/, " ").strip
      end
      content
    end

    def extract_function_calls(content)
      function_requests = []

      # Try patterns in order of specificity to avoid duplicates
      patterns = [
        /```[^`]*FUNCTION_CALL:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)[^`]*```/i,  # In code blocks (most specific)
        /`FUNCTION_CALL:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)`/i,                # In inline code
        /FUNCTION_CALL:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)/i,                  # FUNCTION_CALL: func_name(params)
        /FUNCTIONCALL:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)/i,                   # FUNCTIONCALL: func_name(params)
        /BALANCESHEET:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)/i,                   # BALANCESHEET: func_name(params)
        /CALL:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)/i                           # CALL: func_name(params)
      ]

      cleaned_content = content.dup

      # Try each pattern and stop at the first match to avoid duplicates
      patterns.each do |pattern|
        matches = content.scan(pattern)
        if matches.any?
          # Only process the FIRST function call to avoid multiple simultaneous executions
          match = matches.first
          function_name = normalize_function_name(match[0])
          params_str = match[1] || ""

          # Parse parameters
          params = parse_function_params(params_str)

          function_requests << ChatFunctionRequest.new(
            id: SecureRandom.uuid,
            call_id: SecureRandom.uuid,
            function_name: function_name,
            function_args: params.to_json  # Convert Hash to JSON string
          )

          # If we found function calls, remove everything from the function call onwards
          # This prevents the model from generating fake data after the function call
          if pattern.match(content)
            # Find the position of the function call and truncate content there
            match_position = content.index(pattern.match(content)[0])
            cleaned_content = content[0...match_position].strip
          end

          break # Stop after first successful pattern match
        end
      end

      # If no function calls found, return original content
      cleaned_content = content if function_requests.empty?

      [ function_requests, cleaned_content ]
  end

    def parse_function_params(params_str)
      params = {}

      # Parse parameters like: param1=value1, param2=value2
      params_str.scan(/(\w+)=([^,]+)/) do |key, value|
        # Remove quotes and trim whitespace
        clean_value = value.strip.gsub(/^["']|["']$/, "")
        params[key] = clean_value
      end

      params
    end

    def normalize_function_name(name)
      # Convert camelCase variations to snake_case
      # getbalance_sheet -> get_balance_sheet
      # getBalanceSheet -> get_balance_sheet
      name = name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase

      # Handle specific cases for known functions
      case name
      when /getbalance.*sheet/
        "get_balance_sheet"
      when /getaccounts?/
        "get_accounts"
      when /gettransactions?/
        "get_transactions"
      when /getincome.*statement/
        "get_income_statement"
      else
        name
      end
    end

    def clean_content(content)
      # Remove function call lines from the visible content (handle both formats)
      content.gsub(/FUNCTION[_\s]*CALL\s*:\s*\w+\([^)]*\)/i, "").strip
    end

    def message
      # This method is no longer used, but kept for compatibility
      content = extract_content(@response)
      ChatMessage.new(
        id: SecureRandom.uuid,
        output_text: content
      )
    end
end

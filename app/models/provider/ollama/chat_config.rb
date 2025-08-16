class Provider::Ollama::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  def tools
    # Convert functions to a format the model can understand
    functions.map do |fn|
      {
        type: "function",
        function: {
          name: fn[:name],
          description: fn[:description],
          parameters: fn[:params_schema] || { type: "object", properties: {} }
        }
      }
    end
  end

  def build_input(prompt)
    parts = []

    # Add function definitions to the prompt for text-based function calling
    if functions.any?
      function_descriptions = functions.map do |fn|
        desc = "- #{fn[:name]}: #{fn[:description]}"
        if fn[:params_schema] && fn[:params_schema][:properties]
          params = fn[:params_schema][:properties].keys.join(", ")
          desc += "\n  Parameters: #{params}" if params.present?
        end
        desc
      end.join("\n")

      parts << "Available functions:\n#{function_descriptions}\n"
      parts << "CRITICAL INSTRUCTIONS FOR FUNCTION CALLS:\n"
      parts << "1. Use EXACTLY this format: FUNCTION_CALL: function_name(parameters)\n"
      parts << "2. Call ONLY ONE function at a time\n"
      parts << "3. Do NOT use FUNCTIONCALL (missing underscore)\n"
      parts << "4. Do NOT call multiple functions in sequence\n"
      parts << "5. After calling a function, WAIT for the result before doing anything else\n"
      parts << "\nCorrect examples:\n"
      parts << "FUNCTION_CALL: get_balance_sheet()\n"
      parts << "FUNCTION_CALL: get_accounts()\n"
      parts << "\nINCORRECT examples (DO NOT DO THIS):\n"
      parts << "FUNCTIONCALL: getbalancesheet() ❌\n"
      parts << "FUNCTION_CALL: get_balance_sheet()FUNCTION_CALL: get_accounts() ❌\n"
    end

    # Add function results if any
    if function_results.any?
      results_context = function_results.map do |fn_result|
        "Function #{fn_result[:name]} returned: #{fn_result[:output]}"
      end.join("\n")

      parts << "Previous function results:\n#{results_context}\n"
    end

    # Add the main prompt
    parts << prompt

    parts.join("\n")
  end

  private
    attr_reader :functions, :function_results
end

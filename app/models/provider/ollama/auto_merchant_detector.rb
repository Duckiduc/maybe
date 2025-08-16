class Provider::Ollama::AutoMerchantDetector
  def initialize(ollama_provider, transactions:, user_merchants:)
    @ollama_provider = ollama_provider
    @transactions = transactions
    @user_merchants = user_merchants
  end

  def auto_detect_merchants
    prompt = build_prompt
    model_name = ENV.fetch("OLLAMA_MODEL", "llama3.2")
    response = ollama_provider.generate_completion(prompt, model: model_name)

    Rails.logger.info("Auto-detecting merchants with Ollama using #{model_name}")

    build_response(extract_merchants(response))
  end

  private
    attr_reader :ollama_provider, :transactions, :user_merchants

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def build_response(merchants)
      merchants.map do |merchant|
        AutoDetectedMerchant.new(
          transaction_id: merchant["transaction_id"],
          business_name: normalize_ai_value(merchant["business_name"]),
          business_url: normalize_ai_value(merchant["business_url"]),
        )
      end
    end

    def normalize_ai_value(ai_value)
      return nil if ai_value == "null" || ai_value.nil?

      ai_value
    end

    def extract_merchants(response)
      # Try to extract JSON from the response
      json_match = response.match(/```json\s*(\{.*?\})\s*```/m) || response.match(/(\{.*?\})/m)

      if json_match
        begin
          response_json = JSON.parse(json_match[1])
          return response_json.dig("merchants") || []
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse Ollama JSON response: #{e.message}")
          Rails.logger.error("Response: #{response}")
        end
      end

      # Fallback: try to parse the entire response as JSON
      begin
        response_json = JSON.parse(response)
        response_json.dig("merchants") || []
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse Ollama response as JSON: #{e.message}")
        Rails.logger.error("Response: #{response}")
        []
      end
    end

    def build_prompt
      <<~PROMPT.strip_heredoc
        You are an assistant to a consumer personal finance app.

        Closely follow ALL the rules below while auto-detecting business names and website URLs:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Do not include the subdomain in the business_url (i.e. "amazon.com" not "www.amazon.com")
        - User merchants are considered "manual" user-generated merchants and should only be used in 100% clear cases
        - Be slightly pessimistic. We favor returning "null" over returning a false positive.
        - NEVER return a name or URL for generic transaction names (e.g. "Paycheck", "Laundromat", "Grocery store", "Local diner")

        Determining a value:

        - First attempt to determine the name + URL from your knowledge of global businesses
        - If no certain match, attempt to match one of the user-provided merchants
        - If no match, return "null"

        Example 1 (known business):

        ```
        Transaction name: "Some Amazon purchases"

        Result:
        - business_name: "Amazon"
        - business_url: "amazon.com"
        ```

        Example 2 (generic business):

        ```
        Transaction name: "local diner"

        Result:
        - business_name: null
        - business_url: null
        ```

        Here are the user's available merchants in JSON format:

        ```json
        #{user_merchants.to_json}
        ```

        Use BOTH your knowledge AND the user-generated merchants to auto-detect the following transactions:

        ```json
        #{transactions.to_json}
        ```

        Return "null" if you are not 80%+ confident in your answer.

        Respond with a JSON object in this exact format:

        ```json
        {
          "merchants": [
            {
              "transaction_id": "transaction_id_here",
              "business_name": "business_name_or_null",
              "business_url": "business_url_or_null"
            }
          ]
        }
        ```
      PROMPT
    end
end

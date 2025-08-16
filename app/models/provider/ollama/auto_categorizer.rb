class Provider::Ollama::AutoCategorizer
  def initialize(ollama_provider, transactions: [], user_categories: [])
    @ollama_provider = ollama_provider
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    prompt = build_prompt
    model_name = ENV.fetch("OLLAMA_MODEL", "llama3.2")
    response = ollama_provider.generate_completion(prompt, model: model_name)

    Rails.logger.info("Auto-categorizing transactions with Ollama using #{model_name}")

    build_response(extract_categorizations(response))
  end

  private
    attr_reader :ollama_provider, :transactions, :user_categories

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization["transaction_id"],
          category_name: normalize_category_name(categorization["category_name"]),
        )
      end
    end

    def normalize_category_name(category_name)
      return nil if category_name == "null" || category_name.nil?

      category_name
    end

    def extract_categorizations(response)
      # Try to extract JSON from the response
      json_match = response.match(/```json\s*(\{.*?\})\s*```/m) || response.match(/(\{.*?\})/m)

      if json_match
        begin
          response_json = JSON.parse(json_match[1])
          return response_json.dig("categorizations") || []
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse Ollama JSON response: #{e.message}")
          Rails.logger.error("Response: #{response}")
        end
      end

      # Fallback: try to parse the entire response as JSON
      begin
        response_json = JSON.parse(response)
        response_json.dig("categorizations") || []
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse Ollama response as JSON: #{e.message}")
        Rails.logger.error("Response: #{response}")
        []
      end
    end

    def build_prompt
      <<~PROMPT.strip_heredoc
        You are an assistant to a consumer personal finance app. You will be provided a list
        of the user's transactions and a list of the user's categories. Your job is to auto-categorize
        each transaction.

        Closely follow ALL the rules below while auto-categorizing:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Attempt to match the most specific category possible (i.e. subcategory over parent category)
        - Category and transaction classifications should match (i.e. if transaction is an "expense", the category must have classification of "expense")
        - If you don't know the category, return "null"
          - You should always favor "null" over false positives
          - Be slightly pessimistic. Only match a category if you're 60%+ confident it is the correct one.
        - Each transaction has varying metadata that can be used to determine the category
          - Note: "hint" comes from 3rd party aggregators and typically represents a category name that
            may or may not match any of the user-supplied categories

        Here are the user's available categories in JSON format:

        ```json
        #{user_categories.to_json}
        ```

        Use the available categories to auto-categorize the following transactions:

        ```json
        #{transactions.to_json}
        ```

        Respond with a JSON object in this exact format:

        ```json
        {
          "categorizations": [
            {
              "transaction_id": "transaction_id_here",
              "category_name": "category_name_here_or_null"
            }
          ]
        }
        ```
      PROMPT
    end
end

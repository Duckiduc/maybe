require "test_helper"

class Provider::OllamaTest < ActiveSupport::TestCase
  include LLMInterfaceTest

  setup do
    @subject = @ollama = Provider::Ollama.new(base_url: "http://localhost:11434", model: "llama3.2")
    @subject_model = "llama3.2"
  end

  test "ollama errors are automatically raised" do
    # Mock a failed connection
    RubyLLM.stubs(:chat).raises(StandardError.new("Connection failed"))

    response = @ollama.chat_response("Test", model: "invalid-model-that-will-trigger-api-error")

    assert_not response.success?
    assert_kind_of Provider::Ollama::Error, response.error
  end

  test "auto categorizes transactions by various attributes" do
    skip "Ollama integration test - requires local Ollama server" unless ENV["RUN_OLLAMA_TESTS"]

    input_transactions = [
      { id: "1", name: "McDonalds", amount: 20, classification: "expense", merchant: "McDonalds", hint: "Fast Food" },
      { id: "2", name: "Amazon purchase", amount: 100, classification: "expense", merchant: "Amazon" },
      { id: "3", name: "Netflix subscription", amount: 10, classification: "expense", merchant: "Netflix", hint: "Subscriptions" },
      { id: "4", name: "paycheck", amount: 3000, classification: "income" },
      { id: "5", name: "Italian dinner with friends", amount: 100, classification: "expense" },
      { id: "6", name: "1212XXXBCaaa charge", amount: 2.99, classification: "expense" }
    ]

    input_categories = [
      { id: "1", name: "Food & Drink", classification: "expense" },
      { id: "2", name: "Entertainment", classification: "expense" },
      { id: "3", name: "Income", classification: "income" },
      { id: "4", name: "Restaurants", classification: "expense" },
      { id: "5", name: "Shopping", classification: "expense" }
    ]

    response = @ollama.auto_categorize(transactions: input_transactions, user_categories: input_categories)

    assert response.success?

    categorizations = response.data

    assert_equal 6, categorizations.length

    # Test that each result has the required structure
    categorizations.each do |categorization|
      assert_instance_of Provider::LlmConcept::AutoCategorization, categorization
      assert categorization.transaction_id.present?
      # category_name can be nil if no match found
    end

    # Test that transaction IDs match
    returned_transaction_ids = categorizations.map(&:transaction_id)
    expected_transaction_ids = input_transactions.map { |t| t[:id] }
    assert_equal expected_transaction_ids.sort, returned_transaction_ids.sort
  end

  test "auto detects merchants with expected format" do
    skip "Ollama integration test - requires local Ollama server" unless ENV["RUN_OLLAMA_TESTS"]

    input_transactions = [
      { id: "1", name: "Payment to Amazon Prime", amount: 15, classification: "expense" },
      { id: "2", name: "STARBUCKS STORE 12345", amount: 5, classification: "expense" },
      { id: "3", name: "Netflix Subscription", amount: 10, classification: "expense" },
      { id: "4", name: "Random charge XYZ123", amount: 25, classification: "expense" }
    ]

    response = @ollama.auto_detect_merchants(transactions: input_transactions, user_merchants: [])

    assert response.success?

    merchants = response.data

    assert_equal 4, merchants.length

    # Test that each result has the required structure
    merchants.each do |merchant|
      assert_instance_of Provider::LlmConcept::AutoDetectedMerchant, merchant
      assert merchant.transaction_id.present?
      # business_name and business_url can be nil if not detected
    end

    # Test that transaction IDs match
    returned_transaction_ids = merchants.map(&:transaction_id)
    expected_transaction_ids = input_transactions.map { |t| t[:id] }
    assert_equal expected_transaction_ids.sort, returned_transaction_ids.sort
  end

  test "basic chat response works" do
    skip "Ollama integration test - requires local Ollama server" unless ENV["RUN_OLLAMA_TESTS"]

    response = @ollama.chat_response("Hello! Please respond with exactly: 'Hi there!'", model: "llama3.2")

    assert response.success?

    chat_response = response.data

    assert_instance_of Provider::LlmConcept::ChatResponse, chat_response
    assert chat_response.id.present?
    assert_equal "llama3.2", chat_response.model
    assert chat_response.messages.any?

    first_message = chat_response.messages.first
    assert_instance_of Provider::LlmConcept::ChatMessage, first_message
    assert first_message.id.present?
    assert first_message.output_text.present?
  end

  test "basic streaming response works" do
    skip "Ollama integration test - requires local Ollama server" unless ENV["RUN_OLLAMA_TESTS"]

    streamed_chunks = []

    response = @ollama.chat_response(
      "Count from 1 to 3, with each number on a new line.",
      model: "llama3.2",
      streamer: proc { |chunk| streamed_chunks << chunk }
    )

    assert response.success?

    # Should have received some streaming chunks
    assert streamed_chunks.any?

    # Final response should still be properly formatted
    chat_response = response.data
    assert_instance_of Provider::LlmConcept::ChatResponse, chat_response
    assert chat_response.messages.any?
  end
end

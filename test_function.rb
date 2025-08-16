#!/usr/bin/env ruby

require "bundler/setup"
require_relative "config/environment"

# Test the exact format the model is outputting
content = "FUNCTIONCALL: getbalance_sheet()"

parser = Provider::Ollama::ChatParser.new(content)
result = parser.parsed

puts "Testing model output: #{content}"
puts "Function requests found: #{result.function_requests.length}"
result.function_requests.each_with_index do |req, i|
  puts "  #{i + 1}. Name: #{req.function_name}, Args: #{req.function_args}"
end
puts "Cleaned content: '#{result.messages.first&.output_text || 'empty'}'"

# Test if the function exists and can be called
if result.function_requests.any?
  user = User.first # Get any user for testing
  family = user.family

  begin
    function = Assistant::Function::GetBalanceSheet.new(user)
    result_data = function.call({})
    puts "\nFunction execution successful!"
    puts "Result keys: #{result_data.keys}"
    puts "Net worth: #{result_data.dig(:net_worth, :current)}"
  rescue => e
    puts "\nFunction execution failed: #{e.message}"
  end
end

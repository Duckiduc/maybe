#!/usr/bin/env ruby

require "bundler/setup"
require_relative "config/environment"

# Test the parser with the code block response
content = "```\nFUNCTION_CALL: get_balance_sheet()\n```"

parser = Provider::Ollama::ChatParser.new(content)
result = parser.parsed

puts "Testing content: #{content.inspect}"
puts "Function requests found: #{result.function_requests.length}"
puts "First request class: #{result.function_requests.first.class}"
puts "First request: #{result.function_requests.first.inspect}"
result.function_requests.each_with_index do |req, i|
  puts "  #{i + 1}. Request: #{req.inspect}"
  if req.respond_to?(:function_name)
    puts "    Name: #{req.function_name}, Args: #{req.function_args}"
  end
end
puts "Cleaned content: '#{result.messages.first&.output_text || 'empty'}'"

#!/usr/bin/env ruby

require "bundler/setup"
require_relative "config/environment"

# Test the actual response pattern we're getting
content = 'FUNCTIONCALL: getbalancesheet()```plaintext{ Checking: { "currentbalance:$5,000,historicaldata: [{date:%d-%m-%Y,balance:$4,800}, {date:%d-%m-%Y,balance:$4,600}] },Savings: {currentbalance:$20,000,historical_data: [{date:%d-%m-%Y,balance:$21,000}, {date:%d-%m-%Y,balance:$20,500}] },Net Worth: {current:$25,000,composition: [Checking Account: $5,000,Savings Account: $20,000"] }}```'

parser = Provider::Ollama::ChatParser.new(content)
result = parser.parsed

puts "Testing actual content:"
puts "Function requests found: #{result.function_requests.length}"
result.function_requests.each_with_index do |req, i|
  puts "  #{i + 1}. Name: #{req.function_name}, Args: #{req.function_args}"
end
puts "Cleaned content: '#{result.messages.first&.output_text || 'empty'}'"

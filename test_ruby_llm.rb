#!/usr/bin/env ruby

require "ruby_llm"

begin
  RubyLLM.configure do |config|
    config.ollama_api_base = "http://localhost:11434/v1"
  end

  chat = RubyLLM.chat(model: "phi3.5", provider: :ollama)
  puts "Ask method parameters: #{chat.method(:ask).parameters}"
  puts "Ask method arity: #{chat.method(:ask).arity}"

  # Test simple usage
  response = chat.ask("What is 2+2?")
  puts "Response class: #{response.class}"
  puts "Response content: #{response.content if response.respond_to?(:content)}"

  # Test streaming
  puts "\nTesting streaming:"
  collected_content = ""

  response = chat.ask("What is 3+3?") do |chunk|
    puts "Chunk class: #{chunk.class}"
    puts "Chunk methods: #{chunk.methods.grep(/content|text|message/).sort}"
    puts "Chunk content: #{chunk.content if chunk.respond_to?(:content)}"
    collected_content += chunk.content if chunk.respond_to?(:content) && chunk.content
  end

  puts "Final collected content: #{collected_content}"
  puts "Final response content: #{response.content if response.respond_to?(:content)}"
rescue => e
  puts "Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
end

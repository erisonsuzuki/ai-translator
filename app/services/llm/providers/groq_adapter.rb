module Llm
  module Providers
    class GroqAdapter < BaseAdapter
      BASE_URL = ENV.fetch("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
      MODEL = ENV.fetch("GROQ_MODEL", "llama-3.3-70b-versatile")

      def provider_name
        "groq"
      end

      def translate(prompt:)
        payload = post_json(
          url: "#{BASE_URL}/chat/completions",
          api_key: ENV["GROQ_API_KEY"],
          body: {
            model: MODEL,
            temperature: prompt.dig(:llm, :temperature) || 0.3,
            max_tokens: prompt.dig(:llm, :max_tokens) || 700,
            messages: [
              { role: "system", content: prompt.fetch(:system) },
              { role: "user", content: prompt.fetch(:user) }
            ]
          }
        )

        normalized_from(payload, provider: provider_name)
      end
    end
  end
end

module Llm
  module Providers
    class NemotronAdapter < BaseAdapter
      BASE_URL = ENV.fetch("NEMOTRON_BASE_URL", "https://integrate.api.nvidia.com/v1")
      MODEL = ENV.fetch("NEMOTRON_MODEL", "nvidia/llama-3.1-nemotron-70b-instruct")

      def provider_name
        "nemotron"
      end

      def translate(prompt:)
        payload = post_json(
          url: "#{BASE_URL}/chat/completions",
          api_key: ENV["NEMOTRON_API_KEY"],
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

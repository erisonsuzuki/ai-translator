require "json"
require "net/http"
require "uri"

module Llm
  module Providers
    class BaseAdapter
      DEFAULT_TIMEOUT = ENV.fetch("LLM_TIMEOUT_SECONDS", 20).to_i

      def provider_name
        raise NotImplementedError
      end

      def translate(prompt:)
        raise NotImplementedError
      end

      private

      def post_json(url:, api_key:, body:)
        raise Errors::NonRetryableError, "Missing API key for #{provider_name}" if api_key.to_s.strip.empty?

        uri = URI.parse(url)
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)

        response = with_http(uri) { |http| http.request(request) }
        parse_response(response)
      rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT, SocketError => e
        raise Errors::RetryableError, "#{provider_name} network error: #{e.message}"
      end

      def with_http(uri)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: DEFAULT_TIMEOUT,
                                            open_timeout: DEFAULT_TIMEOUT) do |http|
          yield http
        end
      end

      def parse_response(response)
        status = response.code.to_i
        payload = JSON.parse(response.body)

        case status
        when 200
          payload
        when 429
          raise Errors::RetryableError, "#{provider_name} rate limit (429)"
        when 500..599
          raise Errors::RetryableError, "#{provider_name} server error (#{status})"
        else
          error_message = payload.dig("error", "message") || "#{provider_name} request failed (#{status})"
          raise Errors::NonRetryableError, error_message
        end
      rescue JSON::ParserError
        raise Errors::RetryableError, "#{provider_name} returned invalid JSON"
      end

      def normalized_from(payload, provider:)
        text = payload.dig("choices", 0, "message", "content")
        model = payload["model"]
        usage = payload["usage"] || {}

        raise Errors::RetryableError, "#{provider_name} missing content" if text.to_s.strip.empty?

        {
          text:,
          provider:,
          model:,
          tokens_in: usage["prompt_tokens"],
          tokens_out: usage["completion_tokens"]
        }
      end
    end
  end
end

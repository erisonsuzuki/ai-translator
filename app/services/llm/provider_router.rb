module Llm
  class ProviderRouter
    DEFAULT_MAX_ATTEMPTS = ENV.fetch("LLM_MAX_ATTEMPTS", 2).to_i

    def initialize(primary: Providers::GroqAdapter.new, fallback: Providers::NemotronAdapter.new)
      @primary = primary
      @fallback = fallback
      @max_attempts = [ DEFAULT_MAX_ATTEMPTS, 1 ].max
    end

    def call(prompt:)
      try_with_fallback(prompt)
    end

    private

    def try_with_fallback(prompt)
      try_provider(@primary, prompt)
    rescue Errors::RetryableError, Errors::NonRetryableError => primary_error
      instrument("translation.provider.fallback", from: @primary.provider_name, to: @fallback.provider_name,
                                               error_class: primary_error.class.name)
      begin
        try_provider(@fallback, prompt)
      rescue Errors::RetryableError, Errors::NonRetryableError => fallback_error
        raise Errors::AllProvidersFailed,
              "All providers failed. primary=#{@primary.provider_name} fallback=#{@fallback.provider_name} error=#{fallback_error.class}"
      end
    rescue StandardError => e
      raise Errors::AllProvidersFailed, "Unexpected routing failure: #{e.class}: #{e.message}"
    end

    def try_provider(adapter, prompt)
      attempts = 0

      begin
        attempts += 1
        instrument("translation.provider.attempt", provider: adapter.provider_name, attempt: attempts)
        adapter.translate(prompt:)
      rescue Errors::RetryableError => e
        instrument("translation.provider.failed", provider: adapter.provider_name, attempt: attempts,
                                                error_class: e.class.name, message: e.message)
        if attempts >= @max_attempts
          raise
        else
          sleep(backoff_for(attempts))
          retry
        end
      rescue Errors::NonRetryableError => e
        instrument("translation.provider.failed", provider: adapter.provider_name, attempt: attempts,
                                                error_class: e.class.name, message: e.message)
        raise
      end
    end

    def backoff_for(attempt)
      (0.3 * (3**(attempt - 1))).round(2)
    end

    def instrument(event, payload = {})
      ActiveSupport::Notifications.instrument(event, payload)
    end
  end
end

module Llm
  module Errors
    class RetryableError < StandardError; end
    class NonRetryableError < StandardError; end
    class AllProvidersFailed < StandardError; end
  end
end

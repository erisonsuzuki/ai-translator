class TranslateText
  def self.call(input_text:, mode:)
    new(input_text:, mode:).call
  end

  def initialize(input_text:, mode:)
    @input_text = input_text
    @mode = mode
  end

  def call
    prompt = PromptRenderer.render(mode: @mode, source_text: @input_text)
    Llm::ProviderRouter.new.call(prompt:)
  end
end

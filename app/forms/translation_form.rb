class TranslationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_INPUT_CHARS = 5000

  attribute :input_text, :string
  attribute :mode, :string

  validate :validate_input_text
  validate :validate_mode

  def self.from_params(params)
    attrs = params.require(:translation).permit(:input_text, :mode)
    new(input_text: attrs[:input_text], mode: attrs[:mode])
  end

  def self.mode_options
    PromptRepository.mode_options
  end

  def self.default_mode
    mode_options.first&.last || "formal_english"
  end

  def first_error_message
    errors[:base].first
  end

  def normalized_input_text
    normalize(input_text)
  end

  def normalized_mode
    normalize(mode)
  end

  private

  def validate_input_text
    normalized = normalized_input_text

    if normalized.blank?
      errors.add(:base, "Please enter a message to translate.")
      return
    end

    if normalized.length > MAX_INPUT_CHARS
      errors.add(:base, "Please keep input under #{MAX_INPUT_CHARS} characters.")
    end
  end

  def validate_mode
    return if errors[:base].present?

    unless PromptRepository.mode_exists?(normalized_mode)
      errors.add(:base, "Invalid translation mode selected.")
    end
  end

  def normalize(value)
    value.to_s.strip
  end
end

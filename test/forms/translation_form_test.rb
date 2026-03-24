require "test_helper"

class TranslationFormTest < ActiveSupport::TestCase
  test "valid with acceptable input and mode" do
    form = TranslationForm.new(input_text: "hello", mode: "formal_english")

    assert form.valid?
  end

  test "invalid when input is blank" do
    form = TranslationForm.new(input_text: "   ", mode: "formal_english")

    assert_not form.valid?
    assert_includes form.errors[:base], "Please enter a message to translate."
  end

  test "invalid when input exceeds max chars" do
    form = TranslationForm.new(input_text: "a" * (TranslationForm::MAX_INPUT_CHARS + 1), mode: "formal_english")

    assert_not form.valid?
    assert_includes form.errors[:base], "Please keep input under #{TranslationForm::MAX_INPUT_CHARS} characters."
  end

  test "invalid when mode is unknown" do
    form = TranslationForm.new(input_text: "hello", mode: "unknown")

    assert_not form.valid?
    assert_includes form.errors[:base], "Invalid translation mode selected."
  end

  test "from_params requires translation payload" do
    assert_raises(ActionController::ParameterMissing) do
      TranslationForm.from_params(ActionController::Parameters.new(input_text: "hello", mode: "formal_english"))
    end
  end

  test "normalizes input text and mode" do
    form = TranslationForm.new(input_text: "  hello  ", mode: " formal_english ")

    assert form.valid?
    assert_equal "hello", form.normalized_input_text
    assert_equal "formal_english", form.normalized_mode
  end
end

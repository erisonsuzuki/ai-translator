require "application_system_test_case"

class TranslationsResultResetTest < ApplicationSystemTestCase
  test "typing new text clears stale result" do
    with_translate_text_stub(text: "Initial translated text", provider: "groq") do
      visit root_path
      fill_in "Your text", with: "olá time"
      select "Formal English", from: "Mode"
      click_button "Translate"

      assert_text "Initial translated text"
      assert_selector "#translation_result .result"

      fill_in "Your text", with: "olá time com nova ideia"

      assert_no_selector "#translation_result .result"
      assert_selector "#translation_result .result-placeholder", text: "Result cleared because the source text changed"
      assert_selector "[data-translation-result-reset-target='state']", text: "Previous translation result cleared because source text changed.", visible: :all
    end
  end

  private

  def with_translate_text_stub(result)
    original = TranslateText.method(:call)
    TranslateText.define_singleton_method(:call) { |**_kwargs| result }
    yield
  ensure
    TranslateText.define_singleton_method(:call, original)
  end
end

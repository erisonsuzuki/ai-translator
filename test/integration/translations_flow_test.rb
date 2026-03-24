require "test_helper"

class TranslationsFlowTest < ActionDispatch::IntegrationTest
  test "new page includes result reset hooks" do
    get root_path

    assert_response :success
    assert_includes response.body, "data-controller=\"translation-result-reset\""
    assert_includes response.body, "input-&gt;translation-result-reset#sourceChanged"
    assert_includes response.body, "id=\"translation_result\""
  end

  test "turbo submit renders result instead of 204" do
    with_translate_text_stub({ text: "Formal result", provider: "groq" }) do
      post translations_path,
           params: { translation: { input_text: "test", mode: "formal_english" } },
           as: :turbo_stream
    end

    assert_response :success
    assert_turbo_stream_response
    assert_includes response.body, "target=\"translation_result\""
    assert_includes response.body, "id=\"translation_result\""
    assert_includes response.body, "Formal result"
    assert_includes response.body, "Provider: groq"
  end

  test "html submit renders result" do
    with_translate_text_stub({ text: "Formal result", provider: "groq" }) do
      post translations_path, params: { translation: { input_text: "test", mode: "formal_english" } }
    end

    assert_response :success
    assert_includes response.body, "Formal result"
  end

  test "blank input returns unprocessable entity" do
    post translations_path,
         params: { translation: { input_text: "", mode: "formal_english" } },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_turbo_stream_response
    assert_includes response.body, "target=\"flash_messages\""
    assert_includes response.body, "Please enter a message to translate."
  end

  test "missing translation payload returns bad request" do
    post translations_path, params: { input_text: "test", mode: "formal_english" }, as: :turbo_stream

    assert_response :bad_request
    assert_turbo_stream_response
    assert_includes response.body, "Invalid translation request."
  end

  test "invalid mode returns unprocessable entity" do
    post translations_path,
         params: { translation: { input_text: "test", mode: "bad_mode" } },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_turbo_stream_response
    assert_includes response.body, "Invalid translation mode selected."
  end

  test "too long input returns unprocessable entity" do
    post translations_path,
         params: { translation: { input_text: "a" * (TranslationForm::MAX_INPUT_CHARS + 1), mode: "formal_english" } },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_turbo_stream_response
    assert_includes response.body, "Please keep input under #{TranslationForm::MAX_INPUT_CHARS} characters."
  end

  test "provider failure returns service unavailable" do
    with_translate_text_error(Llm::Errors::AllProvidersFailed.new("down")) do
      post translations_path,
           params: { translation: { input_text: "test", mode: "formal_english" } },
           as: :turbo_stream
    end

    assert_response :service_unavailable
    assert_turbo_stream_response
    assert_includes response.body, "Translation service is temporarily unavailable. Please try again."
  end

  test "prompt config failure returns internal server error" do
    with_translate_text_error(PromptRepository::ConfigError.new("bad config")) do
      post translations_path,
           params: { translation: { input_text: "test", mode: "formal_english" } },
           as: :turbo_stream
    end

    assert_response :internal_server_error
    assert_turbo_stream_response
    assert_includes response.body, "Prompt configuration error. Please contact support."
  end

  test "html validation failure returns unprocessable entity" do
    post translations_path, params: { translation: { input_text: "", mode: "formal_english" } }

    assert_response :unprocessable_entity
    assert_includes response.body, "Please enter a message to translate."
  end

  test "html provider failure returns service unavailable" do
    with_translate_text_error(Llm::Errors::AllProvidersFailed.new("down")) do
      post translations_path, params: { translation: { input_text: "test", mode: "formal_english" } }
    end

    assert_response :service_unavailable
    assert_includes response.body, "Translation service is temporarily unavailable. Please try again."
  end

  test "html prompt config failure returns internal server error" do
    with_translate_text_error(PromptRepository::ConfigError.new("bad config")) do
      post translations_path, params: { translation: { input_text: "test", mode: "formal_english" } }
    end

    assert_response :internal_server_error
    assert_includes response.body, "Prompt configuration error. Please contact support."
  end

  private

  def with_translate_text_stub(result)
    original = TranslateText.method(:call)
    TranslateText.define_singleton_method(:call) { |**_kwargs| result }
    yield
  ensure
    TranslateText.define_singleton_method(:call, original)
  end

  def assert_turbo_stream_response
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "<turbo-stream"
  end

  def with_translate_text_error(error)
    original = TranslateText.method(:call)
    TranslateText.define_singleton_method(:call) { |**_kwargs| raise error }
    yield
  ensure
    TranslateText.define_singleton_method(:call, original)
  end
end

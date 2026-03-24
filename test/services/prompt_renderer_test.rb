require "test_helper"

class PromptRendererTest < ActiveSupport::TestCase
  test "linkedin mode keeps source language and includes linkedin post guidance" do
    prompt = PromptRenderer.render(mode: "linkedin_style", source_text: "eu xinguei o chefe")

    assert_includes prompt[:system], "keep exactly the same language"
    assert_includes prompt[:system], "Do not translate to another language"
    refute_includes prompt[:system], "Always produce the final output in English"
    assert_includes prompt[:user], "same language as the source text"
    assert_includes prompt[:user], "Do not translate to a different language"
    assert_includes prompt[:user], "strong opening hook"
    assert_includes prompt[:user], "short paragraphs (1-3 lines)"
    assert_includes prompt[:user], "Return only the final rewritten text, ready to be posted on LinkedIn"
  end

  test "formal english mode explicitly enforces english output" do
    prompt = PromptRenderer.render(mode: "formal_english", source_text: "eu xinguei o chefe")

    assert_includes prompt[:system], "Always produce the final output in English"
    assert_includes prompt[:user], "Rewrite the source text as polished formal English"
    refute_includes prompt[:user], "same language as the source text"
  end

  test "informal english mode explicitly enforces english output" do
    prompt = PromptRenderer.render(mode: "informal_english", source_text: "eu xinguei o chefe")

    assert_includes prompt[:system], "Always produce the final output in English"
    assert_includes prompt[:user], "Rewrite the source text as clear informal English"
    refute_includes prompt[:user], "same language as the source text"
  end
end

class TranslationsController < ApplicationController
  SAFE_DEFAULT_MODE = "formal_english"

  rescue_from Llm::Errors::AllProvidersFailed, with: :handle_provider_error
  rescue_from Llm::Errors::RetryableError, Llm::Errors::NonRetryableError, with: :handle_provider_error
  rescue_from PromptRenderer::TemplateError, PromptRepository::ConfigError, with: :handle_prompt_error
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  def new
    build_default_form
    @mode_options = TranslationForm.mode_options
  end

  def create
    @form = TranslationForm.from_params(params)
    @mode_options = TranslationForm.mode_options

    unless @form.valid?
      flash.now[:alert] = @form.first_error_message
      return render_response(status: :unprocessable_entity)
    end

    result = TranslateText.call(input_text: @form.normalized_input_text, mode: @form.normalized_mode)
    @output_text = result.fetch(:text)
    @provider = result.fetch(:provider)
    render_response(status: :ok)
  end

  private

  def build_default_form
    @form = TranslationForm.new(input_text: "", mode: TranslationForm.default_mode)
  end

  def render_new(status:)
    render :new, formats: :html, status:
  end

  def render_response(status:)
    if turbo_stream_request?
      render turbo_stream: [
        turbo_stream.replace("flash_messages", partial: "translations/flash"),
        turbo_stream.replace(
          "translation_result",
          partial: "translations/result",
          locals: { output_text: @output_text, provider: @provider }
        )
      ], status:
    else
      render_new(status:)
    end
  end

  def turbo_stream_request?
    request.format.turbo_stream?
  end

  def handle_provider_error(error)
    Rails.logger.warn("translations.provider_error error=#{error.class}")
    flash.now[:alert] = "Translation service is temporarily unavailable. Please try again."
    @mode_options = TranslationForm.mode_options
    @form ||= TranslationForm.new(input_text: "", mode: SAFE_DEFAULT_MODE)
    @output_text = nil
    @provider = nil
    render_response(status: :service_unavailable)
  end

  def handle_prompt_error(error)
    Rails.logger.error("translations.prompt_config_error error=#{error.class}")
    flash.now[:alert] = "Prompt configuration error. Please contact support."
    @mode_options = []
    @form ||= TranslationForm.new(input_text: "", mode: SAFE_DEFAULT_MODE)
    @output_text = nil
    @provider = nil
    render_response(status: :internal_server_error)
  end

  def handle_parameter_missing(error)
    Rails.logger.warn("translations.parameter_missing error=#{error.class}")
    @mode_options = TranslationForm.mode_options
    build_default_form
    flash.now[:alert] = "Invalid translation request."
    @output_text = nil
    @provider = nil
    render_response(status: :bad_request)
  end
end

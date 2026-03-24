class PromptRenderer
  class TemplateError < StandardError; end

  PLACEHOLDER_PATTERN = /\{\{(\w+)\}\}/.freeze

  def self.render(mode:, source_text:)
    config = PromptRepository.mode_config!(mode)
    vars = {
      "source_text" => source_text.to_s,
      "style_label" => config[:style_label].to_s
    }

    system_template = config.fetch(:system_template)
    user_template = config.fetch(:user_template)

    {
      system: interpolate(system_template, vars),
      user: interpolate(user_template, vars),
      llm: (config[:llm] || {}).deep_symbolize_keys
    }
  rescue KeyError => e
    raise TemplateError, "Missing prompt config key: #{e.message}"
  end

  def self.interpolate(template, vars)
    placeholders = template.scan(PLACEHOLDER_PATTERN).flatten.uniq
    missing = placeholders.reject { |key| vars[key].present? }
    raise TemplateError, "Missing template variables: #{missing.join(', ')}" if missing.any?

    rendered = template.dup
    vars.each do |key, value|
      rendered.gsub!("{{#{key}}}", value.to_s)
    end

    unresolved = rendered.scan(PLACEHOLDER_PATTERN).flatten.uniq
    raise TemplateError, "Unresolved template variables: #{unresolved.join(', ')}" if unresolved.any?

    rendered
  end

  private_class_method :interpolate
end

class PromptRepository
  class ConfigError < StandardError; end
  class UnknownModeError < ConfigError; end

  DEFAULTS_PATH = Rails.root.join("config/prompts/defaults.yml")
  MODES_GLOB = Rails.root.join("config/prompts/modes/*.yml")

  def self.mode_options
    modes.map { |key, config| [ config.fetch(:label), key ] }
  end

  def self.mode_exists?(mode)
    modes.key?(mode.to_s)
  end

  def self.mode_config!(mode)
    key = mode.to_s
    config = modes[key]
    raise UnknownModeError, "Unknown mode: #{mode}" if config.nil?

    defaults.deep_merge(config)
  end

  def self.defaults
    @defaults ||= begin
      parsed = parse_yaml(DEFAULTS_PATH)
      parsed.fetch(:defaults)
    rescue KeyError
      raise ConfigError, "Missing defaults section in #{DEFAULTS_PATH}"
    end
  end

  def self.modes
    @modes ||= begin
      configs = Dir[MODES_GLOB.to_s].sort.map { |path| parse_mode_file(path) }
      keys = configs.map { |cfg| cfg.fetch(:key) }
      duplicates = keys.tally.select { |_k, count| count > 1 }.keys
      raise ConfigError, "Duplicate mode keys: #{duplicates.join(', ')}" if duplicates.any?

      configs.index_by { |cfg| cfg.fetch(:key) }
    end
  end

  def self.parse_mode_file(path)
    cfg = parse_yaml(path)
    key = cfg[:key].to_s
    label = cfg[:label].to_s
    raise ConfigError, "Missing key in #{path}" if key.empty?
    raise ConfigError, "Missing label in #{path}" if label.empty?

    cfg.merge(key:, label:)
  end

  def self.parse_yaml(path)
    parsed = YAML.safe_load_file(path, aliases: false)
    raise ConfigError, "Invalid YAML content in #{path}" unless parsed.is_a?(Hash)

    parsed.deep_symbolize_keys
  rescue Errno::ENOENT
    raise ConfigError, "Missing config file: #{path}"
  rescue Psych::SyntaxError => e
    raise ConfigError, "Invalid YAML syntax in #{path}: #{e.message}"
  end

  private_class_method :parse_mode_file, :parse_yaml
end

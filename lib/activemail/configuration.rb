# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'tokens'
require_relative 'inliner'

module ActiveMail
  extend T::Sig

  ComponentMap = T.type_alias { T::Hash[String, T.class_of(ActiveMail::Components::Base)] }

  sig { returns(ActiveMail::Configuration) }
  def self.configuration
    @configuration ||= T.let(Configuration.new, T.nilable(ActiveMail::Configuration))
  end

  sig { returns(ActiveMail::Tokens) }
  def self.tokens
    configuration.tokens
  end

  sig { params(config: T.untyped).returns(ActiveMail::Configuration) }
  def self.configuration=(config)
    raise TypeError, 'Not an ActiveMail::Configuration' unless config.is_a?(Configuration)

    @configuration = config
  end

  sig { params(block: T.proc.params(config: ActiveMail::Configuration).void).void }
  def self.configure(&block)
    block.call(configuration)
  end

  # <html[\s>] so a <htmlfoo> custom tag or "<html" in text never flips the parse mode.
  sig { params(html: String).returns(T::Boolean) }
  def self.full_document?(html)
    html.match?(/<html[\s>]/i)
  end

  # The complete SCSS variable bridge — tokens + the grid layout knobs.
  # Single source for the .scss.erb bridge (Sprockets) and tokens:export (Propshaft).
  sig { returns(String) }
  def self.scss_variables
    "#{tokens.to_scss}$am-grid-container-width: #{configuration.container_width}px !default;\n" \
      "$am-column-count: #{configuration.column_count} !default;\n"
  end

  # Route warnings to the app logger when present (Sentry breadcrumbs, log
  # aggregation), else $stderr — which is often dropped in production.
  sig { params(message: String).void }
  def self.log_warning(message)
    logger = rails_logger
    logger ? logger.warn(message) : Kernel.warn(message)
  end

  sig { returns(T.untyped) }
  def self.rails_logger
    return unless Object.const_defined?(:Rails)

    rails = Object.const_get(:Rails)
    rails.respond_to?(:logger) ? rails.logger : nil
  end

  # Invalid bytes degrade deterministically to U+FFFD, but that silently corrupts
  # content — surface it per on_parse_error before scrubbing.
  sig { params(html_string: String).returns(String) }
  def self.scrub_invalid_bytes(html_string)
    mode = configuration.on_parse_error
    message = '[activemail] input had invalid byte sequences; scrubbed to U+FFFD'
    raise ParseError, message if mode == :raise

    log_warning(message) unless mode == :ignore
    html_string.scrub
  end

  # Rejects non-integers rather than silently coercing ("abc"→0, 12.9→12); zero or
  # negative dimensions blow up at transform time (Infinity ghost width).
  sig { params(name: Symbol, value: T.untyped).returns(Integer) }
  def self.positive_integer!(name, value)
    raise TypeError, "#{name} must be an Integer, got #{value.inspect} (#{value.class})" unless value.is_a?(Integer)
    raise ArgumentError, "#{name} must be positive, got #{value}" unless value.positive?

    value
  end

  # Author attributes are untrusted strings: base 10 only (Integer() reads "010" as
  # octal and "0x20" as hex), nil when not a positive integer.
  sig { params(value: T.untyped).returns(T.nilable(Integer)) }
  def self.parse_positive_integer(value)
    string = value.to_s.strip
    return unless string.match?(/\A\d+\z/)

    int = string.to_i
    int if int.positive?
  end

  class Configuration
    extend T::Sig

    ON_PARSE_ERROR_MODES = T.let(%i[ignore warn raise].freeze, T::Array[Symbol])

    sig { returns(ActiveMail::Inliner::Setting) }
    attr_reader :inliner

    sig { returns(Symbol) }
    attr_reader :template_engine, :on_parse_error

    sig { returns(Integer) }
    attr_reader :column_count, :container_width

    sig { returns(T.nilable(String)) }
    attr_reader :blank_link_rel

    # Mutating the returned hash would bypass validate_component!.
    sig { returns(ActiveMail::ComponentMap) }
    def components
      @components.dup.freeze
    end

    sig { returns(ActiveMail::Tokens) }
    def tokens
      @tokens ||= T.let(ActiveMail::Tokens.new, T.nilable(ActiveMail::Tokens))
    end

    sig { void }
    def initialize
      @template_engine = T.let(:erb, Symbol)
      @column_count = T.let(12, Integer)
      @container_width = T.let(600, Integer)
      @components = T.let({}, ActiveMail::ComponentMap)
      @on_parse_error = T.let(:warn, Symbol)
      @inliner = T.let(:premailer, ActiveMail::Inliner::Setting)
      @blank_link_rel = T.let('noopener', T.nilable(String))
    end

    # Shared: building the component map per render is pure overhead.
    sig { returns(ActiveMail::Core) }
    def core
      @core ||= T.let(ActiveMail::Core.new(config: self), T.nilable(ActiveMail::Core))
    end

    # Validates eagerly (like sibling setters): a typo fails at boot, not silently mid-delivery.
    sig { params(value: T.any(String, ActiveMail::Inliner::Setting)).returns(ActiveMail::Inliner::Setting) }
    def inliner=(value)
      setting = value.is_a?(String) ? value.to_sym : value
      @resolved_inliner = T.let(ActiveMail::Inliner.resolve(setting), T.nilable(ActiveMail::Inliner::Base))
      @inliner = setting
    end

    sig { returns(ActiveMail::Inliner::Base) }
    def resolved_inliner
      @resolved_inliner ||= T.let(ActiveMail::Inliner.resolve(@inliner), T.nilable(ActiveMail::Inliner::Base))
    end

    sig { params(value: T.untyped).returns(Symbol) }
    def on_parse_error=(value)
      mode = value.respond_to?(:to_sym) ? value.to_sym : value
      raise ArgumentError, "on_parse_error must be one of #{ON_PARSE_ERROR_MODES.inspect}" unless ON_PARSE_ERROR_MODES.include?(mode)

      @on_parse_error = mode
    end

    sig { params(value: T.untyped).returns(Symbol) }
    def template_engine=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_sym'" unless value.respond_to?(:to_sym)

      @template_engine = value.to_sym
    end

    sig { params(value: T.untyped).returns(Integer) }
    def column_count=(value)
      @column_count = ActiveMail.positive_integer!(:column_count, value)
      invalidate_core!
      @column_count
    end

    sig { params(value: T.untyped).returns(Integer) }
    def container_width=(value)
      @container_width = ActiveMail.positive_integer!(:container_width, value)
      invalidate_core!
      @container_width
    end

    sig { params(value: T.untyped).returns(T.nilable(String)) }
    def blank_link_rel=(value)
      raise TypeError, "blank_link_rel must be a String or nil, got #{value.inspect} (#{value.class})" unless value.nil? || value.is_a?(String)

      normalized = value&.strip
      @blank_link_rel = normalized && normalized.empty? ? nil : normalized
    end

    sig { params(value: T.untyped).returns(ActiveMail::ComponentMap) }
    def components=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_hash'" unless value.respond_to?(:to_hash)

      # Lookup is by node name (String); a Symbol key would never match.
      normalized = value.to_hash.transform_keys(&:to_s)
      normalized.each { |tag, klass| ActiveMail::Components.validate_component!(tag, klass) }
      invalidate_core!
      @components = normalized
    end

    sig { params(tag: T.any(String, Symbol), component_class: T.class_of(ActiveMail::Components::Base)).void }
    def register_component(tag, component_class)
      ActiveMail::Components.validate_component!(tag, component_class)

      invalidate_core!
      @components = @components.merge(tag.to_s => component_class)
    end

    private

    sig { void }
    def invalidate_core!
      @core = nil
    end
  end
end

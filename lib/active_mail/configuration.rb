# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'tokens'
require_relative 'inliner/base'
require_relative 'inliner/premailer'
require_relative 'inliner/roadie'
require_relative 'inliner/null'

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

  # Zero or negative dimensions blow up at transform time (Infinity ghost width).
  # Reject non-integers rather than silently coercing ("abc"→0, 12.9→12).
  sig { params(name: Symbol, value: T.untyped).returns(Integer) }
  def self.assert_positive_dimension!(name, value)
    raise ArgumentError, "#{name} must be a positive integer, got #{value.inspect}" unless value.is_a?(Integer) && value.positive?

    value
  end

  class Configuration
    extend T::Sig

    ON_PARSE_ERROR_MODES = T.let(%i[ignore warn raise].freeze, T::Array[Symbol])

    INLINERS = T.let(
      { premailer: ActiveMail::Inliner::Premailer, roadie: ActiveMail::Inliner::Roadie, null: ActiveMail::Inliner::Null }.freeze,
      T::Hash[Symbol, T.class_of(ActiveMail::Inliner::Base)]
    )

    InlinerSetting = T.type_alias { T.any(Symbol, ActiveMail::Inliner::Base, T.class_of(ActiveMail::Inliner::Base)) }

    sig { returns(InlinerSetting) }
    attr_reader :inliner

    # Lets a host already running another inliner (e.g. premailer-rails) opt out.
    sig { returns(T::Boolean) }
    attr_reader :register_inline_interceptor

    sig { params(value: T.untyped).void }
    def register_inline_interceptor=(value)
      raise TypeError, 'register_inline_interceptor must be true or false' unless [true, false].include?(value)

      @register_inline_interceptor = value
    end

    sig { returns(Symbol) }
    attr_reader :template_engine

    sig { returns(Symbol) }
    attr_reader :on_parse_error

    sig { returns(Integer) }
    attr_reader :column_count

    sig { returns(Integer) }
    attr_reader :container_width

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
      @tokens = T.let(nil, T.nilable(ActiveMail::Tokens))
      @inliner = T.let(:premailer, InlinerSetting)
      @resolved_inliner = T.let(nil, T.nilable(ActiveMail::Inliner::Base))
      @register_inline_interceptor = T.let(true, T::Boolean)
    end

    # Validates eagerly (like sibling setters): a typo fails at boot, not silently mid-delivery.
    sig { params(value: T.any(Symbol, String, ActiveMail::Inliner::Base, T.class_of(ActiveMail::Inliner::Base))).returns(InlinerSetting) }
    def inliner=(value)
      resolved = value.is_a?(String) ? value.to_sym : value
      resolve_inliner(resolved) # raises on an invalid value, eagerly
      @resolved_inliner = nil   # a new setting invalidates the memoized instance
      @inliner = resolved
    end

    # Memoized so the lifecycle is consistent (one instance reused, not re-built per call).
    sig { returns(ActiveMail::Inliner::Base) }
    def resolved_inliner
      @resolved_inliner ||= resolve_inliner(@inliner)
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
      @column_count = positive_integer!(:column_count, value)
    end

    sig { params(value: T.untyped).returns(Integer) }
    def container_width=(value)
      @container_width = positive_integer!(:container_width, value)
    end

    sig { params(value: T.untyped).returns(ActiveMail::ComponentMap) }
    def components=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_hash'" unless value.respond_to?(:to_hash)

      # Lookup is by node name (String); a Symbol key would never match.
      normalized = value.to_hash.transform_keys(&:to_s)
      normalized.each { |tag, klass| ActiveMail::Components.validate_component!(tag, klass) }
      @components = normalized
    end

    sig { params(tag: T.any(String, Symbol), component_class: T.class_of(ActiveMail::Components::Base)).void }
    def register_component(tag, component_class)
      ActiveMail::Components.validate_component!(tag, component_class)

      @components = @components.merge(tag.to_s => component_class)
    end

    private

    # Single source for both eager validation (in the setter) and resolution.
    sig { params(value: InlinerSetting).returns(ActiveMail::Inliner::Base) }
    def resolve_inliner(value)
      return value if value.is_a?(ActiveMail::Inliner::Base)
      return value.new if value.is_a?(Class) && value < ActiveMail::Inliner::Base
      return T.must(INLINERS[value]).new if value.is_a?(Symbol) && INLINERS.key?(value)

      raise ArgumentError, "unknown inliner #{value.inspect}, expected one of #{INLINERS.keys.inspect}, an Inliner::Base subclass, or an instance"
    end

    # Integer-only (no to_int): a Float would otherwise be silently truncated
    # (12.9 -> 12), contradicting assert_positive_dimension!'s invariant.
    sig { params(name: Symbol, value: T.untyped).returns(Integer) }
    def positive_integer!(name, value)
      raise TypeError, "#{name} must be an Integer, got #{value.inspect} (#{value.class})" unless value.is_a?(Integer)

      ActiveMail.assert_positive_dimension!(name, value)
    end
  end
end

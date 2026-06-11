# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module Inky
  extend T::Sig

  ComponentMap = T.type_alias { T::Hash[String, T.class_of(Inky::Components::Base)] }

  sig { returns(Inky::Configuration) }
  def self.configuration
    @configuration ||= T.let(Configuration.new, T.nilable(Inky::Configuration))
  end

  sig { params(config: T.untyped).returns(Inky::Configuration) }
  def self.configuration=(config)
    raise TypeError, 'Not an Inky::Configuration' unless config.is_a?(Configuration)

    @configuration = config
  end

  sig { params(block: T.proc.params(config: Inky::Configuration).void).void }
  def self.configure(&block)
    block.call(configuration)
  end

  # Zero or negative dimensions blow up at transform time (Infinity ghost width).
  sig { params(name: Symbol, value: T.untyped).returns(Integer) }
  def self.assert_positive_dimension!(name, value)
    int = value.to_i
    raise ArgumentError, "#{name} must be a positive integer, got #{int}" unless int.positive?

    int
  end

  class Configuration
    extend T::Sig

    ON_PARSE_ERROR_MODES = T.let(%i[ignore warn raise].freeze, T::Array[Symbol])

    sig { returns(Symbol) }
    attr_reader :template_engine

    sig { returns(Symbol) }
    attr_reader :on_parse_error

    sig { returns(Integer) }
    attr_reader :column_count

    sig { returns(Integer) }
    attr_reader :container_width

    # Mutating the returned hash would bypass validate_component!.
    sig { returns(Inky::ComponentMap) }
    def components
      @components.dup.freeze
    end

    sig { void }
    def initialize
      @template_engine = T.let(:erb, Symbol)
      @column_count = T.let(12, Integer)
      @container_width = T.let(600, Integer)
      @components = T.let({}, Inky::ComponentMap)
      @on_parse_error = T.let(:warn, Symbol)
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

    sig { params(value: T.untyped).returns(Inky::ComponentMap) }
    def components=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_hash'" unless value.respond_to?(:to_hash)

      # Lookup is by node name (String); 1.x callers used Symbol keys.
      normalized = value.to_hash.transform_keys(&:to_s)
      normalized.each { |tag, klass| Inky::Components.validate_component!(tag, klass) }
      @components = normalized
    end

    sig { params(tag: T.any(String, Symbol), component_class: T.class_of(Inky::Components::Base)).void }
    def register_component(tag, component_class)
      Inky::Components.validate_component!(tag, component_class)

      @components = @components.merge(tag.to_s => component_class)
    end

    private

    sig { params(name: Symbol, value: T.untyped).returns(Integer) }
    def positive_integer!(name, value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_int'" unless value.respond_to?(:to_int)

      Inky.assert_positive_dimension!(name, value.to_int)
    end
  end
end

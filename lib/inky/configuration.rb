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

  sig { params(config: Inky::Configuration).returns(Inky::Configuration) }
  def self.configuration=(config)
    raise TypeError, 'Not an Inky::Configuration' unless config.is_a?(Configuration)

    @configuration = config
  end

  sig { params(block: T.proc.params(config: Inky::Configuration).void).void }
  def self.configure(&block)
    block.call(configuration)
  end

  class Configuration
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :template_engine

    sig { returns(Integer) }
    attr_reader :column_count

    sig { returns(Integer) }
    attr_reader :container_width

    sig { returns(Inky::ComponentMap) }
    attr_reader :components

    sig { void }
    def initialize
      @template_engine = T.let(:erb, Symbol)
      @column_count = T.let(12, Integer)
      @container_width = T.let(600, Integer)
      @components = T.let({}, Inky::ComponentMap)
    end

    sig { params(value: T.untyped).returns(Symbol) }
    def template_engine=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_sym'" unless value.respond_to?(:to_sym)

      @template_engine = value.to_sym
    end

    sig { params(value: T.untyped).returns(Integer) }
    def column_count=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_int'" unless value.respond_to?(:to_int)

      @column_count = value.to_int
    end

    sig { params(value: T.untyped).returns(Integer) }
    def container_width=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_int'" unless value.respond_to?(:to_int)

      @container_width = value.to_int
    end

    sig { params(value: Inky::ComponentMap).returns(Inky::ComponentMap) }
    def components=(value)
      raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_hash'" unless value.respond_to?(:to_hash)

      @components = value.to_hash
    end

    # Register a custom tag handled by the given component class.
    # The class must inherit from Inky::Components::Base.
    sig { params(tag: String, component_class: T.class_of(Inky::Components::Base)).void }
    def register_component(tag, component_class)
      unless component_class < Inky::Components::Base
        raise TypeError, "#{component_class} must inherit from Inky::Components::Base"
      end

      @components = @components.merge(tag.to_s => component_class)
    end
  end
end

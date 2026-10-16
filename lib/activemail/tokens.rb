# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'tokens/defaults'
require_relative 'tokens/button_style'
require_relative 'tokens/scss_serializer'

module ActiveMail
  class Tokens
    extend T::Sig

    sig { void }
    def initialize
      @stores = T.let(GROUPS.transform_values(&:dup), T::Hash[Symbol, TokenMap])
    end

    sig { params(name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def color(name, value = nil)
      access(:color, name, value)
    end

    sig { params(name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def font(name, value = nil)
      access(:font, name, value)
    end

    sig { params(name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def spacing(name, value = nil)
      access(:spacing, name, value)
    end

    sig { params(name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def radius(name, value = nil)
      access(:radius, name, value)
    end

    # Raise rather than interpolating nil into the CSS.
    sig { params(name: T.any(String, Symbol)).returns(String) }
    def color!(name)
      fetch!(:color, name)
    end

    sig { params(name: T.any(String, Symbol)).returns(String) }
    def font!(name)
      fetch!(:font, name)
    end

    sig { params(name: T.any(String, Symbol)).returns(String) }
    def spacing!(name)
      fetch!(:spacing, name)
    end

    sig { params(name: T.any(String, Symbol)).returns(String) }
    def radius!(name)
      fetch!(:radius, name)
    end

    # Frozen snapshot: mutating the result can't bypass the DSL setters.
    sig { returns(T::Hash[Symbol, TokenMap]) }
    def to_h
      @stores.transform_values { |store| store.dup.freeze }.freeze
    end

    sig { params(groups: TokenMap).void }
    def load(**groups)
      groups.each do |group, values|
        values.each { |name, value| access(group, name, value) }
      end
    end

    # Every token with derived colors filled in; nil marks a derived token left unset.
    sig { returns(T::Hash[Symbol, T::Hash[Symbol, T.nilable(String)]]) }
    def resolved
      colors = DERIVED_COLORS.keys.to_h { |name| [name, color(name)] }
      @stores.merge(color: store_for(:color).merge(colors))
    end

    sig { params(variant: T.any(String, Symbol)).returns(ButtonStyle) }
    def button_style(variant)
      ButtonStyle.from(self, variant)
    end

    sig { returns(String) }
    def to_scss
      ScssSerializer.call(resolved)
    end

    private

    sig { params(group: Symbol).returns(TokenMap) }
    def store_for(group)
      @stores.fetch(group) { raise KeyError, "unknown token group #{group.inspect}" }
    end

    sig { params(group: Symbol, name: T.any(String, Symbol)).returns(String) }
    def fetch!(group, name)
      access(group, name, nil) || raise(KeyError, "unknown or unset #{group} token #{name.inspect}")
    end

    sig { params(group: Symbol, key: Symbol).returns(T.nilable(String)) }
    def derived(group, key)
      return unless group == :color

      source = DERIVED_COLORS[key]
      source && store_for(:color)[source]
    end

    sig { params(group: Symbol, name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def access(group, name, value)
      store = store_for(group)
      key = name.to_sym
      return store.fetch(key) { derived(group, key) } if value.nil?
      # Emitted verbatim into SCSS — reject blanks that would yield broken CSS.
      raise ArgumentError, "token #{key} value must not be blank" if value.strip.empty?

      store[key] = value
    end
  end
end

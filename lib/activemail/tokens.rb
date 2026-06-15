# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'tokens/button_style'
require_relative 'tokens/scss_serializer'

module ActiveMail
  class Tokens
    extend T::Sig

    TokenMap = T.type_alias { T::Hash[Symbol, String] }

    DEFAULT_COLORS = T.let(
      {
        primary: '#2a9d8f',
        secondary: '#264653',
        text: '#1a1a1a',
        background: '#ffffff',
        muted: '#6b7280',
        border: '#e5e7eb',
        button_text: '#ffffff'
      }.freeze,
      TokenMap
    )

    SYSTEM_FONT_STACK = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif'

    DEFAULT_FONTS = T.let(
      {
        body: SYSTEM_FONT_STACK,
        heading: SYSTEM_FONT_STACK
      }.freeze,
      TokenMap
    )

    DEFAULT_SPACINGS = T.let(
      {
        xs: '4px',
        sm: '8px',
        md: '16px',
        lg: '24px',
        xl: '40px'
      }.freeze,
      TokenMap
    )

    DEFAULT_RADII = T.let(
      {
        button: '4px',
        box: '4px'
      }.freeze,
      TokenMap
    )

    # Open/Closed: adding a group here is the only change needed to wire it everywhere.
    GROUPS = T.let(
      {
        color: DEFAULT_COLORS,
        font: DEFAULT_FONTS,
        spacing: DEFAULT_SPACINGS,
        radius: DEFAULT_RADII
      }.freeze,
      T::Hash[Symbol, TokenMap]
    )

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

    sig { params(variant: T.any(String, Symbol)).returns(ButtonStyle) }
    def button_style(variant)
      ButtonStyle.from(self, variant)
    end

    sig { returns(String) }
    def to_scss
      ScssSerializer.call(@stores)
    end

    private

    sig { params(group: Symbol).returns(TokenMap) }
    def store_for(group)
      @stores.fetch(group) { raise KeyError, "unknown token group #{group.inspect}" }
    end

    sig { params(group: Symbol, name: T.any(String, Symbol)).returns(String) }
    def fetch!(group, name)
      store_for(group).fetch(name.to_sym) { raise KeyError, "unknown #{group} token #{name.inspect}" }
    end

    sig { params(group: Symbol, name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def access(group, name, value)
      store = store_for(group)
      key = name.to_sym
      return store[key] if value.nil?
      # Emitted verbatim into SCSS — reject blanks that would yield broken CSS.
      raise ArgumentError, "token #{key} value must not be blank" if value.strip.empty?

      store[key] = value
    end
  end
end

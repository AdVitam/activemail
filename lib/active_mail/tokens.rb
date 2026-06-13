# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  # Design-tokens registry: the single Ruby source of truth, bridged to SCSS by #to_scss.
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

    sig { void }
    def initialize
      @colors = T.let(DEFAULT_COLORS.dup, TokenMap)
      @fonts = T.let(DEFAULT_FONTS.dup, TokenMap)
      @spacings = T.let(DEFAULT_SPACINGS.dup, TokenMap)
    end

    # color/font/spacing act as setter when a value is given, getter otherwise.
    sig { params(name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def color(name, value = nil)
      access(@colors, name, value)
    end

    sig { params(name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def font(name, value = nil)
      access(@fonts, name, value)
    end

    sig { params(name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def spacing(name, value = nil)
      access(@spacings, name, value)
    end

    # Frozen dup: mutating the returned hash must not bypass the DSL setters.
    sig { returns(TokenMap) }
    def colors
      @colors.dup.freeze
    end

    sig { returns(TokenMap) }
    def fonts
      @fonts.dup.freeze
    end

    sig { returns(TokenMap) }
    def spacings
      @spacings.dup.freeze
    end

    # SCSS bridge: !default lets power-users pre-declare overrides upstream.
    # Values are emitted verbatim (trusted, app-controlled input) — not escaped.
    sig { returns(String) }
    def to_scss
      lines = scss_lines('color', @colors) + scss_lines('font', @fonts) + scss_lines('spacing', @spacings)
      "#{lines.join("\n")}\n"
    end

    private

    sig { params(store: TokenMap, name: T.any(String, Symbol), value: T.nilable(String)).returns(T.nilable(String)) }
    def access(store, name, value)
      key = name.to_sym
      return store[key] if value.nil?
      # Emitted verbatim into SCSS by #to_scss — reject blanks that would yield broken CSS.
      raise ArgumentError, "token #{key} value must not be blank" if value.strip.empty?

      store[key] = value
    end

    sig { params(group: String, store: TokenMap).returns(T::Array[String]) }
    def scss_lines(group, store)
      store.map { |name, value| "$am-#{group}-#{scss_name(name)}: #{value} !default;" }
    end

    sig { params(name: Symbol).returns(String) }
    def scss_name(name)
      name.to_s.tr('_', '-')
    end
  end
end

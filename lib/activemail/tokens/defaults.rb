# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  class Tokens
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

    # Optional colors resolve to another token (nil: unset) so components and the
    # SCSS bridge read the same value whether or not the host configured them.
    DERIVED_COLORS = T.let(
      {
        primary_text: :button_text,
        primary_border: nil,
        secondary_text: :button_text,
        secondary_border: nil,
        info_box_background: :background,
        info_box_border: :border,
        info_box_text: :text
      }.freeze,
      T::Hash[Symbol, T.nilable(Symbol)]
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
  end
end

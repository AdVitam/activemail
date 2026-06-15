# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  class Tokens
    # Resolved appearance of a button variant — consumed by the Cta component and
    # mirrored by the .cta/.button SCSS. `border` nil means "no outline".
    class ButtonStyle < T::Struct
      extend T::Sig

      const :background, String
      const :color, String
      const :radius, String
      const :border, T.nilable(String)

      # Resolves a variant (:primary/:secondary/…) from a token registry. color
      # falls back to :button_text; border is opt-in (a "<variant>_border" token).
      sig { params(tokens: ActiveMail::Tokens, variant: T.any(String, Symbol)).returns(ButtonStyle) }
      def self.from(tokens, variant)
        new(
          background: tokens.color!(variant),
          color: tokens.color("#{variant}_text") || tokens.color!(:button_text),
          radius: tokens.radius!(:button),
          border: tokens.color("#{variant}_border")
        )
      end
    end
  end
end

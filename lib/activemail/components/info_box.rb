# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Colors read from tokens at transform time (runtime config), not load-time constants.
    class InfoBox < Base
      extend T::Sig

      sig { override.overridable.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        classes = combine_classes(node, 'info-box')
        [
          %(<table class="#{classes}" #{TABLE_RESET} style="width:100%;"><tbody><tr>),
          %(<td style="#{cell_style}">#{inner}</td>),
          '</tr></tbody></table>'
        ].join
      end

      private

      # Box-scoped tokens (fall back to page-level ones) so a host can give the box
      # a distinct surface without colliding with :background/:border/:text.
      sig { returns(String) }
      def cell_style
        tokens = ActiveMail.tokens
        background = tokens.color(:info_box_background) || tokens.color!(:background)
        border = tokens.color(:info_box_border) || tokens.color!(:border)
        text = tokens.color(:info_box_text) || tokens.color!(:text)
        "background-color:#{background};border-left:5px solid #{border};border-radius:#{tokens.radius!(:box)};" \
          "color:#{text};padding:#{tokens.spacing!(:md)};"
      end
    end
  end
end

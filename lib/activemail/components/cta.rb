# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Colors read from tokens at transform time (runtime config), not load-time constants.
    # Styles are inlined so the button survives clients that strip <style> (Gmail mobile…).
    class Cta < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        # A CTA without a link is an authoring bug — surface it at render time.
        raise ArgumentError, '<cta> requires an href attribute' if node.attr('href').to_s.strip.empty?

        style = ActiveMail.tokens.button_style(class?(node, 'secondary') ? :secondary : :primary)
        anchor = %(<a href="#{escape_attr(node.attr('href'))}"#{target_attribute(node)} ) +
                 %(style="#{link_style(style)}">#{inner}</a>)
        bulletproof_button_table(
          outer_classes: combine_classes(node, 'cta'),
          inner: anchor,
          cell_style: cell_style(style)
        )
      end

      private

      sig { params(style: ActiveMail::Tokens::ButtonStyle).returns(String) }
      def cell_style(style)
        "background:#{style.background};border-radius:#{style.radius};#{border_css(style)}"
      end

      sig { params(style: ActiveMail::Tokens::ButtonStyle).returns(String) }
      def link_style(style)
        "display:inline-block;text-decoration:none;#{BUTTON_PADDING}" \
          "background:#{style.background};color:#{style.color};font-weight:bold;" \
          "border-radius:#{style.radius};#{border_css(style)}"
      end

      sig { params(style: ActiveMail::Tokens::ButtonStyle).returns(String) }
      def border_css(style)
        style.border ? "border:1px solid #{style.border};" : ''
      end
    end
  end
end

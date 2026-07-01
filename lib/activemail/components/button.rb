# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Button < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        expand = class?(node, 'expand')
        inner = anchor(node, inner, expand) if node.attr('href')
        inner = "<center>#{inner}</center>" if expand

        expander = expand ? '<td class="expander"></td>' : ''
        # CSS-driven by design: colors come from .button rules, not inline tokens —
        # a distinct robustness model from <cta>, which inlines its palette.
        bulletproof_button_table(
          outer_classes: combine_classes(node, 'button'),
          inner: inner,
          outer_extra: expander
        )
      end

      private

      sig { params(node: Nokogiri::XML::Node, inner: String, expand: T::Boolean).returns(String) }
      def anchor(node, inner, expand)
        links = link_attributes(node)
        extra = expand ? ' align="center" class="float-center"' : ''
        # Padding on the <a> makes the whole button a clickable target.
        link_style = "display:inline-block;text-decoration:none;#{BUTTON_PADDING}"
        attrs = %(#{pass_through_attributes(node)}href="#{escape_attr(node.attr('href'))}"#{links}#{extra})
        %(<a #{attrs}#{style_attribute(node, link_style)}>#{inner}</a>)
      end
    end
  end
end

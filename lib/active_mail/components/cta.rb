# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Colors read from tokens at transform time (runtime config), not load-time constants.
    class Cta < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        # A CTA without a link is an authoring bug — surface it at render time.
        raise ArgumentError, '<cta> requires an href attribute' if node.attr('href').to_s.strip.empty?

        background = ActiveMail.tokens.color!(class?(node, 'secondary') ? :secondary : :primary)
        classes = combine_classes(node, 'cta')
        anchor = %(<a href="#{escape_attr(node.attr('href'))}"#{target_attribute(node)} style="#{link_style(background)}">#{inner}</a>)
        [
          %(<table class="#{classes}" #{TABLE_RESET}><tbody><tr><td>),
          %(<table #{TABLE_RESET}><tbody><tr><td style="background:#{background};border-radius:4px;">),
          "#{anchor}</td></tr></tbody></table></td></tr></tbody></table>"
        ].join
      end

      private

      sig { params(background: String).returns(String) }
      def link_style(background)
        'display:inline-block;text-decoration:none;padding:12px 24px;' \
          "background:#{background};color:#{ActiveMail.tokens.color!(:button_text)};font-weight:bold;border-radius:4px;"
      end
    end
  end
end

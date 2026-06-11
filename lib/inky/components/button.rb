# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Button < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        expand = class?(node, 'expand')
        inner = anchor(node, inner, expand) if node.attr('href')
        inner = "<center>#{inner}</center>" if expand

        classes = combine_classes(node, 'button')
        expander = expand ? '<td class="expander"></td>' : ''
        [
          %(<table class="#{classes}" #{TABLE_RESET}><tbody><tr><td>),
          %(<table #{TABLE_RESET}><tbody><tr><td>#{inner}</td></tr></tbody></table>),
          %(</td>#{expander}</tr></tbody></table>)
        ].join
      end

      private

      sig { params(node: Nokogiri::XML::Node, inner: String, expand: T::Boolean).returns(String) }
      def anchor(node, inner, expand)
        target = target_attribute(node)
        extra = expand ? ' align="center" class="float-center"' : ''
        # Padding on the <a> makes the whole button a clickable target.
        link_style = 'display:inline-block;text-decoration:none;padding:12px 24px;'
        attrs = %(#{pass_through_attributes(node)}href="#{escape_attr(node.attr('href'))}"#{target}#{extra})
        %(<a #{attrs}#{style_attribute(node, link_style)}>#{inner}</a>)
      end
    end
  end
end

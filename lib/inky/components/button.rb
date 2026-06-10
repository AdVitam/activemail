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
        attributes = pass_through_attributes(node)
        href = node.attr('href')

        if href
          target = target_attribute(node)
          extra = ' align="center" class="float-center"' if expand
          # Padding on the <a> makes the whole button a clickable target.
          link_style = 'display:inline-block;text-decoration:none;padding:12px 24px;'
          inner = %(<a #{attributes}href="#{href}"#{target}#{extra} style="#{link_style}">#{inner}</a>)
        end
        inner = "<center>#{inner}</center>" if expand

        classes = combine_classes(node, 'button')
        expander = '<td class="expander"></td>' if expand
        %(<table class="#{classes}" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td>#{inner}</td></tr></tbody></table></td>#{expander}</tr></tbody></table>)
      end
    end
  end
end

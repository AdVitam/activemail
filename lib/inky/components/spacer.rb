# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Spacer < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, _inner: String).returns(String) }
      def transform(node, _inner)
        classes = combine_classes(node, 'spacer')
        size_sm = node.attr('size-sm')
        size_lg = node.attr('size-lg')

        if size_sm || size_lg
          html = +''
          html << build_table(node, classes, 'hide-for-large', size_sm) if size_sm
          html << build_table(node, classes, 'show-for-large', size_lg) if size_lg
          html
        else
          build_table(node, classes, nil, node.attr('size') || '16')
        end
      end

      private

      sig { params(node: Nokogiri::XML::Node, classes: String, extra: T.nilable(String), size: String).returns(String) }
      def build_table(node, classes, extra, size)
        css_class = extra ? "#{classes} #{extra}" : classes
        # mso-line-height-rule:exactly keeps Outlook from inflating the spacer.
        style = "font-size:#{size}px;line-height:#{size}px;mso-line-height-rule:exactly;"
        %(<table class="#{css_class}" #{TABLE_RESET}#{style_attribute(node, 'width:100%;')}><tbody><tr><td height="#{size}" style="#{style}">&nbsp;</td></tr></tbody></table>)
      end
    end
  end
end

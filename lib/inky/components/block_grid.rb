# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class BlockGrid < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        up = positive_int(node.attr('up'))
        classes = combine_classes(node, ['block-grid', up && "up-#{up}"].compact.join(' '))
        %(<table class="#{classes}" #{TABLE_RESET}#{style_attribute(node, 'width:100%;')}><tbody><tr>#{inner}</tr></tbody></table>)
      end
    end
  end
end

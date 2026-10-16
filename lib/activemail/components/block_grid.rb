# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    class BlockGrid < TableComponent
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        up = positive_int(node.attr('up'))
        classes = ['block-grid', up && "up-#{up}"].compact.join(' ')
        %(<table#{root_attributes(node, classes: classes, layout_style: 'width:100%;')} #{TABLE_RESET}><tbody><tr>#{inner}</tr></tbody></table>)
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        [*super, 'up']
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    class Row < TableComponent
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        %(<table#{root_attributes(node, classes: 'row', layout_style: 'width:100%;')} #{TABLE_RESET}><tbody><tr>#{inner}</tr></tbody></table>)
      end
    end
  end
end

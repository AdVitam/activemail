# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    class HLine < TableComponent
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, _inner: String).returns(String) }
      def transform(node, _inner)
        %(<table#{root_attributes(node, classes: 'h-line', layout_style: 'width:100%;')} #{TABLE_RESET}><tbody><tr><th>&nbsp;</th></tr></tbody></table>)
      end
    end
  end
end

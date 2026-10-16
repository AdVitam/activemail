# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    class Menu < TableComponent
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        [
          %(<table#{root_attributes(node, classes: 'menu')} #{TABLE_RESET}><tbody><tr><td>),
          %(<table #{TABLE_RESET}><tbody><tr>#{inner}</tr></tbody></table>),
          '</td></tr></tbody></table>'
        ].join
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Row < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'row')
        %(<table #{attributes} #{TABLE_RESET}#{style_attribute(node, 'width:100%;')}><tbody><tr>#{inner}</tr></tbody></table>)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Wrapper < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'wrapper')
        [
          %(<table #{attributes} #{TABLE_RESET} align="center"#{style_attribute(node, 'width:100%;')}><tbody><tr>),
          %(<td class="wrapper-inner">#{inner}</td></tr></tbody></table>)
        ].join
      end
    end
  end
end

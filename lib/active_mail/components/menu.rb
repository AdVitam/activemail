# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Menu < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'menu')
        [
          %(<table #{attributes} #{TABLE_RESET}#{style_attribute(node)}><tbody><tr><td>),
          %(<table #{TABLE_RESET}><tbody><tr>#{inner}</tr></tbody></table>),
          '</td></tr></tbody></table>'
        ].join
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Menu < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'menu')
        %(<table #{attributes} role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr>#{inner}</tr></tbody></table></td></tr></tbody></table>)
      end
    end
  end
end

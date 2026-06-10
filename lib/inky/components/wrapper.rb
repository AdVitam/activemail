# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Wrapper < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'wrapper')
        %(<table #{attributes} role="presentation" align="center" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr><td class="wrapper-inner">#{inner}</td></tr></tbody></table>)
      end
    end
  end
end

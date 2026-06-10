# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class BlockGrid < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        classes = combine_classes(node, "block-grid up-#{node.attr('up')}")
        %(<table class="#{classes}" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr>#{inner}</tr></tbody></table>)
      end
    end
  end
end

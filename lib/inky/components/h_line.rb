# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class HLine < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, _inner: String).returns(String) }
      def transform(node, _inner)
        classes = combine_classes(node, 'h-line')
        attributes = pass_through_attributes(node)
        %(<table #{attributes}class="#{classes}" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr><th>&nbsp;</th></tr></tbody></table>)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Callout < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        classes = combine_classes(node, 'callout-inner')
        attributes = pass_through_attributes(node)
        %(<table #{attributes}class="callout" role="presentation" border="0" cellpadding="0" cellspacing="0"#{style_attribute(node, 'width:100%;')}><tbody><tr><th class="#{classes}">#{inner}</th><th class="expander"></th></tr></tbody></table>)
      end
    end
  end
end

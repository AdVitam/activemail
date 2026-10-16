# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Callout < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        classes = combine_classes(node, 'callout-inner')
        [
          %(<table#{root_attributes(node, classes: 'callout', layout_style: 'width:100%;')} #{TABLE_RESET}><tbody><tr>),
          %(<th class="#{escape_attr(classes)}">#{inner}</th><th class="expander"></th>),
          '</tr></tbody></table>'
        ].join
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        TABLE_RESET_ATTRIBUTES
      end
    end
  end
end

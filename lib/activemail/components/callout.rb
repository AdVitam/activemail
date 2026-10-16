# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    class Callout < TableComponent
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        classes = combine_classes(node, 'callout-inner')
        [
          %(<table class="callout"#{passthrough_attributes(node)}#{style_attribute(node, 'width:100%;')} #{TABLE_RESET}><tbody><tr>),
          %(<th class="#{escape_attr(classes)}">#{inner}</th><th class="expander"></th>),
          '</tr></tbody></table>'
        ].join
      end
    end
  end
end

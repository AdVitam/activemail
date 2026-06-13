# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Center < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, _inner: String).returns(String) }
      def transform(node, _inner)
        elements = node.elements
        elements.each do |child|
          child['align'] = 'center'
          child['class'] = combine_classes(child, 'float-center')
        end
        items = elements.css('.menu-item').to_a.concat(elements.css('item').to_a)
        items.each { |item| item['class'] = combine_classes(item, 'float-center') }
        node.to_s
      end
    end
  end
end

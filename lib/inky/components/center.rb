# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Center < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, _inner)
        node.elements.each do |child|
          child['align'] = 'center'
          child['class'] = combine_classes(child, 'float-center')
          items = node.elements.css('.menu-item').to_a.concat(node.elements.css('item').to_a)
          items.each do |item|
            item['class'] = combine_classes(item, 'float-center')
          end
        end
        node.to_s
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Center < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        node.elements.each do |child|
          child['align'] = 'center'
          child['class'] = combine_classes(child, 'float-center')
        end
        node.css('.menu-item').each { |item| item['class'] = combine_classes(item, 'float-center') }
        %(<center#{root_attributes(node, classes: 'float-center')} align="center">#{inner}</center>)
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        ['align']
      end
    end
  end
end

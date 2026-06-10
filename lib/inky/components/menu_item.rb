# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class MenuItem < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        target = target_attribute(node)
        attributes = combine_attributes(node, 'menu-item')
        %(<#{::Inky::Core::INTERIM_TH_TAG} #{attributes}><a href="#{node.attr('href')}"#{target}>#{inner}</a></#{::Inky::Core::INTERIM_TH_TAG}>)
      end
    end
  end
end

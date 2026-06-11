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
        anchor = %(<a href="#{escape_attr(node.attr('href'))}"#{target}>#{inner}</a>)
        %(<#{::Inky::Core::INTERIM_TH_TAG} #{attributes}#{style_attribute(node)}>#{anchor}</#{::Inky::Core::INTERIM_TH_TAG}>)
      end
    end
  end
end

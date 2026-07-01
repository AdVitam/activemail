# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class MenuItem < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'menu-item')
        # No href → a non-link item, not a broken <a href="">; mirrors <button>.
        content = node.attr('href') ? %(<a href="#{escape_attr(node.attr('href'))}"#{link_attributes(node)}>#{inner}</a>) : inner
        th = ::ActiveMail::Core::INTERIM_TH_TAG
        %(<#{th} #{attributes}#{style_attribute(node)}>#{content}</#{th}>)
      end
    end
  end
end

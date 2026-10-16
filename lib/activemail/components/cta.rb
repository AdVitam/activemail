# typed: strict
# frozen_string_literal: true

require_relative 'button_renderer'

module ActiveMail
  module Components
    class Cta < ButtonRenderer
      extend T::Sig

      sig { override.returns(String) }
      def root_class
        'cta'
      end

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        # A CTA without a link is an authoring bug — surface it at render time.
        raise ArgumentError, '<cta> requires an href attribute' if node.attr('href').to_s.strip.empty?

        super
      end
    end
  end
end

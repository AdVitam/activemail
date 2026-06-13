# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Bordered panel. Colors read from tokens at transform time (runtime config).
    class InfoBox < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        classes = combine_classes(node, 'info-box')
        [
          %(<table class="#{classes}" #{TABLE_RESET} style="width:100%;"><tbody><tr>),
          %(<td style="#{cell_style}">#{inner}</td>),
          '</tr></tbody></table>'
        ].join
      end

      private

      sig { returns(String) }
      def cell_style
        tokens = ActiveMail.tokens
        "background-color:#{tokens.color!(:background)};border-left:5px solid #{tokens.color!(:border)};" \
          "color:#{tokens.color!(:text)};padding:16px;"
      end
    end
  end
end

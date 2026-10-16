# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Colors read from tokens at transform time (runtime config), not load-time constants.
    class InfoBox < Base
      extend T::Sig

      sig { override.overridable.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        [
          %(<table#{root_attributes(node, classes: 'info-box', layout_style: 'width:100%;')} #{TABLE_RESET}><tbody><tr>),
          %(<td style="#{cell_style}">#{inner}</td>),
          '</tr></tbody></table>'
        ].join
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        TABLE_RESET_ATTRIBUTES
      end

      sig { returns(String) }
      def cell_style
        tokens = ActiveMail.tokens
        "background-color:#{tokens.color!(:info_box_background)};border-left:5px solid #{tokens.color!(:info_box_border)};" \
          "border-radius:#{tokens.radius!(:box)};color:#{tokens.color!(:info_box_text)};padding:#{tokens.spacing!(:md)};"
      end
    end
  end
end

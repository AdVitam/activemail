# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    # Colors read from tokens at transform time (runtime config), not load-time constants.
    class InfoBox < TableComponent
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

      sig { returns(String) }
      def cell_style
        tokens = core.config.tokens
        "background-color:#{tokens.color!(:info_box_background)};border-left:5px solid #{tokens.color!(:info_box_border)};" \
          "border-radius:#{tokens.radius!(:box)};color:#{tokens.color!(:info_box_text)};padding:#{tokens.spacing!(:md)};"
      end
    end
  end
end

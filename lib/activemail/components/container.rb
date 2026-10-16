# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    class Container < TableComponent
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        width = container_width
        attributes = root_attributes(node, classes: 'container', layout_style: "width:100%;max-width:#{width}px;margin:0 auto;")
        # Outlook Word ignores max-width; the MSO ghost table pins the width.
        [
          %(<!--[if mso | IE]><table #{TABLE_RESET} align="center" width="#{width}"><tr><td><![endif]-->),
          %(<table#{attributes} #{TABLE_RESET} align="center">),
          %(<tbody><tr><td>#{inner}</td></tr></tbody></table>),
          '<!--[if mso | IE]></td></tr></table><![endif]-->'
        ].join
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        [*super, 'align']
      end
    end
  end
end

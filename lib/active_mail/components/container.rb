# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Container < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'container')
        width = container_width
        # Outlook Word ignores max-width; the MSO ghost table pins the width.
        [
          %(<!--[if mso | IE]><table #{TABLE_RESET} align="center" width="#{width}"><tr><td><![endif]-->),
          %(<table #{attributes} #{TABLE_RESET} align="center"#{style_attribute(node, "width:100%;max-width:#{width}px;margin:0 auto;")}>),
          %(<tbody><tr><td>#{inner}</td></tr></tbody></table>),
          '<!--[if mso | IE]></td></tr></table><![endif]-->'
        ].join
      end
    end
  end
end

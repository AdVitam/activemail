# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Container < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        attributes = combine_attributes(node, 'container')
        width = container_width
        # Outlook Word ignores max-width; the MSO ghost table pins the width.
        <<~HTML.delete("\n")
          <!--[if mso | IE]><table role="presentation" align="center" border="0" cellpadding="0" cellspacing="0" width="#{width}"><tr><td><![endif]-->
          <table #{attributes} role="presentation" align="center" border="0" cellpadding="0" cellspacing="0"#{style_attribute(node, "width:100%;max-width:#{width}px;margin:0 auto;")}><tbody><tr><td>#{inner}</td></tr></tbody></table>
          <!--[if mso | IE]></td></tr></table><![endif]-->
        HTML
      end
    end
  end
end

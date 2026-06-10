# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    # The <inky> tag is a marker that renders a bare <tr>, mirroring inky.js.
    class Inky < Base
      extend T::Sig

      sig { override.params(_node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(_node, inner)
        %(<tr>#{inner}</tr>)
      end
    end
  end
end

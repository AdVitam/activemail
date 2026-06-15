# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Renders a bare <tr>, useful inside hand-written tables.
    class Inky < Base
      extend T::Sig

      sig { override.params(_node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(_node, inner)
        %(<tr>#{inner}</tr>)
      end
    end
  end
end
